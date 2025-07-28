# Prism Telemetry Agent

The Prism Telemetry Agent is an optional component that provides infrastructure insights and performance benchmarking data to the Corrective Drift service for optimization recommendations.

## 🎯 Purpose

- **Infrastructure Insights**: Collect anonymized infrastructure metrics for benchmarking
- **Optimization Recommendations**: Enable Corrective Drift to provide cost and performance optimization suggestions
- **Community Benchmarks**: Contribute to community performance baselines (with consent)
- **Drift Detection**: Early warning system for infrastructure drift and anomalies

## 🔒 Privacy & Consent

The telemetry agent is **opt-in only** and implements comprehensive privacy controls:

### Privacy Levels

| Level | Data Collected | Anonymization | Use Case |
|-------|----------------|---------------|----------|
| **Minimal** | Basic cluster info, node count | Full anonymization | Community benchmarks only |
| **Standard** | + Resource usage, workload types | Anonymized | Platform insights + optimization |
| **Detailed** | + Network policies, detailed metrics | Hashed identifiers | Full optimization recommendations |

### User Consent

- **Explicit Opt-in**: Must be explicitly enabled by user
- **Granular Control**: Choose privacy level and data types
- **Revocable**: Can be disabled at any time
- **Transparent**: Clear indication of what data is collected

## 🚀 Quick Start

### Enable Telemetry

```hcl
# terraform.tfvars
enable_telemetry_agent = true
telemetry_privacy_level = "standard"  # minimal, standard, detailed
telemetry_endpoint = "https://telemetry.corrective-drift.com/v1/collect"
```

### Disable Telemetry

```hcl
# terraform.tfvars
enable_telemetry_agent = false
```

Or use the toggle script:
```bash
./scripts/toggle-telemetry.sh disable
```

## 📊 Data Collection

### Infrastructure Metrics (All Levels)

- **Cluster Information**: Kubernetes version, distribution, cloud provider
- **Node Count**: Number of worker nodes (anonymized)
- **Basic Resources**: Total CPU cores, memory capacity
- **Geographic Region**: Cloud region (for latency optimization)

### Platform Usage (Standard+)

- **Cell Deployment**: Number and types of cells deployed
- **Feature Usage**: Which Prism features are enabled
- **Observability Stack**: Monitoring tools in use
- **eBPF Features**: Security and networking features enabled

### Performance Benchmarks (Detailed)

- **Startup Times**: Pod and service startup performance
- **Network Latency**: Inter-service communication metrics
- **Storage Performance**: IOPS and throughput metrics
- **Cost Efficiency**: Resource utilization patterns

### Never Collected

- **Application Code**: No access to application source or data
- **Secrets/Credentials**: No sensitive information collected
- **Personal Data**: No user-identifiable information
- **Application Logs**: No application-specific log data

## 🔧 Configuration

### Basic Configuration

```yaml
telemetry:
  enabled: true
  privacy_level: "standard"
  reporting_interval_minutes: 60
  endpoint: "https://telemetry.corrective-drift.com/v1/collect"
  
consent:
  timestamp: "2024-01-01T00:00:00Z"
  version: "1.0"
  privacy_policy_url: "https://corrective-drift.com/privacy"
```

### Advanced Configuration

```yaml
telemetry:
  # Data collection rules
  collection_rules:
    collect_cluster_info: true
    collect_resource_usage: true
    collect_workload_types: true
    collect_network_policies: false
    anonymize_data: true
    
  # Retention policy
  local_retention_days: 7
  
  # Batching configuration
  batch_size: 100
  flush_interval_seconds: 300
  
  # Retry configuration
  max_retries: 3
  retry_backoff_seconds: 30
```

## 🔌 Integration with Corrective Drift

### Data Flow

1. **Collection**: Agent collects metrics based on privacy settings
2. **Anonymization**: Data is anonymized/hashed per privacy level
3. **Batching**: Metrics are batched for efficient transmission
4. **Transmission**: Encrypted HTTPS POST to Corrective Drift service
5. **Processing**: Corrective Drift analyzes for optimization opportunities
6. **Recommendations**: Insights delivered via API or dashboard

### API Endpoints

- **POST /v1/collect**: Submit telemetry data
- **GET /v1/recommendations/{cluster_id}**: Retrieve optimization recommendations
- **POST /v1/consent**: Update consent preferences
- **DELETE /v1/data/{cluster_id}**: Request data deletion

### Authentication

- **Cluster ID**: Unique, anonymized cluster identifier
- **API Key**: Optional for premium insights (enterprise)
- **TLS**: All communication encrypted with TLS 1.3

## 📈 Benefits

### For Users

- **Performance Insights**: Compare your infrastructure against community benchmarks
- **Cost Optimization**: Automated recommendations for cost reduction
- **Proactive Monitoring**: Early detection of performance degradation
- **Best Practices**: Learn from community deployment patterns

### For Community

- **Benchmark Data**: Anonymized performance baselines for different workloads
- **Platform Improvements**: Data-driven platform enhancement priorities
- **Documentation**: Real-world usage patterns inform documentation
- **Feature Development**: Usage data guides new feature development

## 🛡️ Security

### Data Protection

- **Encryption in Transit**: TLS 1.3 for all communications
- **No Sensitive Data**: Explicit exclusion of secrets and PII
- **Anonymization**: Cryptographic hashing of identifiers
- **Audit Trail**: Complete logging of data collection activities

### Access Controls

- **RBAC**: Kubernetes RBAC limits agent permissions
- **Service Account**: Dedicated service account with minimal privileges
- **Network Policies**: Restricted network access (if enabled)
- **Resource Limits**: CPU and memory limits prevent resource exhaustion

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Kubernetes    │    │  Telemetry       │    │  Corrective Drift   │
│   Cluster       │───▶│  Agent           │───▶│  Service            │
│                 │    │                  │    │                     │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────────┐ │
│ │ Node Metrics│ │    │ │ Data         │ │    │ │ Analytics       │ │
│ └─────────────┘ │    │ │ Collector    │ │    │ │ Engine          │ │
│ ┌─────────────┐ │    │ └──────────────┘ │    │ └─────────────────┘ │
│ │ Pod Metrics │ │    │ ┌──────────────┐ │    │ ┌─────────────────┐ │
│ └─────────────┘ │    │ │ Anonymizer   │ │    │ │ Recommendation  │ │
│ ┌─────────────┐ │    │ └──────────────┘ │    │ │ Engine          │ │
│ │ Workloads   │ │    │ ┌──────────────┐ │    │ └─────────────────┘ │
│ └─────────────┘ │    │ │ Transmitter  │ │    │                     │
└─────────────────┘    │ └──────────────┘ │    └─────────────────────┘
                       └──────────────────┘
```

## 🔄 Management

### Toggle Telemetry

```bash
# Enable telemetry
kubectl patch configmap telemetry-config -n prism-observability \
  --patch '{"data":{"enabled":"true"}}'

# Disable telemetry  
kubectl patch configmap telemetry-config -n prism-observability \
  --patch '{"data":{"enabled":"false"}}'

# Restart agent to apply changes
kubectl rollout restart deployment/telemetry-agent -n prism-observability
```

### View Collected Data

```bash
# Check telemetry status
kubectl get pods -n prism-observability -l app.kubernetes.io/name=telemetry-agent

# View agent logs
kubectl logs -n prism-observability deployment/telemetry-agent

# Check configuration
kubectl get configmap telemetry-config -n prism-observability -o yaml
```

### Data Deletion

```bash
# Request data deletion (requires cluster ID)
curl -X DELETE "https://telemetry.corrective-drift.com/v1/data/${CLUSTER_ID}" \
  -H "Authorization: Bearer ${API_TOKEN}"
```

## 🧪 Testing

### Local Testing

```bash
# Test telemetry agent locally
docker run -it --rm \
  -v $PWD/config.yaml:/etc/telemetry/config.yaml \
  prism-platform/telemetry-agent:latest \
  --config /etc/telemetry/config.yaml \
  --dry-run

# Validate configuration
kubectl apply --dry-run=client -f telemetry-deployment.yaml
```

### Integration Testing

```bash
# Deploy test environment
terraform apply -var="enable_telemetry_agent=true" -var="environment=test"

# Verify telemetry collection
kubectl exec -n prism-observability deployment/telemetry-agent -- \
  curl localhost:8080/metrics

# Check data transmission
kubectl logs -n prism-observability deployment/telemetry-agent -f
```

## 📜 Compliance

### GDPR Compliance

- **Data Minimization**: Collect only necessary data
- **Purpose Limitation**: Data used only for stated purposes
- **Right to Erasure**: Data deletion API available
- **Consent Management**: Explicit opt-in with granular controls

### SOC 2 Compliance

- **Security Controls**: Encryption and access controls
- **Availability**: Monitoring and alerting for service availability
- **Processing Integrity**: Data validation and error handling
- **Confidentiality**: Data anonymization and access restrictions

## 🤝 Community

### Opt-out Information

Users can opt-out at any time:
1. Set `enable_telemetry_agent = false` in configuration
2. Use the toggle script: `./scripts/toggle-telemetry.sh disable`
3. Contact support for data deletion requests

### Community Benefits

Aggregated, anonymized data helps the community by:
- Identifying common performance bottlenecks
- Validating optimization strategies
- Improving platform stability and performance
- Guiding feature development priorities

## 📞 Support

- **Documentation**: [docs.prism-platform.io/telemetry](https://docs.prism-platform.io/telemetry)
- **Issues**: [GitHub Issues](https://github.com/prism-platform/prism/issues)
- **Privacy Questions**: privacy@corrective-drift.com
- **Data Deletion**: data-deletion@corrective-drift.com

---

**Privacy-First Design**: The telemetry agent is designed with privacy as a core principle, providing value to both individual users and the broader community while maintaining strict data protection standards. 