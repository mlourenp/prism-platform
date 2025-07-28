output "cluster_id" {
  description = "The name/ID of the EKS cluster"
  value       = aws_eks_cluster.cluster.id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.cluster.arn
}

output "cluster_endpoint" {
  description = "The endpoint for the Kubernetes API server"
  value       = aws_eks_cluster.cluster.endpoint
}

output "kubernetes_api_endpoint" {
  description = "The endpoint for the Kubernetes API server (alias for cluster_endpoint)"
  value       = aws_eks_cluster.cluster.endpoint
}

output "cluster_security_group_id" {
  description = "The security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "The security group ID attached to the EKS nodes"
  value       = aws_security_group.node.id
}

output "cluster_certificate_authority_data" {
  description = "The base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.cluster.certificate_authority[0].data
  sensitive   = true
}

output "ondemand_node_group_id" {
  description = "The ID of the on-demand node group"
  value       = aws_eks_node_group.ondemand.id
}

output "ondemand_node_group_arn" {
  description = "The ARN of the on-demand node group"
  value       = aws_eks_node_group.ondemand.arn
}

output "spot_node_group_id" {
  description = "The ID of the spot node group"
  value       = aws_eks_node_group.spot.id
}

output "spot_node_group_arn" {
  description = "The ARN of the spot node group"
  value       = aws_eks_node_group.spot.arn
}

output "cluster_role_arn" {
  description = "The ARN of the IAM role used by the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "The ARN of the IAM role used by the EKS nodes"
  value       = aws_iam_role.node.arn
}

output "eks_managed_node_groups" {
  description = "Map of EKS managed node groups"
  value = {
    ondemand = {
      id        = aws_eks_node_group.ondemand.id
      arn       = aws_eks_node_group.ondemand.arn
      status    = aws_eks_node_group.ondemand.status
      capacity  = "ON_DEMAND"
      node_role = aws_iam_role.node.arn
    }
    spot = {
      id        = aws_eks_node_group.spot.id
      arn       = aws_eks_node_group.spot.arn
      status    = aws_eks_node_group.spot.status
      capacity  = "SPOT"
      node_role = aws_iam_role.node.arn
    }
  }
}
