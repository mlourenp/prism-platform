# Policy fix for EKS inline policy deprecation warnings

# Add IAM role policies explicitly for the EKS cluster role
resource "aws_iam_role_policy" "eks_cluster_policies" {
  count = 1

  name   = "eks-cluster-policies"
  role   = module.eks.cluster_iam_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:*",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# Local values to capture all node group names from the EKS module
locals {
  node_group_name = var.node_group_name
}

# Add IAM role policies explicitly for the EKS node groups
resource "aws_iam_role_policy" "eks_node_group_policies" {
  count = 1

  name   = "eks-node-group-policy-${local.node_group_name}"
  role   = module.eks.eks_managed_node_groups[local.node_group_name].iam_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications",
          "ec2:DescribeVpcs",
          "eks:DescribeCluster",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# We no longer need the exclusive policies - they're causing errors and are now deprecated
# Instead, we'll use the aws_iam_role_policy resources above directly

# The following resources have been removed as they're causing errors:
# - aws_iam_role_policies_exclusive.eks_cluster_exclusive
# - aws_iam_role_policies_exclusive.eks_node_group_exclusive
