# Terraform Backend Setup

This directory contains the Terraform configuration to set up a secure and efficient backend for storing Terraform state files. It follows AWS best practices for state management.

## Overview

The setup includes:

- **S3 Bucket**: For remote state storage with versioning enabled
- **DynamoDB Table**: For state locking to prevent concurrent modifications
- **Security Measures**: Encryption, access logging, and public access blocking
- **IAM Policy**: For controlled access to the backend resources
- **Lifecycle Rules**: For managing old state versions and logs

## Prerequisites

- AWS CLI installed and configured with appropriate credentials
- Terraform ≥ 1.0.0 installed
- Appropriate IAM permissions to create S3 buckets, DynamoDB tables, and IAM policies

## Deployment

You can deploy this backend using the provided bootstrap script:

```bash
cd terraform/backend-setup
chmod +x backend-bootstrap.sh
./backend-bootstrap.sh
```

The script will:

1. Verify AWS credentials
2. Create a `terraform.tfvars` file with default or customized values
3. Initialize and apply the Terraform configuration
4. Generate a `backend.conf` file for use in other Terraform projects

Alternatively, you can deploy manually:

```bash
cd terraform/backend-setup
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Configuration

The following variables can be customized:

| Variable              | Description                                  | Default                            |
| --------------------- | -------------------------------------------- | ---------------------------------- |
| `aws_region`          | AWS region to create resources in            | `us-west-2`                        |
| `state_bucket_name`   | Name of the S3 bucket for Terraform state    | `prism-platform-terraform-state` |
| `dynamodb_table_name` | Name of the DynamoDB table for state locking | `prism-platform-terraform-locks` |

You can customize these values by:

- Editing `terraform.tfvars`
- Setting environment variables (e.g., `export TF_VAR_state_bucket_name="my-custom-bucket"`)
- Passing them as command line arguments (e.g., `terraform apply -var="state_bucket_name=my-custom-bucket"`)

## Usage

After deploying this backend, you can use it in other Terraform projects:

1. Add a backend configuration to your Terraform project:

```hcl
terraform {
  backend "s3" {
    # These values must be provided via backend.conf or during init
  }
}
```

2. Create a `backend.conf` file with the appropriate values:

```hcl
bucket         = "prism-platform-terraform-state"
key            = "path/to/your/project/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "prism-platform-terraform-locks"
encrypt        = true
```

3. Initialize your project with the backend configuration:

```bash
terraform init -backend-config=backend.conf
```

## Security Considerations

This backend setup implements multiple security best practices:

- **Encryption**: Server-side encryption is enabled for all objects
- **Versioning**: All state files are versioned to prevent data loss
- **Access Logging**: All access to the state bucket is logged
- **Public Access Blocking**: All public access to the buckets is blocked
- **State Locking**: Prevents concurrent modifications that could corrupt state
- **Lifecycle Management**: Old state versions and logs are cleaned up automatically

## IAM Permissions

The configuration creates an IAM policy (`terraform-backend-access`) that can be attached to IAM users, groups, or roles. This policy provides the minimum permissions needed to use the Terraform backend:

- `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on the state bucket
- `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:DeleteItem` on the locks table
