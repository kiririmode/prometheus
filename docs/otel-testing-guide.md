# OTel メトリクス送信 動作確認ガイド

このドキュメントでは、OpenTelemetry Collector へのメトリクス送信と動作確認の手順を説明する。

## 前提条件

- dev 環境が Terraform で構築済みであること
- AWS CLI が設定済みであること
- `curl` と `jq` がインストールされていること

## エンドポイント情報

| サービス                   | URL                                   |
| -------------------------- | ------------------------------------- |
| OTel Collector (OTLP/HTTP) | `https://otel.kiririmo.de/v1/metrics` |
| Grafana                    | `https://dashboard.kiririmo.de`       |

エンドポイントは Terraform output から取得可能:

```bash
cd environments/dev
terraform output otel_custom_url
terraform output grafana_custom_url
```

## 動作確認手順

### 1. インフラ状態の確認

#### ECS タスクの稼働状態を確認

```bash
aws ecs describe-services \
  --cluster prometheus-dev-cluster \
  --services prometheus-dev-otel-service \
  --region ap-northeast-1 \
  --query "services[0].{status:status,runningCount:runningCount,desiredCount:desiredCount}" \
  --output json
```

期待される結果:

```json
{
  "status": "ACTIVE",
  "runningCount": 1,
  "desiredCount": 1
}
```

#### ALB ターゲットヘルスチェック確認

```bash
# ステップ1: ターゲットグループ ARN を取得
aws elbv2 describe-target-groups \
  --region ap-northeast-1 \
  --query "TargetGroups[?contains(TargetGroupName, 'otel')].TargetGroupArn" \
  --output text
```

上記で出力された ARN を使用してヘルスチェック状態を確認:

```bash
# ステップ2: ヘルスチェック状態を確認（ARN は上記の出力で置き換える）
aws elbv2 describe-target-health \
  --target-group-arn "<上記で取得した ARN>" \
  --region ap-northeast-1 \
  --output json | jq '.TargetHealthDescriptions[] | {target: .Target.Id, state: .TargetHealth.State}'
```

期待される結果:

```json
{
  "target": "10.0.x.x",
  "state": "healthy"
}
```

### 2. テストメトリクスの送信

#### 簡易テスト（curl）

```bash
# テストスクリプトを使用（推奨）
./scripts/send-test-metrics.sh

# または手動で実行
curl -X POST "https://otel.kiririmo.de/v1/metrics" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }]
      },
      "scopeMetrics": [{
        "scope": {"name": "test"},
        "metrics": [{
          "name": "http_requests_total",
          "sum": {
            "dataPoints": [{
              "asInt": "42",
              "timeUnixNano": "'$(date +%s)000000000'"
            }],
            "aggregationTemporality": 2,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'
```

期待されるレスポンス:

```json
{ "partialSuccess": {} }
```

### 3. メトリクス受信の確認

#### CloudWatch Logs で確認

```bash
aws logs tail /ecs/prometheus-dev-otel-collector \
  --since 5m \
  --region ap-northeast-1 \
  | grep -i "Metrics"
```

`debug` exporter からの出力例:

```
info  Metrics  {"resource metrics": 1, "metrics": 1, "data points": 1}
```

#### Grafana で確認

1. https://dashboard.kiririmo.de にアクセス
2. 左メニューから **Explore** を選択
3. データソースとして **Amazon Managed Prometheus** を選択
4. 以下の PromQL クエリを実行:

```promql
# テストで送信したメトリクス
http_requests_total

# OTel Collector 自身のメトリクス
{job="otel-collector"}

# すべてのメトリクス（確認用）
{__name__=~".+"}
```

## トラブルシューティング

### OTel Collector が起動しない

```bash
# 最新のログを確認
aws logs tail /ecs/prometheus-dev-otel-collector \
  --since 10m \
  --region ap-northeast-1

# サービスイベントを確認
aws ecs describe-services \
  --cluster prometheus-dev-cluster \
  --services prometheus-dev-otel-service \
  --region ap-northeast-1 \
  --query "services[0].events[:5]" \
  --output json
```

### よくあるエラーと対処法

| エラー                                 | 原因                  | 対処法                                               |
| -------------------------------------- | --------------------- | ---------------------------------------------------- |
| `s3 uri does not match the pattern`    | S3 URI 形式が不正     | `s3://bucket.s3.region.amazonaws.com/key` 形式か確認 |
| `logging exporter has been deprecated` | 古い exporter 設定    | `logging` を `debug` に変更                          |
| `has invalid keys: address`            | 無効な telemetry 設定 | `telemetry.metrics.address` を削除                   |
| ALB ターゲットが unhealthy             | ヘルスチェック失敗    | Security Group とポート 4318 の設定を確認            |

### ECS サービスの再デプロイ

設定変更後にタスクを再起動する:

```bash
aws ecs update-service \
  --cluster prometheus-dev-cluster \
  --service prometheus-dev-otel-service \
  --force-new-deployment \
  --region ap-northeast-1
```

## 関連ドキュメント

- [CLAUDE.md](../CLAUDE.md) - プロジェクト概要とセットアップ手順
- [architecture.md](../architecture.md) - アーキテクチャ詳細
- [why-otel-collector.md](../why-otel-collector.md) - OTel Collector の必要性
