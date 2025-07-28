#!/bin/bash

# Script to teardown Terraform backend infrastructure
# This script will remove the S3 bucket and DynamoDB table created for Terraform state management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set AWS Profile
AWS_PROFILE="default"

# Print banner
echo -e "${RED}=========================================================${NC}"
echo -e "${RED}       Terraform Backend Cleanup Script                  ${NC}"
echo -e "${RED}=========================================================${NC}"
echo -e "${YELLOW}WARNING: This script will permanently delete:${NC}"
echo -e "  - The S3 bucket storing your Terraform state files"
echo -e "  - The S3 bucket storing access logs"
echo -e "  - The DynamoDB table used for state locking"
echo -e "  - The IAM policy for backend access"
echo -e ""
echo -e "${YELLOW}Using AWS Profile: ${GREEN}${AWS_PROFILE}${NC}"
echo -e ""
echo -e "${RED}This operation cannot be undone and may result in data loss${NC}"
echo -e "${RED}if you have active Terraform projects using this backend.${NC}"
echo -e "${BLUE}=========================================================${NC}"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found.${NC}"
    echo -e "This file is needed to determine which resources to clean up."
    echo -e "Please run this script from the same directory where backend-bootstrap.sh was executed."
    exit 1
fi

# Load variables from terraform.tfvars
# Safely extract values using grep and cut
STATE_BUCKET_NAME=$(grep 'state_bucket_name' terraform.tfvars | cut -d '=' -f2 | tr -d ' "')
DYNAMODB_TABLE_NAME=$(grep 'dynamodb_table_name' terraform.tfvars | cut -d '=' -f2 | tr -d ' "')
AWS_REGION=$(grep 'aws_region' terraform.tfvars | cut -d '=' -f2 | tr -d ' "')

echo -e "${YELLOW}Resources to remove:${NC}"
echo -e "  - S3 bucket: ${RED}${STATE_BUCKET_NAME}${NC}"
echo -e "  - S3 log bucket: ${RED}${STATE_BUCKET_NAME}-logs${NC}"
echo -e "  - DynamoDB table: ${RED}${DYNAMODB_TABLE_NAME}${NC}"
echo -e "  - IAM policy: ${RED}terraform-backend-access${NC}"
echo -e "  - AWS Region: ${RED}${AWS_REGION}${NC}"

# Extra serious confirmation
echo -e ""
echo -e "${RED}DANGER ZONE: This is a destructive operation!${NC}"
echo -e "${RED}All state files in the bucket will be permanently deleted.${NC}"
echo -e ""
read -p "Type 'DELETE' (all caps) to confirm deletion: " -r CONFIRMATION
if [[ "$CONFIRMATION" != "DELETE" ]]; then
    echo -e "${GREEN}Cleanup aborted. No resources were deleted.${NC}"
    exit 0
fi

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity --profile ${AWS_PROFILE} &>/dev/null; then
    echo -e "${RED}Error: AWS credentials not configured properly for profile ${AWS_PROFILE}.${NC}"
    echo -e "Please run 'aws configure --profile ${AWS_PROFILE}' to set up the profile."
    exit 1
fi
echo -e "${GREEN}AWS credentials OK.${NC}"

# Export AWS_PROFILE for Terraform
export AWS_PROFILE=${AWS_PROFILE}

# Check if S3 bucket has contents and warn user
echo -e "${YELLOW}Checking if S3 bucket contains state files...${NC}"
if aws s3 ls "s3://${STATE_BUCKET_NAME}" --region "${AWS_REGION}" --profile ${AWS_PROFILE} 2>/dev/null | grep -q ".tfstate"; then
    echo -e "${RED}WARNING: The S3 bucket contains Terraform state files!${NC}"
    echo -e "These state files may be used by active Terraform projects."
    echo -e "Deleting them will make it impossible to manage those resources with Terraform."
    echo -e ""
    echo -e "Please make sure you have backed up any important state files before proceeding."
    echo -e ""
    read -p "Are you absolutely sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        echo -e "${GREEN}Cleanup aborted. No resources were deleted.${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}No state files found or bucket doesn't exist. Proceeding with cleanup.${NC}"
fi

# APPROACH 1: Modify the main.tf file to remove lifecycle blocks
echo -e "${YELLOW}Temporarily modifying Terraform files to remove lifecycle blocks...${NC}"

# Backup original files before modifying
cp main.tf main.tf.backup

# Remove lifecycle blocks from the main.tf file
sed -i '' '/lifecycle {/,/}/d' main.tf

# Or APPROACH 2: Empty S3 buckets directly using AWS CLI (bypassing lifecycle protection)
echo -e "${YELLOW}Emptying S3 buckets...${NC}"
if aws s3 ls "s3://${STATE_BUCKET_NAME}" --region "${AWS_REGION}" --profile ${AWS_PROFILE} &>/dev/null; then
    echo -e "Emptying state bucket..."
    aws s3 rm "s3://${STATE_BUCKET_NAME}" --recursive --region "${AWS_REGION}" --profile ${AWS_PROFILE}

    # Disable bucket versioning to remove all versions
    echo -e "Disabling bucket versioning..."
    aws s3api put-bucket-versioning --bucket "${STATE_BUCKET_NAME}" --versioning-configuration Status=Suspended --region "${AWS_REGION}" --profile ${AWS_PROFILE}

    # Delete all object versions
    echo -e "Deleting all object versions..."
    aws s3api list-object-versions --bucket "${STATE_BUCKET_NAME}" --region "${AWS_REGION}" --profile ${AWS_PROFILE} --output json | \
    jq -r '.Versions[]? | .Key + " " + .VersionId' | \
    while read KEY VERSIONID; do
        aws s3api delete-object --bucket "${STATE_BUCKET_NAME}" --key "$KEY" --version-id "$VERSIONID" --region "${AWS_REGION}" --profile ${AWS_PROFILE}
    done

    # Delete all delete markers
    echo -e "Deleting all delete markers..."
    aws s3api list-object-versions --bucket "${STATE_BUCKET_NAME}" --region "${AWS_REGION}" --profile ${AWS_PROFILE} --output json | \
    jq -r '.DeleteMarkers[]? | .Key + " " + .VersionId' | \
    while read KEY VERSIONID; do
        aws s3api delete-object --bucket "${STATE_BUCKET_NAME}" --key "$KEY" --version-id "$VERSIONID" --region "${AWS_REGION}" --profile ${AWS_PROFILE}
    done
fi

if aws s3 ls "s3://${STATE_BUCKET_NAME}-logs" --region "${AWS_REGION}" --profile ${AWS_PROFILE} &>/dev/null; then
    echo -e "Emptying logs bucket..."
    aws s3 rm "s3://${STATE_BUCKET_NAME}-logs" --recursive --region "${AWS_REGION}" --profile ${AWS_PROFILE}

    # Similar version cleanup for logs bucket
    echo -e "Disabling logs bucket versioning..."
    aws s3api put-bucket-versioning --bucket "${STATE_BUCKET_NAME}-logs" --versioning-configuration Status=Suspended --region "${AWS_REGION}" --profile ${AWS_PROFILE}

    # Delete all object versions in logs bucket
    echo -e "Deleting all object versions in logs bucket..."
    aws s3api list-object-versions --bucket "${STATE_BUCKET_NAME}-logs" --region "${AWS_REGION}" --profile ${AWS_PROFILE} --output json | \
    jq -r '.Versions[]? | .Key + " " + .VersionId' | \
    while read KEY VERSIONID; do
        aws s3api delete-object --bucket "${STATE_BUCKET_NAME}-logs" --key "$KEY" --version-id "$VERSIONID" --region "${AWS_REGION}" --profile ${AWS_PROFILE}
    done

    # Delete all delete markers in logs bucket
    echo -e "Deleting all delete markers in logs bucket..."
    aws s3api list-object-versions --bucket "${STATE_BUCKET_NAME}-logs" --region "${AWS_REGION}" --profile ${AWS_PROFILE} --output json | \
    jq -r '.DeleteMarkers[]? | .Key + " " + .VersionId' | \
    while read KEY VERSIONID; do
        aws s3api delete-object --bucket "${STATE_BUCKET_NAME}-logs" --key "$KEY" --version-id "$VERSIONID" --region "${AWS_REGION}" --profile ${AWS_PROFILE}
    done
fi

# Try to apply terraform destroy (now that lifecycle blocks are removed and buckets are empty)
echo -e "${YELLOW}Destroying Terraform backend infrastructure...${NC}"
if terraform destroy -auto-approve; then
    echo -e "${GREEN}Terraform resources successfully destroyed.${NC}"
else
    echo -e "${YELLOW}Standard terraform destroy failed. Trying alternative approach...${NC}"

    # If terraform destroy failed, try to manually remove resources using AWS CLI
    echo -e "${YELLOW}Attempting to delete resources directly with AWS CLI...${NC}"

    # Delete IAM policy first
    echo -e "Deleting IAM policy terraform-backend-access..."
    aws iam delete-policy --policy-arn $(aws iam list-policies --query "Policies[?PolicyName=='terraform-backend-access'].Arn" --output text --profile ${AWS_PROFILE}) --profile ${AWS_PROFILE} 2>/dev/null || true

    # Delete DynamoDB table
    echo -e "Deleting DynamoDB table ${DYNAMODB_TABLE_NAME}..."
    aws dynamodb delete-table --table-name "${DYNAMODB_TABLE_NAME}" --region "${AWS_REGION}" --profile ${AWS_PROFILE} 2>/dev/null || true

    # Delete S3 buckets
    echo -e "Deleting S3 buckets..."
    aws s3api delete-bucket --bucket "${STATE_BUCKET_NAME}" --region "${AWS_REGION}" --profile ${AWS_PROFILE} 2>/dev/null || true
    aws s3api delete-bucket --bucket "${STATE_BUCKET_NAME}-logs" --region "${AWS_REGION}" --profile ${AWS_PROFILE} 2>/dev/null || true
fi

# Restore original main.tf file if we modified it
if [ -f "main.tf.backup" ]; then
    mv main.tf.backup main.tf
fi

# Clean up local files
echo -e "${YELLOW}Cleaning up local files...${NC}"
rm -f backend.conf backend-example.tf tfplan terraform.tfstate*

echo -e "${BLUE}=========================================================${NC}"
echo -e "${GREEN}Terraform backend infrastructure has been removed!${NC}"
echo -e "${BLUE}=========================================================${NC}"
