# Management Cluster Terraform Configuration

This directory contains Terraform configurations to deploy an EKS management cluster with Crossplane installed. This management cluster serves as the control plane for managing other resources through Crossplane.

## Architecture

The Terraform configuration creates:

1. **VPC** - A dedicated VPC with public and private subnets across multiple availability zones
2. **EKS Cluster** - A managed Kubernetes cluster with appropriate node groups
3. **Cluster Add-ons** - Common EKS add-ons like metrics-server, cluster-autoscaler, and AWS Load Balancer Controller
4. **Crossplane** - Installation and configuration of Crossplane with AWS, Kubernetes, and Helm providers

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0.0
- kubectl
- IAM permissions to create VPC, EKS clusters, IAM roles, etc.
- S3 bucket for Terraform state (optional but recommended)

## Customizing the Configuration

Before applying, review and update the following files according to your needs:

- `variables.tf` - Default values for variables
- `provider.tf` - AWS provider and backend configuration
- `main.tf` - EKS cluster and VPC configuration
- `crossplane.tf` - Crossplane installation configuration

## Complete Setup Guide

### Step 1: Deploy the Management Cluster

1. Initialize the Terraform working directory:

```bash
cd terraform/management-cluster
terraform init -backend-config=backend.conf
```

2. Review the deployment plan:

```bash
terraform plan -out=tfplan
```

3. Apply the configuration to create the EKS cluster:

```bash
terraform apply tfplan
```

4. Configure kubectl to access the cluster:

```bash
aws eks update-kubeconfig --region $(terraform output -raw region) --name $(terraform output -raw cluster_name)
```

5. Verify cluster access:

```bash
kubectl get nodes
```

### Step 2: Deploy Crossplane

1. Use the provided deployment script to install Crossplane with necessary providers:

```bash
./deploy-crossplane.sh
```

2. Verify Crossplane installation:

```bash
kubectl get pods -n crossplane-system
```

3. Verify providers are installed correctly:

```bash
kubectl get providers
```

Expected output should include:

- provider-aws
- provider-kubernetes
- provider-helm

4. Verify provider configurations:

```bash
kubectl get providerconfig
```

### Step 3: Deploy a Crossplane Cell

1. Review and customize the cell configuration files if needed:

   - `prism-platform-namespace.yaml`: Namespace definition
   - `prism-platform-cell-xrd.yaml`: Cell Composite Resource Definition
   - `prism-platform-cell-composition-aws.yaml`: AWS-specific composition
   - `cell-claim.yaml`: Cell claim with resource requirements

2. Deploy the cell using the provided script:

```bash
./apply-cell-deployment.sh
```

3. Verify the cell deployment:

```bash
kubectl get cellclaim -n prism-platform
kubectl get pods -n prism-platform
```

4. Check the namespace labels to verify proper configuration:

```bash
kubectl get namespace prism-platform -o yaml
```

Look for labels like `cell-instance`, `cellType`, and `managed-by`.

5. Monitor the deployment progress:

```bash
kubectl get pods -n prism-platform -w
```

### Step 4: Deploy Applications to the Cell

1. Apply your application deployment YAML:

```bash
kubectl apply -f core-services-deployment.yaml
```

2. Verify application deployment:

```bash
kubectl get pods -n prism-platform -l app=prism-platform
```

### Step 5: Set up SQLite Development Environment

The setup script includes an option to configure a SQLite development environment for local testing and development. This environment allows you to test the corrective drift application with a lightweight SQLite database instead of a full production database.

1. The SQLite environment is automatically set up during cluster creation if the `.env.sqlite` file exists in the project root.

2. Manually set up the SQLite environment:

```bash
# Ensure you're in the project root
cd ../../

# Create required directories
mkdir -p data
touch data/prism_platform.db

# Copy SQLite environment configuration
cp .env.sqlite .env

# Initialize database schema (if scripts exist)
python3 scripts/init_database.py --sqlite

# Seed database with development data (optional)
python3 scripts/seed_database.py --dev --sqlite
```

3. Start the SQLite development stack:

```bash
docker-compose -f docker-compose.sqlite.yml up -d
```

4. Verify services are running:

```bash
docker-compose -f docker-compose.sqlite.yml ps
```

5. Access development services:

   - API: <http://localhost:8000>
   - Simulation API: <http://localhost:8001>
   - Optimization API: <http://localhost:8002>
   - Frontend: <http://localhost:3000>
   - Prometheus: <http://localhost:9090>
   - Grafana: <http://localhost:3001>

6. Stop the SQLite development stack:

```bash
docker-compose -f docker-compose.sqlite.yml down
```

## Crossplane Provider Setup

The Terraform configuration automatically installs and configures:

- AWS Provider for Crossplane
- Kubernetes Provider for Crossplane
- Helm Provider for Crossplane

Each provider is configured with `InjectedIdentity` credentials source, assuming you have set up IRSA (IAM Roles for Service Accounts) for Crossplane.

## Deployment Instructions

1. Initialize the Terraform working directory:

```bash
terraform init -backend-config=backend.conf
```

2. Review the deployment plan:

```bash
terraform plan -out=tfplan
```

3. Apply the configuration:

```bash
terraform apply tfplan
```

4. Configure kubectl to access the cluster:

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

5. Verify Crossplane installation:

```bash
kubectl get pods -n crossplane-system
```

## Connecting GitHub Actions to the Management Cluster

After creating the cluster, you need to:

1. Update GitHub Actions secrets/variables with the cluster information
2. Configure OIDC authentication between GitHub Actions and AWS
3. Create appropriate IAM roles with permissions to interact with the management cluster

## Maintenance Operations

### Upgrading Crossplane

To upgrade Crossplane or its providers, update the version variables in `variables.tf` and apply the changes:

```bash
terraform apply
```

### Scaling the Cluster

Modify the `node_min_capacity`, `node_max_capacity`, and `node_desired_capacity` variables in `variables.tf` and apply the changes.

### Disaster Recovery

1. Ensure your Terraform state is stored in a durable backend (like S3)
2. Regularly back up Crossplane resources using:

   ```bash
   kubectl get compositions,compositeresourcedefinitions -A -o yaml > crossplane-backup.yaml
   ```

## Security Considerations

- The EKS control plane logs are enabled and sent to CloudWatch
- EKS cluster secrets are encrypted
- Private subnets are used for the cluster nodes
- Public access to the EKS API server can be restricted further in `main.tf`

## Clean Up

To perform a complete cleanup of all resources:

1. Clean up any cell deployments first:

```bash
# Delete cell claim to trigger cleanup of managed resources
kubectl delete cellclaim --all -n prism-platform

# Delete the namespace after resources are cleaned up
kubectl delete namespace prism-platform
```

2. Clean up Crossplane and all related resources:

```bash
./cleanup-crossplane.sh
```

3. Destroy all infrastructure using Terraform:

```bash
./teardown-cluster.sh
```

Or alternatively:

```bash
terraform destroy
```

**Warning**: This will destroy the management cluster and all its resources. Any resources managed by Crossplane will become orphaned and may need to be cleaned up separately.

## SQLite Development Environment Notes

The SQLite development environment uses Docker Compose to run a lightweight, local version of the corrective drift application. This is useful for:

1. **Local development**: Develop and test features without needing a full EKS cluster
2. **Faster iterations**: Quick local testing before deploying to the Kubernetes cluster
3. **Reduced costs**: Develop locally without running cloud resources

Key features of the SQLite environment:

- Uses SQLite database instead of PostgreSQL for simpler setup
- Includes Prometheus and Grafana for local monitoring
- Supports remote debugging (ports 5678-5681)
- Automatically reloads code changes
- All services run in Docker containers for isolation

To switch between SQLite and production environments:

```bash
# Use SQLite for development
cp .env.sqlite .env

# Use production configuration
cp .env.prod .env
```

## ECR Repositories

The following ECR repositories are created:

- prism-platform/base
- prism-platform/drift-detector
- prism-platform/feedback-loop

## Pushing to ECR Repositories

To push images directly to the ECR repositories, follow these steps:

### 1. Update GitHub Actions Workflow

Create or update your GitHub Actions workflow files (`.github/workflows/*.yml`) to build and push directly to ECR:

```yaml
name: Build and Push to ECR

on:
  push:
    branches: [main]
    paths:
      - "src/**"
      - ".github/workflows/build-push.yml"
  workflow_dispatch:

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/CorrospondDriftDeploymentRole
          aws-region: us-west-2

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build, tag, and push image to Amazon ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: prism-platform/base # Change to match your repository
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -t $ECR_REGISTRY/$ECR_REPOSITORY:latest .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
          echo "::set-output name=image::$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
```

### 2. Push from Local Development Environment

For local development, you can use the AWS CLI:

```bash
# Login to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

# Build your image
docker build -t <account-id>.dkr.ecr.us-west-2.amazonaws.com/prism-platform/base:latest .

# Push to ECR
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/prism-platform/base:latest
```

### 3. Use ECR Images in Kubernetes Deployments

In your Kubernetes deployments, reference the ECR images:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drift-detector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: drift-detector
  template:
    metadata:
      labels:
        app: drift-detector
    spec:
      containers:
        - name: drift-detector
          image: <account-id>.dkr.ecr.us-west-2.amazonaws.com/prism-platform/drift-detector:latest
          imagePullPolicy: Always
```

### 4. ECR Repository URL References

You can get the repository URLs from Terraform outputs after applying:

```bash
terraform output ecr_repository_urls
```

This will return a map of repository names to their URLs.
