# Prism Platform - Crossplane Domain Cell Architecture

This directory contains the Crossplane compositions and configurations for implementing the Prism Platform's cell-based architecture. The platform provides a generic, reusable foundation for deploying cloud-native applications across multiple domains.

## Architecture Overview

The Prism Platform implements a **hybrid two-tier cell model**:

1. **Domain (Top-Level Cell)**: Represents a business domain or application area
2. **Purpose (Sub-Cell)**: Functional separation within a domain

### Purpose-Based Subcells

Each domain cell is automatically subdivided into purpose-specific subcells:

- **Channel**: Frontend services, API gateways, user interfaces
- **Data**: Databases, caches, data processing services
- **Logic**: Business logic, workers, processing engines
- **Observability**: Monitoring, logging, alerting services
- **Security**: Authentication, authorization, policy enforcement

## Components

### Compositions

- `xdomaincell.yaml`: Main composition for creating domain cells
- `xrd-domaincell.yaml`: Composite Resource Definition for domain cells

### Examples

- `web-application.yaml`: Example web application deployment
- `ml-platform.yaml`: Example ML platform deployment

### Key Features

- **Multi-Cloud Ready**: Currently supports AWS with extensibility for other providers
- **Cost Optimized**: Graviton instances, spot capacity, reserved instances
- **Security First**: Network isolation, RBAC, compliance frameworks
- **Performance Focused**: Placement groups, node affinity, resource optimization
- **Scalable**: Auto-scaling node groups, HPA support

## Usage

### 1. Deploy a Domain Cell

```bash
kubectl apply -f examples/web-application.yaml
```

### 2. Customize for Your Domain

```yaml
apiVersion: platform.prism.io/v1alpha1
kind: DomainCellClaim
metadata:
  name: my-application-prod
  namespace: my-team
spec:
  domain: api
  environment: prod
  tenant: my-company
  region: us-east-1
  
  nodeGroups:
    channel:
      instanceTypes: ["c6g.large"]
      minSize: 3
      maxSize: 15
      desiredSize: 5
      
  services:
    channel:
      - "api-gateway"
      - "frontend"
    data:
      - "postgresql"
      - "redis"
    logic:
      - "order-service"
      - "payment-service"
```

### 3. Monitor Cell Status

```bash
kubectl get domaincellclaims
kubectl describe domaincellclaim my-application-prod
```

## Configuration Options

### Node Groups

Each purpose has dedicated node groups with optimized instance types:

- **Channel**: General purpose (t3a, c6g)
- **Data**: Memory optimized (r6g, r7g)
- **Logic**: Compute optimized (c6g) or GPU (g4dn, g5)
- **Observability**: Balanced (m6g)
- **Security**: Small, secure (t3a.small)

### Cost Optimization

- **Reserved Instances**: For predictable workloads
- **Spot Instances**: For fault-tolerant workloads
- **Graviton Processors**: ARM-based for cost efficiency
- **Savings Plans**: Commitment-based discounts

### Compliance

Supported compliance frameworks:
- SOC2, GDPR, HIPAA, PCI-DSS
- Basel, SOX, FINRA, MiFID (Financial)

## Best Practices

1. **Domain Separation**: Use separate cells for different business domains
2. **Environment Isolation**: Separate cells for dev/staging/prod
3. **Resource Right-Sizing**: Start small and scale based on metrics
4. **Cost Monitoring**: Enable detailed billing and cost allocation tags
5. **Security**: Use least privilege access and network policies

## Contributing

When adding new compositions or examples:

1. Keep examples generic and domain-agnostic
2. Use descriptive names that indicate purpose
3. Include comprehensive documentation
4. Test with multiple scenarios
5. Follow Crossplane best practices

## Support

For issues or questions about the Prism Platform cell architecture:

1. Check existing examples for similar patterns
2. Review Crossplane documentation
3. Test in development environment first
4. Submit issues with detailed reproduction steps