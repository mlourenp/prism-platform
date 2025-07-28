terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }

  # Backend configuration should only be in root module
  # backend "s3" {
  #   # These values should be provided through backend config or environment variables
  #   # bucket         = "your-terraform-state-bucket"
  #   # key            = "management-cluster/terraform.tfstate"
  #   # region         = "us-west-2"
  #   # dynamodb_table = "terraform-locks"
  #   # encrypt        = true
  # }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile  # Configurable AWS profile (null uses default credential chain)

  # Additional provider configurations as needed
  # assume_role {
  #   role_arn = "arn:aws:iam::123456789012:role/TerraformExecutionRole"
  # }

  default_tags {
    tags = var.tags
  }
}

# Kubernetes provider will be configured after the EKS cluster is created
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = var.aws_profile != null ? ["eks", "get-token", "--cluster-name", var.cluster_name, "--profile", var.aws_profile] : ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

# Helm provider for installing Crossplane
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = var.aws_profile != null ? ["eks", "get-token", "--cluster-name", var.cluster_name, "--profile", var.aws_profile] : ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}

# Kubectl provider for custom resources
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--profile", "prism-platform-role"]
    command     = "aws"
  }
}
