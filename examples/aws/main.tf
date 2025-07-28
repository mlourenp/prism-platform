# AWS Example Deployment for Prism Infrastructure Platform
# This example shows how to deploy Prism on AWS with basic configuration

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}

# Configure Kubernetes Provider (assumes EKS cluster exists)
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Configure Helm Provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Data sources for existing EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# Deploy Prism Infrastructure Platform
module "prism" {
  source = "../../"
  
  # Global configuration
  environment  = var.environment
  project_name = "prism-aws-example"
  
  # AWS-specific configuration
  aws_primary_region = var.aws_region
  
  # Feature configuration - basic setup
  enable_crossplane           = true
  enable_service_mesh         = false  # Start with basics
  enable_ebpf_observability   = false  # Enable in later stages
  enable_observability_stack  = false  # Toggle on when needed
  enable_telemetry_agent      = false  # Optional for insights
  enable_cost_estimation      = true   # Always useful
  
  # Tags
  common_tags = var.common_tags
}

# Example: Create a simple workload cell
module "example_workload_cell" {
  source = "../../modules/cell-deployment"
  
  # Dependencies
  depends_on = [module.prism]
  
  # Configuration
  environment = var.environment
  name_prefix = "example-workload"
  
  # Cell-specific configuration
  default_cell_config = {
    cpu_limit     = "1000m"
    memory_limit  = "2Gi"
    storage_limit = "10Gi"
    replica_count = 2
  }
  
  # AWS networking
  vpc_cidr_block = "10.0.0.0/16"
  
  # Feature flags (aligned with main platform)
  enable_service_mesh      = false
  enable_ebpf_policies     = false
  enable_observability     = false
  
  common_tags = var.common_tags
} 