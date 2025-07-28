# Crossplane Bootstrap Module

This module installs and configures Crossplane for multi-cloud infrastructure orchestration as part of the Prism infrastructure platform.

## Overview

The Crossplane Bootstrap module provides:

- **Crossplane Installation**: Deploys Crossplane via Helm chart
- **Multi-Cloud Provider Setup**: Configures providers for AWS, GCP, Azure, Oracle, and IBM
- **Provider Configuration**: Sets up ProviderConfigs for enabled cloud providers
- **Cost Estimation Integration**: Optional Infracost integration for cost transparency

## Usage

### Basic Usage

```hcl
module "crossplane_bootstrap" {
  source = "./modules/crossplane-bootstrap"
  
  environment = "production"
  name_prefix = "mycompany-prod"
  
  # Enable AWS provider
  aws_region = "us-east-1"
  
  # Enable GCP provider
  gcp_project_id = "my-gcp-project"
  gcp_region     = "us-central1"
  
  common_tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

### Multi-Cloud Setup

```hcl
module "crossplane_bootstrap" {
  source = "./modules/crossplane-bootstrap"
  
  environment = "production"
  name_prefix = "mycompany-prod"
  
  # Multi-cloud configuration
  aws_region            = "us-east-1"
  gcp_project_id        = "my-gcp-project" 
  azure_subscription_id = "12345678-1234-1234-1234-123456789012"
  
  # Cost estimation
  enable_cost_estimation = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| name_prefix | Prefix for resource naming | `string` | n/a | yes |
| common_tags | Common tags to be applied to all resources | `map(string)` | `{}` | no |
| aws_region | AWS region for provider configuration | `string` | `""` | no |
| gcp_project_id | Google Cloud project ID | `string` | `""` | no |
| gcp_region | Google Cloud region | `string` | `""` | no |
| azure_subscription_id | Azure subscription ID | `string` | `""` | no |
| oci_tenancy_ocid | Oracle Cloud tenancy OCID | `string` | `""` | no |
| ibm_api_key | IBM Cloud API key | `string` | `""` | no |
| enable_cost_estimation | Enable Infracost integration | `bool` | `true` | no |
| crossplane_version | Version of Crossplane to install | `string` | `"1.14.0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| crossplane_namespace | Kubernetes namespace where Crossplane is installed |
| crossplane_version | Version of Crossplane that was installed |
| enabled_providers | List of enabled cloud providers |
| aws_provider_config_name | Name of the AWS ProviderConfig (if enabled) |
| gcp_provider_config_name | Name of the GCP ProviderConfig (if enabled) |
| azure_provider_config_name | Name of the Azure ProviderConfig (if enabled) |
| cost_estimation_enabled | Whether cost estimation is enabled |
| crossplane_ready | Indicates that Crossplane installation is complete |

## Prerequisites

- Kubernetes cluster with sufficient resources
- Helm provider configured
- Cloud provider credentials available as Kubernetes secrets (see below)

## Provider Credentials Setup

### AWS

Create a Kubernetes secret with AWS credentials:

```bash
kubectl create secret generic aws-secret \
  --namespace crossplane-system \
  --from-literal=creds='[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY'
```

### Google Cloud

Create a Kubernetes secret with GCP service account key:

```bash
kubectl create secret generic gcp-secret \
  --namespace crossplane-system \
  --from-file=creds=path/to/gcp-service-account.json
```

### Azure

Create a Kubernetes secret with Azure credentials:

```bash
kubectl create secret generic azure-secret \
  --namespace crossplane-system \
  --from-literal=creds='{
  "clientId": "YOUR_CLIENT_ID",
  "clientSecret": "YOUR_CLIENT_SECRET",
  "subscriptionId": "YOUR_SUBSCRIPTION_ID",
  "tenantId": "YOUR_TENANT_ID"
}'
```

## Cost Estimation

When `enable_cost_estimation` is `true`, the module integrates with Infracost to provide cost transparency:

- Cost estimates for provisioned resources
- Monthly cost projections
- Cost comparison between environments

## Monitoring

The module provides standard Kubernetes resources that can be monitored:

- Crossplane deployment status
- Provider installation status  
- Resource utilization metrics

## Examples

See the `examples/` directory for complete deployment examples:

- `examples/aws/` - AWS-only deployment
- `examples/gcp/` - Google Cloud deployment  
- `examples/multi-cloud/` - Multi-cloud deployment

## Version Compatibility

| Prism Version | Crossplane Version | Kubernetes Version |
|---------------|-------------------|-------------------|
| 1.0.x         | 1.14.x           | 1.24+             |
| 1.1.x         | 1.14.x           | 1.25+             |
| 1.2.x         | 1.14.x           | 1.26+             |

## Support

For issues and questions:

- Check the [troubleshooting guide](../../../docs/troubleshooting.md)
- Open an issue in the [GitHub repository](https://github.com/your-org/prism)
- Join our community discussions 