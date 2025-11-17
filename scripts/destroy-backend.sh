#!/bin/bash
set -e

# Terraform Backend Cleanup Script
# This script removes the S3 bucket and DynamoDB table used for Terraform state management
# WARNING: This will delete all Terraform state files!

# Configuration
BUCKET_NAME="prometheus-terraform-state-dev"
DYNAMODB_TABLE="prometheus-terraform-lock"
AWS_REGION="ap-northeast-1"

echo "=========================================="
echo "Terraform Backend Cleanup"
echo "=========================================="
echo "Bucket Name: ${BUCKET_NAME}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "Region: ${AWS_REGION}"
echo "=========================================="
echo ""
echo "WARNING: This will delete all Terraform state files!"
echo "This action cannot be undone."
echo ""
read -r -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed."
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials are not configured."
    exit 1
fi

# Delete S3 bucket
echo "Deleting S3 bucket: ${BUCKET_NAME}..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "✓ S3 bucket does not exist"
else
    # Remove all objects and versions
    echo "Removing all objects and versions from bucket..."
    aws s3api delete-objects \
        --bucket "${BUCKET_NAME}" \
        --delete "$(aws s3api list-object-versions \
            --bucket "${BUCKET_NAME}" \
            --output json \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
            --region "${AWS_REGION}")" \
        --region "${AWS_REGION}" 2>/dev/null || true

    # Remove delete markers
    aws s3api delete-objects \
        --bucket "${BUCKET_NAME}" \
        --delete "$(aws s3api list-object-versions \
            --bucket "${BUCKET_NAME}" \
            --output json \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
            --region "${AWS_REGION}")" \
        --region "${AWS_REGION}" 2>/dev/null || true

    # Delete bucket
    aws s3 rb "s3://${BUCKET_NAME}" --force --region "${AWS_REGION}"
    echo "✓ S3 bucket deleted successfully"
fi

# Delete DynamoDB table
echo "Deleting DynamoDB table: ${DYNAMODB_TABLE}..."
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" &> /dev/null; then
    aws dynamodb delete-table \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${AWS_REGION}"

    echo "Waiting for DynamoDB table to be deleted..."
    aws dynamodb wait table-not-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${AWS_REGION}"
    echo "✓ DynamoDB table deleted successfully"
else
    echo "✓ DynamoDB table does not exist"
fi

echo ""
echo "=========================================="
echo "Backend Cleanup Complete!"
echo "=========================================="
