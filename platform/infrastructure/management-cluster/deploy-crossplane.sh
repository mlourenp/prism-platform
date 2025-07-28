#!/bin/bash
set -e

echo "Starting Crossplane deployment with phased approach..."

# Function to check if CRDs are installed
check_crd_exists() {
  local crd_name=$1
  kubectl get crd $crd_name >/dev/null 2>&1
  return $?
}

# Function to wait for a CRD to be registered
wait_for_crd() {
  local crd_name=$1
  local max_attempts=30
  local attempt=1

  echo "Waiting for CRD $crd_name to be registered..."

  while ! check_crd_exists $crd_name; do
    if [ $attempt -gt $max_attempts ]; then
      echo "CRD $crd_name not registered after $max_attempts attempts"
      return 1
    fi

    echo "Attempt $attempt/$max_attempts: CRD $crd_name not yet registered, waiting..."
    sleep 10
    attempt=$((attempt + 1))
  done

  echo "✓ CRD $crd_name is registered"
  return 0
}

# Phase 1: Install Crossplane core
echo "Phase 1: Installing Crossplane core..."
terraform apply -target=helm_release.crossplane -auto-approve

# Wait for core Crossplane CRDs to be registered
echo "Waiting for Crossplane core CRDs to be registered..."
wait_for_crd "providers.pkg.crossplane.io" || exit 1
wait_for_crd "configurations.pkg.crossplane.io" || exit 1

echo "Crossplane core installation complete."
sleep 30  # Give some time for the controllers to start

# Phase 2: Install Providers one by one
echo "Phase 2: Installing AWS Provider..."
terraform apply -target=kubectl_manifest.crossplane_aws_provider -auto-approve

echo "Waiting for AWS Provider CRDs to be registered..."
wait_for_crd "providerconfigs.aws.crossplane.io" || exit 1
sleep 30  # Give time for the AWS provider controller to start

echo "Installing Kubernetes Provider..."
terraform apply -target=kubectl_manifest.crossplane_k8s_provider -auto-approve

echo "Waiting for Kubernetes Provider CRDs to be registered..."
wait_for_crd "providerconfigs.kubernetes.crossplane.io" || exit 1
sleep 30

echo "Installing Helm Provider..."
terraform apply -target=kubectl_manifest.crossplane_helm_provider -auto-approve

echo "Waiting for Helm Provider CRDs to be registered..."
wait_for_crd "providerconfigs.helm.crossplane.io" || exit 1
sleep 30

# Phase 3: Install Provider Configurations
echo "Phase 3: Installing Provider Configurations..."
echo "Installing AWS Provider Configuration..."
terraform apply -target=kubectl_manifest.aws_provider_config -auto-approve

echo "Installing Kubernetes Provider Configuration..."
terraform apply -target=kubectl_manifest.k8s_provider_config -auto-approve

echo "Installing Helm Provider Configuration..."
terraform apply -target=kubectl_manifest.helm_provider_config -auto-approve

# Phase 4: Create managed resources namespace and finalize installation
echo "Phase 4: Creating managed resources namespace and finalizing installation..."
terraform apply -target=kubernetes_namespace.crossplane_managed -auto-approve

# Finally, run a complete apply to ensure everything is in sync
echo "Phase 5: Running final apply to ensure all resources are created..."
terraform apply -auto-approve

echo "Crossplane installation complete!"
echo "To verify installation, run: kubectl get providers"
