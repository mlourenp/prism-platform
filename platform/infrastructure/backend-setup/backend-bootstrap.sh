#!/bin/bash

# Script to initialize and deploy Terraform backend infrastructure
# This script will set up S3 bucket and DynamoDB table for Terraform state management

set -e

# Default values
AWS_REGION=${AWS_REGION:-"us-west-2"}
STATE_BUCKET_NAME=${STATE_BUCKET_NAME:-"prism-platform-terraform-state"}
DYNAMODB_TABLE_NAME=${DYNAMODB_TABLE_NAME:-"prism-platform-terraform-locks"}
AWS_PROFILE="default"
ACCOUNT_ID=$(aws sts get-caller-identity --profile ${AWS_PROFILE} --query Account --output text)

# Append account ID to ensure bucket name uniqueness
STATE_BUCKET_NAME="${STATE_BUCKET_NAME}-${ACCOUNT_ID}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}=========================================================${NC}"
echo -e "${BLUE}       Terraform Backend Bootstrap Script               ${NC}"
echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}This script will create:${NC}"
echo -e "  - S3 bucket: ${GREEN}${STATE_BUCKET_NAME}${NC}"
echo -e "  - DynamoDB table: ${GREEN}${DYNAMODB_TABLE_NAME}${NC}"
echo -e "  - AWS Region: ${GREEN}${AWS_REGION}${NC}"
echo -e "  - Using AWS Profile: ${GREEN}${AWS_PROFILE}${NC}"
echo -e "${BLUE}=========================================================${NC}"

# Ask for confirmation
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborting...${NC}"
    exit 1
fi

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity --profile ${AWS_PROFILE} &>/dev/null; then
    echo -e "${RED}Error: AWS credentials not configured properly for profile ${AWS_PROFILE}.${NC}"
    echo -e "Please run 'aws configure --profile ${AWS_PROFILE}' to set up the profile."
    exit 1
fi
echo -e "${GREEN}AWS credentials OK.${NC}"

# Create terraform.tfvars file
echo -e "${YELLOW}Creating terraform.tfvars file...${NC}"
cat > terraform.tfvars << EOF
aws_region = "${AWS_REGION}"
state_bucket_name = "${STATE_BUCKET_NAME}"
dynamodb_table_name = "${DYNAMODB_TABLE_NAME}"
aws_profile = "${AWS_PROFILE}"
EOF
echo -e "${GREEN}terraform.tfvars created.${NC}"

# Initialize and apply Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

echo -e "${YELLOW}Setting AWS Profile for Terraform...${NC}"
export AWS_PROFILE=${AWS_PROFILE}

echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

echo -e "${YELLOW}Planning Terraform changes...${NC}"
terraform plan -out=tfplan -var-file=terraform.tfvars

echo -e "${YELLOW}Applying Terraform changes...${NC}"
terraform apply tfplan

echo -e "${GREEN}Terraform backend infrastructure created successfully!${NC}"

# Generate backend.conf for other projects
echo -e "${YELLOW}Generating backend.conf file...${NC}"
cat > backend.conf << EOF
bucket         = "${STATE_BUCKET_NAME}"
region         = "${AWS_REGION}"
dynamodb_table = "${DYNAMODB_TABLE_NAME}"
encrypt        = true
profile        = "${AWS_PROFILE}"
EOF
echo -e "${GREEN}backend.conf generated.${NC}"

# Generate example backend configuration
echo -e "${YELLOW}Generating example backend configuration...${NC}"
cat > backend-example.tf << EOF
# Example Terraform backend configuration using the newly created backend
# Copy this configuration to your Terraform projects

terraform {
  backend "s3" {
    # These values must be provided via backend.conf or during init
    # bucket         = "${STATE_BUCKET_NAME}"
    # key            = "path/to/your/project/terraform.tfstate"
    # region         = "${AWS_REGION}"
    # dynamodb_table = "${DYNAMODB_TABLE_NAME}"
    # encrypt        = true
    # profile        = "${AWS_PROFILE}"
  }
}

# Usage: terraform init -backend-config=path/to/backend.conf
EOF
echo -e "${GREEN}backend-example.tf generated.${NC}"

echo -e "${BLUE}=========================================================${NC}"
echo -e "${GREEN}Backend setup complete!${NC}"
echo -e "${YELLOW}For each Terraform project, initialize with:${NC}"
echo -e "  terraform init -backend-config=path/to/backend.conf"
echo -e ""
echo -e "${YELLOW}Make sure to set a unique state file key for each project in backend.conf:${NC}"
echo -e "  key = \"path/to/your/project/terraform.tfstate\""
echo -e "${BLUE}=========================================================${NC}"
