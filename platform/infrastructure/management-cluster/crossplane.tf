# Install Crossplane using Helm
resource "helm_release" "crossplane" {
  name       = "crossplane"
  repository = "https://charts.crossplane.io/stable"
  chart      = "crossplane"
  namespace  = var.crossplane_namespace
  version    = var.crossplane_version

  create_namespace = true

  # Basic Crossplane configuration values
  set {
    name  = "metrics.enabled"
    value = "true"
  }

  set {
    name  = "replicas"
    value = "2"  # High availability for management
  }

  # Resource requirements
  set {
    name  = "resourcesCrossplane.limits.cpu"
    value = "1"
  }
  set {
    name  = "resourcesCrossplane.limits.memory"
    value = "1Gi"
  }
  set {
    name  = "resourcesCrossplane.requests.cpu"
    value = "500m"
  }
  set {
    name  = "resourcesCrossplane.requests.memory"
    value = "512Mi"
  }

  # Enable webhooks for validation
  set {
    name  = "webhooks.enabled"
    value = "true"
  }

  # Optional: Configure provider packages caching
  # set {
  #   name  = "packageCache.medium"
  #   value = "EmptyDir"
  # }
  # set {
  #   name  = "packageCache.sizeLimit"
  #   value = "5Mi"
  # }

  depends_on = [module.eks]
}

# Install AWS Provider for Crossplane
resource "kubectl_manifest" "crossplane_aws_provider" {
  yaml_body = <<YAML
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: crossplane/provider-aws:${var.aws_provider_version}
YAML

  depends_on = [helm_release.crossplane]
}

# Install Kubernetes Provider for Crossplane
resource "kubectl_manifest" "crossplane_k8s_provider" {
  yaml_body = <<YAML
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: crossplane/provider-kubernetes:${var.k8s_provider_version}
YAML

  depends_on = [helm_release.crossplane]
}

# Install Helm Provider for Crossplane (for managing Helm releases)
resource "kubectl_manifest" "crossplane_helm_provider" {
  yaml_body = <<YAML
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: crossplane/provider-helm:${var.helm_provider_version}
YAML

  depends_on = [helm_release.crossplane]
}

# Create AWS Provider Config using existing IRSA setup
# Note: We assume the IAM role for Crossplane is already set up
resource "kubectl_manifest" "aws_provider_config" {
  yaml_body = <<YAML
apiVersion: aws.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
YAML

  depends_on = [
    kubectl_manifest.crossplane_aws_provider,
    # Add a wait for the CRD to be available
    null_resource.wait_for_aws_provider_crd
  ]
}

# Create Kubernetes Provider Config for in-cluster access
resource "kubectl_manifest" "k8s_provider_config" {
  yaml_body = <<YAML
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: in-cluster
spec:
  credentials:
    source: InjectedIdentity
YAML

  depends_on = [
    kubectl_manifest.crossplane_k8s_provider,
    # Add a wait for the CRD to be available
    null_resource.wait_for_k8s_provider_crd
  ]
}

# Create Helm Provider Config for in-cluster releases
resource "kubectl_manifest" "helm_provider_config" {
  yaml_body = <<YAML
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: in-cluster
spec:
  credentials:
    source: InjectedIdentity
YAML

  depends_on = [
    kubectl_manifest.crossplane_helm_provider,
    # Add a wait for the CRD to be available
    null_resource.wait_for_helm_provider_crd
  ]
}

# Create namespace for managed resources
resource "kubernetes_namespace" "crossplane_managed" {
  metadata {
    name = "crossplane-managed"

    labels = {
      "app.kubernetes.io/managed-by" = "crossplane"
    }
  }

  depends_on = [helm_release.crossplane]
}

# Add null resources to ensure CRDs are available before trying to create provider configs
resource "null_resource" "wait_for_aws_provider_crd" {
  depends_on = [kubectl_manifest.crossplane_aws_provider]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --for=condition=established crd/providerconfigs.aws.crossplane.io --timeout=180s
    EOT
  }
}

resource "null_resource" "wait_for_k8s_provider_crd" {
  depends_on = [kubectl_manifest.crossplane_k8s_provider]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --for=condition=established crd/providerconfigs.kubernetes.crossplane.io --timeout=180s
    EOT
  }
}

resource "null_resource" "wait_for_helm_provider_crd" {
  depends_on = [kubectl_manifest.crossplane_helm_provider]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --for=condition=established crd/providerconfigs.helm.crossplane.io --timeout=180s
    EOT
  }
}
