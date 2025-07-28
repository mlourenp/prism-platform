# Prism Service Mesh Module

This module deploys Istio service mesh with eBPF acceleration via Merbridge, providing advanced networking, security, and observability capabilities for the Prism platform.

## Features

- 🌐 **Multi-Cloud Istio Deployment**: Supports AWS, GCP, Azure, Oracle, IBM, and bare-metal
- ⚡ **eBPF Acceleration**: Merbridge integration for high-performance networking
- 🔒 **mTLS Security**: Automatic mutual TLS between services
- 🌍 **Multi-Cluster Support**: Cross-cluster service discovery and traffic management
- 📊 **Built-in Observability**: Metrics, tracing, and access logs
- 🚪 **Gateway Management**: Ingress and east-west gateways

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Istio Control Plane                     │
├─────────────────────────────────────────────────────────────┤
│  istiod  │ Ingress Gateway │ East-West Gateway │ Merbridge │
├─────────────────────────────────────────────────────────────┤
│              eBPF Accelerated Data Plane                   │
├─────────────────────────────────────────────────────────────┤
│     Logic     │    Channel    │     Data     │  Security   │
│     Cells     │     Cells     │    Cells     │    Cells    │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Service Mesh Deployment

```hcl
module "service_mesh" {
  source = "./modules/service-mesh"
  
  environment = "production"
  name_prefix = "prism"
  provider    = "aws"
  region      = "us-east-1"
  
  # Basic configuration
  istio_version = "1.26.1"
  mesh_id      = "prism-mesh"
  network_name = "prism-network"
  
  common_tags = {
    Environment = "production"
    Project     = "prism"
  }
}
```

### Multi-Cluster Setup

```hcl
module "service_mesh" {
  source = "./modules/service-mesh"
  
  environment = "production"
  name_prefix = "prism"
  provider    = "aws"
  region      = "us-east-1"
  
  # Multi-cluster configuration
  enable_multi_cluster = true
  mesh_id             = "prism-global"
  network_name        = "aws-us-east-1"
  
  mesh_networks = [
    {
      name     = "gcp-europe-west1"
      registry = "Kubernetes"
      gateways = [
        {
          service = "istio-eastwestgateway"
          port    = 15443
        }
      ]
    }
  ]
}
```

### eBPF Acceleration Configuration

```hcl
module "service_mesh" {
  source = "./modules/service-mesh"
  
  environment = "production"
  name_prefix = "prism"
  provider    = "gcp"
  region      = "us-central1"
  
  # eBPF acceleration
  enable_ebpf_acceleration = true
  merbridge_version       = "v0.5.0"
  cni_mode               = "cilium"  # Works with Cilium CNI
  
  # Resource optimization for eBPF
  pilot_resources = {
    cpu_request    = "1000m"
    memory_request = "4Gi"
    cpu_limit      = "2000m"
    memory_limit   = "8Gi"
  }
}
```

### Security-Focused Deployment

```hcl
module "service_mesh" {
  source = "./modules/service-mesh"
  
  environment = "production"
  name_prefix = "prism-secure"
  provider    = "azure"
  region      = "eastus"
  
  # Strict security
  mtls_mode = "STRICT"
  
  # Restricted ingress
  ingress_source_ranges = [
    "10.0.0.0/8",    # Internal networks only
    "172.16.0.0/12", # Private networks
    "192.168.0.0/16" # Local networks
  ]
  
  # Enhanced observability for security
  enable_telemetry    = true
  enable_tracing      = true
  enable_access_logs  = true
  access_log_format   = "JSON"
}
```

## Configuration Options

### Core Configuration

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `environment` | Environment name | `string` | Required |
| `name_prefix` | Prefix for resource names | `string` | Required |
| `provider` | Cloud provider | `string` | Required |
| `istio_version` | Istio version | `string` | `"1.26.1"` |
| `mesh_id` | Unique mesh identifier | `string` | `"mesh1"` |

### Multi-Cluster Configuration

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `enable_multi_cluster` | Enable multi-cluster mesh | `bool` | `false` |
| `network_name` | Network name for cluster | `string` | `"network1"` |
| `mesh_networks` | Multi-cluster network config | `list(object)` | `[]` |

### eBPF Acceleration

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `enable_ebpf_acceleration` | Enable Merbridge eBPF | `bool` | `true` |
| `merbridge_version` | Merbridge version | `string` | `"v0.5.0"` |
| `cni_mode` | CNI mode for Merbridge | `string` | `"auto"` |

### Security Configuration

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `mtls_mode` | mTLS mode (STRICT/PERMISSIVE/DISABLE) | `string` | `"STRICT"` |
| `ingress_source_ranges` | Allowed source IP ranges | `list(string)` | `["0.0.0.0/0"]` |

### Observability Configuration

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `enable_telemetry` | Enable telemetry collection | `bool` | `true` |
| `enable_tracing` | Enable distributed tracing | `bool` | `true` |
| `tracing_sampling_rate` | Tracing sampling rate | `number` | `0.1` |
| `enable_access_logs` | Enable access logs | `bool` | `true` |

## Outputs

### Service Mesh Information

- `istio_namespace`: Istio installation namespace
- `mesh_id`: Service mesh identifier
- `mtls_mode`: Configured mTLS mode
- `service_mesh_config`: Complete configuration object

### Gateway Information

- `ingress_gateway_service_name`: Ingress gateway service name
- `eastwest_gateway_service_name`: East-west gateway service name

### eBPF Acceleration

- `ebpf_acceleration_enabled`: eBPF acceleration status
- `merbridge_version`: Deployed Merbridge version

## Integration with Cell Architecture

### Enabling Service Mesh for Cells

```yaml
# Logic Cell with Istio injection
apiVersion: prism.io/v1alpha1
kind: Cell
metadata:
  name: compute-workload
  labels:
    istio-injection: enabled  # Enable sidecar injection
spec:
  cellId: "compute-us-east-1"
  cellType: "logic"
  provider: "aws"
  region: "us-east-1"
```

### Inter-Cell Communication Policies

```yaml
# Authorization policy for cell communication
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: channel-to-logic
  namespace: logic-cell-namespace
spec:
  selector:
    matchLabels:
      prism.io/cell-type: logic
  rules:
  - from:
    - source:
        namespaces: ["channel-cell-namespace"]
  - to:
    - operation:
        methods: ["GET", "POST"]
```

## Cloud Provider Specific Features

### AWS Integration
- Network Load Balancer (NLB) for ingress
- EKS integration with IAM roles
- VPC CNI compatibility

### Google Cloud Integration  
- Google Cloud Load Balancer
- GKE Autopilot support
- Cloud Armor integration

### Azure Integration
- Azure Load Balancer
- AKS integration
- Azure Policy compatibility

### Oracle Cloud Integration
- OCI Load Balancer
- OKE container engine support
- OCI native networking

### Bare Metal Support
- MetalLB load balancer
- Custom CNI configurations
- Hardware-specific optimizations

## Performance Optimization

### eBPF Benefits with Merbridge
- **Reduced Latency**: Bypass iptables rules
- **Lower CPU Usage**: Kernel-level packet processing
- **Better Throughput**: Direct packet forwarding
- **Reduced Memory**: Fewer userspace hops

### Resource Sizing Guidelines

#### Small Clusters (< 100 pods)
```hcl
pilot_resources = {
  cpu_request    = "500m"
  memory_request = "2Gi"
  cpu_limit      = "1000m"
  memory_limit   = "4Gi"
}
```

#### Medium Clusters (100-500 pods)
```hcl
pilot_resources = {
  cpu_request    = "1000m"
  memory_request = "4Gi"
  cpu_limit      = "2000m"
  memory_limit   = "8Gi"
}
```

#### Large Clusters (> 500 pods)
```hcl
pilot_resources = {
  cpu_request    = "2000m"
  memory_request = "8Gi"
  cpu_limit      = "4000m"
  memory_limit   = "16Gi"
}
```

## Troubleshooting

### Common Issues

#### Sidecar Injection Not Working
```bash
# Check webhook configuration
kubectl get mutatingwebhookconfiguration istio-sidecar-injector

# Verify namespace labels
kubectl get namespace -l istio-injection=enabled
```

#### eBPF Acceleration Issues
```bash
# Check Merbridge status
kubectl get daemonset merbridge -n istio-system

# Verify eBPF programs
kubectl exec -n istio-system ds/merbridge -- bpftool prog list
```

#### Multi-Cluster Connectivity
```bash
# Test cross-cluster discovery
istioctl proxy-config cluster <pod-name> | grep <remote-service>

# Check east-west gateway
kubectl get service istio-eastwestgateway -n istio-system
```

## Security Considerations

### mTLS Configuration
- **STRICT**: All communication encrypted (recommended for production)
- **PERMISSIVE**: Mixed plaintext and encrypted (migration mode)
- **DISABLE**: No mTLS (development only)

### Network Policies
- Ingress gateway source IP restrictions
- Cell-to-cell communication rules
- External service access controls

### Certificate Management
- Automatic certificate rotation
- Custom CA integration
- Certificate monitoring and alerting

This service mesh module provides the networking foundation for the Prism platform's cell-based architecture while maintaining security, performance, and observability across multi-cloud deployments. 