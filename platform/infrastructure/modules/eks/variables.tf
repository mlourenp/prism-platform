variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "ID of the VPC where the EKS cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where the EKS cluster will be created"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "database_subnet_ids" {
  description = "List of database subnet IDs"
  type        = list(string)
  default     = []
}

variable "api_access_cidrs" {
  description = "List of CIDR blocks that can access the Kubernetes API server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting Kubernetes secrets"
  type        = string
}

variable "ondemand_node_desired_size" {
  description = "Desired number of on-demand nodes in the node group"
  type        = number
  default     = 2
}

variable "ondemand_node_min_size" {
  description = "Minimum number of on-demand nodes in the node group"
  type        = number
  default     = 1
}

variable "ondemand_node_max_size" {
  description = "Maximum number of on-demand nodes in the node group"
  type        = number
  default     = 4
}

variable "spot_node_desired_size" {
  description = "Desired number of spot nodes in the node group"
  type        = number
  default     = 1
}

variable "spot_node_min_size" {
  description = "Minimum number of spot nodes in the node group"
  type        = number
  default     = 0
}

variable "spot_node_max_size" {
  description = "Maximum number of spot nodes in the node group"
  type        = number
  default     = 10
}

variable "ondemand_instance_types" {
  description = "List of EC2 instance types for on-demand node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "spot_instance_types" {
  description = "List of EC2 instance types for spot node group"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium", "t3.large", "t3a.large"]
}

variable "node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 20
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
