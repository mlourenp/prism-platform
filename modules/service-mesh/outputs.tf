# Prism Service Mesh Module Outputs

output "istio_namespace" {
  description = "Namespace where Istio is installed"
  value       = kubernetes_namespace.istio_system.metadata[0].name
}

output "istio_version" {
  description = "Version of Istio installed"
  value       = var.istio_version
}

output "mesh_id" {
  description = "Service mesh identifier"
  value       = var.mesh_id
}

output "network_name" {
  description = "Network name for multi-cluster setup"
  value       = var.network_name
}

# Gateway Information
output "ingress_gateway_enabled" {
  description = "Whether ingress gateway is enabled"
  value       = var.enable_ingress_gateway
}

output "ingress_gateway_service_name" {
  description = "Name of the ingress gateway service"
  value       = var.enable_ingress_gateway ? "istio-ingressgateway" : null
}

output "eastwest_gateway_enabled" {
  description = "Whether east-west gateway is enabled"
  value       = var.enable_multi_cluster
}

output "eastwest_gateway_service_name" {
  description = "Name of the east-west gateway service"
  value       = var.enable_multi_cluster ? "istio-eastwestgateway" : null
}

# eBPF Acceleration
output "ebpf_acceleration_enabled" {
  description = "Whether eBPF acceleration with Merbridge is enabled"
  value       = var.enable_ebpf_acceleration
}

output "merbridge_version" {
  description = "Version of Merbridge deployed"
  value       = var.enable_ebpf_acceleration ? var.merbridge_version : null
}

output "cni_mode" {
  description = "CNI mode configured for Merbridge"
  value       = var.enable_ebpf_acceleration ? var.cni_mode : null
}

# Security Configuration
output "mtls_mode" {
  description = "mTLS mode configured for the mesh"
  value       = var.mtls_mode
}

output "peer_authentication_name" {
  description = "Name of the default peer authentication policy"
  value       = "default"
}

# Observability Configuration
output "telemetry_enabled" {
  description = "Whether telemetry collection is enabled"
  value       = var.enable_telemetry
}

output "tracing_enabled" {
  description = "Whether distributed tracing is enabled"
  value       = var.enable_tracing
}

output "tracing_sampling_rate" {
  description = "Sampling rate for distributed tracing"
  value       = var.tracing_sampling_rate
}

output "access_logs_enabled" {
  description = "Whether access logs are enabled"
  value       = var.enable_access_logs
}

# Helm Release Information
output "helm_releases" {
  description = "Information about deployed Helm releases"
  value = {
    istio_base = {
      name      = helm_release.istio_base.name
      chart     = helm_release.istio_base.chart
      version   = helm_release.istio_base.version
      namespace = helm_release.istio_base.namespace
      status    = helm_release.istio_base.status
    }
    istiod = {
      name      = helm_release.istiod.name
      chart     = helm_release.istiod.chart
      version   = helm_release.istiod.version
      namespace = helm_release.istiod.namespace
      status    = helm_release.istiod.status
    }
    ingress_gateway = var.enable_ingress_gateway ? {
      name      = helm_release.istio_ingress[0].name
      chart     = helm_release.istio_ingress[0].chart
      version   = helm_release.istio_ingress[0].version
      namespace = helm_release.istio_ingress[0].namespace
      status    = helm_release.istio_ingress[0].status
    } : null
    eastwest_gateway = var.enable_multi_cluster ? {
      name      = helm_release.istio_eastwest[0].name
      chart     = helm_release.istio_eastwest[0].chart
      version   = helm_release.istio_eastwest[0].version
      namespace = helm_release.istio_eastwest[0].namespace
      status    = helm_release.istio_eastwest[0].status
    } : null
  }
}

# Service Mesh Configuration for Other Modules
output "service_mesh_config" {
  description = "Service mesh configuration for use by other modules"
  value = {
    enabled                = true
    namespace             = kubernetes_namespace.istio_system.metadata[0].name
    version               = var.istio_version
    mesh_id               = var.mesh_id
    network_name          = var.network_name
    mtls_mode             = var.mtls_mode
    ebpf_acceleration     = var.enable_ebpf_acceleration
    multi_cluster_enabled = var.enable_multi_cluster
    telemetry_enabled     = var.enable_telemetry
    tracing_enabled       = var.enable_tracing
    ingress_gateway = var.enable_ingress_gateway ? {
      enabled      = true
      service_name = "istio-ingressgateway"
      namespace    = kubernetes_namespace.istio_system.metadata[0].name
    } : null
    eastwest_gateway = var.enable_multi_cluster ? {
      enabled      = true
      service_name = "istio-eastwestgateway"
      namespace    = kubernetes_namespace.istio_system.metadata[0].name
    } : null
  }
}

# Integration Points
output "istio_injection_label" {
  description = "Label to enable Istio injection in namespaces"
  value       = "istio-injection=enabled"
}

output "pilot_discovery_address" {
  description = "Address of Istio pilot discovery service"
  value       = "istiod.${kubernetes_namespace.istio_system.metadata[0].name}.svc.cluster.local:15010"
}

output "webhook_config_name" {
  description = "Name of Istio admission webhook configuration"
  value       = "istio-sidecar-injector"
} 