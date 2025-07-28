variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "prism-platform-mgmt"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "region" {
  description = "AWS region to deploy the resources"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
  default     = "mgmt-nodes"
}

variable "node_instance_types" {
  description = "Instance types for the EKS node group"
  type        = list(string)
  default     = ["m5.large"]
}

variable "node_desired_capacity" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_min_capacity" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_max_capacity" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Disk size for the EKS nodes in GB"
  type        = number
  default     = 50
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "management"
    ManagedBy   = "terraform"
    Purpose     = "crossplane-management"
  }
}

variable "crossplane_version" {
  description = "Version of Crossplane Helm chart to install"
  type        = string
  default     = "1.15.1"
}

variable "crossplane_namespace" {
  description = "Kubernetes namespace for Crossplane"
  type        = string
  default     = "crossplane-system"
}

variable "aws_provider_version" {
  description = "Version of AWS Provider for Crossplane"
  type        = string
  default     = "v0.37.0"
}

variable "k8s_provider_version" {
  description = "Version of Kubernetes Provider for Crossplane"
  type        = string
  default     = "v0.7.0"
}

variable "helm_provider_version" {
  description = "Version of Helm Provider for Crossplane"
  type        = string
  default     = "v0.18.0"
}

# ECR Variables
variable "create_ecr_repository" {
  description = "Whether to create ECR repositories"
  type        = bool
  default     = true
}

variable "ecr_repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["prism-platform/base", "prism-platform/drift-detector", "prism-platform/feedback-loop"]
}

variable "ecr_image_tag_mutability" {
  description = "The tag mutability setting for the ECR repositories"
  type        = string
  default     = "MUTABLE"
}

variable "ecr_image_scanning_configuration" {
  description = "Configuration for image scanning in the ECR repositories"
  type        = object({
    scan_on_push = bool
  })
  default = {
    scan_on_push = true
  }
}

variable "ecr_lifecycle_policy" {
  description = "Whether to enable ECR lifecycle policy"
  type        = bool
  default     = true
}

variable "ecr_max_image_count" {
  description = "Maximum number of images to keep in ECR repositories"
  type        = number
  default     = 20
}
