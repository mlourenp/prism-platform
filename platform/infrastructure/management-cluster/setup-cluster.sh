#!/bin/bash
set -e

echo "================================================"
echo "EKS Management Cluster - Complete Setup"
echo "================================================"

# Variables
START_TIME=$(date +%s)

# Get region and profile from backend.conf
REGION=$(grep "region" backend.conf | awk '{print $3}' | tr -d '"')
AWS_PROFILE=$(grep "profile" backend.conf | awk '{print $3}' | tr -d '"')

# Export variables for child scripts
export AWS_PROFILE
export AWS_REGION=$REGION

echo "Using AWS Profile: $AWS_PROFILE"
echo "Using AWS Region: $REGION"

# Step 1: Create core infrastructure (VPC, EKS Cluster)
echo "Step 1: Deploying core infrastructure (VPC, EKS)..."
terraform init -reconfigure -backend-config=backend.conf
terraform apply -target=module.vpc -auto-approve
terraform apply -target=module.eks -auto-approve

# Step 2: Apply policy fixes
echo "Step 2: Applying policy fixes..."
cp policy-fix.tf.example policy-fix.tf 2>/dev/null || true
terraform apply -target=aws_iam_role_policy.eks_cluster_policies -auto-approve
terraform apply -target=aws_iam_role_policy.eks_node_group_policies -auto-approve

# Step 3: Apply ECR and other cloud resources (in parallel with EKS setup)
echo "Step 3: Creating ECR repositories and supporting cloud resources..."
terraform apply -target=aws_ecr_repository.this -auto-approve
terraform apply -target=aws_ecr_lifecycle_policy.this -auto-approve
terraform apply -target=aws_cloudwatch_log_group.application_logs -auto-approve
terraform apply -target=aws_ssm_parameter.db_credentials -auto-approve
terraform apply -target=aws_ssm_parameter.api_credentials -auto-approve
terraform apply -target=aws_s3_bucket.application_assets -auto-approve
terraform apply -target=aws_s3_bucket.crossplane_providers -auto-approve
terraform apply -target=aws_dynamodb_table.crossplane_locks -auto-approve

# Step 4: Configure kubectl
echo "Step 4: Configuring kubectl..."
CLUSTER_NAME=$(terraform output -raw cluster_name)
# Using REGION and AWS_PROFILE from backend.conf
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME --profile $AWS_PROFILE

# Step 5: Deploy EKS add-ons in the correct order
echo "Step 5: Deploying EKS add-ons in sequence..."
chmod +x deploy-addons.sh
./deploy-addons.sh

# Step 6: Deploy Crossplane
echo "Step 6: Deploying Crossplane and providers..."
chmod +x deploy-crossplane.sh
./deploy-crossplane.sh

# Step 7: Set up SQLite development environment for corrective drift cell
echo "Step 7: Setting up SQLite development environment..."
# Create required directories
mkdir -p ../../data
touch ../../data/prism_platform.db

# Copy SQLite environment configuration
if [ -f ../../.env.sqlite ]; then
  echo "Found .env.sqlite file, configuring SQLite environment..."
  cp ../../.env.sqlite ../../.env

  # Check if we need to populate the database with initial schema
  if [ ! -s ../../data/prism_platform.db ]; then
    echo "Initializing SQLite database schema..."
    pushd ../../

    # Run database migration/initialization if scripts exist
    if [ -f scripts/init_database.py ]; then
      python3 scripts/init_database.py --sqlite
    fi

    # Optionally seed with development data
    if [ -f scripts/seed_database.py ]; then
      python3 scripts/seed_database.py --dev --sqlite
    fi

    popd
  fi

  echo "SQLite development environment setup complete."
else
  echo "Warning: .env.sqlite file not found in project root. Skipping SQLite setup."
fi

# Step 8: Deploy the corrective drift cell with SQLite configuration
echo "Step 8: Deploying corrective drift cell..."
chmod +x ../../apply-cell-deployment.sh
pushd ../..
./apply-cell-deployment.sh
popd

# Step 9: Deploy initial core cell using Crossplane
echo "Step 9: Deploying initial core cell using Crossplane..."

# Ensure the prism-platform namespace exists
kubectl apply -f ../../prism-platform-namespace.yaml

# Verify Crossplane is ready
echo "Verifying Crossplane status..."
if ! kubectl get crds | grep -q 'apiextensions.crossplane.io'; then
  echo "Warning: Crossplane CRDs not found. Core cell deployment may fail."
  echo "Proceeding anyway, but you may need to run the cell deployment manually."
else
  echo "Crossplane is installed and ready."
fi

# Apply the core cell deployment resources
echo "Applying core cell Crossplane resources..."

# Apply the Cell XRD definition first
kubectl apply -f ../../prism-platform-cell-xrd.yaml
echo "Waiting for Cell XRD to be processed (20 seconds)..."
sleep 20

# Apply the Cell composition for AWS providers
echo "Applying Cell Composition for AWS provider..."
kubectl apply -f ../../prism-platform-cell-composition-aws.yaml
echo "Waiting for composition to be processed (10 seconds)..."
sleep 10

# Create the core cell claim
echo "Applying core cell claim..."
kubectl apply -f ../../cell-claim.yaml
echo "Waiting for cell claim to be processed (30 seconds)..."
sleep 30

# Check cell claim status
echo "Checking cell claim status..."
kubectl get cellclaim core-services-cell -n prism-platform -o wide || echo "CellClaim not yet available"

# Apply the actual core services
echo "Deploying core services..."
kubectl apply -f ../../core-services-deployment.yaml

# Calculate total time
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo "================================================"
echo "Setup completed successfully in ${MINUTES}m ${SECONDS}s!"
echo ""
echo "Your EKS cluster '$CLUSTER_NAME' is now ready."
echo ""
echo "Useful commands:"
echo "- kubectl get nodes                             # List cluster nodes"
echo "- kubectl get pods -A                           # List all pods"
echo "- kubectl get providers -n crossplane-system    # List Crossplane providers"
echo "- kubectl get providerconfigs                   # List provider configurations"
echo "- kubectl get cellclaim -n prism-platform     # List cell claims in prism-platform namespace"
echo ""
echo "For SQLite development:"
echo "- cd ../../                                     # Go to project root"
echo "- docker-compose -f docker-compose.sqlite.yml up -d  # Start SQLite development stack"
echo "================================================"

# Print ECR login instructions
ECR_REGISTRY=$(terraform output -raw ecr_registry_url)
echo "To push Docker images to your ECR repositories:"
echo "aws ecr get-login-password --region $REGION --profile $AWS_PROFILE | docker login --username AWS --password-stdin $ECR_REGISTRY"
