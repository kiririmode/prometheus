# Grafana データ永続化戦略：EFS vs Dashboards as Code

## 概要

ECS Fargate上でGrafanaを運用する際のデータ永続化戦略について、2つの主要なアプローチを比較し、ベストプラクティスを提示する。

## 2つのアプローチ

### 1. EFS 永続ストレージアプローチ

Amazon EFSをマウントボリュームとして使用し、Grafanaの設定、ダッシュボード、状態ファイルを永続化する従来型の方法。

**仕組み:**

- EFSボリュームを `/var/lib/grafana` にマウント
- UIでの変更がそのままEFSに保存される
- コンテナ再起動後もデータが保持される

### 2. Dashboards as Code（GitOps）アプローチ

ダッシュボード、データソース、設定をコードとしてGitで管理し、コンテナ起動時にプロビジョニングAPI経由で自動構築する方法。

**仕組み:**

- ダッシュボード定義をJSONファイルとしてGit管理
- データソース設定をYAMLとして管理
- コンテナ起動時にGrafana Provisioning APIで自動構築
- 永続ストレージは不要（ステートレス）

## 詳細比較

| 観点                   | EFS 永続ストレージ                                         | Dashboards as Code (GitOps)               |
| ---------------------- | ---------------------------------------------------------- | ----------------------------------------- |
| **初期セットアップ**   | 簡単（EFS マウントのみ）                                   | やや複雑（Provisioning API の理解が必要） |
| **ダッシュボード管理** | UI で直接編集可能                                          | Git + PR ベースのレビュー                 |
| **変更の永続性**       | 即座に保存                                                 | Git commit 後に反映                       |
| **バージョン管理**     | 追加ツールが必要                                           | Git で自動的に管理                        |
| **監査証跡**           | CloudWatch Logs に依存                                     | Git 履歴が完全な監査証跡                  |
| **マルチ環境展開**     | 手動同期が必要、ドリフトリスク高                           | 同一コードから一貫したデプロイ            |
| **ディザスタリカバリ** | EFS スナップショットに依存<br>RTO: 数分〜数時間            | Git から即座に再構築<br>RTO: 数秒〜数分   |
| **コスト**             | EFS: $0.30/GB/月 + データ転送<br>（50-100MB で $15-30/月） | ほぼゼロ（Git ストレージのみ）            |
| **起動時間**           | 高速（既存状態をロード）                                   | やや遅い（プロビジョニング実行）          |
| **運用複雑性**         | 長期的には高い（ドリフト管理）                             | 初期は高いが、長期的には低い              |
| **コラボレーション**   | 衝突リスクあり                                             | PR レビュープロセスで品質保証             |
| **コンプライアンス**   | 追加の監査仕組みが必要                                     | Git が不変の監査証跡を提供                |

## メリット・デメリット詳細

### EFS アプローチ

<!-- textlint-disable ja-technical-writing/no-doubled-joshi -->

#### メリット

- ✅ **セットアップが簡単** - 既存のGrafana運用経験をそのまま活かせる
- ✅ **UI ベースの直感的な操作** - コードを書かずにダッシュボード作成
- ✅ **変更が即座に反映** - 保存ボタンを押すだけで永続化
- ✅ **学習コスト低** - Grafanaの標準的な使い方

#### デメリット

- ❌ **コストが継続的に発生** - EFS料金が発生する。環境あたり$15-30/月である。
- ❌ **設定ドリフトのリスク** - UI変更でコード乖離する
- ❌ **ファイル権限問題** - EFSマウント時のUID/GID不一致
- ❌ **マルチ環境管理が困難** - dev/staging/prodの同期が手動
- ❌ **バックアップ戦略が必要** - EFSスナップショットの運用
- ❌ **監査証跡が不完全** - 変更者・変更時刻・変更内容の追跡困難

### Dashboards as Code アプローチ

#### メリット

- ✅ **完全な監査証跡** - すべての変更をGit履歴で追跡可能
- ✅ **コストほぼゼロ** - 永続ストレージ不要
- ✅ **マルチ環境展開が容易** - 同一コードから一貫性のあるデプロイ
- ✅ **ディザスタリカバリが簡単** - Gitから即座に再構築
- ✅ **チームコラボレーション** - PRベースのレビュープロセス
- ✅ **Infrastructure as Code** - すべてがコード化され再現可能
- ✅ **設定ドリフトゼロ** - コンテナ再起動でクリーンな状態に
- ✅ **コンプライアンス対応** - 変更履歴が自動的に記録

#### デメリット

- ❌ **初期セットアップが複雑** - Grafana Provisioningの理解が必要
- ❌ **ワークフロー変更が必要** - UIでの直接編集からGitベースへ移行する
- ❌ **起動時間がやや長い** - プロビジョニングAPI呼び出しのオーバーヘッド
- ❌ **一部機能の制限** - 高度なUI機能がProvisioning API未対応の可能性
- ❌ **規律が必要** - すべての変更をGit経由にするポリシー遵守

<!-- textlint-enable ja-technical-writing/no-doubled-joshi -->

## ベストプラクティス：ハイブリッドアプローチ

本番環境では、**両方のアプローチを組み合わせたハイブリッド戦略**が最も効果的である。

### 推奨構成

#### 📦 **Dashboards as Code で管理するもの（必須）**

以下はすべてGitでコード管理し、プロビジョニング経由で自動構築：

1. **データソース設定**
   - Prometheus/AMPエンドポイント
   - 認証情報（環境変数経由）
   - クエリ設定

2. **標準ダッシュボード**
   - チーム間で共有する共通ダッシュボード
   - インフラ監視用ダッシュボード
   - SLO/SLIダッシュボード
   - ビジネスメトリクスダッシュボード

3. **アラートルール**
   - アラート定義
   - 通知チャネル設定
   - エスカレーションポリシー

4. **組織設定**
   - ユーザーロール
   - チーム構成
   - 権限設定

#### 💾 **永続ストレージ（EFS/オプション）で管理するもの**

以下は必要に応じてEFSで永続化（開発環境では不要な場合が多い）：

1. **アドホック分析ダッシュボード**
   - 個人のアナリストが作成する一時的なダッシュボード
   - 調査・デバッグ用の臨時ダッシュボード

2. **プラグインデータ**
   - 状態を必要とするプラグインの設定

3. **ユーザー個別設定**
   - UI設定のカスタマイズ
   - 個人のPreferences

**重要**: 定期的に（四半期ごと）アドホックダッシュボードを監査し、有用なものはGitに移行する。

### ディレクトリ構造例

```
configs/grafana/
├── provisioning/
│   ├── datasources/
│   │   ├── amp-datasource.yaml          # AMP データソース設定
│   │   └── cloudwatch-datasource.yaml   # CloudWatch データソース（オプション）
│   │
│   ├── dashboards/
│   │   ├── dashboards.yaml              # ダッシュボードプロバイダー設定
│   │   └── default/                     # デフォルトフォルダ
│   │       ├── infrastructure.json      # インフラ監視ダッシュボード
│   │       ├── otel-collector.json      # OTel Collector メトリクス
│   │       └── application.json         # アプリケーションメトリクス
│   │
│   ├── notifiers/
│   │   └── slack-notifier.yaml          # Slack 通知設定
│   │
│   └── alerting/
│       ├── rules.yaml                   # アラートルール定義
│       └── contact-points.yaml          # 連絡先設定
│
└── grafana.ini                          # Grafana 本体設定（オプション）
```

### 実装例：データソース設定

**configs/grafana/provisioning/datasources/amp-datasource.yaml:**

```yaml
apiVersion: 1

datasources:
  - name: AWS Managed Prometheus
    type: prometheus
    access: proxy
    url: ${AMP_ENDPOINT}
    isDefault: true
    jsonData:
      httpMethod: POST
      sigV4Auth: true
      sigV4AuthType: default
      sigV4Region: ${AWS_REGION}
    editable: false
    version: 1
```

**環境変数での差し替え（ECS Task Definition）:**

```json
{
  "environment": [
    {
      "name": "AMP_ENDPOINT",
      "value": "https://aps-workspaces.ap-northeast-1.amazonaws.com/workspaces/ws-xxx/api/v1"
    },
    {
      "name": "AWS_REGION",
      "value": "ap-northeast-1"
    },
    {
      "name": "GF_PATHS_PROVISIONING",
      "value": "/etc/grafana/provisioning"
    }
  ]
}
```

### 実装例：ダッシュボード設定

**configs/grafana/provisioning/dashboards/dashboards.yaml:**

```yaml
apiVersion: 1

providers:
  - name: "default"
    orgId: 1
    folder: ""
    type: file
    disableDeletion: true
    updateIntervalSeconds: 10
    allowUiUpdates: false
    options:
      path: /etc/grafana/provisioning/dashboards/default
```

**重要な設定:**

- `disableDeletion: true` - UIからの削除を防止
- `allowUiUpdates: false` - UIでの編集を禁止（コードからのみ更新）
- `updateIntervalSeconds: 10` - 変更を自動検出

## 規模別推奨戦略

### 🏢 小規模チーム（< 10 ユーザー、< 50 ダッシュボード）

**推奨**: **Dashboards as Code 一本**

```
理由:
- 運用のシンプルさが最優先
- インフラコストゼロ
- 学習コストは初期のみで長期的に低コスト
- 全員が Git を使用している前提
```

**構成:**

- EFSは使用しない
- すべてのダッシュボードをGit管理
- ConfigMapまたはVolume Mountでプロビジョニング
- 月額コスト削減: $15-30

---

### 🏭 中規模組織（10-100 ユーザー、50-500 ダッシュボード）

**推奨**: **ハイブリッドアプローチ**

```
理由:
- 標準化と柔軟性のバランス
- チーム間の標準ダッシュボード共有が重要
- 一部のアドホック分析ニーズに対応
- 段階的な GitOps 導入が可能
```

**構成:**

- 標準ダッシュボード（70-80%）: Git管理
- アドホックダッシュボード（20-30%）: EFS（オプション）
- 四半期ごとにアドホックダッシュボードを監査し、有用なものをGit移行
- `allowUiUpdates: true` でアドホック作成を許可しつつ、定期的にコード化

---

### 🏙️ 大規模企業（> 100 ユーザー、> 500 ダッシュボード）

**推奨**: **厳格な Dashboards as Code + マルチインスタンス**

```
理由:
- スケーラビリティと一貫性が最優先
- チームごとに Grafana インスタンスを分離
- 完全な監査証跡が必要
- 変更管理プロセスの標準化
```

**構成:**

- チーム/部門ごとに独立したGrafanaインスタンス
- 各インスタンスに専用のGitリポジトリ
- すべてのダッシュボードを厳格にコード管理
- `allowUiUpdates: false` でUI経由の変更を完全禁止
- Pull Request + レビュー必須
- CI/CDパイプラインで自動デプロイ

**Git リポジトリ構造例:**

```
grafana-dashboards-platform/     # Platform チーム
grafana-dashboards-application/  # Application チーム
grafana-dashboards-security/     # Security チーム
grafana-dashboards-business/     # Business Analytics チーム
```

---

### 🔒 コンプライアンス重視環境（金融、医療、政府系）

**推奨**: **Dashboards as Code（必須）**

```
理由:
- 完全な監査証跡が法的要件
- 変更履歴の不変性が必要
- アクセス制御とレビュープロセスの義務化
- ロールバック可能性の保証
```

**必須要件:**

- すべての変更をGitで管理
- Pull Request + 2名以上のレビュー承認
- Gitリポジトリへのアクセス制御（RBAC）
- Git履歴の改ざん防止（署名付きコミット）
- デプロイログの長期保存（CloudWatch Logs）
- 定期的な監査レポート生成

## GitOps ワークフロー実装

### 推奨 Git ブランチ戦略

```
main (本番環境)
  ↑
staging (ステージング環境)
  ↑
develop (開発環境)
  ↑
feature/* (機能ブランチ)
```

### ダッシュボード変更フロー

1. **開発者が feature ブランチを作成**

   ```bash
   git checkout -b feature/add-api-latency-dashboard
   ```

2. **ダッシュボード JSON を編集・追加**

   ```bash
   # Grafana UI でダッシュボードを作成（開発環境）
   # Export JSON を実行
   # configs/grafana/provisioning/dashboards/default/ に保存
   git add configs/grafana/provisioning/dashboards/default/api-latency.json
   git commit -m "Add API latency monitoring dashboard"
   ```

3. **Pull Request を作成**
   - レビュアーがダッシュボードJSONを確認
   - CIでダッシュボードJSONのLintチェック（オプション）

4. **マージ後、自動デプロイ**
   - developブランチへのマージ → 開発環境Grafanaに自動デプロイ
   - stagingブランチへのマージ → ステージング環境へ
   - mainブランチへのマージ → 本番環境へ

### 自動デプロイ実装例（GitHub Actions）

```yaml
name: Deploy Grafana Dashboards

on:
  push:
    branches:
      - develop
      - staging
      - main
    paths:
      - "configs/grafana/**"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-1

      - name: Update ECS Service
        run: |
          # ECS タスク定義を更新して新しい設定をマウント
          aws ecs update-service \
            --cluster prometheus-${{ github.ref_name }}-ecs-cluster \
            --service grafana \
            --force-new-deployment
```

## マイグレーション戦略

### 既存 EFS 環境から Dashboards as Code への移行

#### Phase 1: 棚卸し（1週間）

1. 既存ダッシュボードをExport（JSON出力）
2. ダッシュボードを分類：
   - 🟢 標準ダッシュボード（チーム共有、本番使用）
   - 🟡 アドホックダッシュボード（個人用、調査用）
   - 🔴 不要ダッシュボード（使用されていない）

#### Phase 2: Git リポジトリ準備（1週間）

1. Gitリポジトリ作成
2. ディレクトリ構造設計
3. 🟢 標準ダッシュボードをGitにコミット
4. Provisioning設定ファイル作成

#### Phase 3: 並行運用（2-4週間）

1. Provisioningを `allowUiUpdates: true` で有効化
2. EFSも並行して維持
3. 新規ダッシュボードは必ずGit経由で作成
4. 既存ダッシュボードの動作確認

#### Phase 4: EFS 廃止（1週間）

1. `allowUiUpdates: false` に変更
2. EFSマウントを削除
3. ECS Task DefinitionからEFSボリューム削除
4. EFSリソース削除（コスト削減）

## コスト比較（開発環境、月額）

### EFS アプローチ

| 項目                         | 料金          |
| ---------------------------- | ------------- |
| EFS ストレージ（50GB）       | $15.00        |
| EFS データ転送               | $5.00         |
| EFS スループット（Bursting） | $0.00         |
| **合計**                     | **$20.00/月** |

### Dashboards as Code アプローチ

| 項目                            | 料金                |
| ------------------------------- | ------------------- |
| Git ストレージ（GitHub/GitLab） | $0.00（無料プラン） |
| **合計**                        | **$0.00/月**        |

### 年間コスト削減効果

```
削減額 = $20/月 × 12ヶ月 = $240/年（開発環境のみ）

3環境（dev/staging/prod）の場合:
$240/年 × 3環境 = $720/年
```

## トラブルシューティング

### プロビジョニングが失敗する

**症状**: ダッシュボードが表示されない

**確認事項**:

1. CloudWatch Logsでプロビジョニングログ確認

   ```bash
   aws logs tail /ecs/grafana --follow
   ```

2. JSON構文エラーチェック

   ```bash
   jq . configs/grafana/provisioning/dashboards/default/dashboard.json
   ```

3. Provisioningパス確認
   ```bash
   # ECS Task Definition の環境変数
   GF_PATHS_PROVISIONING=/etc/grafana/provisioning
   ```

### データソース接続エラー

**症状**: "Failed to query" エラー

**確認事項**:

1. IAM Task RoleにAMP読み取り権限があるか

   ```json
   {
     "Effect": "Allow",
     "Action": ["aps:QueryMetrics", "aps:GetSeries", "aps:GetLabels", "aps:GetMetricMetadata"],
     "Resource": "*"
   }
   ```

2. SigV4認証設定確認
   ```yaml
   jsonData:
     sigV4Auth: true
     sigV4AuthType: default
     sigV4Region: ap-northeast-1
   ```

### UI で編集したダッシュボードが消える

**症状**: UIで作成したダッシュボードがコンテナ再起動後に消失

**原因**: `allowUiUpdates: false` または永続ストレージ未設定

**解決策**:

1. 開発中は `allowUiUpdates: true` に設定
2. ダッシュボード完成後にJSONをExport
3. Gitにコミットして永続化

## まとめ

### 開発環境（このプロジェクト）の推奨構成

**architecture.md で定義している開発環境では、以下を推奨:**

✅ **Dashboards as Code アプローチを採用**

- EFSは使用しない（コスト削減 $20/月）
- すべてのダッシュボードを `configs/grafana/` でGit管理
- プロビジョニング経由で自動構築
- ステートレスなGrafana運用

✅ **実装ステップ:**

1. `configs/grafana/provisioning/` ディレクトリ構造作成
2. AMPデータソース設定をYAMLで定義
3. サンプルダッシュボードをJSONで作成
4. ECS Task Definitionでボリュームマウント設定
5. 環境変数でAMPエンドポイントを差し替え

✅ **メリット:**

- **月額コスト削減**: $20（EFS不要）
- **再現性**: Gitから完全に再構築可能
- **マルチ環境**: 同一コードでdev/staging/prod展開
- **監査証跡**: すべての変更がGit履歴に記録
- **ディザスタリカバリ**: RTO数分以内

### 本番環境への移行時

本番環境では、以下を検討：

- ハイブリッドアプローチ（標準ダッシュボードはコード管理）
- `allowUiUpdates: false` で厳格なコード管理
- Pull Requestベースのレビュープロセス
- CI/CDパイプラインでの自動デプロイ

---

**参考リンク:**

- [Grafana Provisioning Documentation](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [AWS Managed Prometheus](https://docs.aws.amazon.com/prometheus/)
- [ECS Fargate Storage Options](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-storage.html)
