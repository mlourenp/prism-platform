#!/bin/bash

# Script to reset Terraform state and fix duplicate resource configuration errors
# Use this when you need to clean the state without changing AWS accounts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default AWS profile
AWS_PROFILE="default"

# Print banner
echo -e "${BLUE}=========================================================${NC}"
echo -e "${BLUE}       Terraform State Reset and Clean Script           ${NC}"
echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}This script will:${NC}"
echo -e "  1. Backup your existing Terraform files"
echo -e "  2. Reset Terraform state completely"
echo -e "  3. Clean up stale resources in your configuration"
echo -e "  4. Prepare for a clean terraform apply"
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
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity --profile ${AWS_PROFILE} &>/dev/null; then
    echo -e "${RED}Error: AWS credentials not configured properly for profile ${AWS_PROFILE}.${NC}"
    echo -e "Please run 'aws configure --profile ${AWS_PROFILE}' to set up the profile."
    exit 1
fi

# Get account information
ACCOUNT_ID=$(aws sts get-caller-identity --profile ${AWS_PROFILE} --query Account --output text)
echo -e "${GREEN}Authenticated with AWS Account: ${ACCOUNT_ID}${NC}"

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
echo -e "${YELLOW}Cleaning up Terraform state...${NC}"
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*

# Clean any temporary files that might have been created
echo -e "${YELLOW}Removing any temporary files from previous runs...${NC}"
rm -f remove_lifecycle.tf
rm -f backend-example.tf
rm -f *.backup

# Update the tfvars file if it exists
if [ -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Updating terraform.tfvars with current account ID...${NC}"

    # Check if state_bucket_name already has an account ID appended
    if grep -q "state_bucket_name" terraform.tfvars; then
        CURRENT_BUCKET=$(grep "state_bucket_name" terraform.tfvars | cut -d "=" -f2 | tr -d ' "')
        BASE_BUCKET=$(echo $CURRENT_BUCKET | sed 's/-[0-9]*$//')
        NEW_BUCKET="${BASE_BUCKET}-${ACCOUNT_ID}"

        # Update the state_bucket_name with current account ID
        if [[ "$CURRENT_BUCKET" != "$NEW_BUCKET" ]]; then
            echo -e "${YELLOW}Updating bucket name from ${CURRENT_BUCKET} to ${NEW_BUCKET}${NC}"
            sed -i '' "s|state_bucket_name = \"${CURRENT_BUCKET}\"|state_bucket_name = \"${NEW_BUCKET}\"|g" terraform.tfvars
        fi
    fi

    # Ensure aws_profile is set correctly
    if grep -q "aws_profile" terraform.tfvars; then
        sed -i '' "s|aws_profile = \".*\"|aws_profile = \"${AWS_PROFILE}\"|g" terraform.tfvars
    else
        echo "aws_profile = \"${AWS_PROFILE}\"" >> terraform.tfvars
    fi
fi

# Initialize Terraform from scratch
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init -reconfigure

echo -e "${GREEN}Terraform state has been reset!${NC}"
echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Run terraform plan to verify everything is clean:"
echo -e "     terraform plan"
echo -e ""
echo -e "  2. Apply the configuration to create the backend infrastructure:"
echo -e "     terraform apply"
echo -e ""
echo -e "  3. After completion, run the bootstrap script to generate backend.conf:"
echo -e "     ./backend-bootstrap.sh"
echo -e "${BLUE}=========================================================${NC}"
