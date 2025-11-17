# OpenTelemetry Collectorが必要な理由

## TL;DR

Claude CodeはOTLP（OpenTelemetry Protocol）とPrometheus Pull形式をサポートしているが、**Prometheus Remote Writeは直接サポートしていない**。AWS Managed Prometheus (AMP)はPrometheus Remote Write APIのみを受け付けるため、**プロトコル変換するOpenTelemetry Collectorが必須**である。

## Claude CodeのOTEL送信機能サポート状況

### サポートされているプロトコル

| エクスポーター          | プロトコル        | 方式          | サポート状況                      | 本構成での使用 |
| ----------------------- | ----------------- | ------------- | --------------------------------- | -------------- |
| OTLP                    | HTTP/protobuf     | Push          | ✅ ネイティブサポート (port 4318) | ✅ **採用**    |
| OTLP                    | gRPC              | Push          | ✅ ネイティブサポート (port 4317) | ❌ 不使用      |
| Prometheus              | Exposition Format | Pull (scrape) | ✅ ネイティブサポート             | ❌ 不使用      |
| Prometheus Remote Write | Remote Write      | Push          | ❌ **直接サポートなし**           | -              |

### 設定例

```bash
# OTLP over HTTP（本構成で使用）
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.example.com:4318

# Prometheusスクレイプエンドポイント公開
export OTEL_METRICS_EXPORTER=prometheus
# ローカルでHTTPサーバーを起動し、Prometheusがスクレイプ

# 複数エクスポーター同時使用
export OTEL_METRICS_EXPORTER=otlp,prometheus
```

## AWS Managed Prometheusの受付プロトコル

AWS AMPは以下のAPIのみをサポート：

| API                         | 用途               | プロトコル                               |
| --------------------------- | ------------------ | ---------------------------------------- |
| Prometheus Remote Write API | メトリクス書き込み | HTTP POST（Prometheus Remote Write形式） |
| Prometheus Query API        | メトリクス読み取り | HTTP GET/POST（PromQL）                  |

**重要**: AMPはOTLPを直接受け付けません。

## プロトコルの不一致

```
❌ 直接接続不可能
┌─────────────┐                    ┌─────────────┐
│ Claude Code │ --OTLP (HTTP)-->  │     AMP     │
│             │                    │ (Remote Write│
└─────────────┘                    │  のみ受付)  │
                                   └─────────────┘
                     ↑
                  互換性なし


✅ OpenTelemetry Collector経由で接続可能
┌─────────────┐   OTLP    ┌─────────────┐   Remote Write   ┌─────────────┐
│ Claude Code │ --------> │   OTel      │ --------------> │     AMP     │
│             │  (HTTP)   │  Collector  │ (+ SigV4 auth)  │             │
└─────────────┘           └─────────────┘                 └─────────────┘
                          プロトコル変換
                          + AWS認証
```

## OpenTelemetry Collectorの役割

### 1. プロトコル変換

- **入力**: OTLP (HTTP/protobuf)
- **出力**: Prometheus Remote Write
- Claude CodeとAMP間のブリッジとして機能

### 2. AWS認証（SigV4）

- AMPへのアクセスにはAWS SigV4署名が必須
- Collector側でIAM Roleを使用して自動署名
- Claude Code側では認証不要（シンプル）

### 3. 信頼性向上

- **バッファリング**: 一時的なネットワーク障害時にメトリクスを保持
- **再試行ロジック**: 送信失敗時の自動リトライ（exponential backoff）
- **バックプレッシャー**: AMP側の負荷が高い時の送信制御

### 4. メトリクス処理

- **フィルタリング**: 不要なメトリクスの除外
- **サンプリング**: 高頻度メトリクスの間引き
- **変換**: メトリクス名やラベルの加工
- **集約**: 複数メトリクスの統合

### 5. 拡張性

- **複数の宛先**: AMP + CloudWatch + S3など
- **複数のソース**: Claude Code + 他のアプリケーション
- **中央集約**: 将来的なスケールアウトに対応

## 代替案の検討

### オプション1: Prometheus Agentを使用

```
┌─────────────┐
│ Claude Code │ Prometheusエンドポイント公開
│             │ (HTTPサーバー起動)
└─────────────┘
       ↑
       │ Pull (scrape)
       │
┌─────────────┐
│ Prometheus  │
│   Agent     │
└─────────────┘
       ↓
  Remote Write
       ↓
┌─────────────┐
│     AMP     │
└─────────────┘
```

#### メリット

- Prometheus標準のエコシステムを利用
- Prometheusの機能（Service Discovery、Alerting）が使える

#### デメリット

- **Pull型の制約**: Claude CodeがHTTPサーバーとしてエンドポイントを公開する必要がある
- **外部からのスクレイプ困難**: Claude Codeが外部環境にある場合、アクセスが複雑
- **追加コンポーネント**: Prometheus Agentの管理が必要
- **コスト**: Prometheus Agent実行環境のコスト
- **複雑性**: スクレイプ設定、Service Discovery設定など

### オプション2: OpenTelemetry Collector（推奨）

```
┌─────────────┐
│ Claude Code │
│             │
└─────────────┘
       ↓
   OTLP Push (HTTP)
       ↓
┌─────────────┐
│   OTel      │
│  Collector  │
└─────────────┘
       ↓
  Remote Write + SigV4
       ↓
┌─────────────┐
│     AMP     │
└─────────────┘
```

#### メリット

- **Push型**: Claude CodeからシンプルにOTLP送信
- **外部環境対応**: インターネット経由でも容易
- **AWS統合**: SigV4認証をCollector側で処理
- **OpenTelemetry標準**: ベンダーニュートラル
- **柔軟性**: 複数の宛先、メトリクス加工が容易
- **拡張性**: 将来的な要件変更に対応しやすい

#### デメリット

- **追加コンポーネント**: Collectorの管理が必要
- **コスト**: Collector実行環境のコスト（ECS Fargate）

## OpenTelemetry Collector設定例

### Collector設定（config.yaml）

```yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

  memory_limiter:
    check_interval: 1s
    limit_mib: 512

exporters:
  prometheusremotewrite:
    endpoint: https://aps-workspaces.ap-northeast-1.amazonaws.com/workspaces/ws-xxxxxxxx/api/v1/remote_write
    auth:
      authenticator: sigv4auth
    resource_to_telemetry_conversion:
      enabled: true

extensions:
  sigv4auth:
    region: ap-northeast-1
    service: aps

service:
  extensions: [sigv4auth]
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheusremotewrite]
```

### Claude Code側設定

```bash
# シンプルな設定（OTLP/HTTP使用）
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector-alb.example.com:4318

# または環境変数なしでコード内設定
# Claude Code起動時に上記のエンドポイントを指定
```

## コスト比較

### OpenTelemetry Collector使用

| 項目                        | 月額（USD） |
| --------------------------- | ----------- |
| ECS Fargate (0.5 vCPU, 1GB) | ~$35        |
| ALB                         | ~$15        |
| データ転送                  | ~$5         |
| **合計**                    | **~$55**    |

### Prometheus Agent使用

| 項目                        | 月額（USD） |
| --------------------------- | ----------- |
| ECS Fargate (0.5 vCPU, 1GB) | ~$35        |
| ALB（スクレイプ用）         | ~$15        |
| データ転送                  | ~$5         |
| **合計**                    | **~$55**    |

→ コストはほぼ同じ。柔軟性とシンプルさでOTel Collectorが優位。

## 結論

### OpenTelemetry Collectorが必要な理由（まとめ）

1. **プロトコルの不一致**: Claude Code (OTLP) ⇔ AMP (Prometheus Remote Write)
2. **AWS認証**: SigV4署名の自動付与
3. **信頼性**: バッファリング・再試行による堅牢性
4. **シンプルさ**: Claude Code側の設定が容易（OTLPエンドポイント指定のみ）
5. **拡張性**: 将来的な要件変更に対応可能

### 推奨アーキテクチャ

```
Claude Code
  ↓ (OTLP/HTTP: 4318)
OpenTelemetry Collector
  ↓ (Prometheus Remote Write + SigV4)
AWS Managed Prometheus
  ↓ (PromQL)
Grafana
```

この構成により、**シンプル、堅牢、拡張可能**なメトリクス収集基盤が実現できる。

## 参考資料

- [OpenTelemetry Collector - Prometheus Remote Write Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusremotewriteexporter)
- [AWS Managed Prometheus - Remote Write](https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-onboard-ingest-metrics-remote-write.html)
- [Claude Code Monitoring with OpenTelemetry](https://signoz.io/blog/claude-code-monitoring-with-opentelemetry/)
- [Monitoring Claude Code Usage with Grafana Cloud](https://quesma.com/blog/track-claude-code-usage-and-limits-with-grafana-cloud/)
