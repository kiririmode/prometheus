# Prometheus Monitoring Infrastructure

外部のClaude CodeからOpenTelemetryメトリクスを受信し、AWS Managed Prometheus (AMP)で保存、ECS Fargate上のGrafanaで可視化する監視基盤のTerraformコード。

## アーキテクチャ

詳細なアーキテクチャ設計は[architecture.md](./architecture.md)を参照してください。

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

## 前提条件

- Terraform >= 1.13.0
- AWS CLI設定済み
- 適切なAWS IAM権限

## セットアップ

### 1. S3バケットとDynamoDBテーブルの作成

自動セットアップスクリプトを使用（推奨）:

```bash
./scripts/setup-backend.sh
```

このスクリプトは以下を自動的に実行する:

- S3バケットの作成
- バージョニングの有効化
- 暗号化の設定
- パブリックアクセスのブロック
- DynamoDBテーブルの作成（PAY_PER_REQUESTモード）

手動で作成する場合は、architecture.mdのデプロイ手順を参照すること。

### 2. 変数ファイルの作成

```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsを編集して環境に合わせた値を設定
```

### 3. Terraformの実行

```bash
# 初期化
terraform init

# プランの確認
terraform plan -out=tfplan

# 適用
terraform apply tfplan

# 出力値の確認
terraform output
```

## モジュール構成

- `modules/network/` - VPC、サブネット、NAT Gateway
- `modules/security-groups/` - セキュリティグループ
- `modules/iam/` - IAM Roles & Policies
- `modules/amp/` - AWS Managed Prometheus
- `modules/efs/` - EFS (オプション、Grafana用)
- `modules/ecs-cluster/` - ECS Fargate Cluster
- `modules/alb/` - Application Load Balancers
- `modules/otel-collector/` - OpenTelemetry Collector
- `modules/grafana/` - Grafana

## 設定ファイル

- `configs/otel-collector-config.yaml` - OTel Collector設定
- `configs/grafana/provisioning/` - Grafana Provisioning設定

## コスト最適化

開発環境向けのコスト最適化オプション:

- Fargate Spot使用（$50削減）
- VPC Endpoints使用（$30削減）
- Grafana Dashboards as Code（$20削減）
- Single-AZ NAT Gateway

詳細は[architecture.md](./architecture.md#コスト最適化開発環境向け)を参照。

## デプロイ後の確認

1. **Grafana URL取得**

   ```bash
   terraform output grafana_alb_url
   ```

2. **Grafanaログイン**
   - URL: 上記で取得したURL
   - ユーザー名: admin
   - パスワード: terraform.tfvarsで設定した値

3. **OTel Collector エンドポイント取得**

   ```bash
   terraform output otel_alb_url
   ```

4. **Claude Code設定**
   ```yaml
   exporters:
     otlp:
       endpoint: "<OTel Collector ALB URL>:443"
       tls:
         insecure: false
   ```

## トラブルシューティング

詳細は[architecture.md](./architecture.md#トラブルシューティング)を参照すること。

## クリーンアップ

```bash
terraform destroy
```

## ライセンス

このプロジェクトはMITライセンスの下でライセンスされている。
