# VPC for the Management Cluster
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS-specific tags for subnets that will host load balancers and nodes
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    "cell-network-type"                        = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    "cell-network-type"                        = "private"
  }

  tags = var.tags
}

# EKS Management Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = var.cluster_name
  cluster_version                = var.kubernetes_version
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Management node group configuration
  eks_managed_node_groups = {
    "${var.node_group_name}" = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_capacity
      max_size       = var.node_max_capacity
      desired_size   = var.node_desired_capacity
      disk_size      = var.node_disk_size
      ami_type       = "AL2023_x86_64_STANDARD"

      # Enable IMDSv2
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      # Enable EBS encryption
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  # Allow users/roles to access the cluster
  # (You may want to add your own IAM roles/users here)
  # aws_auth_roles = []
  # aws_auth_users = []

  # Enable cluster encryption
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  # Enable control plane logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Optional: Enable Fargate for some workloads (if needed)
  # fargate_profiles = {
  #   default = {
  #     name = "default"
  #     selectors = [
  #       {
  #         namespace = "default"
  #       }
  #     ]
  #   }
  # }

  tags = var.tags
}

# Note: The inline_policy deprecation warning from the EKS module will need to be addressed
# in a second phase, after the initial EKS cluster creation.
resource "terraform_data" "fix_deprecation_reminder" {
  provisioner "local-exec" {
    command = "echo 'IMPORTANT: After the initial apply completes, create a policy-fix.tf file to address the inline_policy deprecation warnings.'"
  }
}

# Add-ons for EKS
module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Core add-ons
  enable_metrics_server = true
  metrics_server = {
    wait = true
    timeout = 300
  }

  # Load balancer controller
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    wait = true
    timeout = 600
    create_namespace = true
  }

  # Cluster autoscaler
  enable_cluster_autoscaler = true
  cluster_autoscaler = {
    wait = true
    timeout = 300
  }

  # Logging
  enable_aws_for_fluentbit = true
  aws_for_fluentbit = {
    wait = true
    timeout = 300
  }

  # Certificate management
  enable_cert_manager = true
  cert_manager = {
    wait = true
    timeout = 600
    create_namespace = true
    set = [
      {
        name  = "webhook.timeoutSeconds"
        value = "30"
      }
    ]
  }

  # Additional add-ons for Kubernetes 1.32
  enable_aws_cloudwatch_metrics = true
  enable_karpenter = true
  enable_external_dns = true

  # Security add-ons
  enable_aws_node_termination_handler = true

  tags = var.tags
}

# AWS Managed Prometheus
resource "aws_prometheus_workspace" "main" {
  alias = "${var.cluster_name}-prometheus"
  tags  = var.tags
}

# Configure Prometheus for EKS
resource "aws_iam_role_policy" "prometheus" {
  name = "${var.cluster_name}-prometheus"
  role = module.eks.cluster_iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetMetricMetadata",
          "aps:GetSeries"
        ]
        Resource = aws_prometheus_workspace.main.arn
      }
    ]
  })
}

# KEDA Installation
resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = "keda"
  create_namespace = true

  set {
    name  = "podSecurityContext.fsGroup"
    value = "1001"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.keda_irsa.iam_role_arn
  }

  depends_on = [module.eks]
}

# KEDA IAM Role
module "keda_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-keda"

  role_policy_arns = {
    cloudwatch = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
    sqs        = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
    sns        = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
    kinesis    = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
    logs       = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["keda:keda-operator"]
    }
  }

  tags = var.tags
}

# AWS GuardDuty
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = var.tags
}

# AWS Security Hub
resource "aws_securityhub_account" "main" {
  enable_default_standards = true
  auto_enable_controls    = true
}

# AWS Security Hub
resource "aws_securityhub_standards_subscription" "main" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

# Get current region
data "aws_region" "current" {}
