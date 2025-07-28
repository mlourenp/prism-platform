# Prism Platform Security Hardening

This directory contains security hardening components for the Prism Platform platform. These components implement production-grade security controls for all aspects of the system.

## Components

The security hardening package includes:

1. **RBAC Configuration** (`rbac-configuration.yaml`)

   - Enforces least privilege principle for service accounts
   - Defines specific roles for different components
   - Creates cell-specific service accounts with limited permissions

2. **Image Security Policy** (`image-security-policy.yaml`)

   - Prevents use of vulnerable container images
   - Enforces approved image registries
   - Requires security scanning before deployment

3. **TLS Policy** (`cluster-tls-policy.yaml`)

   - Enforces TLS for all service communications
   - Implements mutual TLS for internal traffic
   - Configures certificate management with automatic rotation

4. **Pod Security Standards** (`security-context-defaults.yaml`)

   - Defines hardened container security contexts
   - Blocks privileged containers
   - Enforces read-only filesystems where possible

5. **Audit Policy** (`audit-policy.yaml`)

   - Monitors all security-relevant events
   - Logs RBAC changes and privileged operations
   - Integrates with SIEM systems for security monitoring

6. **Secrets Management** (`secrets-management.yaml`)
   - Securely manages sensitive configuration values
   - Integrates with external secret stores (AWS Secrets Manager)
   - Enforces strict access controls

## Implementation Order

For best results, implement these components in the following order:

1. RBAC Configuration
2. Pod Security Standards
3. TLS Policy
4. Secrets Management
5. Image Security Policy
6. Audit Policy

## Prerequisites

- Kubernetes 1.22+
- Istio Service Mesh (for mTLS)
- OPA Gatekeeper (for admission control)
- cert-manager (for certificate management)
- AWS EKS or similar managed Kubernetes service

## Implementation Instructions

### 1. Install Required Operators

```bash
# Install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
./bin/istioctl install --set profile=demo -y

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

# Install OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.7/deploy/gatekeeper.yaml
```

### 2. Create Namespace with Security Labels

```bash
kubectl create namespace prism-platform

kubectl label namespace prism-platform \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### 3. Apply Security Components

```bash
# Apply RBAC configuration
kubectl apply -f kubernetes/security/rbac-configuration.yaml

# Apply security context defaults
kubectl apply -f kubernetes/security/security-context-defaults.yaml

# Apply TLS policy
kubectl apply -f kubernetes/security/cluster-tls-policy.yaml

# Apply secrets management
kubectl apply -f kubernetes/security/secrets-management.yaml

# Apply image security policy
kubectl apply -f kubernetes/security/image-security-policy.yaml

# Apply audit policy
# Note: This requires additional configuration on the Kubernetes API server
kubectl apply -f kubernetes/security/audit-policy.yaml
```

### 4. Verify Implementation

```bash
# Verify RBAC configuration
kubectl get roles,rolebindings,clusterroles,clusterrolebindings -n prism-platform

# Verify pod security standards
kubectl get psp
kubectl auth can-i use podsecuritypolicy/prism-platform-restricted

# Verify TLS configuration
kubectl get peerauthentication,destinationrule -n prism-platform

# Verify secrets management
kubectl get secrets -n prism-platform

# Verify image security policy
kubectl get constraints
```

## Security Monitoring

After implementing these security components, set up continuous security monitoring:

1. **Audit Logs**: Forward Kubernetes audit logs to your SIEM system
2. **Container Scanning**: Implement regular vulnerability scanning for running containers
3. **Configuration Drift**: Monitor for unauthorized changes to security configurations
4. **Access Reviews**: Regularly review RBAC permissions and prune unnecessary access

## Regular Security Reviews

Schedule regular security reviews to ensure ongoing compliance:

1. Quarterly review of RBAC permissions
2. Monthly vulnerability scanning of container images
3. Bi-annual penetration testing of the cluster
4. Weekly review of audit logs for suspicious activity

## Additional Resources

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/overview/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- [AWS EKS Security Best Practices](https://aws.github.io/aws-eks-best-practices/security/docs/)
