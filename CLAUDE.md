# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリは、外部のClaude CodeからOpenTelemetryメトリクスを受信し、AWS Managed Prometheus (AMP)で保存、ECS Fargate上のGrafanaで可視化する監視基盤をTerraformで構築するプロジェクトである。

**重要**: 実装時は利用可能なMCPサーバー（Terraform、AWS Documentation、AWS Pricing、GitHub、Perplexity）を積極的に活用し、最新の情報と効率的な実装を心がけること。

## 開発コマンド

### Linting & Formatting

```bash
# Markdown文書の日本語校正
npx textlint *.md

# Pre-commitフックの手動実行（全ファイル）
pre-commit run --all-files

# Pre-commitフックの実行（変更ファイルのみ）
pre-commit run
```

### Git操作

```bash
# コミット前チェック（pre-commit hooksが自動実行される）
git commit -m "message"

# Terraformコードのフォーマット
terraform fmt -recursive
```

### Terraform セットアップ

#### バックエンド構築（初回のみ）

Terraformのstateファイルを管理するS3バケットとDynamoDBテーブルを作成する。

```bash
# 自動セットアップスクリプトを使用（推奨）
./scripts/setup-backend.sh
```

このスクリプトは以下を自動的に実行する：

- S3バケットの作成（`prometheus-terraform-state-dev`）
- バージョニングの有効化
- AES256暗号化の設定
- パブリックアクセスのブロック
- TLS強制のバケットポリシー適用
- 90日後に古いバージョンを削除するライフサイクルポリシー
- DynamoDBテーブルの作成（`prometheus-terraform-lock`、PAY_PER_REQUESTモード）
- 適切なタグの設定

**手動セットアップ（非推奨）**: 手動で作成する場合は `architecture.md` のデプロイ手順を参照。

#### バックエンド削除（クリーンアップ時）

**警告**: このコマンドは全てのTerraform stateファイルを削除する。

```bash
# バックエンドのクリーンアップ
./scripts/destroy-backend.sh
```

#### Terraform実行手順

```bash
# 1. 変数ファイルの作成
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsを編集（environment, owner, パスワード等を設定）

# 2. 初期化
terraform init

# 3. プランの確認
terraform plan -out=tfplan

# 4. 適用
terraform apply tfplan

# 5. 出力値の確認
terraform output
terraform output -json > outputs.json  # JSON形式で保存
```

#### 主要な出力値

- `otel_alb_url` - OTel CollectorのエンドポイントURL（Claude Code設定用）
- `grafana_alb_url` - Grafana WebUIのURL
- `grafana_admin_password` - Grafana管理者パスワード（sensitive）
- `amp_workspace_id` - AMP Workspace ID
- `amp_remote_write_endpoint` - AMP Remote Writeエンドポイント

## アーキテクチャ概要

### データフロー

```
Claude Code (外部)
  ↓ OTLP/HTTP (4318)
Application Load Balancer
  ↓
ECS Fargate: OpenTelemetry Collector
  ↓ Prometheus Remote Write + SigV4認証
AWS Managed Prometheus (AMP)
  ↓ PromQL Query
ECS Fargate: Grafana (Self-hosted)
```

### 主要コンポーネント

1. **OpenTelemetry Collector** (`modules/otel-collector/`)
   - Claude CodeのOTLPメトリクスをPrometheus Remote Write形式に変換
   - **重要**: Claude CodeはOTLPのみサポート、AMPはRemote Writeのみ受付のため、Collectorが必須（詳細は `why-otel-collector.md` 参照）
   - ECS Fargate上で実行、SigV4認証でAMPへ送信

2. **AWS Managed Prometheus** (`modules/amp/`)
   - メトリクスの長期保存（デフォルト150日、開発環境では30日推奨）
   - PromQLクエリのサポート

3. **Grafana** (`modules/grafana/`)
   - ECS Fargate上でセルフホスト
   - **データ永続化戦略**: Dashboards as Code（GitOps）アプローチを推奨
   - EFS不使用により月額$20のコスト削減が可能
   - 詳細は `grafana-storage-strategy.md` 参照

4. **ネットワーク** (`modules/network/`)
   - 新規VPC作成（10.0.0.0/16）
   - Multi-AZ構成（パブリック×2、プライベート×2）
   - 開発環境: NAT Gateway×1、本番: ×2推奨

## Terraform構成の特徴

### モジュール構造

すべてのコンポーネントは再利用可能な独立モジュールとして実装されている：

- `modules/network/` - VPC、サブネット、IGW、NAT
- `modules/security-groups/` - 各コンポーネントのSG
- `modules/iam/` - Task Role、Execution Role
- `modules/amp/` - AMP Workspace
- `modules/efs/` - Grafana用永続ストレージ（オプション）
- `modules/ecs-cluster/` - Fargateクラスター
- `modules/alb/` - ALB×2（OTel、Grafana用）
- `modules/otel-collector/` - OTel Collectorタスク定義
- `modules/grafana/` - Grafanaタスク定義

### ベストプラクティス

1. **State管理**: S3バックエンド + DynamoDB state locking必須
   - セットアップ: `./scripts/setup-backend.sh` で自動構築
   - バックエンド設定: `backend.tf`
   - リージョン: ap-northeast-1
2. **タグ戦略**: `locals.tf` で共通タグを定義（Environment, Project, ManagedBy）
3. **命名規則**: `{project}-{environment}-{resource-type}-{name}` 形式
4. **バージョン固定**: Terraform 1.13.0+、AWS Provider 6.21.0

## セキュリティ考慮事項

### IAM Roles

- **OTel Collector Task Role**: `aps:RemoteWrite` 権限必須
- **Grafana Task Role**: `aps:QueryMetrics`, `aps:GetSeries` 等の読み取り権限
- **ECS Task Execution Role**: ECR pull、CloudWatch Logs、Secrets Manager

### Security Groups

各コンポーネント間の通信は最小権限の原則に従って設定：

- ALB（OTel）→ 443 → OTel Collector:4318
- ALB（Grafana）→ 443 → Grafana:3000
- OTel Collector → HTTPS → AMP API
- Grafana → HTTPS → AMP API

### 認証フロー

- **Claude Code → ALB**: API Key（カスタムヘッダー）またはSG制御
- **OTel → AMP**: SigV4署名（自動）
- **Grafana → AMP**: SigV4署名（Grafana AWS SDK plugin）
- **Grafana Login**: 基本認証（環境変数設定）

## コスト最適化（開発環境）

### 推奨設定

| 項目            | 開発環境                        | 月額削減効果    |
| --------------- | ------------------------------- | --------------- |
| ECS Fargate     | Fargate Spot使用                | $50削減（-38%） |
| NAT Gateway     | Single-AZ構成                   | -               |
| VPC Endpoints   | AMP、CloudWatch Logs用          | $30削減         |
| Grafana永続化   | Dashboards as Code（EFS不使用） | $20削減         |
| AMP保持期間     | 30日                            | -               |
| CloudWatch Logs | 7日保持                         | -               |

**最適化前**: ~$132/月 → **最適化後**: ~$32/月

## MCPサーバー活用ガイド

このプロジェクトでは以下のMCPサーバーが利用可能である。実装時は積極的に活用すること：

### 1. Terraform MCP Server

**使用タイミング**: Terraformコード生成・検証時

```bash
# 最新のプロバイダーバージョン確認
get_latest_provider_version(namespace="hashicorp", name="aws")

# AWSリソースのドキュメント検索
search_providers(provider_name="aws", service_slug="ecs", provider_document_type="resources")
get_provider_details(provider_doc_id="取得したID")

# モジュール検索
search_modules(module_query="ecs fargate")
get_module_details(module_id="取得したID")
```

**ベストプラクティス**:

- コード生成前に必ず最新バージョンとドキュメントを確認
- `terraform validate` と `terraform fmt` を実行

### 2. AWS Documentation MCP Server

**使用タイミング**: AWSサービスの仕様確認時

```bash
# サービスドキュメント検索
search_documentation(search_phrase="AWS Managed Prometheus remote write")

# 特定ドキュメントの読み込み
read_documentation(url="https://docs.aws.amazon.com/...")

# 関連ドキュメントの推奨
recommend(url="現在閲覧中のURL")
```

### 3. AWS Pricing MCP Server

**使用タイミング**: コスト見積もり時

```bash
# サービスコード検索
get_pricing_service_codes(filter="prometheus")

# 価格情報取得
get_pricing(service_code="AmazonPrometheus", region="ap-northeast-1")

# コストレポート生成
generate_cost_report(pricing_data={...}, service_name="AWS Managed Prometheus")
```

### 4. GitHub MCP Server

**使用タイミング**: Issue/PR管理時

```bash
# Issue作成
issue_write(method="create", owner="...", repo="...", title="...", body="...")

# PRレビュー
pull_request_review_write(method="create", owner="...", repo="...", pullNumber=...)
```

### 5. Perplexity MCP Server

**使用タイミング**: 最新情報の調査時

```bash
# 簡単な質問
search(query="AWS Fargate latest pricing 2025")

# 複雑な調査
reason(query="Terraform best practices for ECS Fargate multi-environment deployment")

# 詳細リサーチ
deep_research(query="OpenTelemetry Collector performance optimization on AWS")
```

## トラブルシューティング

### OTel Collectorにメトリクスが届かない

1. Security GroupでPort 4318開放確認
2. Claude CodeのExporter設定確認（エンドポイントURL）
3. CloudWatch LogsでOTel Collectorログ確認: `/ecs/otel-collector`
4. ALBターゲットヘルスチェック確認

### AMPにデータが書き込まれない

1. IAM Task Roleに `aps:RemoteWrite` 権限確認
2. OTel CollectorログでSigV4認証エラー確認
3. AWS ConsoleでAMP Workspaceのメトリクス受信状況確認

### Grafanaでデータが表示されない

1. Grafana DataSource設定確認（SigV4認証、AMPエンドポイント）
2. IAM Task Roleに `aps:QueryMetrics` 権限確認
3. Grafana Explore機能でPromQLクエリ直接実行

### Provisioning（Dashboards as Code）が失敗

1. CloudWatch Logs確認: `/ecs/grafana`
2. JSON構文エラーチェック: `jq . dashboard.json`
3. 環境変数確認: `GF_PATHS_PROVISIONING=/etc/grafana/provisioning`

## 重要な設計判断

### なぜOpenTelemetry Collectorが必要か？

Claude CodeはOTLP（OpenTelemetry Protocol）のみサポートし、AWS AMPはPrometheus Remote Writeのみサポートするため、Collectorによるプロトコル変換が必須である。詳細は `why-otel-collector.md` 参照。

### なぜGrafanaをセルフホストするか？

AWS Managed Grafanaは高価（$250/月～）であり、開発環境では小規模なセルフホストが十分なため。ECS Fargate上での運用は$15/月程度。

### なぜDashboards as Code（GitOps）か？

- 月額$20のEFSコスト削減
- 完全な監査証跡（Git履歴）
- マルチ環境展開の一貫性
- ディザスタリカバリの簡易化
- 設定ドリフトの防止

詳細は `grafana-storage-strategy.md` 参照。

## 実装フェーズ

### Phase 1: 基礎インフラ

- ネットワークモジュール（VPC、サブネット、NAT）
- セキュリティグループモジュール
- IAMモジュール

### Phase 2: データストレージ

- AMPモジュール
- EFSモジュール（オプション、Dashboards as Code使用時は不要）

### Phase 3: コンピューティング

- ECSクラスターモジュール
- ALBモジュール

### Phase 4: アプリケーション

- OTel Collectorモジュール（タスク定義、ECS Service）
- Grafanaモジュール（タスク定義、ECS Service）

### Phase 5: 設定ファイル

- `configs/otel-collector-config.yaml`
- `configs/grafana/provisioning/` 配下の設定

## 開発環境の特徴

- **リージョン**: ap-northeast-1（東京）
- **環境名**: dev
- **コスト最適化**: Fargate Spot、Single-AZ NAT、短いログ保持期間
- **データ永続化**: Dashboards as Code（EFS不使用）

## 関連ドキュメント

- `architecture.md` - 詳細なアーキテクチャ設計
- `why-otel-collector.md` - OTel Collector必要性の詳細
- `grafana-storage-strategy.md` - Grafana永続化戦略の詳細
- `.pre-commit-config.yaml` - コード品質チェック設定
- `.devcontainer/` - 開発環境設定

## 注意事項

### Terraform実行前の準備

1. **バックエンドのセットアップ**（初回のみ）

   ```bash
   ./scripts/setup-backend.sh
   ```

   これにより以下が自動作成される：
   - S3バケット（tfstate管理用）: `prometheus-terraform-state-dev`
   - DynamoDBテーブル（state lock用）: `prometheus-terraform-lock`

2. **変数ファイルの作成**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvarsを編集
   ```

3. **AWS認証情報の設定**
   ```bash
   aws configure
   # または環境変数でAWS_ACCESS_KEY_ID、AWS_SECRET_ACCESS_KEYを設定
   ```

### 機密情報の取り扱い

- `.gitignore` で `*.tfstate`、`*.tfvars`、`.env` を除外済み
- Secrets ManagerまたはParameter Storeを使用
- 環境変数はECS Task Definitionで設定

### コードスタイル

- Terraform: 公式フォーマッター（`terraform fmt`）使用
- Markdown: Prettier + textlint（日本語校正）
- JSON: Prettier使用
