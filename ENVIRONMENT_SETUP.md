# Prism Platform v1.2 - Environment Setup for Testing

**Complete environment preparation for Phase 1 testing validation**

---

## 🛠️ **Required Tools & Versions**

### **Core Infrastructure Tools**
```bash
# Terraform (Infrastructure as Code)
terraform --version  # Required: >= 1.0, Recommended: >= 1.6
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Kubectl (Kubernetes CLI)
kubectl version --client  # Required: >= 1.28, Recommended: >= 1.29
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm (Kubernetes Package Manager)
helm version  # Required: >= 3.8, Recommended: >= 3.13
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update && sudo apt-get install helm
```

### **Load Testing & Monitoring**
```bash
# K6 (Load Testing) - Optional but recommended
k6 version  # Recommended for performance testing
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update && sudo apt-get install k6

# Infracost (Cost Analysis) - Recommended
infracost --version  # For cost transparency testing
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
```

### **Utility Tools**
```bash
# jq (JSON processing)
jq --version  # Required for metrics processing
sudo apt-get install jq

# curl (HTTP client)
curl --version  # Required for API testing

# watch (Real-time monitoring)
watch --version  # Useful for monitoring during tests
```

---

## ☁️ **Cloud Provider Credentials**

### **AWS Configuration**
```bash
# Install AWS CLI
aws --version  # Required: >= 2.13
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Configure AWS credentials
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region: us-east-1 (or your preferred region)
# Default output format: json

# Verify AWS access
aws sts get-caller-identity
aws eks list-clusters
```

### **Google Cloud Configuration**
```bash
# Install Google Cloud SDK
gcloud version  # Required: >= 445.0
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Set default project and region
gcloud config set project YOUR_PROJECT_ID
gcloud config set compute/region us-central1

# Verify GCP access
gcloud auth list
gcloud projects list
```

### **Azure Configuration**
```bash
# Install Azure CLI
az version  # Required: >= 2.53
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Set default subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify Azure access
az account show
az group list
```

---

## 🔧 **Environment Variables**

### **Required Environment Variables**
```bash
# Create environment file
cat > .env.testing << 'EOF'
# ===========================================
# Prism Platform Testing Configuration
# ===========================================

# Test Configuration
export PRISM_TEST_ENVIRONMENT="testing"
export PRISM_TEST_REGION="us-east-1"
export PRISM_TEST_DURATION="10m"
export PRISM_TEST_VUS="50"

# Cloud Provider Settings
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"
export GCP_PROJECT="your-gcp-project"
export GCP_REGION="us-central1"
export AZURE_SUBSCRIPTION_ID="your-azure-subscription"

# Kubernetes Configuration
export KUBECONFIG="$HOME/.kube/config"
export KUBE_NAMESPACE="prism-platform"

# Testing Features
export ENABLE_PERFORMANCE_TESTING="true"
export ENABLE_COST_ANALYSIS="true"
export ENABLE_MULTI_CLOUD_TESTING="false"  # Set to true for multi-cloud tests
export CLEANUP_AFTER_TESTS="true"

# Monitoring Configuration
export PROMETHEUS_RETENTION="24h"
export GRAFANA_ADMIN_PASSWORD="prism-test-2024"
export ENABLE_ALERTS="true"

# Cost Management
export INFRACOST_API_KEY="your-infracost-api-key"  # Optional
export COST_BUDGET_LIMIT="100"  # Monthly budget limit in USD

# Security Settings
export ENABLE_SECURITY_SCANNING="true"
export POD_SECURITY_STANDARD="restricted"

# Performance Tuning
export MAX_PARALLEL_TESTS="3"
export TEST_TIMEOUT="30m"
export RESOURCE_CLEANUP_TIMEOUT="10m"
EOF

# Load environment variables
source .env.testing

# Add to your shell profile for persistence
echo "source $(pwd)/.env.testing" >> ~/.bashrc
```

### **Optional Advanced Configuration**
```bash
# Advanced testing configuration
cat >> .env.testing << 'EOF'

# eBPF Testing
export ENABLE_EBPF_TESTING="true"
export CILIUM_VERSION="1.15.3"
export TETRAGON_VERSION="0.10.0"

# Service Mesh Testing
export ENABLE_SERVICE_MESH_TESTING="true"
export ISTIO_VERSION="1.26.1"
export ENABLE_MERBRIDGE="true"

# Load Testing Configuration
export K6_DURATION="10m"
export K6_VUS="50"
export K6_RAMP_TIME="2m"

# Multi-Cloud Testing (if enabled)
export MULTI_CLOUD_PRIMARY="aws"
export MULTI_CLOUD_SECONDARY="gcp"
export ENABLE_CROSS_CLOUD_REPLICATION="false"

# Observability Testing
export ENABLE_OBSERVABILITY_TOGGLE_TEST="true"
export PROMETHEUS_SCRAPE_INTERVAL="15s"
export GRAFANA_DASHBOARD_REFRESH="5s"

# Cell Architecture Testing
export ENABLE_ALL_CELL_TYPES="true"
export CELL_TYPES="logic,channel,data,security,external,integration,legacy,observability"

# Debug and Logging
export DEBUG_MODE="false"
export VERBOSE_LOGGING="false"
export SAVE_TERRAFORM_LOGS="true"
EOF
```

---

## 🔐 **Kubernetes Cluster Access**

### **Option 1: Use Existing Cluster**
```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# Create test namespace
kubectl create namespace prism-platform-testing --dry-run=client -o yaml | kubectl apply -f -

# Verify permissions
kubectl auth can-i create pods --namespace=prism-platform-testing
kubectl auth can-i create services --namespace=prism-platform-testing
kubectl auth can-i create deployments --namespace=prism-platform-testing
```

### **Option 2: Create Test Cluster (AWS EKS)**
```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create test cluster
eksctl create cluster \
  --name prism-test-cluster \
  --region us-east-1 \
  --nodegroup-name prism-test-nodes \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name prism-test-cluster
```

### **Option 3: Local Development (Kind)**
```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# Create local cluster
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: prism-test
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

kind create cluster --config kind-config.yaml
```

---

## 💰 **Cost Management Setup**

### **Infracost Configuration (Recommended)**
```bash
# Register for Infracost API key (free)
infracost auth login

# Test cost analysis
cd prism/examples/aws/minimal-stack/
infracost breakdown --path=.

# Set up cost monitoring
echo 'export INFRACOST_API_KEY="your-api-key"' >> .env.testing
```

### **AWS Cost Budgets**
```bash
# Create cost budget for testing
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "prism-testing-budget",
    "BudgetLimit": {
      "Amount": "100",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

---

## 📊 **Monitoring & Alerting Setup**

### **Slack Integration (Optional)**
```bash
# Set up Slack webhook for test alerts
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
echo 'export SLACK_WEBHOOK_URL="your-webhook-url"' >> .env.testing
```

### **Email Notifications (Optional)**
```bash
# Configure email for test results
export NOTIFICATION_EMAIL="your-email@company.com"
export SMTP_SERVER="smtp.company.com"
export SMTP_PORT="587"
```

---

## ✅ **Environment Verification**

### **Run Complete Verification**
```bash
# Execute verification script
./prism/scripts/verify-environment.sh
```

### **Manual Verification Checklist**
```bash
# 1. Tool Versions
echo "=== Tool Verification ==="
terraform --version | grep "Terraform"
kubectl version --client --short
helm version --short
k6 version 2>/dev/null || echo "K6 not installed (optional)"
infracost --version 2>/dev/null || echo "Infracost not installed (optional)"

# 2. Cloud Access
echo "=== Cloud Access Verification ==="
aws sts get-caller-identity && echo "✅ AWS access verified" || echo "❌ AWS access failed"
gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null && echo "✅ GCP access verified" || echo "❌ GCP access failed"
az account show --query name -o tsv 2>/dev/null && echo "✅ Azure access verified" || echo "❌ Azure access failed"

# 3. Kubernetes Access
echo "=== Kubernetes Access Verification ==="
kubectl cluster-info && echo "✅ Kubernetes access verified" || echo "❌ Kubernetes access failed"
kubectl auth can-i create pods && echo "✅ Pod creation permission verified" || echo "❌ Insufficient permissions"

# 4. Environment Variables
echo "=== Environment Variables ==="
echo "Test Environment: ${PRISM_TEST_ENVIRONMENT:-'NOT SET'}"
echo "Test Region: ${PRISM_TEST_REGION:-'NOT SET'}"
echo "Cleanup Enabled: ${CLEANUP_AFTER_TESTS:-'NOT SET'}"

# 5. Network Connectivity
echo "=== Network Connectivity ==="
curl -s https://registry.terraform.io/v1/modules 2>/dev/null && echo "✅ Terraform registry accessible" || echo "❌ Terraform registry inaccessible"
curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt 2>/dev/null && echo "✅ Kubernetes releases accessible" || echo "❌ Kubernetes releases inaccessible"
```

---

## 🚀 **Quick Environment Setup Script**

```bash
# Create automated setup script
cat > setup-test-environment.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Setting up Prism testing environment..."

# Load environment variables
source .env.testing 2>/dev/null || echo "⚠️  .env.testing not found, using defaults"

# Verify tools
echo "📋 Verifying required tools..."
command -v terraform >/dev/null 2>&1 || { echo "❌ terraform required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl required"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm required"; exit 1; }

# Verify cloud access
echo "☁️  Verifying cloud access..."
aws sts get-caller-identity >/dev/null 2>&1 && echo "✅ AWS configured" || echo "⚠️  AWS not configured"

# Verify Kubernetes access
echo "🎛️  Verifying Kubernetes access..."
kubectl cluster-info >/dev/null 2>&1 && echo "✅ Kubernetes accessible" || echo "❌ Kubernetes not accessible"

# Create test namespace
kubectl create namespace prism-platform-testing --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Environment setup complete!"
echo "🚀 Ready to run: cd prism/ && ./scripts/run-phase1-tests.sh"
EOF

chmod +x setup-test-environment.sh
```

---

## 🎯 **Ready to Test Checklist**

- [ ] **Tools Installed**: Terraform, kubectl, helm
- [ ] **Cloud Credentials**: AWS/GCP/Azure configured
- [ ] **Environment Variables**: `.env.testing` file created and sourced
- [ ] **Kubernetes Access**: Cluster accessible and permissions verified
- [ ] **Cost Management**: Infracost configured (optional)
- [ ] **Monitoring**: Slack/email notifications configured (optional)
- [ ] **Verification**: All checks pass

---

## 🚀 **Execute Testing**

Once your environment is configured, run:

```bash
# Quick verification
./setup-test-environment.sh

# Start Phase 1 testing
cd prism/
./scripts/run-phase1-tests.sh
```

**Need help?** Check the troubleshooting section in `PHASE_1_TESTING_VALIDATION.md` 