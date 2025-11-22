#!/bin/bash
set -e

# Terraform バックエンド クリーンアップスクリプト
# Terraform state 管理用の S3 バケットを削除します
# 警告: このスクリプトは全ての Terraform state ファイルを削除します！

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
echo "Terraform バックエンド クリーンアップ"
echo "=========================================="
echo "環境: ${ENVIRONMENT}"
echo "S3バケット名: ${BUCKET_NAME}"
echo "リージョン: ${AWS_REGION}"
echo "=========================================="
echo ""
echo "警告: ${ENVIRONMENT} 環境の全ての Terraform state ファイルが削除されます！"
echo "この操作は取り消せません。"
echo ""
read -r -p "続行しますか？ (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "中止しました。"
    exit 0
fi

# AWS CLI のインストール確認
if ! command -v aws &> /dev/null; then
    echo "エラー: AWS CLI がインストールされていません。"
    exit 1
fi

# AWS 認証情報の確認
echo "AWS 認証情報を確認中..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "エラー: AWS 認証情報が設定されていません。"
    exit 1
fi

# S3 バケットの削除
echo "S3バケットを削除中: ${BUCKET_NAME}..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "✓ S3バケットは存在しません"
else
    # 全てのオブジェクトとバージョンを削除
    echo "バケット内の全てのオブジェクトとバージョンを削除中..."
    aws s3api delete-objects \
        --bucket "${BUCKET_NAME}" \
        --delete "$(aws s3api list-object-versions \
            --bucket "${BUCKET_NAME}" \
            --output json \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
            --region "${AWS_REGION}")" \
        --region "${AWS_REGION}" 2>/dev/null || true

    # 削除マーカーを削除
    aws s3api delete-objects \
        --bucket "${BUCKET_NAME}" \
        --delete "$(aws s3api list-object-versions \
            --bucket "${BUCKET_NAME}" \
            --output json \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
            --region "${AWS_REGION}")" \
        --region "${AWS_REGION}" 2>/dev/null || true

    # バケットを削除
    aws s3 rb "s3://${BUCKET_NAME}" --force --region "${AWS_REGION}"
    echo "✓ S3バケットを削除しました"
fi

echo ""
echo "=========================================="
echo "バックエンドのクリーンアップが完了しました！"
echo "=========================================="
echo ""
echo "環境: ${ENVIRONMENT}"
echo "削除したS3バケット: ${BUCKET_NAME}"
echo ""
echo "=========================================="
