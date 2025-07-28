#!/bin/bash
set -e

echo "Continuing in-flight EKS add-ons deployment..."

# Function to detect and fix common issues
fix_common_issues() {
  # Check if there are Terraform state issues, if so, refresh state
  echo "Refreshing Terraform state..."
  terraform refresh

  # Fix any existing webhook configurations before proceeding
  echo "Fixing any existing webhook configurations..."
  if kubectl get mutatingwebhookconfiguration -o name 2>/dev/null | grep aws-load-balancer-webhook >/dev/null 2>&1; then
    echo "Increasing webhook timeouts for existing webhooks..."
    kubectl get mutatingwebhookconfiguration -o name | grep aws-load-balancer-webhook | xargs -I{} kubectl patch {} --type json -p '[{"op":"replace","path":"/webhooks/0/timeoutSeconds","value":30}]' || true
    kubectl get validatingwebhookconfiguration -o name | grep aws-load-balancer-webhook | xargs -I{} kubectl patch {} --type json -p '[{"op":"replace","path":"/webhooks/0/timeoutSeconds","value":30}]' || true

    echo "Restarting any existing AWS Load Balancer Controller deployments..."
    kubectl rollout restart deployment aws-load-balancer-controller -n kube-system 2>/dev/null || true

    echo "Waiting for controller to stabilize..."
    sleep 30
  fi
}

# Function to wait for a resource to be available
wait_for_resource() {
  resource_type=$1
  resource_name=$2
  namespace=$3
  max_attempts=${4:-20}

  echo "Waiting for $resource_type/$resource_name in namespace $namespace..."

  attempt=1
  until kubectl get $resource_type $resource_name -n $namespace >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -gt $max_attempts ]; then
      echo "Resource $resource_type/$resource_name not found after $max_attempts attempts, continuing anyway..."
      return 1
    fi
    echo "Waiting for $resource_type/$resource_name to appear (attempt $attempt/$max_attempts)..."
    sleep 15
  done

  if [ "$resource_type" == "deployment" ]; then
    echo "Waiting for deployment to be available..."
    kubectl wait --for=condition=available --timeout=300s deployment/$resource_name -n $namespace || true
  fi

  return 0
}

# Step 1: Verify kubectl access to the cluster
echo "Verifying cluster access..."
kubectl get nodes

# Call fix function at the beginning
fix_common_issues

# Step 2: Apply metrics server first (no webhook dependencies)
echo "Phase 1: Installing Metrics Server..."
terraform apply -target=module.eks_blueprints_addons.module.metrics_server -auto-approve || true

# Wait for metrics-server deployment
wait_for_resource deployment metrics-server kube-system

# Step 3: Apply Load Balancer Controller with patience
echo "Phase 2: Installing AWS Load Balancer Controller..."
terraform apply -target=module.eks_blueprints_addons.module.aws_load_balancer_controller -auto-approve || fix_common_issues

# Step 4: Wait for LB controller to be fully ready
echo "Waiting for AWS Load Balancer Controller to be ready..."
wait_for_resource deployment aws-load-balancer-controller kube-system

echo "Sleeping for 30 seconds to ensure webhooks have time to register..."
sleep 30

# Step 5: Apply cert-manager separately
echo "Phase 3: Installing cert-manager..."
terraform apply -target=module.eks_blueprints_addons.module.cert_manager -auto-approve || fix_common_issues

# Wait for cert-manager deployments
wait_for_resource deployment cert-manager cert-manager
wait_for_resource deployment cert-manager-webhook cert-manager
wait_for_resource deployment cert-manager-cainjector cert-manager

echo "Sleeping for 30 seconds to ensure cert-manager webhooks have time to register..."
sleep 30

# Step 6: Apply the remaining add-ons
echo "Phase 4: Installing remaining add-ons..."
terraform apply -target=module.eks_blueprints_addons.module.cluster_autoscaler -auto-approve || fix_common_issues
wait_for_resource deployment cluster-autoscaler-aws-cluster-autoscaler kube-system

terraform apply -target=module.eks_blueprints_addons.module.aws_for_fluentbit -auto-approve || fix_common_issues
wait_for_resource daemonset aws-for-fluent-bit kube-system

# Step 7: Final apply to ensure consistency
echo "Phase 5: Final apply to ensure all resources are consistent..."
terraform apply -auto-approve || (fix_common_issues && terraform apply -auto-approve)

echo "EKS add-ons deployment completed!"
echo "If you still encounter webhook errors, run ./reset-webhooks.sh and then run this script again."
