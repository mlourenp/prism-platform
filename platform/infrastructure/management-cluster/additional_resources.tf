# S3 Bucket for Application Assets and Backups
resource "aws_s3_bucket" "application_assets" {
  bucket = "${var.cluster_name}-assets-${var.region}"

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-assets"
    }
  )
}

resource "aws_s3_bucket_ownership_controls" "application_assets" {
  bucket = aws_s3_bucket.application_assets.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "application_assets" {
  bucket = aws_s3_bucket.application_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "application_assets" {
  bucket = aws_s3_bucket.application_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB Table for Crossplane Lock Management
resource "aws_dynamodb_table" "crossplane_locks" {
  name           = "${var.cluster_name}-crossplane-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

# S3 Bucket for Crossplane Provider Caching
resource "aws_s3_bucket" "crossplane_providers" {
  bucket = "${var.cluster_name}-crossplane-providers-${var.region}"

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-crossplane-providers"
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "crossplane_providers" {
  bucket = aws_s3_bucket.crossplane_providers.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = 30

  tags = var.tags
}

# IAM Policy for Crossplane to manage AWS resources
resource "aws_iam_policy" "crossplane_provider_aws" {
  name        = "${var.cluster_name}-crossplane-provider-aws"
  description = "Policy for Crossplane AWS Provider to manage AWS resources"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          # EKS permissions
          "eks:*",
          # EC2 permissions
          "ec2:*",
          # RDS permissions
          "rds:*",
          # S3 permissions
          "s3:*",
          # IAM permissions
          "iam:*",
          # VPC permissions
          "ec2:*Vpc*",
          "ec2:*Subnet*",
          "ec2:*Route*",
          "ec2:*SecurityGroup*",
          "ec2:*Address*",
          "ec2:*NetworkInterface*",
          # CloudWatch permissions
          "logs:*",
          # KMS permissions
          "kms:*",
          # SQS permissions
          "sqs:*",
          # SNS permissions
          "sns:*",
          # DynamoDB permissions
          "dynamodb:*",
          # Autoscaling permissions
          "autoscaling:*",
          # Load Balancer permissions
          "elasticloadbalancing:*",
          # ECR permissions
          "ecr:*"
        ],
        Resource = "*"
      }
    ]
  })
}

# Create IRSA (IAM Role for Service Account) for Crossplane Provider AWS
resource "aws_iam_role" "crossplane_provider_aws" {
  name = "${var.cluster_name}-crossplane-provider-aws"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_arn, "/^arn:aws:iam::[0-9]+:oidc-provider\\//", "")}:aud": "sts.amazonaws.com",
            "${replace(module.eks.oidc_provider_arn, "/^arn:aws:iam::[0-9]+:oidc-provider\\//", "")}:sub": "system:serviceaccount:${var.crossplane_namespace}:provider-aws"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "crossplane_provider_aws" {
  role       = aws_iam_role.crossplane_provider_aws.name
  policy_arn = aws_iam_policy.crossplane_provider_aws.arn
}

# Parameter Store for storing sensitive configuration
resource "aws_ssm_parameter" "db_credentials" {
  name        = "/${var.cluster_name}/database/credentials"
  description = "Database credentials for the application"
  type        = "SecureString"
  value       = jsonencode({
    username = "admin"
    password = "Change-me-in-production!" # Replace with a secure password generation in production
  })

  tags = var.tags
}

resource "aws_ssm_parameter" "api_credentials" {
  name        = "/${var.cluster_name}/api/credentials"
  description = "API credentials for the application"
  type        = "SecureString"
  value       = jsonencode({
    key = "change-me-in-production" # Replace with a secure key generation in production
  })

  tags = var.tags
}

# Namespace for Crossplane Provider Secrets
/*
resource "kubernetes_namespace" "crossplane_providers" {
  metadata {
    name = "${var.crossplane_namespace}-providers"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "crossplane.io/scope"          = "providers"
    }
  }

  depends_on = [module.eks]
}

# Service Account for Crossplane Provider AWS
resource "kubernetes_service_account" "crossplane_provider_aws" {
  metadata {
    name      = "provider-aws"
    namespace = var.crossplane_namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.crossplane_provider_aws.arn
    }

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  automount_service_account_token = true

  depends_on = [helm_release.crossplane]
}
*/
