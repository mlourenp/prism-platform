# Prism Infrastructure Platform - Crossplane Definitions

This directory contains the Crossplane Custom Resource Definitions (CRDs) and compositions for the Prism Infrastructure Platform. These definitions enable a declarative approach to managing multi-region infrastructure using Kubernetes-native objects.

## Version Information

- Kubernetes: 1.32
- Crossplane: 1.15.1
- AWS Provider: v0.37.0
- Kubernetes Provider: v0.7.0
- Helm Provider: v0.18.0
- Istio: 1.26.1
- Merbridge: 0.5.0
- Cilium: 1.15.3
- Tetragon: 0.10.0
- Falco: 0.37.0
- Pixie: 0.12.0

## Directory Structure

```
crossplane/
├── definitions/             # CRD definitions for custom resources
│   ├── cell-definition.yaml                # Application boundary in a region
│   ├── cell-observability-definition.yaml  # Observability config for a cell
│   ├── cell-policy-definition.yaml         # Policy config for cells
│   ├── global-infrastructure-definition.yaml  # Global routing and config
│   └── regional-infrastructure-definition.yaml # Region-specific infrastructure
├── compositions/            # Crossplane compositions that define how resources are assembled
│   └── regional-infrastructure-aws-composition.yaml  # AWS implementation
└── README.md
```

## Custom Resource Definitions

### RegionalInfrastructure

Represents the infrastructure for a specific AWS region, including:

- VPC and networking components
- EKS cluster configuration (Kubernetes 1.32)
- Service mesh (Istio 1.26.1 with Cilium 1.15.3)
- eBPF-based networking (Merbridge 0.5.0, Tetragon 0.10.0)
- Security monitoring (Falco 0.37.0)
- Observability (Pixie 0.12.0)
- Data services (Elasticsearch, Redis)
- Backup systems

### GlobalInfrastructure

Defines global infrastructure that spans multiple regions, including:

- Multi-region routing policies
- DNS configuration
- Load balancing and failover mechanisms
- Global observability
- Security controls

### Cell

Represents an application boundary within a region, providing:

- Resource allocations
- Service definitions
- Ingress configuration
- Monitoring setup
- Network policies

### CellPolicy

Defines security and operational policies for cells, including:

- Pod security policies
- Network policies
- Resource quotas
- Compliance standards
- Audit logging requirements

### CellObservability

Configures detailed observability for cells:

- Metrics collection (Prometheus)
- Logging (Fluentd, Elasticsearch)
- Tracing (Jaeger)
- Alerting (Alertmanager)
- Custom dashboards (Grafana)

## Compositions

The compositions directory contains implementations of the abstract CRDs for specific cloud providers.

### regional-infrastructure-aws-composition.yaml

This composition defines how a RegionalInfrastructure resource is composed of AWS resources using Crossplane providers:

- VPC, subnets, internet gateway, NAT gateways (using AWS EC2 provider)
- EKS cluster and node groups (using AWS EKS provider)
- Service mesh, observability tools, and data services (using Helm provider)

## Getting Started

1. Install Crossplane on your Kubernetes cluster:

   ```bash
   helm repo add crossplane-stable https://charts.crossplane.io/stable
   helm repo update
   helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace --version 1.15.1
   ```

2. Install the required Crossplane providers:

   ```bash
   # AWS Provider
   kubectl crossplane install provider crossplane/provider-aws:v0.37.0

   # Kubernetes Provider
   kubectl crossplane install provider crossplane/provider-kubernetes:v0.7.0

   # Helm Provider
   kubectl crossplane install provider crossplane/provider-helm:v0.18.0
   ```

3. Apply the CRD definitions:

   ```bash
   kubectl apply -f crossplane/definitions/
   ```

4. Apply the compositions:

   ```bash
   kubectl apply -f crossplane/compositions/
   ```

5. Create provider configurations (not included - create securely with your credentials)
6. Apply example resources:

   ```bash
   kubectl apply -f config/examples/global-infrastructure.yaml
   kubectl apply -f config/examples/regional-infrastructure-us-east-1.yaml
   kubectl apply -f config/examples/cell-us-east-1.yaml
   kubectl apply -f config/examples/cell-policy-production.yaml
   kubectl apply -f config/examples/cell-observability-us-east-1.yaml
   ```

## Security Best Practices

1. Use AWS IAM Roles for Service Accounts (IRSA) for pod-level permissions
2. Enable encryption at rest for all persistent storage
3. Implement network policies to restrict pod-to-pod communication
4. Use AWS Secrets Manager or HashiCorp Vault for sensitive data
5. Enable audit logging for all API server requests
6. Implement pod security standards (PSS) at the cluster level
7. Use AWS KMS for envelope encryption of secrets

## Monitoring and Observability

1. Use AWS CloudWatch for infrastructure metrics
2. Implement Prometheus and Grafana for application metrics
3. Use AWS X-Ray for distributed tracing
4. Enable AWS CloudTrail for API activity logging
5. Implement centralized logging with Fluentd and Elasticsearch

## Backup and Disaster Recovery

1. Use Velero for Kubernetes resource backups
2. Implement cross-region replication for critical data
3. Regular backup testing and validation
4. Documented recovery procedures
5. Automated backup scheduling and retention policies

## Relationship Between Resources

```
                  +---------------------------+
                  |   GlobalInfrastructure    |
                  +---------------------------+
                              |
                              | references
                              v
+------------------+    +----------------+    +------------------+
| RegionalInfra    |<---| RegionalInfra |---->| RegionalInfra    |
| (us-east-1)      |    | (us-west-2)   |    | (eu-west-1)      |
+------------------+    +----------------+    +------------------+
        ^                      ^                     ^
        |                      |                     |
        | references           | references          | references
        |                      |                     |
  +-----+------+        +------+-----+        +------+-----+
  | Cell       |        | Cell       |        | Cell       |
  | (primary)  |        | (secondary)|        | (reporting)|
  +-----+------+        +-----+------+        +------------+
        ^                     ^                      ^
        |                     |                      |
  +-----+------+        +-----+------+        +------+-----+
  | CellPolicy |        | CellPolicy |        | CellPolicy |
  +------------+        +------------+        +------------+
        ^                     ^                      ^
        |                     |                      |
  +-----+--------+      +-----+--------+      +------+-------+
  | CellObserv.  |      | CellObserv.  |      | CellObserv.  |
  +--------------+      +--------------+      +--------------+
```
