# Prism Platform Observability Framework

This directory contains the production-grade monitoring, alerting, and observability configuration for the Prism Platform platform.

## Components

The observability framework includes:

1. **Service Level Objectives (SLOs)** (`slo-definitions.yaml`)

   - Defines clear objectives for system performance
   - Creates alerting thresholds based on error budgets
   - Provides a foundation for SRE practices

2. **Prometheus Rules** (`prometheus-rules.yaml`)

   - Comprehensive alerting configuration
   - Monitors resource utilization, application health, and system performance
   - Configures critical alerts for immediate response

3. **Prometheus Configuration** (`prometheus-operator-values.yaml`)

   - Production-ready Prometheus deployment
   - Optimized settings for scalability and reliability
   - Configured service discovery for automatic monitoring

4. **Alertmanager Configuration** (`alertmanager-config.yaml`)

   - Alert routing and notification channels
   - Customized notification templates
   - Comprehensive alerting strategy with appropriate escalations

5. **Grafana Dashboards** (`grafana-dashboards/`)
   - Pre-configured dashboards for key services
   - SLO monitoring and visualization
   - API and service performance views

## Implementation Order

For best results, implement these components in the following order:

1. Prometheus Operator with provided values
2. Alertmanager configuration
3. Prometheus Rules for alerting
4. SLO definitions
5. Grafana dashboards

## Prerequisites

- Kubernetes 1.22+
- Helm 3.0+
- kube-prometheus-stack operator (installed via Helm)
- cert-manager (for TLS certificates)
- Optional: Loki for log aggregation

## Implementation Instructions

### 1. Install Prometheus Operator

```bash
# Add the Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus Operator with our custom values
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f kubernetes/observability/prometheus-operator-values.yaml
```

### 2. Configure Alertmanager

```bash
# Apply the Alertmanager configuration
kubectl apply -f kubernetes/observability/alertmanager-config.yaml

# Update the Alertmanager CRD to use this configuration
kubectl patch alertmanager prometheus-alertmanager -n monitoring --type=merge \
  --patch '{"spec":{"configSecret":"alertmanager-config"}}'
```

### 3. Apply Prometheus Rules

```bash
# Apply the custom alert rules
kubectl apply -f kubernetes/observability/prometheus-rules.yaml
```

### 4. Install SLO Operator and Definitions

```bash
# Install the SLO operator
kubectl apply -f https://github.com/slok/sloth/releases/download/v0.9.0/sloth.yaml

# Apply the SLO definitions
kubectl apply -f kubernetes/observability/slo-definitions.yaml
```

### 5. Import Grafana Dashboards

The dashboards will be automatically provisioned if you're using the provided Prometheus Operator values.

For manual import:

1. Port-forward to access Grafana:

   ```bash
   kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
   ```

2. Log in to Grafana (admin/your-password)

3. Import dashboards manually from JSON files in `kubernetes/observability/grafana-dashboards/`

## ServiceMonitor Configuration

Our configuration automatically discovers services with the following labels:

- `monitoring: "enabled"`
- `app.kubernetes.io/part-of: "prism-platform"`
- `cell.corrospondent.io/scrape: "true"` (for Prism Platform cells)

Ensure your services have these labels and expose metrics on a `/metrics` endpoint.

## Alert Notification Channels

The following notification channels are configured in Alertmanager:

- **Slack**: General alerts and warnings
- **PagerDuty**: Critical alerts requiring immediate attention
- **Email**: For specific teams (Database, Security)

Update the actual integration details in the Alertmanager configuration.

## Service Level Objectives (SLOs)

We've defined the following SLOs for key services:

- **API Service**: 99.9% availability, 95% of requests under 200ms
- **Data Cell**: 99.5% processing success rate
- **Logic Cell**: 99% of operations under 500ms
- **Drift Detection**: 99.5% accuracy

These SLOs are monitored with burn rate alerts to detect when we're consuming our error budget too quickly.

## Recommended Alert Handling Procedures

1. **Critical Alerts**: Require immediate attention and designated on-call response
2. **Warning Alerts**: Review during business hours and prioritize in upcoming work
3. **Info Alerts**: Collect for trend analysis and potential system improvements

## Dashboard Organization

Grafana dashboards are organized hierarchically:

1. **Overview**: High-level system status and SLO compliance
2. **Service-specific**: Detailed metrics for each major service
3. **Infrastructure**: Kubernetes and cloud resources
4. **SLO**: Detailed SLO compliance and error budget tracking

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/)
- [SLO Implementation Guide](https://sre.google/workbook/implementing-slos/)
- [Alert Design Philosophy](https://docs.google.com/document/d/199PqyG3UsyXlwieHaqbGiWVa8eMWi8zzAn0YfcApr8Q/)
