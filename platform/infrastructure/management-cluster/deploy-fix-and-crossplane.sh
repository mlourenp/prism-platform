#!/bin/bash
set -e

echo "================================================"
echo "EKS Management Cluster - Policy Fix and Crossplane Deployment"
echo "================================================"

# Step 1: Apply the policy fix
echo "Step 1: Applying EKS policy fix..."
./policy-fix-complete.sh

# Step 2: Check if Crossplane namespace exists (to determine if we need to run the cleanup)
if kubectl get namespace crossplane-system >/dev/null 2>&1; then
  echo "Step 2: Existing Crossplane installation detected."
  echo "Would you like to clean up the existing installation? (y/n)"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Running Crossplane cleanup..."
    ./cleanup-crossplane.sh
  else
    echo "Skipping cleanup. Will attempt to work with existing installation."
  fi
else
  echo "Step 2: No existing Crossplane installation detected."
fi

# Step 3: Deploy Crossplane
echo "Step 3: Deploying Crossplane..."
./deploy-crossplane.sh

echo "================================================"
echo "Deployment Complete!"
echo "To verify Crossplane installation, run: kubectl get providers"
echo "To access the cluster dashboard, run: kubectl -n kubernetes-dashboard create token admin-user"
echo "================================================"
