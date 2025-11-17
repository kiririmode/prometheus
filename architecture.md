# Prometheus Monitoring Architecture

## 概要

外部のClaude Codeから送信されるOpenTelemetryメトリクスをAWS Managed Service for Prometheus (AMP)で受信し、セルフホストGrafana（ECS Fargate）で可視化するアーキテクチャ。

### 環境仕様

- **環境**: 開発環境（dev）
- **リージョン**: ap-northeast-1（東京）
- **VPC**: 新規作成
- **Grafana**: セルフホスト（ECS Fargate上に構築）

## アーキテクチャ図

```
┌─────────────────┐
│  Claude Code    │
│   (External)    │
└────────┬────────┘
         │ OTLP/HTTP or OTLP/gRPC
         │ (Port 4318/4317)
         ▼
┌─────────────────────────────────────┐
│         AWS Cloud (VPC)             │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  Application Load Balancer   │  │
│  │  (Public-facing)             │  │
│  └──────────┬───────────────────┘  │
│             │                       │
│             ▼                       │
│  ┌──────────────────────────────┐  │
│  │  ECS Fargate / EC2           │  │
│  │  OpenTelemetry Collector     │  │
│  │  - Receiver: OTLP            │  │
│  │  - Exporter: Prometheus      │  │
│  │    Remote Write              │  │
│  └──────────┬───────────────────┘  │
│             │ Remote Write API      │
│             │ (SigV4 Auth)          │
│             ▼                       │
│  ┌──────────────────────────────┐  │
│  │  AWS Managed Prometheus      │  │
│  │  (AMP Workspace)             │  │
│  └──────────┬───────────────────┘  │
│             │                       │
│             │ PromQL Query          │
│             ▼                       │
│  ┌──────────────────────────────┐  │
│  │  ECS Fargate                 │  │
│  │  Grafana (Self-hosted)       │  │
│  │  - Data Source: AMP          │  │
│  │  - Dashboard/Alerts          │  │
│  └──────────────────────────────┘  │
│             ↑                       │
└─────────────┼───────────────────────┘
              │ HTTPS Access (ALB)
              │
         (Operators)
```

## コンポーネント

### 1. AWS Managed Prometheus (AMP)

- **目的**: Prometheusメトリクスの保存とクエリ
- **機能**:
  - Prometheus Remote Write APIによるメトリクス受信
  - 長期保存（150日のデフォルト保持期間）
  - PromQLクエリのサポート
  - 自動スケーリング

### 2. OpenTelemetry Collector

- **デプロイ先**: ECS FargateまたはEC2
- **目的**: OTLPメトリクスの受信とPrometheus形式への変換
- **必要性**: Claude CodeはOTLPのみサポートし、AMPはPrometheus Remote Writeのみ受付。Collectorでプロトコル変換が必須 → [詳細な理由](./why-otel-collector.md)
- **構成**:
  - **Receiver**: OTLP (HTTP: 4318)
  - **Processor**: Batch, Memory Limiter
  - **Exporter**: Prometheus Remote Write (SigV4認証)

### 3. Application Load Balancer (ALB)

- **目的**: 外部からのOTLPトラフィックのルーティング
- **機能**:
  - HTTPSターミネーション (TLS 1.2+)
  - ヘルスチェック
  - セキュリティグループによるアクセス制御

### 4. Grafana（セルフホスト on ECS Fargate）

- **目的**: メトリクスの可視化
- **デプロイ先**: ECS Fargate
- **機能**:
  - AMPデータソース統合（SigV4認証）
  - ダッシュボード作成・管理
  - アラート設定
  - 基本認証またはOAuth
- **データ永続化**:
  - オプション1: EFSボリューム（ダッシュボード、プラグイン保存用）
  - オプション2: 環境変数/ConfigMapでダッシュボードをコード管理（推奨）
  - 詳細な比較とベストプラクティスは[Grafana データ永続化戦略](./grafana-storage-strategy.md)を参照

### 5. ネットワーク構成

- **VPC**: 専用VPC（CIDR: 10.0.0.0/16）
- **サブネット**:
  - パブリックサブネット × 2 (Multi-AZ): ALB用
  - プライベートサブネット × 2 (Multi-AZ): OTel Collector用
- **NAT Gateway**: OTel CollectorからAWSサービスへのアウトバウンド通信用
- **VPC Endpoints**: AMP, CloudWatch Logs等へのプライベート接続（コスト最適化）

## セキュリティ

### IAM Roles

1. **OTel Collector Task Role**
   - AMP Remote Write権限（`aps:RemoteWrite`）
   - CloudWatch Logs書き込み権限
   - ECRイメージ取得権限（ECS Task Execution Role経由）

2. **Grafana Task Role**
   - AMP読み取り権限（`aps:QueryMetrics`, `aps:GetSeries`, `aps:GetLabels`, `aps:GetMetricMetadata`）
   - CloudWatch Logs書き込み権限

3. **ECS Task Execution Role**（共通）
   - ECRイメージpull権限
   - CloudWatch Logsストリーム作成権限
   - Secrets Manager読み取り権限（環境変数用）

### Security Groups

1. **ALB Security Group（OTel用）**
   - Inbound: HTTPS (443) - Claude Codeからのアクセス（特定IPまたは0.0.0.0/0）
   - Outbound: OTel Collector (4318)

2. **ALB Security Group（Grafana用）**
   - Inbound: HTTPS (443) - 運用者のIPアドレス範囲のみ
   - Outbound: Grafana (3000)

3. **OTel Collector Security Group**
   - Inbound: ALBからの4318
   - Outbound: HTTPS (443) - AMP API, VPC Endpoints

4. **Grafana Security Group**
   - Inbound: ALBからの3000
   - Outbound: HTTPS (443) - AMP API, VPC Endpoints

5. **EFS Security Group**（Grafana用データ永続化）
   - Inbound: NFS (2049) - Grafana Security Groupから
   - Outbound: なし

### 認証・認可

- **Claude Code → ALB（OTel）**:
  - オプション1: API Key（カスタムヘッダー）
  - オプション2: 認証なし（Security Groupで制御）
- **運用者 → ALB（Grafana）**: HTTPS経由でアクセス
- **Grafana ログイン**: 基本認証（admin/password）、環境変数で設定
- **OTel Collector → AMP**: AWS SigV4署名（IAM Task Role）
- **Grafana → AMP**: AWS SigV4署名（IAM Task Role、Grafana AWS SDK plugin使用）

## データフロー

1. Claude Codeが外部からOTLPメトリクスを送信（HTTPS経由）
2. ALBがリクエストを受信し、OTel Collectorに転送
3. OTel CollectorがOTLPメトリクスを受信
4. Collectorがメトリクスを処理し、Prometheus形式に変換
5. CollectorがAMP Remote Write APIを使用してメトリクスを送信（SigV4認証）
6. AMPがメトリクスを保存
7. GrafanaがAMPからメトリクスをクエリして可視化

## スケーラビリティ

- **OTel Collector**: ECS Fargateのオートスケーリング（CPU/メモリベース）
- **AMP**: フルマネージド、AWS側が自動スケーリング
- **ALB**: トラフィックに応じて自動スケーリング

## モニタリング・アラート

- OTel Collectorのメトリクス（self-monitoring）
- CloudWatch Logsでログ集約
- CloudWatch Alarmsで異常検知
- Grafanaでカスタムアラート

## コスト最適化（開発環境向け）

1. **VPC Endpoints**: AMP, CloudWatch Logs用のVPC Endpointsを作成しNAT Gateway料金を削減
2. **Fargate Spot**: 開発環境ではSpotキャパシティを使用（コスト削減50-70%）
3. **NAT Gateway**: Single-AZ構成（本番ではMulti-AZ推奨）
4. **AMP保持期間**: 短め（30日程度）に設定
5. **ECS Task最小構成**: CPU 0.25 vCPU、メモリ0.5 GB（開発環境）
6. **CloudWatch Logs保持**: 7日間
7. **Grafana**: Dashboards as CodeでEFS不使用（月額 $20削減）- [詳細](./grafana-storage-strategy.md#コスト比較開発環境月額)

## Terraform構成とベストプラクティス

### ディレクトリ構造

```
.
├── README.md                       # セットアップガイド、使い方
├── .gitignore                      # 機密情報除外設定
├── backend.tf                      # S3バックエンド設定（tfstate管理）
├── main.tf                         # プロバイダー設定、モジュール呼び出し
├── variables.tf                    # 入力変数定義
├── outputs.tf                      # 出力値定義
├── locals.tf                       # ローカル変数、タグ戦略
├── terraform.tfvars.example        # 変数値サンプル（Git管理）
├── terraform.tfvars                # 実際の変数値（Git除外）
│
├── modules/                        # 再利用可能なモジュール群
│   ├── network/                    # VPC、サブネット、NAT、IGW
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   │
│   ├── security-groups/            # セキュリティグループ
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── iam/                        # IAM Roles & Policies
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── policies/
│   │       ├── otel-task-role.json
│   │       └── grafana-task-role.json
│   │
│   ├── amp/                        # AWS Managed Prometheus
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecs-cluster/                # ECS Cluster
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── alb/                        # Application Load Balancer
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── efs/                        # EFS for Grafana persistence
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── otel-collector/             # OpenTelemetry Collector (ECS)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── templates/
│   │       └── task-definition.json.tpl
│   │
│   └── grafana/                    # Grafana (ECS)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── templates/
│           └── task-definition.json.tpl
│
└── configs/                        # アプリケーション設定ファイル
    ├── otel-collector-config.yaml  # OTel Collector設定
    └── grafana/
        └── provisioning/           # Grafana Provisioning設定（推奨）
            ├── datasources/        # データソース設定
            │   └── amp-datasource.yaml
            ├── dashboards/         # ダッシュボード設定
            │   ├── dashboards.yaml # プロバイダー設定
            │   └── default/        # ダッシュボードJSON格納
            │       └── sample.json
            └── notifiers/          # 通知設定（オプション）
                └── slack.yaml
        # 詳細は grafana-storage-strategy.md を参照
```

### 適用するベストプラクティス

#### 1. モジュール化

- 各コンポーネントを独立したモジュールとして実装
- 再利用性と保守性を向上
- 明確な入力（variables）と出力（outputs）の定義

#### 2. 変数管理

- `variables.tf`: 型、デフォルト値、説明を明記
- `terraform.tfvars`: 環境固有の値を設定
- `terraform.tfvars.example`: サンプルとして提供（機密情報なし）

#### 3. State管理

- S3バックエンドでリモート管理
- DynamoDB使用でstate locking有効化
- バージョニング有効化でロールバック可能に

#### 4. タグ戦略

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = "prometheus-monitoring"
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}
```

#### 5. セキュリティ

- IAM Roleは最小権限原則
- Security Groupは必要最小限のポート開放
- 機密情報はSecrets ManagerまたはParameter Store使用
- `.gitignore` で `*.tfstate`、`*.tfvars` を除外

#### 6. 命名規則

```
{project}-{environment}-{resource-type}-{name}
例: prometheus-dev-alb-otel
   prometheus-dev-ecs-cluster
   prometheus-dev-sg-grafana
```

#### 7. ドキュメント

- 各モジュールにREADME.md
- 使用方法、入力変数、出力値を記載
- アーキテクチャ図の更新

#### 8. バージョン管理

- Terraformバージョンを `required_version` で固定
- Providerバージョンを `required_providers` で固定

```hcl
terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

## 実装計画

### Phase 1: 基礎インフラ（ネットワーク、セキュリティ）

1. **ネットワークモジュール** (`modules/network/`)
   - VPC作成（CIDR: 10.0.0.0/16）
   - パブリックサブネット × 2（ap-northeast-1a, 1c）
   - プライベートサブネット × 2（ap-northeast-1a, 1c）
   - Internet Gateway
   - NAT Gateway × 1（開発環境、Single-AZ）
   - ルートテーブル

2. **セキュリティグループモジュール** (`modules/security-groups/`)
   - ALB（OTel用）: 443 → 4318/4317
   - ALB（Grafana用）: 443 → 3000
   - OTel Collector: 4318/4317から、443へ
   - Grafana: 3000から、443へ
   - EFS: 2049（NFS）

3. **IAMモジュール** (`modules/iam/`)
   - ECS Task Execution Role（共通）
   - OTel Collector Task Role（AMP書き込み）
   - Grafana Task Role（AMP読み取り）

### Phase 2: データストレージ（AMP、EFS）

4. **AMPモジュール** (`modules/amp/`)
   - Workspaceリソース作成
   - タグ設定
   - アラートマネージャー（オプション）

5. **EFSモジュール（オプション）** (`modules/efs/`)
   - EFSファイルシステム作成（Grafana用、Dashboards as Codeを使用する場合は不要）
   - マウントターゲット × 2（Multi-AZ）
   - バックアップポリシー（AWS Backup連携）
   - 詳細は[Grafana データ永続化戦略](./grafana-storage-strategy.md)を参照

### Phase 3: コンピューティング（ECS、ALB）

6. **ECSクラスターモジュール** (`modules/ecs-cluster/`)
   - Fargateクラスター作成
   - Container Insights有効化
   - クラスター設定

7. **ALBモジュール** (`modules/alb/`)
   - ALB × 2作成（OTel用、Grafana用）
   - ターゲットグループ作成
   - リスナー設定（HTTP/HTTPS）
   - ヘルスチェック設定

### Phase 4: アプリケーション（OTel、Grafana）

8. **OTel Collectorモジュール** (`modules/otel-collector/`)
   - ECS Task Definition作成
   - コンテナイメージ: `otel/opentelemetry-collector-contrib:latest`
   - 環境変数設定（AMP endpoint等）
   - ECS Service作成（desired count: 2、開発環境では1）
   - Auto Scaling設定

9. **Grafanaモジュール** (`modules/grafana/`)
   - ECS Task Definition作成
   - コンテナイメージ: `grafana/grafana:latest`
   - EFSボリュームマウント設定
   - 環境変数設定（admin password等）
   - ECS Service作成（desired count: 1）

### Phase 5: 設定ファイル・統合

10. **設定ファイル作成** (`configs/`)
    - `otel-collector-config.yaml`: OTLP Receiver、Prometheus Remote Write Exporter
    - `grafana/provisioning/datasources/`: AMPデータソース設定（SigV4認証）
    - `grafana/provisioning/dashboards/`: サンプルダッシュボード（JSON）
    - 詳細なディレクトリ構造は[Grafana データ永続化戦略](./grafana-storage-strategy.md#ディレクトリ構造例)を参照

11. **ルートモジュール統合** (ルートディレクトリ)
    - `main.tf`: 全モジュール呼び出し
    - `variables.tf`: 共通変数定義
    - `outputs.tf`: ALB URL等の出力
    - `backend.tf`: S3バックエンド設定

## デプロイ手順

### 事前準備

1. **必要なツールのインストール**

   ```bash
   # Terraform
   brew install terraform  # macOS
   # または https://www.terraform.io/downloads

   # AWS CLI
   brew install awscli  # macOS
   ```

2. **AWS認証情報の設定**

   ```bash
   aws configure --profile prometheus-dev
   # Access Key ID、Secret Access Key、Region（ap-northeast-1）を設定
   ```

3. **S3バケット作成（tfstate用）**

   ```bash
   aws s3 mb s3://prometheus-terraform-state-dev --region ap-northeast-1
   aws s3api put-bucket-versioning \
     --bucket prometheus-terraform-state-dev \
     --versioning-configuration Status=Enabled
   ```

4. **DynamoDBテーブル作成（state lock用）**
   ```bash
   aws dynamodb create-table \
     --table-name prometheus-terraform-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
     --region ap-northeast-1
   ```

### Terraform実行

1. **環境変数ファイルの作成**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvarsを編集（環境に合わせて値を設定）
   ```

2. **初期化**

   ```bash
   terraform init
   ```

3. **プランの確認**

   ```bash
   terraform plan -out=tfplan
   ```

4. **適用**

   ```bash
   terraform apply tfplan
   ```

5. **出力値の確認**
   ```bash
   terraform output
   # OTel Collector ALB URL、Grafana ALB URLが表示される
   ```

### アプリケーション設定

1. **Grafana初期設定**
   - Grafana ALB URLにアクセス（`terraform output grafana_url`）
   - 初期パスワードでログイン（`terraform output grafana_admin_password`）
   - AMPデータソースが自動設定されていることを確認

2. **Claude Code設定**

   ```yaml
   # Claude Code側のOTLP Exporter設定例
   exporters:
     otlp:
       endpoint: "<OTel Collector ALB URL>:443"
       tls:
         insecure: false
   ```

3. **動作確認**
   - Claude Codeからメトリクスを送信
   - Grafana Exploreでメトリクスが表示されることを確認

## リソース仕様（開発環境）

### ネットワーク

| リソース               | 仕様                                                             |
| ---------------------- | ---------------------------------------------------------------- |
| VPC CIDR               | 10.0.0.0/16                                                      |
| パブリックサブネット   | 10.0.1.0/24 (ap-northeast-1a)<br>10.0.2.0/24 (ap-northeast-1c)   |
| プライベートサブネット | 10.0.11.0/24 (ap-northeast-1a)<br>10.0.12.0/24 (ap-northeast-1c) |
| NAT Gateway            | 1個（ap-northeast-1a、開発環境）                                 |

### ECS Task仕様

#### OpenTelemetry Collector

| 項目             | 値                                            |
| ---------------- | --------------------------------------------- |
| CPU              | 0.5 vCPU (512)                                |
| メモリ           | 1 GB (1024 MB)                                |
| Desired Count    | 1（開発環境）、2（本番環境推奨）              |
| Launch Type      | FARGATE（開発環境はFARGATE_SPOT推奨）         |
| コンテナイメージ | `otel/opentelemetry-collector-contrib:latest` |
| ポート           | 4318 (HTTP)                                   |

#### Grafana

| 項目             | 値                       |
| ---------------- | ------------------------ |
| CPU              | 0.25 vCPU (256)          |
| メモリ           | 0.5 GB (512 MB)          |
| Desired Count    | 1                        |
| Launch Type      | FARGATE                  |
| コンテナイメージ | `grafana/grafana:latest` |
| ポート           | 3000                     |
| ボリューム       | EFS（/var/lib/grafana）  |

### ALB仕様

| 項目               | 値                                                          |
| ------------------ | ----------------------------------------------------------- |
| Scheme             | internet-facing                                             |
| IP Address Type    | ipv4                                                        |
| Load Balancer Type | application                                                 |
| Target Type        | ip（Fargate用）                                             |
| Health Check       | HTTP:4318/health（OTel）<br>HTTP:3000/api/health（Grafana） |

### AMP仕様

| 項目            | 値               |
| --------------- | ---------------- |
| Workspace Alias | prometheus-dev   |
| Data Retention  | 30日（開発環境） |

### EFS仕様

| 項目             | 値                              |
| ---------------- | ------------------------------- |
| Performance Mode | General Purpose                 |
| Throughput Mode  | Bursting（開発環境）            |
| Encryption       | 有効化（aws/elasticfilesystem） |

## 想定コスト（ap-northeast-1、月額概算）

### 開発環境

| サービス        | 項目                                     | 月額（USD）  |
| --------------- | ---------------------------------------- | ------------ |
| ECS Fargate     | OTel Collector (0.5 vCPU, 1GB) × 1 × 24h | ~$35         |
| ECS Fargate     | Grafana (0.25 vCPU, 0.5GB) × 1 × 24h     | ~$15         |
| ALB             | 2個 × 730時間                            | ~$30         |
| NAT Gateway     | 1個 × 730時間 + データ転送               | ~$40         |
| AMP             | サンプル処理（100万サンプル/月）         | ~$5          |
| EFS             | 5GB（Grafana用）                         | ~$2          |
| CloudWatch Logs | 10GB/月                                  | ~$5          |
| **合計**        |                                          | **~$132/月** |

### コスト削減オプション

- Fargate Spotの使用: $50削減（-38%）
- VPC Endpoints使用（NAT Gateway削減）: $30削減
- Grafana Dashboards as Code（EFS不使用）: $20削減 - [詳細](./grafana-storage-strategy.md)
- **最適化後合計**: ~$32/月

## 運用考慮事項

### バックアップ・永続化

- **Grafanaダッシュボード**: EFSバックアップ、またはダッシュボードJSON定義をGit管理
- **AMPデータ**: 自動的に30日間保持（設定可能）
- **Terraformステート**: S3バージョニング有効化

### モニタリング

- ECS Container Insights有効化（CPU/メモリ使用率）
- CloudWatch Alarmsでタスク異常終了を検知
- OTel CollectorのSelf-MonitoringメトリクスをAMPに送信
- Grafana自体のメトリクス可視化

### セキュリティ更新

- **コンテナイメージ**: 月1回の定期更新（latest tag使用の場合）
- **Terraform**: 四半期ごとにProvider更新
- **AWS VPC/セキュリティグループ**: 必要に応じて見直し

### スケーリング

- **OTel Collector**: CPU使用率70%でスケールアウト（最大4タスク）
- **Grafana**: 通常スケーリング不要（読み取り専用のため）

### ディザスタリカバリ

- 開発環境ではSingle-AZ構成
- 本番環境ではMulti-AZ（2つ以上のAZ）推奨

### ログ管理

- CloudWatch Logs保持期間: 7日（開発環境）
- ログフォーマット: JSON（構造化ログ）
- ログレベル: INFO（開発環境）、WARN（本番環境）

## トラブルシューティング

### OTel Collectorにメトリクスが届かない

1. Security Groupでポート4318が開放されているか確認
2. Claude CodeのExporter設定確認（エンドポイントURL、TLS設定）
3. CloudWatch LogsでOTel Collectorのログ確認
4. ALBターゲットヘルスチェックの確認

### AMPにデータが書き込まれない

1. IAM Task RoleにAMP書き込み権限があるか確認
2. OTel CollectorログでSigV4認証エラー確認
3. AMPワークスペースのメトリクス受信状況確認（AWS Console）

### Grafanaでデータが表示されない

1. Grafana DataSource設定確認（AMP endpoint、SigV4認証）
2. IAM Task RoleにAMP読み取り権限があるか確認
3. Grafana Explore機能で直接PromQLクエリ実行

## 参考リソース

### AWS公式ドキュメント

- [AWS Managed Prometheus](https://docs.aws.amazon.com/prometheus/)
- [Amazon ECS](https://docs.aws.amazon.com/ecs/)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/)

### OpenTelemetry

- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)
- [Prometheus Remote Write Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusremotewriteexporter)

### Grafana

- [Grafana Documentation](https://grafana.com/docs/)
- [Grafana AWS SDK Plugin](https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/aws-authentication/)

### Terraform

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
