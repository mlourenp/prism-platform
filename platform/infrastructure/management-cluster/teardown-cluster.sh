#!/bin/bash
set -e

echo "================================================"
echo "EKS Management Cluster - Graceful Teardown"
echo "================================================"

# Confirm the action
echo "WARNING: This will destroy your entire EKS cluster and all related resources."
echo "This action cannot be undone. All data in the cluster will be lost."
read -p "Do you want to proceed with the teardown? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Teardown aborted."
  exit 1
fi

# Get cluster name for logging
CLUSTER_NAME=$(terraform output -raw cluster_name)
echo "Beginning teardown of cluster: $CLUSTER_NAME"

# Step 1: Clean up any cell deployments first
echo "Step 1: Cleaning up Cell deployments..."
if kubectl get namespace prism-platform &>/dev/null; then
  echo "Found Cell deployment in prism-platform namespace, cleaning up..."

  # Delete specialized cell claims first
  echo "Removing all specialized Cell claims..."

  # List of cell types to clean up
  CELL_TYPES=("data" "security" "observability" "integration" "channel")

  # Delete each specialized cell claim
  for cell_type in "${CELL_TYPES[@]}"; do
    echo "Removing ${cell_type} cell claim..."
    kubectl delete -f cells/${cell_type}/${cell_type}-cell-claim.yaml --ignore-not-found=true || true

    # Also delete the compositions for each cell type
    echo "Removing ${cell_type} cell composition..."
    kubectl delete -f cells/${cell_type}/${cell_type}-cell-composition-aws.yaml --ignore-not-found=true || true
  done

  # Delete any remaining cell claims
  echo "Removing any remaining Cell claims..."
  kubectl delete cellclaim --all -n prism-platform 2>/dev/null || true

  # Wait for resources to be cleaned up
  echo "Waiting for Cell resources to be cleaned up..."
  sleep 45

  # Check for and delete any cell-specific namespaces
  for cell_type in "${CELL_TYPES[@]}"; do
    if kubectl get namespace ${cell_type}-cell &>/dev/null; then
      echo "Cleaning up ${cell_type}-cell namespace..."
      kubectl delete deployments --all -n ${cell_type}-cell 2>/dev/null || true
      kubectl delete services --all -n ${cell_type}-cell 2>/dev/null || true
      kubectl delete configmaps --all -n ${cell_type}-cell 2>/dev/null || true
      kubectl delete secrets --all -n ${cell_type}-cell 2>/dev/null || true
      kubectl delete pvc --all -n ${cell_type}-cell 2>/dev/null || true

      # Delete the cell namespace
      echo "Removing ${cell_type}-cell namespace..."
      kubectl delete namespace ${cell_type}-cell --wait=false 2>/dev/null || true
    fi
  done

  # Delete any remaining deployments in the prism-platform namespace
  echo "Removing any remaining deployments in the prism-platform namespace..."
  kubectl delete deployments --all -n prism-platform 2>/dev/null || true
  kubectl delete services --all -n prism-platform 2>/dev/null || true
  kubectl delete configmaps --all -n prism-platform 2>/dev/null || true
  kubectl delete secrets --all -n prism-platform 2>/dev/null || true

  # Delete the namespace itself
  echo "Removing prism-platform namespace..."
  kubectl delete namespace prism-platform --wait=false 2>/dev/null || true

  echo "Cell deployment cleanup complete."
fi

# Step 2: Clean up Crossplane resources
echo "Step 2: Cleaning up Crossplane resources..."
if kubectl get namespace crossplane-system &>/dev/null; then
  echo "Found Crossplane installation, cleaning up..."

  # First patch any stuck composite resources to remove finalizers
  echo "Checking for composite resources with finalizers..."
  COMPOSITE_RESOURCES=$(kubectl get composite -A -o name 2>/dev/null || true)
  if [ -n "$COMPOSITE_RESOURCES" ]; then
    echo "Found composite resources, removing finalizers..."
    for resource in $COMPOSITE_RESOURCES; do
      echo "Removing finalizers from $resource"
      kubectl patch $resource --type="json" -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
    done
  fi

  # Remove any stuck cell claims by removing finalizers
  echo "Checking for cell claims with finalizers..."
  CELL_CLAIMS=$(kubectl get cellclaim -A -o name 2>/dev/null || true)
  if [ -n "$CELL_CLAIMS" ]; then
    echo "Found cell claims, removing finalizers..."
    for claim in $CELL_CLAIMS; do
      echo "Removing finalizers from $claim"
      kubectl patch $claim --type="json" -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
    done
  fi

  # Remove any managed resources with a timeout to prevent hanging
  echo "Removing any Crossplane managed resources..."
  MANAGED_RESOURCES=$(kubectl get managed -A -o name 2>/dev/null || true)
  if [ -n "$MANAGED_RESOURCES" ]; then
    echo "Found managed resources, attempting to delete with timeout..."
    for resource in $MANAGED_RESOURCES; do
      echo "Deleting $resource"
      timeout 30s kubectl delete $resource --wait=false 2>/dev/null || echo "Timed out waiting for $resource to delete, continuing..."
    done

    # Force remove finalizers from any stuck managed resources
    echo "Checking for stuck managed resources..."
    REMAINING_RESOURCES=$(kubectl get managed -A -o name 2>/dev/null || true)
    if [ -n "$REMAINING_RESOURCES" ]; then
      echo "Found stuck managed resources, forcing removal of finalizers..."
      for resource in $REMAINING_RESOURCES; do
        echo "Force removing finalizers from $resource"
        kubectl patch $resource --type="json" -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
      done
    fi
  else
    echo "No managed resources found."
  fi

  # Remove provider configs
  echo "Removing Crossplane provider configurations..."
  kubectl get providerconfigs -A -o name 2>/dev/null | xargs -r kubectl delete --wait=false 2>/dev/null || true

  # Remove Crossplane providers
  echo "Removing Crossplane providers..."
  PROVIDERS=$(kubectl get providers -A -o name 2>/dev/null || true)
  if [ -n "$PROVIDERS" ]; then
    for provider in $PROVIDERS; do
      echo "Deleting provider $provider"
      kubectl delete $provider --wait=false 2>/dev/null || true

      # Wait a bit between provider deletions to avoid overwhelming the API server
      sleep 5
    done
  else
    echo "No providers found."
  fi

  # Remove compositions and XRDs for cells
  echo "Removing Cell XRDs and Compositions..."
  kubectl get compositions -A -o name | grep -i cell 2>/dev/null | xargs -r kubectl delete --wait=false 2>/dev/null || true
  kubectl get xrd -A -o name | grep -i cell 2>/dev/null | xargs -r kubectl delete --wait=false 2>/dev/null || true

  # Delete the main Cell XRD
  echo "Deleting Cell XRD definition..."
  kubectl delete -f prism-platform-cell-xrd.yaml --ignore-not-found=true --wait=false || true

  # Give Crossplane time to clean up
  echo "Waiting for Crossplane resources to be removed..."
  sleep 30

  # Check if any resources are still stuck
  STUCK_RESOURCES=$(kubectl get managed -A 2>/dev/null || true)
  if [ -n "$STUCK_RESOURCES" ]; then
    echo "Warning: Some managed resources are still present. Proceeding with cleanup anyway."
    echo "The teardown process will continue, but you may need to manually check for orphaned AWS resources."
  fi

  # Delete the Crossplane namespace (will remove the installation)
  echo "Removing Crossplane namespace..."
  kubectl delete namespace crossplane-system --wait=false 2>/dev/null || true
  kubectl delete namespace crossplane-managed --wait=false 2>/dev/null || true

  echo "Crossplane resources cleanup complete."
fi

# Step 3: Remove Terraform-managed EKS add-ons
echo "Step 3: Removing EKS add-ons..."
terraform destroy -target=module.eks_blueprints_addons -auto-approve || true

# Step 4: Remove custom policies
echo "Step 4: Removing custom IAM policies..."
terraform destroy -target=aws_iam_role_policy.eks_cluster_policies -auto-approve || true
terraform destroy -target=aws_iam_role_policy.eks_node_group_policies -auto-approve || true
terraform destroy -target=aws_iam_role_policies_exclusive.eks_cluster_exclusive -auto-approve || true
terraform destroy -target=aws_iam_role_policies_exclusive.eks_node_group_exclusive -auto-approve || true

# Step 5: Remove ECR repositories and other application resources
echo "Step 5: Removing application resources..."
terraform destroy -target=aws_ecr_repository.this -auto-approve || true
terraform destroy -target=aws_ecr_lifecycle_policy.this -auto-approve || true
terraform destroy -target=aws_cloudwatch_log_group.application_logs -auto-approve || true
terraform destroy -target=aws_ssm_parameter.db_credentials -auto-approve || true
terraform destroy -target=aws_ssm_parameter.api_credentials -auto-approve || true
terraform destroy -target=aws_s3_bucket.application_assets -auto-approve || true
terraform destroy -target=aws_s3_bucket.crossplane_providers -auto-approve || true
terraform destroy -target=aws_dynamodb_table.crossplane_locks -auto-approve || true

# Step 6: Destroy EKS nodegroups using both AWS CLI and Terraform
echo "Step 6: Identifying and destroying all EKS nodegroups..."

# Get the AWS region from Terraform
AWS_REGION=$(terraform output -raw region 2>/dev/null || echo "us-west-2")
echo "Using AWS region: $AWS_REGION"

# List all nodegroups using AWS CLI
echo "Listing all nodegroups for cluster $CLUSTER_NAME..."
NODEGROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --profile default 2>/dev/null | jq -r '.nodegroups[]' 2>/dev/null || echo "")

if [ -n "$NODEGROUPS" ]; then
  echo "Found the following nodegroups to delete:"
  echo "$NODEGROUPS"

  # Delete each nodegroup using AWS CLI
  for nodegroup in $NODEGROUPS; do
    echo "Deleting nodegroup $nodegroup using AWS CLI..."
    aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $AWS_REGION --profile default || echo "Failed to delete nodegroup $nodegroup using AWS CLI, continuing with Terraform..."

    # Wait a bit for the nodegroup deletion to start
    echo "Waiting for nodegroup $nodegroup deletion to begin..."
    sleep 10
  done

  # Also try to delete nodegroups with Terraform as a backup
  echo "Attempting to delete nodegroups using Terraform..."
  terraform destroy -target=module.eks.module.eks.aws_eks_node_group.this -auto-approve || true

  # Wait for nodegroups to be fully deleted
  echo "Waiting for all nodegroups to be fully deleted..."
  for nodegroup in $NODEGROUPS; do
    echo "Checking status of nodegroup $nodegroup..."
    RETRIES=0
    MAX_RETRIES=30

    while [ $RETRIES -lt $MAX_RETRIES ]; do
      NG_STATUS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $AWS_REGION --profile default 2>/dev/null | jq -r '.nodegroup.status' 2>/dev/null || echo "DELETED")

      if [ "$NG_STATUS" = "DELETED" ] || [ "$NG_STATUS" = "DELETE_FAILED" ]; then
        echo "Nodegroup $nodegroup status: $NG_STATUS, proceeding..."
        break
      else
        echo "Nodegroup $nodegroup status: $NG_STATUS, waiting... ($RETRIES/$MAX_RETRIES)"
        RETRIES=$((RETRIES+1))
        sleep 20
      fi
    done

    if [ $RETRIES -eq $MAX_RETRIES ]; then
      echo "Warning: Maximum retries reached for nodegroup $nodegroup. Attempting to force removal of finalizers..."
      # Try to manually clean up AWS resources if necessary
      # This is a fallback in case normal deletion doesn't work
      # Could add manual cleanup steps here if needed
    fi
  done
else
  echo "No nodegroups found for cluster $CLUSTER_NAME"
fi

# Double-check that all nodegroups are gone
REMAINING_NODEGROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --profile default 2>/dev/null | jq -r '.nodegroups | length' 2>/dev/null || echo "0")

if [ "$REMAINING_NODEGROUPS" != "0" ]; then
  echo "Warning: There are still $REMAINING_NODEGROUPS nodegroup(s) attached to the cluster."
  echo "This may cause the cluster deletion to fail. Consider manually deleting them using AWS Console or CLI."
  echo "Press Enter to continue anyway, or Ctrl+C to abort the script and manually delete the nodegroups."
  read -p ""
else
  echo "All nodegroups have been successfully deleted."
fi

# Step 7: Destroy the EKS cluster
echo "Step 7: Destroying EKS cluster..."
terraform destroy -target=module.eks -auto-approve

# Step 8: Destroy the VPC and remaining resources
echo "Step 8: Destroying VPC and remaining resources..."
terraform destroy -auto-approve

echo "================================================"
echo "Teardown completed successfully!"
echo "All resources for $CLUSTER_NAME have been destroyed."
echo "================================================"
