#!/bin/bash

# Comprehensive AWS Resource Audit for Prism Platform
echo "🔍 Comprehensive AWS Resource Audit for Prism Platform"
echo "=================================================="

# Define regions to check
REGIONS=("us-east-1" "us-west-2" "eu-west-1" "us-east-2")

total_resources=0

for region in "${REGIONS[@]}"; do
    echo
    echo "=== Checking region: $region ==="
    
    # Check VPCs
    echo -n "VPCs: "
    aws ec2 describe-vpcs --region "$region" --query 'length(Vpcs[?IsDefault==`false`])' --output text 2>/dev/null || echo "No access"
    
    # Check EC2 Instances
    echo -n "EC2 Instances: "
    aws ec2 describe-instances --region "$region" --query 'length(Reservations[].Instances[?State.Name!=`terminated`])' --output text 2>/dev/null || echo "No access"
    
    # Check EKS Clusters
    echo -n "EKS Clusters: "
    aws eks list-clusters --region "$region" --query 'length(clusters)' --output text 2>/dev/null || echo "No access"
done

echo
echo "📊 Complete audit finished. Check output above for any resources."
