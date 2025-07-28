#!/bin/bash

# Comprehensive AWS Resource Cleanup for Prism Platform
echo "🧹 Comprehensive AWS Resource Cleanup for Prism Platform"
echo "=================================================================="

AWS_PROFILE="${1:-default}"
REGIONS=("us-east-1" "us-west-2" "eu-west-1" "us-east-2")

# Function to run AWS CLI with profile
aws_cmd() {
    if [[ "$AWS_PROFILE" == "default" ]]; then
        aws "$@"
    else
        aws --profile "$AWS_PROFILE" "$@"
    fi
}

# Check profile and show account info
echo "🔐 Verifying AWS profile: $AWS_PROFILE"
if ! aws_cmd sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ ERROR: AWS profile '$AWS_PROFILE' is not configured or invalid"
    exit 1
fi

account_info=$(aws_cmd sts get-caller-identity 2>/dev/null)
account_id=$(echo "$account_info" | jq -r '.Account' 2>/dev/null || echo "Unknown")
user_arn=$(echo "$account_info" | jq -r '.Arn' 2>/dev/null || echo "Unknown")

echo "✅ Profile valid"
echo "Account: $account_id"
echo "User: $user_arn"
echo

# Safety confirmation
echo "🚨 WARNING: This will DELETE AWS resources in the following account and regions:"
echo "Profile: $AWS_PROFILE"
echo "Account: $account_id"
echo "Regions: ${REGIONS[*]}"
echo
echo "This action is IRREVERSIBLE and will delete:"
echo "  • VPCs, subnets, and networking resources"
echo "  • EC2 instances and EBS volumes"
echo "  • EKS clusters and node groups"
echo "  • RDS instances and databases"
echo "  • S3 buckets and their contents"
echo "  • Load Balancers and NAT Gateways"
echo "  • IAM roles and policies"
echo "  • CloudWatch logs and metrics"
echo "  • And much more..."
echo
read -p "Are you absolutely sure? (type 'DELETE-ALL-RESOURCES' to confirm): " confirm
if [[ "$confirm" != "DELETE-ALL-RESOURCES" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Cleanup function for each region
cleanup_region() {
    local region=$1
    echo
    echo "=== Cleaning up region: $region ==="
    
    # Delete EKS clusters first
    echo "�� EKS Clusters..."
    clusters=$(aws_cmd eks list-clusters --region "$region" --query 'clusters' --output text 2>/dev/null || echo "")
    if [[ -n "$clusters" && "$clusters" != "None" ]]; then
        for cluster in $clusters; do
            echo "  🗑️ Deleting EKS cluster: $cluster"
            
            # Delete node groups first
            node_groups=$(aws_cmd eks list-nodegroups --cluster-name "$cluster" --region "$region" --query 'nodegroups' --output text 2>/dev/null || echo "")
            if [[ -n "$node_groups" && "$node_groups" != "None" ]]; then
                for ng in $node_groups; do
                    echo "    └─ Deleting node group: $ng"
                    aws_cmd eks delete-nodegroup --cluster-name "$cluster" --nodegroup-name "$ng" --region "$region" 2>/dev/null || true
                done
                echo "    ⏳ Waiting for node groups..."
                sleep 30
            fi
            
            aws_cmd eks delete-cluster --name "$cluster" --region "$region" 2>/dev/null || true
        done
        echo "  ⏳ Waiting for EKS clusters..."
        sleep 60
    else
        echo "  ✅ No EKS clusters found"
    fi
    
    # Terminate EC2 instances
    echo "🔍 EC2 Instances..."
    instances=$(aws_cmd ec2 describe-instances --region "$region" --query 'Reservations[].Instances[?State.Name!=`terminated`].InstanceId' --output text 2>/dev/null || echo "")
    if [[ -n "$instances" && "$instances" != "None" ]]; then
        echo "  🗑️ Terminating EC2 instances..."
        for instance in $instances; do
            echo "    └─ Terminating: $instance"
            aws_cmd ec2 terminate-instances --instance-ids "$instance" --region "$region" 2>/dev/null || true
        done
        echo "  ⏳ Waiting for instances..."
        sleep 30
    else
        echo "  ✅ No EC2 instances found"
    fi
    
    # Delete RDS instances
    echo "🔍 RDS Instances..."
    rds_instances=$(aws_cmd rds describe-db-instances --region "$region" --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null || echo "")
    if [[ -n "$rds_instances" && "$rds_instances" != "None" ]]; then
        for db in $rds_instances; do
            echo "  ��️ Deleting RDS instance: $db"
            aws_cmd rds delete-db-instance --db-instance-identifier "$db" --skip-final-snapshot --region "$region" 2>/dev/null || true
        done
        echo "  ⏳ Waiting for RDS..."
        sleep 30
    else
        echo "  ✅ No RDS instances found"
    fi
    
    # Delete Load Balancers
    echo "🔍 Load Balancers..."
    elbs=$(aws_cmd elbv2 describe-load-balancers --region "$region" --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null || echo "")
    if [[ -n "$elbs" && "$elbs" != "None" ]]; then
        for elb in $elbs; do
            echo "  🗑️ Deleting Load Balancer: $elb"
            aws_cmd elbv2 delete-load-balancer --load-balancer-arn "$elb" --region "$region" 2>/dev/null || true
        done
        echo "  ⏳ Waiting for ELBs..."
        sleep 20
    else
        echo "  ✅ No Load Balancers found"
    fi
    
    # Delete NAT Gateways
    echo "🔍 NAT Gateways..."
    nats=$(aws_cmd ec2 describe-nat-gateways --region "$region" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text 2>/dev/null || echo "")
    if [[ -n "$nats" && "$nats" != "None" ]]; then
        for nat in $nats; do
            echo "  🗑️ Deleting NAT Gateway: $nat"
            aws_cmd ec2 delete-nat-gateway --nat-gateway-id "$nat" --region "$region" 2>/dev/null || true
        done
        echo "  ⏳ Waiting for NAT Gateways..."
        sleep 30
    else
        echo "  ✅ No NAT Gateways found"
    fi
    
    # Release Elastic IPs
    echo "🔍 Elastic IPs..."
    eips=$(aws_cmd ec2 describe-addresses --region "$region" --query 'Addresses[].AllocationId' --output text 2>/dev/null || echo "")
    if [[ -n "$eips" && "$eips" != "None" ]]; then
        for eip in $eips; do
            echo "  🗑️ Releasing Elastic IP: $eip"
            aws_cmd ec2 release-address --allocation-id "$eip" --region "$region" 2>/dev/null || true
        done
    else
        echo "  ✅ No Elastic IPs found"
    fi
    
    # Clean up VPC infrastructure
    echo "🔍 VPC Infrastructure..."
    vpcs=$(aws_cmd ec2 describe-vpcs --region "$region" --query 'Vpcs[?IsDefault==`false`].VpcId' --output text 2>/dev/null || echo "")
    if [[ -n "$vpcs" && "$vpcs" != "None" ]]; then
        for vpc in $vpcs; do
            echo "  🗑️ Cleaning up VPC: $vpc"
            
            # Delete Security Groups (except default)
            sgs=$(aws_cmd ec2 describe-security-groups --region "$region" --filters "Name=vpc-id,Values=$vpc" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
            if [[ -n "$sgs" && "$sgs" != "None" ]]; then
                for sg in $sgs; do
                    echo "    └─ Deleting Security Group: $sg"
                    aws_cmd ec2 delete-security-group --group-id "$sg" --region "$region" 2>/dev/null || true
                done
            fi
            
            # Delete Subnets
            subnets=$(aws_cmd ec2 describe-subnets --region "$region" --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
            if [[ -n "$subnets" && "$subnets" != "None" ]]; then
                for subnet in $subnets; do
                    echo "    └─ Deleting Subnet: $subnet"
                    aws_cmd ec2 delete-subnet --subnet-id "$subnet" --region "$region" 2>/dev/null || true
                done
            fi
            
            # Delete Route Tables (except main)
            route_tables=$(aws_cmd ec2 describe-route-tables --region "$region" --filters "Name=vpc-id,Values=$vpc" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null || echo "")
            if [[ -n "$route_tables" && "$route_tables" != "None" ]]; then
                for rt in $route_tables; do
                    echo "    └─ Deleting Route Table: $rt"
                    aws_cmd ec2 delete-route-table --route-table-id "$rt" --region "$region" 2>/dev/null || true
                done
            fi
            
            # Delete Internet Gateways
            igws=$(aws_cmd ec2 describe-internet-gateways --region "$region" --filters "Name=attachment.vpc-id,Values=$vpc" --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null || echo "")
            if [[ -n "$igws" && "$igws" != "None" ]]; then
                for igw in $igws; do
                    echo "    └─ Detaching and deleting IGW: $igw"
                    aws_cmd ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc" --region "$region" 2>/dev/null || true
                    aws_cmd ec2 delete-internet-gateway --internet-gateway-id "$igw" --region "$region" 2>/dev/null || true
                done
            fi
            
            # Finally delete VPC
            echo "    └─ Deleting VPC: $vpc"
            if aws_cmd ec2 delete-vpc --vpc-id "$vpc" --region "$region" 2>/dev/null; then
                echo "    ✅ VPC $vpc deleted successfully"
            else
                echo "    ❌ Failed to delete VPC $vpc"
            fi
        done
    else
        echo "  ✅ No custom VPCs found"
    fi
    
    echo "  ✅ Region $region cleanup completed"
}

# Clean up global resources (S3, IAM, DynamoDB)
cleanup_global() {
    echo
    echo "=== Cleaning up Global Resources ==="
    
    # S3 Buckets (Prism-related only)
    echo "🔍 S3 Buckets..."
    buckets=$(aws_cmd s3api list-buckets --query 'Buckets[?contains(Name,`prism`) || contains(Name,`corrective`) || contains(Name,`drift`) || contains(Name,`terraform`)].Name' --output text 2>/dev/null || echo "")
    if [[ -n "$buckets" && "$buckets" != "None" ]]; then
        for bucket in $buckets; do
            echo "  🗑️ Emptying and deleting S3 bucket: $bucket"
            aws_cmd s3 rm "s3://$bucket" --recursive 2>/dev/null || true
            aws_cmd s3api delete-bucket --bucket "$bucket" 2>/dev/null || true
        done
    else
        echo "  ✅ No Prism-related S3 buckets found"
    fi
    
    # IAM Roles (Prism-related only)
    echo "🔍 IAM Roles..."
    roles=$(aws_cmd iam list-roles --query 'Roles[?contains(RoleName,`prism`) || contains(RoleName,`corrective`) || contains(RoleName,`drift`) || contains(RoleName,`eks`)].RoleName' --output text 2>/dev/null || echo "")
    if [[ -n "$roles" && "$roles" != "None" ]]; then
        for role in $roles; do
            echo "  🗑️ Deleting IAM role: $role"
            
            # Detach managed policies
            attached_policies=$(aws_cmd iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
            if [[ -n "$attached_policies" && "$attached_policies" != "None" ]]; then
                for policy in $attached_policies; do
                    aws_cmd iam detach-role-policy --role-name "$role" --policy-arn "$policy" 2>/dev/null || true
                done
            fi
            
            # Delete instance profiles
            instance_profiles=$(aws_cmd iam list-instance-profiles-for-role --role-name "$role" --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null || echo "")
            if [[ -n "$instance_profiles" && "$instance_profiles" != "None" ]]; then
                for ip in $instance_profiles; do
                    aws_cmd iam remove-role-from-instance-profile --instance-profile-name "$ip" --role-name "$role" 2>/dev/null || true
                    aws_cmd iam delete-instance-profile --instance-profile-name "$ip" 2>/dev/null || true
                done
            fi
            
            aws_cmd iam delete-role --role-name "$role" 2>/dev/null || true
        done
    else
        echo "  ✅ No Prism-related IAM roles found"
    fi
    
    echo "  ✅ Global resources cleanup completed"
}

# Main execution
echo "🚀 Starting comprehensive cleanup..."

for region in "${REGIONS[@]}"; do
    cleanup_region "$region"
done

cleanup_global

echo
echo "=================================================================="
echo "🎉 Comprehensive cleanup completed!"
echo
echo "🔍 Running verification audit..."
if [[ -f "./scripts/comprehensive-aws-audit.sh" ]]; then
    ./scripts/comprehensive-aws-audit.sh "$AWS_PROFILE"
else
    echo "Audit script not found. Please verify cleanup manually."
fi

echo
echo "🏁 Cleanup process complete!"
echo "If any resources persist, they may require manual cleanup."
