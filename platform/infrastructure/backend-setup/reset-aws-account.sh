#!/bin/bash

# Script to reset Terraform backend configuration for a new AWS account
# Use this when switching to a new AWS account or when you need to reinitialize the backend

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default AWS profile - can be the same even when changing accounts
AWS_PROFILE="default"

# Print banner
echo -e "${BLUE}=========================================================${NC}"
echo -e "${BLUE}    Terraform Backend Reset Script for New AWS Account   ${NC}"
echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}This script will:${NC}"
echo -e "  1. Verify your new AWS account credentials"
echo -e "  2. Backup your existing Terraform files"
echo -e "  3. Reset local Terraform state"
echo -e "  4. Create new configuration with the new AWS account"
echo -e ""
echo -e "${YELLOW}Using AWS Profile: ${GREEN}${AWS_PROFILE}${NC}"
echo -e "${BLUE}=========================================================${NC}"

# Ask for confirmation
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborting...${NC}"
    exit 1
fi

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials for the new account...${NC}"
if ! aws sts get-caller-identity --profile ${AWS_PROFILE} &>/dev/null; then
    echo -e "${RED}Error: AWS credentials not configured properly for profile ${AWS_PROFILE}.${NC}"
    echo -e "Please run 'aws configure --profile ${AWS_PROFILE}' to set up the profile with your new account credentials."
    exit 1
fi

# Get new account information
NEW_ACCOUNT_ID=$(aws sts get-caller-identity --profile ${AWS_PROFILE} --query Account --output text)
echo -e "${GREEN}Successfully authenticated with AWS Account: ${NEW_ACCOUNT_ID}${NC}"

# Verify this is indeed a new account
if [ -f "terraform.tfvars" ]; then
    if grep -q "${NEW_ACCOUNT_ID}" terraform.tfvars; then
        echo -e "${YELLOW}Warning: The current AWS account (${NEW_ACCOUNT_ID}) appears to be the same as the one in terraform.tfvars.${NC}"
        read -p "Are you sure this is a new AWS account? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
            echo -e "${RED}Aborting...${NC}"
            exit 1
        fi
    fi
fi

# Create backup directory
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_DIR="terraform_backup_${TIMESTAMP}"
echo -e "${YELLOW}Creating backup of current configuration in ${BACKUP_DIR}...${NC}"
mkdir -p ${BACKUP_DIR}

# Backup existing files
if [ -f "terraform.tfvars" ]; then
    cp terraform.tfvars ${BACKUP_DIR}/
fi
if [ -f "backend.conf" ]; then
    cp backend.conf ${BACKUP_DIR}/
fi
if [ -f "backend-example.tf" ]; then
    cp backend-example.tf ${BACKUP_DIR}/
fi
if [ -d ".terraform" ]; then
    cp -r .terraform ${BACKUP_DIR}/
fi
if ls terraform.tfstate* 1> /dev/null 2>&1; then
    cp terraform.tfstate* ${BACKUP_DIR}/
fi

echo -e "${GREEN}Backup completed.${NC}"

# Clean up existing Terraform files
echo -e "${YELLOW}Cleaning up existing Terraform state...${NC}"
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* backend.conf backend-example.tf

# Let user specify or keep default values
echo -e "${YELLOW}Setting up new configuration for AWS Account: ${NEW_ACCOUNT_ID}${NC}"
read -p "Enter AWS Region [us-west-2]: " AWS_REGION
AWS_REGION=${AWS_REGION:-"us-west-2"}

read -p "Enter base name for S3 bucket [prism-platform-terraform-state]: " BASE_BUCKET_NAME
BASE_BUCKET_NAME=${BASE_BUCKET_NAME:-"prism-platform-terraform-state"}

read -p "Enter DynamoDB table name [prism-platform-terraform-locks]: " DYNAMODB_TABLE_NAME
DYNAMODB_TABLE_NAME=${DYNAMODB_TABLE_NAME:-"prism-platform-terraform-locks"}

# Create new state bucket name with account ID for uniqueness
STATE_BUCKET_NAME="${BASE_BUCKET_NAME}-${NEW_ACCOUNT_ID}"

# Create new terraform.tfvars file
echo -e "${YELLOW}Creating new terraform.tfvars file...${NC}"
cat > terraform.tfvars << EOF
aws_region = "${AWS_REGION}"
state_bucket_name = "${STATE_BUCKET_NAME}"
dynamodb_table_name = "${DYNAMODB_TABLE_NAME}"
aws_profile = "${AWS_PROFILE}"
EOF
echo -e "${GREEN}terraform.tfvars created.${NC}"

# Done - provide next steps
echo -e "${BLUE}=========================================================${NC}"
echo -e "${GREEN}Reset completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Run the bootstrap script to create the backend infrastructure:"
echo -e "     ./backend-bootstrap.sh"
echo -e ""
echo -e "  2. After bootstrap completes, update all your Terraform projects"
echo -e "     to use the new backend configuration."
echo -e ""
echo -e "  3. If you had resources in the old AWS account, consider migrating"
echo -e "     them or cleaning them up."
echo -e "${BLUE}=========================================================${NC}"
