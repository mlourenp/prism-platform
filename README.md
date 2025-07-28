# Prism Infrastructure Platform

**Open-core multi-cloud infrastructure management plane with toggle-able observability**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-623CE4)](https://terraform.io)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-%3E%3D1.24-326CE5)](https://kubernetes.io)

Prism is a production-ready infrastructure platform that provides unified multi-cloud orchestration with cell-based deployment patterns and comprehensive "flip of a switch" observability.

## 🚀 Quick Start

### Prerequisites

- **Terraform** >= 1.0
- **kubectl** >= 1.24
- **Helm** >= 3.0
- Access to a Kubernetes cluster (EKS, GKE, AKS, or bare-metal)
- Cloud provider credentials configured

### Basic Deployment

```bash
# Clone the repository
git clone https://github.com/prism-community/prism-platform.git
cd prism-platform

# Initialize Terraform
terraform init

# Basic deployment with default settings
terraform apply

# Access Grafana (if observability enabled)
kubectl port-forward -n prism-observability svc/prometheus-grafana 3000:80
```

### Deploy Sample Cells

```bash
# Deploy comprehensive sample cells (all 7 cell types)
./scripts/deploy-sample-cells.sh
```

## 🎛️ Feature Toggle System

Prism provides "flip of a switch" observability and feature control:

### Core Features

| Feature | Variable | Default | Description |
|---------|----------|---------|-------------|
| **Multi-Cloud Orchestration** | `enable_crossplane` | `true` | Crossplane for unified control plane |
| **Service Mesh** | `enable_service_mesh` | `false` | Istio + Merbridge eBPF acceleration |
| **Observability Stack** | `enable_observability_stack` | `true` | Prometheus, Grafana, Alertmanager |
| **eBPF Observability** | `enable_ebpf_observability` | `false` | Cilium, Tetragon, Falco |
| **Pixie Deep Observability** | `enable_pixie` | `false` | Deep debugging and profiling |
| **Datadog Alternative** | `enable_datadog_alternative` | `false` | APM auto-instrumentation |
| **Telemetry Agent** | `enable_telemetry_agent` | `false` | Infrastructure insights (privacy-first) |
| **Cost Estimation** | `enable_cost_estimation` | `true` | Infracost integration |
| **Cell Deployment** | `enable_cell_deployment` | `true` | Cell-based infrastructure patterns |

### Configuration Examples

#### Development Environment
```hcl
# terraform.tfvars
environment = "dev"
cluster_name = "prism-dev"

# Basic observability only
enable_observability_stack = true
enable_ebpf_observability = false
enable_service_mesh = false
```

#### Production Environment with Full Observability
```hcl
# terraform.tfvars
environment = "prod"
cluster_name = "prism-prod"

# Full observability stack
enable_observability_stack = true
  enable_ebpf_observability = true
enable_service_mesh = true
enable_pixie = true

# Enhanced retention for production
observability_retention_days = 30
observability_storage_size = "200Gi"
```

#### Datadog Alternative Setup
```hcl
# terraform.tfvars
enable_datadog_alternative = true
datadog_api_key = "your-datadog-api-key"
datadog_app_key = "your-datadog-app-key"
datadog_site = "datadoghq.com"

# Disable built-in observability to avoid conflicts
enable_observability_stack = false
enable_ebpf_observability = false
```

## 🏗️ Cell-Based Architecture

Prism implements a cell-based architecture with 7 specialized cell types:

### Cell Types

| Cell Type | Purpose | Communication Pattern | Scaling |
|-----------|---------|----------------------|---------|
| **Channel** | API Gateway, External interfaces | Public ↔ External | Horizontal |
| **Logic** | Business logic, Computation | Internal ↔ Data | Horizontal |
| **Data** | Storage, Databases | Internal only | Vertical |
| **ML** | Machine Learning, AI workloads | Internal ↔ Data | GPU-based |
| **Security** | Security scanning, Compliance | Monitor all | Distributed |
| **External** | Third-party integrations | External APIs | Connection-based |
| **Integration** | Workflow orchestration | Cross-cell | Event-driven |
| **Legacy** | Legacy system integration | Hybrid | Bridge-based |
| **Observability** | Monitoring, Alerting | Monitor all | Storage-intensive |

### Cell Communication Matrix

```
          │ Chan │ Logic│ Data │ ML   │ Sec  │ Ext  │ Int  │ Leg  │ Obs  │
──────────────────────────────────────────────────────────────────────────
Channel   │  ✓   │  ✓   │  ✗   │  ✗   │ Audit│  ✓   │  ✓   │  ✓   │ Mon  │
Logic     │  ✓   │  ✓   │  ✓   │  ✓   │ Audit│ Ext  │  ✓   │  ✓   │ Mon  │
Data      │  ✗   │  ✗   │  ✓   │  ✓   │ Audit│  ✗   │  ✗   │  ✓   │ Mon  │
ML        │  ✗   │  ✓   │  ✓   │  ✓   │ Audit│  ✗   │  ✓   │  ✓   │ Mon  │
Security  │ Audit│ Audit│ Audit│ Audit│  ✓   │ Audit│ Audit│ Audit│  ✓   │
External  │  ✗   │  ✗   │  ✗   │  ✗   │ Audit│  ✓   │  ✗   │  ✗   │ Mon  │
Integrate │  ✓   │  ✗   │  ✓   │  ✓   │ Audit│  ✓   │  ✓   │  ✓   │ Mon  │
Legacy    │  ✓   │  ✓   │  ✓   │  ✗   │ Audit│  ✓   │  ✓   │  ✓   │ Mon  │
Observ.   │ Mon  │ Mon  │ Mon  │ Mon  │  ✓   │ Mon  │ Mon  │ Mon  │  ✓   │
```

**Legend**: ✓ = Allowed, ✗ = Blocked, Mon = Monitoring only, Audit = Security audit, Ext = Via External cell

## 🌍 Multi-Cloud Support

### Supported Providers

- **AWS** - EKS, EC2, S3, RDS, etc.
- **Google Cloud** - GKE, Compute Engine, Cloud Storage, etc.
- **Azure** - AKS, Virtual Machines, Blob Storage, etc.
- **Oracle Cloud** - OKE, Compute, Object Storage, etc.
- **IBM Cloud** - IKS, Virtual Servers, Cloud Object Storage, etc.
- **Bare Metal** - kubeadm, MetalLB, local storage, etc.

### Provider Configuration

```hcl
# Multi-cloud deployment example
cloud_provider = "aws"  # Primary provider
region = "us-east-1"

# Optional: Configure additional providers via Crossplane
enable_crossplane = true
```

## 📊 Observability Options

### Built-in Observability Stack

- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization and dashboards
- **Alertmanager** - Alert routing and management
- **Loki** - Log aggregation (optional)
- **Tempo** - Distributed tracing (optional)

### eBPF-Based Observability

- **Cilium** - Network policies and observability
- **Tetragon** - Runtime security and process monitoring
- **Falco** - Threat detection and compliance
- **Hubble** - Network flow visualization

### Datadog Alternative

Complete APM solution with:
- Auto-instrumentation for Java, Python, Node.js, Go, .NET
- Universal service monitoring
- Kubernetes pod logging
- Network performance monitoring
- Security monitoring

### Telemetry Agent

**Privacy-first infrastructure insights** connecting to Corrective Drift service:

#### 🔒 Privacy Levels
- **Minimal**: Basic cluster info (fully anonymized)
- **Standard**: + Resource usage, workload types (anonymized)  
- **Detailed**: + Network policies, performance metrics (hashed IDs)

#### 📊 Benefits
- **Performance Insights**: Compare against community benchmarks
- **Cost Optimization**: Automated recommendations from Corrective Drift
- **Drift Detection**: Early warning for infrastructure anomalies
- **Best Practices**: Learn from anonymized community patterns

#### 🎛️ Easy Toggle
```bash
# Enable with privacy controls
./scripts/toggle-telemetry.sh enable

# Change privacy level
./scripts/toggle-telemetry.sh privacy --level minimal

# Disable anytime
./scripts/toggle-telemetry.sh disable
```

#### 🛡️ Privacy-First Design
- **Explicit opt-in** required
- **No secrets/PII** ever collected
- **Data deletion** available on request
- **GDPR compliant** with granular controls

## 🛠️ Deployment Options

### 1. Management Plane Only

```bash
terraform apply -var="enable_cell_deployment=false"
```

### 2. Data Plane Only

```bash
terraform apply -var="enable_crossplane=false" -var="enable_observability_stack=false"
```

### 3. Full Stack with eBPF

```bash
terraform apply \
  -var="enable_observability_stack=true" \
  -var="enable_ebpf_observability=true" \
  -var="enable_service_mesh=true"
```

### 4. Datadog Integration

```bash
terraform apply \
  -var="enable_datadog_alternative=true" \
  -var="datadog_api_key=your-key" \
  -var="enable_observability_stack=false"
```

## 🚀 Startup & Teardown

### Startup Script

```bash
# Quick start with default configuration
./scripts/startup.sh

# Custom configuration
./scripts/startup.sh --config production.tfvars

# With sample cells
./scripts/startup.sh --deploy-samples
```

### Teardown Script

```bash
# Clean teardown
./scripts/teardown.sh

# Force teardown (in case of issues)
./scripts/teardown.sh --force
```

## 📈 Cost Optimization

### Infracost Integration

Prism includes built-in cost estimation:

```bash
# View cost estimate before deployment
infracost diff --path .

# Monthly cost breakdown
infracost breakdown --path .
```

### Cost Optimization Features

- **Resource right-sizing** based on actual usage
- **Auto-scaling** for cost-efficient workloads
- **Storage optimization** with lifecycle policies
- **Spot instance** integration where applicable
- **Multi-cloud cost comparison** for workload placement

## 🔒 Security & Compliance

### Built-in Security Features

- **Network Policies** - Microsegmentation via Cilium
- **Pod Security Standards** - Kubernetes security contexts
- **Secret Management** - Encrypted secrets at rest
- **RBAC** - Role-based access control
- **Runtime Security** - Falco/Tetragon threat detection

### Compliance Frameworks

- **CIS Kubernetes Benchmark**
- **PCI DSS** compliance patterns
- **SOC 2** audit logging
- **GDPR** data protection controls

## 🔧 Development & Contributing

### Local Development

```bash
# Set up development environment
./scripts/setup-dev.sh

# Run tests
terraform test

# Validate configuration
terraform validate && terraform plan
```

### Module Development

```bash
# Create new module
./scripts/create-module.sh my-new-module

# Test module
cd modules/my-new-module
terraform test
```

## 📚 Documentation

- [Architecture Guide](docs/architecture.md)
- [Module Reference](docs/modules/)
- [API Documentation](docs/api/)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Migration Guide](docs/migration.md)

## 🤝 Support & Community

- **Issues**: [GitHub Issues](https://github.com/prism-community/prism-platform/issues)
- **Discussions**: [GitHub Discussions](https://github.com/prism-community/prism-platform/discussions)
- **Documentation**: [Official Docs](https://docs.prism-platform.io)
- **Slack**: [Community Slack](https://prism-platform.slack.com)

## 📄 License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

## 🏷️ Versioning

We use [Semantic Versioning](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/prism-community/prism-platform/tags).

**Current Version**: v1.2.0
- ✅ **v1.0**: Core multi-cloud Crossplane + bare-metal foundation
- ✅ **v1.1**: Service mesh + eBPF observability with toggle capability  
- ✅ **v1.2**: Cell-based infrastructure patterns + toggleable observability stack

## 🎯 Roadmap

### v1.3 (Next Release)
- Enhanced multi-cloud networking
- Advanced cost optimization algorithms
- Improved cell communication patterns

### v2.0 (Future)
- AI-driven infrastructure optimization
- Advanced compliance automation
- Enterprise integrations

---

**Made with ❤️ by the Prism Platform Team** 