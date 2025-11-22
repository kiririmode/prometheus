#!/bin/bash
set -e

# Terraform バックエンド セットアップスクリプト
# Terraform の state 管理用 S3 バケットを作成します
# 注意: Terraform 1.10以降では S3 ネイティブロック機能により DynamoDB は不要です

# 使用方法を表示
usage() {
    echo "使用方法: $0 <環境名>"
    echo ""
    echo "引数:"
    echo "  環境名    対象環境 (dev, stg, prod)"
    echo ""
    echo "例:"
    echo "  $0 dev"
    echo "  $0 stg"
    echo "  $0 prod"
    exit 1
}

# 環境名のバリデーション
validate_environment() {
    case "$1" in
        dev|stg|prod)
            return 0
            ;;
        *)
            echo "エラー: 無効な環境名 '$1'"
            echo "有効な環境名: dev, stg, prod"
            exit 1
            ;;
    esac
}

# 環境名の引数チェック
if [ -z "$1" ]; then
    usage
fi

ENVIRONMENT="$1"
validate_environment "${ENVIRONMENT}"

# 設定
BUCKET_NAME="visualization-otel-tfstate-${ENVIRONMENT}"
AWS_REGION="ap-northeast-1"

echo "=========================================="
echo "Terraform バックエンド セットアップ"
echo "=========================================="
echo "環境: ${ENVIRONMENT}"
echo "S3バケット名: ${BUCKET_NAME}"
echo "リージョン: ${AWS_REGION}"
echo "=========================================="
echo ""

# AWS CLI のインストール確認
if ! command -v aws &> /dev/null; then
    echo "エラー: AWS CLI がインストールされていません。先にインストールしてください。"
    exit 1
fi

# AWS 認証情報の確認
echo "AWS 認証情報を確認中..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "エラー: AWS 認証情報が設定されていません。"
    echo "'aws configure' を実行して認証情報を設定してください。"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS アカウント ID: ${ACCOUNT_ID}"
echo ""

# S3 バケットの作成
echo "S3バケットを作成中: ${BUCKET_NAME}..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    # us-east-1 以外のリージョンでは LocationConstraint が必要
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3 mb "s3://${BUCKET_NAME}" \
            --region "${AWS_REGION}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    echo "✓ S3バケットを作成しました"
else
    echo "✓ S3バケットは既に存在します"
fi

# バージョニングの有効化
echo "S3バケットのバージョニングを有効化中..."
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled \
    --region "${AWS_REGION}"
echo "✓ バージョニングを有効化しました"

# 暗号化の有効化
echo "S3バケットのデフォルト暗号化を有効化中..."
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }' \
    --region "${AWS_REGION}"
echo "✓ 暗号化を有効化しました"

# パブリックアクセスのブロック
echo "S3バケットのパブリックアクセスをブロック中..."
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "${AWS_REGION}"
echo "✓ パブリックアクセスをブロックしました"

# バケットポリシーの追加
echo "バケットポリシーを追加中..."
BUCKET_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EnforcedTLS",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}",
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
EOF
)

echo "${BUCKET_POLICY}" | aws s3api put-bucket-policy \
    --bucket "${BUCKET_NAME}" \
    --policy file:///dev/stdin \
    --region "${AWS_REGION}"
echo "✓ バケットポリシーを適用しました"

# ライフサイクルポリシーの追加（古いバージョンの自動削除）
echo "ライフサイクルポリシーを追加中..."
LIFECYCLE_POLICY=$(cat <<EOF
{
    "Rules": [
        {
            "ID": "DeleteOldVersions",
            "Status": "Enabled",
            "Prefix": "",
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 90
            }
        }
    ]
}
EOF
)

echo "${LIFECYCLE_POLICY}" | aws s3api put-bucket-lifecycle-configuration \
    --bucket "${BUCKET_NAME}" \
    --lifecycle-configuration file:///dev/stdin \
    --region "${AWS_REGION}"
echo "✓ ライフサイクルポリシーを適用しました（90日後に古いバージョンを削除）"

# タグの追加
echo "S3バケットにタグを追加中..."
aws s3api put-bucket-tagging \
    --bucket "${BUCKET_NAME}" \
    --tagging "TagSet=[
        {Key=Environment,Value=${ENVIRONMENT}},
        {Key=Project,Value=prometheus-monitoring},
        {Key=ManagedBy,Value=terraform},
        {Key=Purpose,Value=terraform-state}
    ]" \
    --region "${AWS_REGION}"
echo "✓ タグを追加しました"

echo ""
echo "=========================================="
echo "バックエンドのセットアップが完了しました！"
echo "=========================================="
echo ""
echo "環境: ${ENVIRONMENT}"
echo "S3バケット: ${BUCKET_NAME}"
echo "リージョン: ${AWS_REGION}"
echo ""
echo "backend.tf に以下の値を設定してください:"
echo "  bucket       = \"${BUCKET_NAME}\""
echo "  key          = \"${ENVIRONMENT}/terraform.tfstate\""
echo "  region       = \"${AWS_REGION}\""
echo "  use_lockfile = true  # S3ネイティブロック（Terraform 1.10以降）"
echo ""
echo "次のコマンドを実行できます:"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
echo ""
echo "=========================================="
