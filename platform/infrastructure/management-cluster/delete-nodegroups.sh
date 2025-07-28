#!/bin/bash
set -e

echo "================================================"
echo "EKS Nodegroup Cleanup Script"
echo "================================================"

# Get cluster name or use provided argument
if [ -z "$1" ]; then
  CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "prism-platform-mgmt")
else
  CLUSTER_NAME="$1"
fi

# Get AWS region or use provided argument
if [ -z "$2" ]; then
  AWS_REGION=$(terraform output -raw region 2>/dev/null || echo "us-west-2")
else
  AWS_REGION="$2"
fi

echo "Cleaning up nodegroups for cluster: $CLUSTER_NAME in region: $AWS_REGION"

# List all nodegroups
echo "Listing all nodegroups for cluster $CLUSTER_NAME..."
NODEGROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --profile default 2>/dev/null | jq -r '.nodegroups[]' 2>/dev/null || echo "")

if [ -z "$NODEGROUPS" ]; then
  echo "No nodegroups found for cluster $CLUSTER_NAME"
  exit 0
fi

echo "Found the following nodegroups to delete:"
echo "$NODEGROUPS"

# Delete each nodegroup
for nodegroup in $NODEGROUPS; do
  echo "Deleting nodegroup $nodegroup using AWS CLI..."
      aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $AWS_REGION --profile default || echo "Failed to delete nodegroup $nodegroup using AWS CLI"

  echo "Waiting for nodegroup $nodegroup deletion to begin..."
  sleep 5
done

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
    echo "Warning: Maximum retries reached for nodegroup $nodegroup."
    echo "You may need to check the AWS Console to ensure proper cleanup."
  fi
done

# Double-check that all nodegroups are gone
REMAINING_NODEGROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --profile default 2>/dev/null | jq -r '.nodegroups | length' 2>/dev/null || echo "0")

if [ "$REMAINING_NODEGROUPS" != "0" ]; then
  echo "Warning: There are still $REMAINING_NODEGROUPS nodegroup(s) attached to the cluster."
  echo "This may cause the cluster deletion to fail. Consider checking the AWS Console."
  exit 1
else
  echo "All nodegroups have been successfully deleted."
  echo "You can now proceed with cluster deletion."
  echo "================================================"
  exit 0
fi
