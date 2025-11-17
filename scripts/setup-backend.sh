#!/bin/bash
set -e

# Terraform Backend Setup Script
# This script creates the S3 bucket and DynamoDB table for Terraform state management

# Configuration
BUCKET_NAME="prometheus-terraform-state-dev"
DYNAMODB_TABLE="prometheus-terraform-lock"
AWS_REGION="ap-northeast-1"
ENVIRONMENT="dev"

echo "=========================================="
echo "Terraform Backend Setup"
echo "=========================================="
echo "Bucket Name: ${BUCKET_NAME}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "Region: ${AWS_REGION}"
echo "Environment: ${ENVIRONMENT}"
echo "=========================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials are not configured."
    echo "Please run 'aws configure' to set up your credentials."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: ${ACCOUNT_ID}"
echo ""

# Create S3 bucket
echo "Creating S3 bucket: ${BUCKET_NAME}..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    # Create bucket with LocationConstraint for regions other than us-east-1
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3 mb "s3://${BUCKET_NAME}" \
            --region "${AWS_REGION}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    echo "✓ S3 bucket created successfully"
else
    echo "✓ S3 bucket already exists"
fi

# Enable versioning
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled \
    --region "${AWS_REGION}"
echo "✓ Versioning enabled"

# Enable encryption
echo "Enabling default encryption on S3 bucket..."
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
echo "✓ Encryption enabled"

# Block public access
echo "Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "${AWS_REGION}"
echo "✓ Public access blocked"

# Add bucket policy
echo "Adding bucket policy..."
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
echo "✓ Bucket policy applied"

# Add lifecycle policy for old versions (optional)
echo "Adding lifecycle policy for old versions..."
LIFECYCLE_POLICY=$(cat <<EOF
{
    "Rules": [
        {
            "Id": "DeleteOldVersions",
            "Status": "Enabled",
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
echo "✓ Lifecycle policy applied"

# Add tags
echo "Adding tags to S3 bucket..."
aws s3api put-bucket-tagging \
    --bucket "${BUCKET_NAME}" \
    --tagging "TagSet=[
        {Key=Environment,Value=${ENVIRONMENT}},
        {Key=Project,Value=prometheus-monitoring},
        {Key=ManagedBy,Value=terraform},
        {Key=Purpose,Value=terraform-state}
    ]" \
    --region "${AWS_REGION}"
echo "✓ Tags added"

echo ""
echo "=========================================="
echo "Creating DynamoDB table for state locking..."
echo "=========================================="

# Check if DynamoDB table exists
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" &> /dev/null; then
    echo "✓ DynamoDB table already exists"
else
    # Create DynamoDB table
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}" \
        --tags \
            Key=Environment,Value="${ENVIRONMENT}" \
            Key=Project,Value=prometheus-monitoring \
            Key=ManagedBy,Value=terraform \
            Key=Purpose,Value=terraform-state-lock

    echo "✓ DynamoDB table created successfully"

    # Wait for table to be active
    echo "Waiting for DynamoDB table to become active..."
    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${AWS_REGION}"
    echo "✓ DynamoDB table is active"
fi

echo ""
echo "=========================================="
echo "Backend Setup Complete!"
echo "=========================================="
echo ""
echo "S3 Bucket: ${BUCKET_NAME}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "Region: ${AWS_REGION}"
echo ""
echo "You can now run:"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
echo ""
echo "=========================================="
