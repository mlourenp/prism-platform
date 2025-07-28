#!/bin/bash
set -e

echo "Cleaning up Crossplane resources..."

# Remove provider configurations
echo "Removing provider configurations..."
kubectl delete providerconfig --all --all-namespaces 2>/dev/null || true

# Remove providers
echo "Removing providers..."
kubectl delete provider --all 2>/dev/null || true

# Remove managed resources namespace
echo "Removing managed resources namespace..."
kubectl delete namespace crossplane-managed 2>/dev/null || true
kubectl delete namespace crossplane-system 2>/dev/null || true

# Remove CRDs
echo "Removing Crossplane CRDs..."
kubectl get crds -o name | grep crossplane.io | xargs -r kubectl delete 2>/dev/null || true
kubectl get crds -o name | grep aws.crossplane.io | xargs -r kubectl delete 2>/dev/null || true
kubectl get crds -o name | grep kubernetes.crossplane.io | xargs -r kubectl delete 2>/dev/null || true
kubectl get crds -o name | grep helm.crossplane.io | xargs -r kubectl delete 2>/dev/null || true

echo "Cleanup complete."
echo "You can now run deploy-crossplane.sh to reinstall Crossplane."
