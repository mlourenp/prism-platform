#!/bin/bash
# This script handles Phase 2 of the EKS deployment - installing add-ons and Crossplane

set -e

echo "🚀 Starting Phase 2 Deployment: Kubernetes Add-ons and Crossplane"

# 1. First, let's ensure we can connect to the cluster
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "prism-platform-mgmt")
REGION=$(terraform output -raw region 2>/dev/null || echo "us-west-2")
AWS_PROFILE="default"

echo "🔑 Configuring kubectl for cluster $CLUSTER_NAME in $REGION..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME --profile $AWS_PROFILE

# 2. Verify connectivity
echo "🔍 Verifying cluster connectivity..."
kubectl get nodes

# 3. Uncomment the add-ons in the Terraform files
echo "📝 Restoring add-ons in Terraform files..."

# Uncomment EKS blueprints add-ons
sed -i.bak -e '/^\/\* *$/,/^ *\*\/ *$/s/^/# PHASE2: /' -e '/^# PHASE2: \/\*/d' -e '/^# PHASE2:  \*\//d' main.tf

# Uncomment Crossplane config
sed -i.bak -e '/^\/\* *$/,/^ *\*\/ *$/s/^/# PHASE2: /' -e '/^# PHASE2: \/\*/d' -e '/^# PHASE2:  \*\//d' crossplane.tf

# Uncomment Kubernetes resources in additional_resources.tf
sed -i.bak -e '/^\/\* *$/,/^ *\*\/ *$/s/^/# PHASE2: /' -e '/^# PHASE2: \/\*/d' -e '/^# PHASE2:  \*\//d' additional_resources.tf

echo "✅ Successfully uncommented Terraform configurations"

# 4. Re-run Terraform
echo "🔄 Applying updated Terraform configuration..."
terraform apply -auto-approve

# 5. Verify Crossplane installation
echo "🔍 Verifying Crossplane installation..."
kubectl get pods -n crossplane-system

# 6. Verify EKS add-ons
echo "🔍 Verifying EKS add-ons..."
kubectl get pods -n kube-system | grep -E 'metrics-server|aws-load-balancer-controller|cluster-autoscaler'

echo "✅ Phase 2 deployment completed successfully!"
