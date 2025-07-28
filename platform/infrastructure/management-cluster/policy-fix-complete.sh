#!/bin/bash
set -e

echo "Applying EKS module policy fix..."

# Force refresh the EKS module state
echo "Refreshing EKS module state..."
terraform refresh

# Apply the policy fix resources
echo "Applying policy fix resources..."
terraform apply -target=aws_iam_role_policy.eks_cluster_policies[0] -auto-approve
terraform apply -target=aws_iam_role_policy.eks_node_group_policies[0] -auto-approve
terraform apply -target=aws_iam_role_policies_exclusive.eks_cluster_exclusive[0] -auto-approve
terraform apply -target=aws_iam_role_policies_exclusive.eks_node_group_exclusive[0] -auto-approve

# Final apply to ensure consistency
echo "Running final apply to ensure all resources are consistent..."
terraform apply -auto-approve

echo "Policy fix complete! If you still see deprecation warnings, they are likely coming from the module itself."
echo "These warnings don't affect functionality and will be resolved when the module is updated."
echo ""
echo "You can now proceed with Crossplane deployment using ./deploy-crossplane.sh"
