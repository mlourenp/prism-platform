#!/bin/bash

# Comprehensive AWS Resource Audit for Prism Platform
# Supports multiple AWS profiles and checks all resource types

echo "🔍 Comprehensive AWS Resource Audit for Prism Platform"
echo "=================================================================="

# AWS Profile to use
AWS_PROFILE="${1:-default}"
echo "Profile: $AWS_PROFILE"

# Regions to check
REGIONS=("us-east-1" "us-west-2" "eu-west-1" "us-east-2")

# Function to run AWS CLI with profile
aws_cmd() {
    if [[ "$AWS_PROFILE" == "default" ]]; then
        aws "$@"
    else
        aws --profile "$AWS_PROFILE" "$@"
    fi
}

# Check profile validity
echo "🔐 Verifying AWS profile: $AWS_PROFILE"
if ! aws_cmd sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ ERROR: AWS profile '$AWS_PROFILE' is not configured or invalid"
    exit 1
fi

account_info=$(aws_cmd sts get-caller-identity 2>/dev/null)
echo "✅ Profile valid"
echo "$account_info" | jq -r '"Account: " + .Account + ", User: " + (.Arn // "Unknown")' 2>/dev/null || echo "$account_info"
echo

total_all_resources=0

for region in "${REGIONS[@]}"; do
    echo "=== Region: $region ==="
    region_total=0
    
    # VPCs (non-default)
    echo -n "  VPCs: "
    vpcs=$(aws_cmd ec2 describe-vpcs --region "$region" --query 'Vpcs[?IsDefault==`false`]' --output json 2>/dev/null || echo "[]")
    vpc_count=$(echo "$vpcs" | jq length 2>/dev/null || echo 0)
    if [[ $vpc_count -gt 0 ]]; then
        echo "$vpc_count found"
        echo "$vpcs" | jq -r '.[] | "    └─ " + .VpcId + " (" + (.Tags[]? | select(.Key=="Name") | .Value // "unnamed") + ")"' 2>/dev/null
        region_total=$((region_total + vpc_count))
    else
        echo "0"
    fi
    
    # EC2 Instances
    echo -n "  EC2 Instances: "
    instances=$(aws_cmd ec2 describe-instances --region "$region" --query 'Reservations[].Instances[?State.Name!=`terminated`]' --output json 2>/dev/null || echo "[]")
    instance_count=$(echo "$instances" | jq length 2>/dev/null || echo 0)
    if [[ $instance_count -gt 0 ]]; then
        echo "$instance_count found"
        region_total=$((region_total + instance_count))
    else
        echo "0"
    fi
    
    # EKS Clusters
    echo -n "  EKS Clusters: "
    clusters=$(aws_cmd eks list-clusters --region "$region" --output json 2>/dev/null || echo '{"clusters":[]}')
    cluster_count=$(echo "$clusters" | jq '.clusters | length' 2>/dev/null || echo 0)
    if [[ $cluster_count -gt 0 ]]; then
        echo "$cluster_count found"
        region_total=$((region_total + cluster_count))
    else
        echo "0"
    fi
    
    # RDS Instances
    echo -n "  RDS Instances: "
    rds_count=$(aws_cmd rds describe-db-instances --region "$region" --query 'length(DBInstances)' --output text 2>/dev/null || echo 0)
    if [[ $rds_count -gt 0 ]]; then
        echo "$rds_count found"
        region_total=$((region_total + rds_count))
    else
        echo "0"
    fi
    
    # Load Balancers
    echo -n "  Load Balancers: "
    elb_count=$(aws_cmd elbv2 describe-load-balancers --region "$region" --query 'length(LoadBalancers)' --output text 2>/dev/null || echo 0)
    if [[ $elb_count -gt 0 ]]; then
        echo "$elb_count found"
        region_total=$((region_total + elb_count))
    else
        echo "0"
    fi
    
    # NAT Gateways
    echo -n "  NAT Gateways: "
    nat_count=$(aws_cmd ec2 describe-nat-gateways --region "$region" --query 'length(NatGateways[?State!=`deleted`])' --output text 2>/dev/null || echo 0)
    if [[ $nat_count -gt 0 ]]; then
        echo "$nat_count found"
        region_total=$((region_total + nat_count))
    else
        echo "0"
    fi
    
    # S3 Buckets (only from us-east-1)
    if [[ "$region" == "us-east-1" ]]; then
        echo -n "  S3 Buckets (Prism-related): "
        bucket_count=$(aws_cmd s3api list-buckets --query 'length(Buckets[?contains(Name,`prism`) || contains(Name,`corrective`) || contains(Name,`drift`)])' --output text 2>/dev/null || echo 0)
        if [[ $bucket_count -gt 0 ]]; then
            echo "$bucket_count found"
            region_total=$((region_total + bucket_count))
        else
            echo "0"
        fi
    fi
    
    echo "  Region subtotal: $region_total resources"
    total_all_resources=$((total_all_resources + region_total))
    echo
done

echo "=================================================================="
echo "📊 COMPREHENSIVE AUDIT SUMMARY"
echo "AWS Profile: $AWS_PROFILE"
echo "Total resources found: $total_all_resources"

if [[ $total_all_resources -gt 0 ]]; then
    echo
    echo "⚠️  CLEANUP REQUIRED"
    echo "To clean up resources, run:"
    echo "  ./scripts/comprehensive-aws-cleanup.sh $AWS_PROFILE"
else
    echo
    echo "✅ ALL CLEAN"
    echo "No AWS resources found that require cleanup."
fi

echo
echo "💡 Usage Examples:"
echo "  Default profile:           ./scripts/comprehensive-aws-audit.sh"
echo "  Specific profile:          ./scripts/comprehensive-aws-audit.sh my-profile"
echo "  default:     ./scripts/comprehensive-aws-audit.sh default"
