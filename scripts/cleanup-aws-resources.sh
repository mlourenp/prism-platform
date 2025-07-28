#!/bin/bash

# Comprehensive AWS Resource Cleanup for Prism Platform
echo "🧹 AWS Resource Cleanup for Prism Platform"
echo "============================================="
echo "⚠️  This will DELETE AWS resources in multiple regions!"
echo

# VPCs to clean up
declare -A VPCS=(
    ["us-east-1"]="vpc-0625dcd2175b85b03"
    ["us-west-2"]="vpc-01250fe3c31af4efe"  
)

# Confirmation
read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

cleanup_vpc() {
    local region=$1
    local vpc_id=$2
    
    echo
    echo "=== Cleaning up VPC $vpc_id in region $region ==="
    
    # Delete NAT Gateways
    echo "Checking for NAT Gateways..."
    nat_gateways=$(aws ec2 describe-nat-gateways --region "$region" --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text 2>/dev/null || echo "")
    if [[ -n "$nat_gateways" ]]; then
        for nat_id in $nat_gateways; do
            echo "  Deleting NAT Gateway: $nat_id"
            aws ec2 delete-nat-gateway --region "$region" --nat-gateway-id "$nat_id" 2>/dev/null || true
        done
        echo "  Waiting for NAT Gateways to delete..."
        sleep 30
    fi
    
    # Delete Internet Gateways
    echo "Checking for Internet Gateways..."
    igws=$(aws ec2 describe-internet-gateways --region "$region" --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null || echo "")
    if [[ -n "$igws" ]]; then
        for igw_id in $igws; do
            echo "  Detaching and deleting Internet Gateway: $igw_id"
            aws ec2 detach-internet-gateway --region "$region" --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" 2>/dev/null || true
            aws ec2 delete-internet-gateway --region "$region" --internet-gateway-id "$igw_id" 2>/dev/null || true
        done
    fi
    
    # Delete EC2 instances
    echo "Checking for EC2 instances..."
    instances=$(aws ec2 describe-instances --region "$region" --filters "Name=vpc-id,Values=$vpc_id" "Name=instance-state-name,Values=running,stopped,stopping" --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || echo "")
    if [[ -n "$instances" ]]; then
        for instance_id in $instances; do
            echo "  Terminating instance: $instance_id"
            aws ec2 terminate-instances --region "$region" --instance-ids "$instance_id" 2>/dev/null || true
        done
        echo "  Waiting for instances to terminate..."
        sleep 20
    fi
    
    # Delete Security Groups (except default)
    echo "Checking for Security Groups..."
    security_groups=$(aws ec2 describe-security-groups --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
    if [[ -n "$security_groups" ]]; then
        for sg_id in $security_groups; do
            echo "  Deleting Security Group: $sg_id"
            aws ec2 delete-security-group --region "$region" --group-id "$sg_id" 2>/dev/null || true
        done
    fi
    
    # Delete Subnets
    echo "Checking for Subnets..."
    subnets=$(aws ec2 describe-subnets --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    if [[ -n "$subnets" ]]; then
        for subnet_id in $subnets; do
            echo "  Deleting Subnet: $subnet_id"
            aws ec2 delete-subnet --region "$region" --subnet-id "$subnet_id" 2>/dev/null || true
        done
    fi
    
    # Delete Route Tables (except main)
    echo "Checking for Route Tables..."
    route_tables=$(aws ec2 describe-route-tables --region "$region" --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null || echo "")
    if [[ -n "$route_tables" ]]; then
        for rt_id in $route_tables; do
            echo "  Deleting Route Table: $rt_id"
            aws ec2 delete-route-table --region "$region" --route-table-id "$rt_id" 2>/dev/null || true
        done
    fi
    
    # Delete the VPC
    echo "Deleting VPC $vpc_id..."
    if aws ec2 delete-vpc --region "$region" --vpc-id "$vpc_id" 2>/dev/null; then
        echo "✅ VPC $vpc_id deleted successfully"
    else
        echo "❌ Failed to delete VPC $vpc_id (may have dependencies)"
    fi
}

# Clean up all VPCs
for region in "${!VPCS[@]}"; do
    vpc_id="${VPCS[$region]}"
    cleanup_vpc "$region" "$vpc_id"
done

echo
echo "🎉 Multi-region cleanup completed!"
echo "Run ./scripts/audit-aws-resources.sh to verify cleanup"
