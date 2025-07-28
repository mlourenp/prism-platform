#!/bin/bash
set -e

echo "================================================"
echo "EKS Management Cluster - Status Check"
echo "================================================"

# Get cluster info
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "unknown")
REGION=$(terraform output -raw region 2>/dev/null || echo "unknown")

echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

# Check if kubectl is configured
echo "Checking kubectl configuration..."
if ! kubectl cluster-info &>/dev/null; then
  echo "⚠️  kubectl is not configured for this cluster."
  echo "   Run: aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"
  echo ""
else
  echo "✅ kubectl is properly configured."

  # Check nodes
  echo ""
  echo "Node Status:"
  kubectl get nodes -o wide

  # Check system pods
  echo ""
  echo "Critical System Pods Status:"
  kubectl get pods -n kube-system

  # Check add-ons
  echo ""
  echo "EKS Add-ons Status:"
  ADDONS_NAMESPACES="cert-manager aws-for-fluent-bit"
  for ns in $ADDONS_NAMESPACES; do
    if kubectl get namespace $ns &>/dev/null; then
      echo ""
      echo "$ns:"
      kubectl get pods -n $ns
    fi
  done

  # Check Crossplane
  echo ""
  echo "Crossplane Status:"
  if kubectl get namespace crossplane-system &>/dev/null; then
    echo "Crossplane Pods:"
    kubectl get pods -n crossplane-system

    echo ""
    echo "Crossplane Providers:"
    kubectl get providers

    echo ""
    echo "Provider Configurations:"
    kubectl get providerconfigs
  else
    echo "⚠️  Crossplane is not installed."
  fi
fi

# Check AWS resources
echo ""
echo "AWS Resources Status:"

# Check VPC
echo "VPC: $(terraform state list | grep module.vpc.aws_vpc.this || echo 'Not found')"

# Check EKS
echo "EKS: $(terraform state list | grep module.eks.aws_eks_cluster.this || echo 'Not found')"

# Check ECR Repositories
echo "ECR Repositories:"
aws ecr describe-repositories --region $REGION --query "repositories[].repositoryUri" --output table 2>/dev/null || echo "None found or no permissions"

echo ""
echo "================================================"
