# Multi-Region Configuration for Production Environment

# Provider configuration
provider "aws" {
  region = "us-west-2"
  alias  = "us_west_2"
}

provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"
}

provider "aws" {
  region = "eu-west-1"
  alias  = "eu_west_1"
}

# Local variables for region-specific details
locals {
  regions = {
    "us-west-2" = {
      name           = "us-west-2"
      provider       = aws.us_west_2
      vpc_id         = module.vpc_us_west_2.vpc_id
      vpc_cidr       = module.vpc_us_west_2.vpc_cidr_block
      private_route_table_ids = module.vpc_us_west_2.private_route_table_ids
      api_endpoint   = module.eks_us_west_2.kubernetes_api_endpoint
      api_zone_id    = "Z2FDTNDATAQYW2" # CloudFront's fixed hosted zone ID
      routing_weight = 100
    },
    "us-east-1" = {
      name           = "us-east-1"
      provider       = aws.us_east_1
      vpc_id         = module.vpc_us_east_1.vpc_id
      vpc_cidr       = module.vpc_us_east_1.vpc_cidr_block
      private_route_table_ids = module.vpc_us_east_1.private_route_table_ids
      api_endpoint   = module.eks_us_east_1.kubernetes_api_endpoint
      api_zone_id    = "Z2FDTNDATAQYW2" # CloudFront's fixed hosted zone ID
      routing_weight = 50
    },
    "eu-west-1" = {
      name           = "eu-west-1"
      provider       = aws.eu_west_1
      vpc_id         = module.vpc_eu_west_1.vpc_id
      vpc_cidr       = module.vpc_eu_west_1.vpc_cidr_block
      private_route_table_ids = module.vpc_eu_west_1.private_route_table_ids
      api_endpoint   = module.eks_eu_west_1.kubernetes_api_endpoint
      api_zone_id    = "Z2FDTNDATAQYW2" # CloudFront's fixed hosted zone ID
      routing_weight = 25
    }
  }
}

# VPC for US West 2 (Primary)
module "vpc_us_west_2" {
  source = "../../modules/networking"

  vpc_name       = "prism-platform-vpc-us-west-2"
  vpc_cidr       = "10.0.0.0/16"

  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

  private_subnets = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
  public_subnets  = ["10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19"]
  intra_subnets   = ["10.0.192.0/21", "10.0.200.0/21", "10.0.208.0/21"]
  database_subnets = ["10.0.216.0/23", "10.0.218.0/23", "10.0.220.0/23"]

  environment = "prod"

  providers = {
    aws = aws.us_west_2
  }

  tags = {
    Environment = "prod"
    Region      = "us-west-2"
    ManagedBy   = "Terraform"
  }
}

# VPC for US East 1 (Secondary)
module "vpc_us_east_1" {
  source = "../../modules/networking"

  vpc_name       = "prism-platform-vpc-us-east-1"
  vpc_cidr       = "10.1.0.0/16"

  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  private_subnets = ["10.1.0.0/19", "10.1.32.0/19", "10.1.64.0/19"]
  public_subnets  = ["10.1.96.0/19", "10.1.128.0/19", "10.1.160.0/19"]
  intra_subnets   = ["10.1.192.0/21", "10.1.200.0/21", "10.1.208.0/21"]
  database_subnets = ["10.1.216.0/23", "10.1.218.0/23", "10.1.220.0/23"]

  environment = "prod"

  providers = {
    aws = aws.us_east_1
  }

  tags = {
    Environment = "prod"
    Region      = "us-east-1"
    ManagedBy   = "Terraform"
  }
}

# VPC for EU West 1 (Tertiary)
module "vpc_eu_west_1" {
  source = "../../modules/networking"

  vpc_name       = "prism-platform-vpc-eu-west-1"
  vpc_cidr       = "10.2.0.0/16"

  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

  private_subnets = ["10.2.0.0/19", "10.2.32.0/19", "10.2.64.0/19"]
  public_subnets  = ["10.2.96.0/19", "10.2.128.0/19", "10.2.160.0/19"]
  intra_subnets   = ["10.2.192.0/21", "10.2.200.0/21", "10.2.208.0/21"]
  database_subnets = ["10.2.216.0/23", "10.2.218.0/23", "10.2.220.0/23"]

  environment = "prod"

  providers = {
    aws = aws.eu_west_1
  }

  tags = {
    Environment = "prod"
    Region      = "eu-west-1"
    ManagedBy   = "Terraform"
  }
}

# EKS Cluster for US West 2 (Primary)
module "eks_us_west_2" {
  source = "../../modules/eks"

  cluster_name    = "prism-platform-eks-us-west-2"
  kubernetes_version = "1.26"

  vpc_id     = module.vpc_us_west_2.vpc_id
  subnet_ids = module.vpc_us_west_2.private_subnet_ids

  public_subnet_ids  = module.vpc_us_west_2.public_subnet_ids
  private_subnet_ids = module.vpc_us_west_2.private_subnet_ids
  database_subnet_ids = module.vpc_us_west_2.database_subnet_ids

  api_access_cidrs = ["0.0.0.0/0"] # Restrict in production

  kms_key_arn = aws_kms_key.eks_secrets_us_west_2.arn

  environment = "prod"

  providers = {
    aws = aws.us_west_2
  }

  tags = {
    Environment = "prod"
    Region      = "us-west-2"
    ManagedBy   = "Terraform"
  }
}

# KMS Key for EKS Secrets in US West 2
resource "aws_kms_key" "eks_secrets_us_west_2" {
  provider = aws.us_west_2

  description             = "KMS key for EKS secrets encryption in us-west-2"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "prism-platform-eks-secrets-key-us-west-2"
    Environment = "prod"
    Region      = "us-west-2"
    ManagedBy   = "Terraform"
  }
}

# EKS Cluster for US East 1 (Secondary)
module "eks_us_east_1" {
  source = "../../modules/eks"

  cluster_name    = "prism-platform-eks-us-east-1"
  kubernetes_version = "1.26"

  vpc_id     = module.vpc_us_east_1.vpc_id
  subnet_ids = module.vpc_us_east_1.private_subnet_ids

  public_subnet_ids  = module.vpc_us_east_1.public_subnet_ids
  private_subnet_ids = module.vpc_us_east_1.private_subnet_ids
  database_subnet_ids = module.vpc_us_east_1.database_subnet_ids

  api_access_cidrs = ["0.0.0.0/0"] # Restrict in production

  kms_key_arn = aws_kms_key.eks_secrets_us_east_1.arn

  environment = "prod"

  providers = {
    aws = aws.us_east_1
  }

  tags = {
    Environment = "prod"
    Region      = "us-east-1"
    ManagedBy   = "Terraform"
  }
}

# KMS Key for EKS Secrets in US East 1
resource "aws_kms_key" "eks_secrets_us_east_1" {
  provider = aws.us_east_1

  description             = "KMS key for EKS secrets encryption in us-east-1"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "prism-platform-eks-secrets-key-us-east-1"
    Environment = "prod"
    Region      = "us-east-1"
    ManagedBy   = "Terraform"
  }
}

# EKS Cluster for EU West 1 (Tertiary)
module "eks_eu_west_1" {
  source = "../../modules/eks"

  cluster_name    = "prism-platform-eks-eu-west-1"
  kubernetes_version = "1.26"

  vpc_id     = module.vpc_eu_west_1.vpc_id
  subnet_ids = module.vpc_eu_west_1.private_subnet_ids

  public_subnet_ids  = module.vpc_eu_west_1.public_subnet_ids
  private_subnet_ids = module.vpc_eu_west_1.private_subnet_ids
  database_subnet_ids = module.vpc_eu_west_1.database_subnet_ids

  api_access_cidrs = ["0.0.0.0/0"] # Restrict in production

  kms_key_arn = aws_kms_key.eks_secrets_eu_west_1.arn

  environment = "prod"

  providers = {
    aws = aws.eu_west_1
  }

  tags = {
    Environment = "prod"
    Region      = "eu-west-1"
    ManagedBy   = "Terraform"
  }
}

# KMS Key for EKS Secrets in EU West 1
resource "aws_kms_key" "eks_secrets_eu_west_1" {
  provider = aws.eu_west_1

  description             = "KMS key for EKS secrets encryption in eu-west-1"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "prism-platform-eks-secrets-key-eu-west-1"
    Environment = "prod"
    Region      = "eu-west-1"
    ManagedBy   = "Terraform"
  }
}

# Multi-Region Module
module "multi_region" {
  source = "../../modules/multi-region"

  project_name = "prism-platform"
  domain_name  = "prism-platform.com" # Replace with actual domain

  regions = local.regions

  primary_region = "us-west-2"

  acm_certificate_arn = aws_acm_certificate.global_cert.arn

  providers = {
    aws.primary_region = aws.us_west_2
    aws.regions = {
      "us-west-2" = aws.us_west_2
      "us-east-1" = aws.us_east_1
      "eu-west-1" = aws.eu_west_1
    }
  }

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    Project     = "prism-platform"
  }
}

# ACM Certificate for CloudFront (must be in us-east-1)
resource "aws_acm_certificate" "global_cert" {
  provider = aws.us_east_1

  domain_name       = "prism-platform.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.prism-platform.com"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "prism-platform-global-cert"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

# Certificate validation records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.global_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = module.multi_region.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# Certificate validation
resource "aws_acm_certificate_validation" "global_cert" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.global_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
