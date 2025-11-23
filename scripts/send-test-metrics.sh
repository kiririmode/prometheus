#!/bin/bash
#
# OTel Collector へテストメトリクスを送信するスクリプト
#
# 使用方法:
#   ./scripts/send-test-metrics.sh [オプション]
#
# オプション:
#   -e, --endpoint URL    OTel Collector エンドポイント（デフォルト: Terraform output から取得）
#   -n, --count NUM       送信回数（デフォルト: 3）
#   -i, --interval SEC    送信間隔（秒）（デフォルト: 2）
#   -s, --service NAME    サービス名（デフォルト: test-service）
#   -h, --help            ヘルプを表示
#

set -euo pipefail

# デフォルト値
ENDPOINT=""
COUNT=3
INTERVAL=2
SERVICE_NAME="test-service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    head -20 "$0" | tail -17 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# 引数パース
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--endpoint)
            ENDPOINT="$2"
            shift 2
            ;;
        -n|--count)
            COUNT="$2"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "不明なオプション: $1"
            show_help
            ;;
    esac
done

# エンドポイントの取得
if [[ -z "$ENDPOINT" ]]; then
    log_info "Terraform output からエンドポイントを取得中..."

    # dev 環境のディレクトリを探す
    DEV_DIR=""
    for dir in "$PROJECT_ROOT/environments/dev" "$PROJECT_ROOT/../environments/dev"; do
        if [[ -d "$dir" ]]; then
            DEV_DIR="$dir"
            break
        fi
    done

    if [[ -z "$DEV_DIR" ]]; then
        log_error "environments/dev ディレクトリが見つかりません"
        log_info "エンドポイントを -e オプションで指定してください"
        exit 1
    fi

    ENDPOINT=$(cd "$DEV_DIR" && terraform output -raw otel_custom_url 2>/dev/null || true)

    if [[ -z "$ENDPOINT" ]]; then
        # カスタムドメインがない場合は ALB URL を使用
        ENDPOINT=$(cd "$DEV_DIR" && terraform output -raw otel_alb_url 2>/dev/null || true)
    fi

    if [[ -z "$ENDPOINT" ]]; then
        log_error "エンドポイントを取得できませんでした"
        log_info "terraform output を確認するか、-e オプションでエンドポイントを指定してください"
        exit 1
    fi
fi

# /v1/metrics パスを追加
METRICS_URL="${ENDPOINT}/v1/metrics"

log_info "=== OTel メトリクス送信テスト ==="
log_info "エンドポイント: $METRICS_URL"
log_info "サービス名: $SERVICE_NAME"
log_info "送信回数: $COUNT"
log_info "送信間隔: ${INTERVAL}秒"
echo ""

# メトリクス送信関数
send_metric() {
    local value=$1
    local metric_name=$2
    local timestamp
    timestamp=$(date +%s)000000000

    local payload
    payload=$(cat <<EOF
{
  "resourceMetrics": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "$SERVICE_NAME"}},
        {"key": "environment", "value": {"stringValue": "dev"}}
      ]
    },
    "scopeMetrics": [{
      "scope": {"name": "test-scope", "version": "1.0.0"},
      "metrics": [{
        "name": "$metric_name",
        "sum": {
          "dataPoints": [{
            "asInt": "$value",
            "timeUnixNano": "$timestamp",
            "attributes": [
              {"key": "method", "value": {"stringValue": "GET"}},
              {"key": "status", "value": {"stringValue": "200"}}
            ]
          }],
          "aggregationTemporality": 2,
          "isMonotonic": true
        }
      }]
    }]
  }]
}
EOF
)

    local response
    local http_code

    # curl でリクエスト送信
    response=$(curl -s -w "\n%{http_code}" -X POST "$METRICS_URL" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -1)

    if [[ "$http_code" == "200" ]]; then
        log_info "送信成功: $metric_name = $value (HTTP $http_code)"
        return 0
    else
        log_error "送信失敗: HTTP $http_code"
        log_error "レスポンス: $body"
        return 1
    fi
}

# メトリクス送信ループ
success_count=0
fail_count=0

for i in $(seq 1 "$COUNT"); do
    log_info "[$i/$COUNT] メトリクス送信中..."

    # カウンターメトリクス（累積値として増加させる）
    value=$((i * 10 + RANDOM % 10))

    if send_metric "$value" "http_requests_total"; then
        ((success_count++))
    else
        ((fail_count++))
    fi

    # 最後のイテレーション以外は待機
    if [[ $i -lt $COUNT ]]; then
        sleep "$INTERVAL"
    fi
done

echo ""
log_info "=== 送信結果 ==="
log_info "成功: $success_count / $COUNT"
if [[ $fail_count -gt 0 ]]; then
    log_warn "失敗: $fail_count / $COUNT"
fi

echo ""
log_info "=== 確認方法 ==="
echo "1. CloudWatch Logs で確認:"
echo "   aws logs tail /ecs/prometheus-dev-otel-collector --since 5m --region ap-northeast-1 | grep -i Metrics"
echo ""
echo "2. Grafana で確認:"
echo "   URL: $(cd "$DEV_DIR" 2>/dev/null && terraform output -raw grafana_custom_url 2>/dev/null || echo "https://dashboard.kiririmo.de")"
echo "   クエリ: http_requests_total{service_name=\"$SERVICE_NAME\"}"

exit $fail_count
