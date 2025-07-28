# Multi-Cloud Cell Deployment Examples

This directory demonstrates how to deploy the complete Prism cell suite across multiple cloud providers, showcasing the platform's multi-cloud orchestration capabilities.

## 🌐 Deployment Scenarios

### Scenario 1: Global E-commerce Platform
**Business Case**: High-availability e-commerce with global presence

```yaml
# US East (AWS) - Primary Region
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: ecommerce-api-us-east
spec:
  cellId: "api-gateway-us-east"
  cellType: "channel"
  provider: "aws"
  region: "us-east-1"
  resources:
    cpu: "8000m"
    memory: "32Gi"
---
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: ecommerce-logic-us-east
spec:
  cellId: "order-processing-us-east"
  cellType: "logic"
  provider: "aws"
  region: "us-east-1"
  resources:
    cpu: "16000m"
    memory: "64Gi"
---
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: ecommerce-data-us-east
spec:
  cellId: "customer-data-us-east"
  cellType: "data"
  provider: "aws"
  region: "us-east-1"
  resources:
    cpu: "8000m"
    memory: "32Gi"
    storage: "2Ti"
```

```yaml
# Europe West (Google Cloud) - Secondary Region
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: ecommerce-api-eu-west
spec:
  cellId: "api-gateway-eu-west"
  cellType: "channel"
  provider: "gcp"
  region: "europe-west1"
  resources:
    cpu: "6000m"
    memory: "24Gi"
---
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: ecommerce-data-eu-west
spec:
  cellId: "customer-data-eu-west"
  cellType: "data"
  provider: "gcp"
  region: "europe-west1"
  resources:
    cpu: "6000m"
    memory: "24Gi"
    storage: "1Ti"
```

### Scenario 2: Financial Services with Compliance
**Business Case**: Multi-region financial platform with strict security requirements

```yaml
# Security-First Deployment (Azure)
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: fintech-security-primary
spec:
  cellId: "security-enforcement-east-us"
  cellType: "security"
  provider: "azure"
  region: "eastus"
  resources:
    cpu: "4000m"
    memory: "16Gi"
---
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: fintech-data-primary
spec:
  cellId: "financial-data-east-us"
  cellType: "data"
  provider: "azure"
  region: "eastus"
  resources:
    cpu: "12000m"
    memory: "48Gi"
    storage: "5Ti"
---
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: fintech-observability
spec:
  cellId: "compliance-monitoring-east-us"
  cellType: "observability"
  provider: "azure"
  region: "eastus"
  resources:
    cpu: "8000m"
    memory: "32Gi"
    storage: "3Ti"
```

### Scenario 3: Legacy Modernization Journey
**Business Case**: Gradual migration from on-premises to cloud-native

```yaml
# Phase 1: Legacy Containerization (On-Premises)
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: legacy-mainframe-migration
spec:
  cellId: "legacy-apps-on-prem"
  cellType: "legacy"
  provider: "baremetal"
  region: "datacenter-1"
  resources:
    cpu: "16000m"
    memory: "128Gi"
    storage: "10Ti"
---
# Phase 2: Integration Layer (Hybrid Cloud)
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: integration-bridge
spec:
  cellId: "hybrid-integration-aws"
  cellType: "integration"
  provider: "aws"
  region: "us-east-1"
  resources:
    cpu: "8000m"
    memory: "32Gi"
---
# Phase 3: Modern Services (Oracle Cloud)
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: modern-api-layer
spec:
  cellId: "api-modernization-oracle"
  cellType: "channel"
  provider: "oracle"
  region: "us-ashburn-1"
  resources:
    cpu: "6000m"
    memory: "24Gi"
```

### Scenario 4: AI/ML Platform with External Integrations
**Business Case**: Machine learning platform with third-party data sources

```yaml
# Logic Processing (IBM Cloud)
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: ml-computation-cell
spec:
  cellId: "ml-training-dallas"
  cellType: "logic"
  provider: "ibm"
  region: "us-south"
  resources:
    cpu: "32000m"  # High compute for ML
    memory: "128Gi"
---
# External Data Integration (AWS)
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: external-data-sources
spec:
  cellId: "data-connectors-us-west"
  cellType: "external"
  provider: "aws"
  region: "us-west-2"
  resources:
    cpu: "8000m"
    memory: "32Gi"
---
# Data Processing (Google Cloud)
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: ml-data-pipeline
spec:
  cellId: "data-processing-us-central"
  cellType: "data"
  provider: "gcp"
  region: "us-central1"
  resources:
    cpu: "16000m"
    memory: "64Gi"
    storage: "5Ti"
```

## 🔧 Deployment Commands

### Prerequisites
```bash
# Install Terraform and configure cloud provider credentials
terraform --version
kubectl version --client

# Configure cloud provider access
export AWS_ACCESS_KEY_ID="your-aws-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret"
export GOOGLE_APPLICATION_CREDENTIALS="path/to/gcp-service-account.json"
export ARM_CLIENT_ID="your-azure-client-id"
export ARM_CLIENT_SECRET="your-azure-client-secret"
export ARM_TENANT_ID="your-azure-tenant-id"
export ARM_SUBSCRIPTION_ID="your-azure-subscription-id"
```

### Deploy E-commerce Platform
```bash
# Deploy primary region (AWS)
cd examples/multi-cloud-cells/ecommerce
kubectl apply -f aws-primary-region.yaml

# Deploy secondary region (GCP)
kubectl apply -f gcp-secondary-region.yaml

# Verify deployment
kubectl get cells -l scenario=ecommerce
```

### Deploy Financial Services Platform
```bash
# Deploy security-first architecture
cd examples/multi-cloud-cells/fintech
kubectl apply -f azure-security-stack.yaml

# Monitor compliance
kubectl get cells -l compliance=required
```

### Deploy Legacy Modernization
```bash
# Phase 1: Legacy containerization
cd examples/multi-cloud-cells/legacy-migration
kubectl apply -f phase1-legacy.yaml

# Phase 2: Integration layer
kubectl apply -f phase2-integration.yaml

# Phase 3: Modern services
kubectl apply -f phase3-modernization.yaml
```

## 📊 Cost Optimization Strategies

### Regional Cost Analysis
| Provider     | Region        | Cost/vCPU/hour | Cost/GB RAM/hour | Cost/GB Storage/month |
|--------------|---------------|----------------|------------------|-----------------------|
| AWS          | us-east-1     | $0.0464        | $0.0125          | $0.10                |
| Google Cloud | us-central1   | $0.0475        | $0.0127          | $0.10                |
| Azure        | eastus        | $0.0496        | $0.0133          | $0.12                |
| Oracle Cloud | us-ashburn-1  | $0.0425        | $0.0114          | $0.085               |
| IBM Cloud    | us-south      | $0.0520        | $0.0140          | $0.11                |

### Optimization Recommendations
1. **Logic Cells**: Deploy in Oracle Cloud for cost-effective compute
2. **Data Cells**: Use AWS for balanced performance and cost
3. **Channel Cells**: Azure for global CDN integration
4. **Security Cells**: Keep local to data for compliance
5. **Legacy Cells**: On-premises for migration phases

## 🌍 Network Connectivity

### Cross-Cloud Networking
```yaml
# VPN/Transit Gateway Configuration
networking:
  aws-to-gcp:
    type: "vpn"
    bandwidth: "1Gbps"
    latency: "<50ms"
  
  aws-to-azure:
    type: "expressroute"
    bandwidth: "10Gbps"
    latency: "<25ms"
  
  on-premises:
    type: "dedicated-line"
    bandwidth: "10Gbps"
    latency: "<10ms"
```

### Service Mesh Configuration
```yaml
# Cross-cloud service mesh
istio:
  multiCluster:
    enabled: true
    discovery:
      - aws-us-east-1
      - gcp-europe-west1
      - azure-eastus
    
  networking:
    enableGlobalTrafficPolicy: true
    enableCrossClusterLoadBalancing: true
```

## 🔍 Monitoring Across Clouds

### Centralized Observability
```yaml
# Global observability cell (AWS)
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: global-observability
spec:
  cellId: "global-monitoring-us-east"
  cellType: "observability"
  provider: "aws"
  region: "us-east-1"
  resources:
    cpu: "24000m"
    memory: "96Gi"
    storage: "10Ti"
  
  # Federation configuration
  federation:
    sources:
      - provider: "gcp"
        endpoint: "prometheus.europe-west1.gcp.local"
      - provider: "azure"
        endpoint: "prometheus.eastus.azure.local"
      - provider: "oracle"
        endpoint: "prometheus.us-ashburn-1.oracle.local"
```

## 🚨 Disaster Recovery

### Multi-Cloud Failover Strategy
1. **Primary**: AWS us-east-1 (Channel + Logic + Data)
2. **Secondary**: GCP europe-west1 (Channel + Data)
3. **Tertiary**: Azure eastus (Data only)

### RTO/RPO Targets
- **Channel Cells**: RTO < 5 minutes, RPO < 1 minute
- **Logic Cells**: RTO < 15 minutes, RPO < 5 minutes
- **Data Cells**: RTO < 30 minutes, RPO < 15 minutes

This multi-cloud approach ensures high availability, cost optimization, and compliance across diverse regulatory environments. 