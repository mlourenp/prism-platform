output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_private_subnets" {
  description = "VPC private subnets"
  value       = module.vpc.private_subnets
}

output "vpc_public_subnets" {
  description = "VPC public subnets"
  value       = module.vpc.public_subnets
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

output "crossplane_namespace" {
  description = "The namespace where Crossplane is installed"
  value       = var.crossplane_namespace
}

output "crossplane_version" {
  description = "The version of Crossplane installed"
  value       = var.crossplane_version
}

output "kubectl_config_command" {
  description = "Command to configure kubectl to access the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "crossplane_status_command" {
  description = "Command to check Crossplane installation status"
  value       = "kubectl get pods -n ${var.crossplane_namespace}"
}

output "crossplane_providers_command" {
  description = "Command to check Crossplane providers status"
  value       = "kubectl get providers -n ${var.crossplane_namespace}"
}

# ECR Outputs
output "ecr_repository_urls" {
  description = "URLs of the ECR repositories"
  value       = var.create_ecr_repository ? { for repo in aws_ecr_repository.this : repo.name => repo.repository_url } : {}
}

output "ecr_registry_id" {
  description = "Registry ID of ECR"
  value       = var.create_ecr_repository && length(aws_ecr_repository.this) > 0 ? aws_ecr_repository.this[0].registry_id : null
}

output "ecr_registry_url" {
  description = "Base URL of ECR registry"
  value       = var.create_ecr_repository && length(aws_ecr_repository.this) > 0 ? "${aws_ecr_repository.this[0].registry_id}.dkr.ecr.${var.region}.amazonaws.com" : null
}

output "ecr_login_command" {
  description = "Command to authenticate Docker to ECR"
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.create_ecr_repository && length(aws_ecr_repository.this) > 0 ? "${aws_ecr_repository.this[0].registry_id}.dkr.ecr.${var.region}.amazonaws.com" : ""}"
}
