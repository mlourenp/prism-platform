# Prism eBPF Observability Module Outputs

output "cilium_namespace" {
  description = "Namespace where Cilium is installed"
  value       = kubernetes_namespace.cilium_system.metadata[0].name
}

output "cilium_chart_version" {
  description = "Version of Cilium chart installed"
  value       = var.cilium_chart_version
}

output "cluster_id" {
  description = "Cilium cluster identifier"
  value       = var.cluster_id
}

# Cilium Configuration
output "cilium_enabled" {
  description = "Whether Cilium networking is enabled"
  value       = var.enable_cilium_networking
}

output "policy_enforcement_mode" {
  description = "Policy enforcement mode configured"
  value       = var.policy_enforcement_mode
}

output "encryption_enabled" {
  description = "Whether network encryption is enabled"
  value       = var.enable_encryption
}

output "encryption_type" {
  description = "Type of encryption configured"
  value       = var.enable_encryption ? var.encryption_type : null
}

# Hubble Configuration
output "hubble_enabled" {
  description = "Whether Hubble is enabled"
  value       = var.enable_hubble
}

output "hubble_ui_enabled" {
  description = "Whether Hubble UI is enabled"
  value       = var.enable_hubble_ui
}

output "hubble_ui_service_name" {
  description = "Name of the Hubble UI service"
  value       = var.enable_hubble_ui ? "hubble-ui" : null
}

output "hubble_relay_service_name" {
  description = "Name of the Hubble relay service"
  value       = var.enable_hubble ? "hubble-relay" : null
}

output "hubble_metrics_enabled" {
  description = "Whether Hubble metrics are enabled"
  value       = var.enable_metrics
}

# Tetragon Configuration
output "tetragon_enabled" {
  description = "Whether Tetragon is enabled"
  value       = var.enable_tetragon
}

output "tetragon_version" {
  description = "Version of Tetragon installed"
  value       = var.enable_tetragon ? var.tetragon_version : null
}

output "tetragon_grpc_enabled" {
  description = "Whether Tetragon gRPC API is enabled"
  value       = var.enable_tetragon ? var.enable_tetragon_grpc : null
}

output "tetragon_operator_enabled" {
  description = "Whether Tetragon operator is enabled"
  value       = var.enable_tetragon ? var.enable_tetragon_operator : null
}

# eBPF Features
output "ebpf_features" {
  description = "eBPF features enabled"
  value = {
    masquerade        = var.enable_masquerade
    host_routing      = var.enable_host_routing
    transparent_proxy = var.enable_transparent_proxy
    encryption        = var.enable_encryption
  }
}

# Load Balancer Configuration
output "load_balancer_config" {
  description = "Load balancer configuration"
  value = {
    algorithm = var.load_balancer_algorithm
    mode      = var.load_balancer_mode
  }
}

# Network Policy Information
output "network_policies_enabled" {
  description = "Whether network policies are enabled"
  value       = var.enable_network_policies
}

output "default_deny_policy_created" {
  description = "Whether default deny policy was created"
  value       = var.create_default_deny_policy
}

output "cell_network_policies" {
  description = "Cell network policies created"
  value       = keys(var.cell_network_policies)
}

output "cluster_network_policies" {
  description = "Cluster network policies created"
  value       = keys(var.cluster_network_policies)
}

output "tetragon_tracing_policies" {
  description = "Tetragon tracing policies created"
  value       = var.enable_tetragon ? keys(var.tetragon_tracing_policies) : []
}

# Monitoring Configuration
output "prometheus_metrics_enabled" {
  description = "Whether Prometheus metrics are enabled"
  value       = var.enable_prometheus_metrics
}

output "service_monitor_enabled" {
  description = "Whether ServiceMonitor is enabled"
  value       = var.enable_service_monitor
}

output "service_monitors_created" {
  description = "ServiceMonitors created for monitoring"
  value = {
    cilium = var.enable_service_monitor && var.enable_prometheus_metrics
    hubble = var.enable_service_monitor && var.enable_hubble && var.enable_metrics
  }
}

# Helm Release Information
output "helm_releases" {
  description = "Information about deployed Helm releases"
  value = {
    cilium = {
      name      = helm_release.cilium.name
      chart     = helm_release.cilium.chart
      version   = helm_release.cilium.version
      namespace = helm_release.cilium.namespace
      status    = helm_release.cilium.status
    }
    tetragon = var.enable_tetragon ? {
      name      = helm_release.tetragon[0].name
      chart     = helm_release.tetragon[0].chart
      version   = helm_release.tetragon[0].version
      namespace = helm_release.tetragon[0].namespace
      status    = helm_release.tetragon[0].status
    } : null
  }
}

# eBPF Observability Configuration for Other Modules
output "ebpf_observability_config" {
  description = "eBPF observability configuration for use by other modules"
  value = {
    enabled   = true
    namespace = kubernetes_namespace.cilium_system.metadata[0].name
    
    cilium = {
      enabled               = var.enable_cilium_networking
      version              = var.cilium_chart_version
      cluster_id           = var.cluster_id
      policy_enforcement   = var.policy_enforcement_mode
      encryption_enabled   = var.enable_encryption
      encryption_type      = var.encryption_type
      metrics_enabled      = var.enable_prometheus_metrics
    }
    
    hubble = {
      enabled         = var.enable_hubble
      ui_enabled      = var.enable_hubble_ui
      metrics_enabled = var.enable_metrics
      service_name    = var.enable_hubble ? "hubble-relay" : null
      ui_service_name = var.enable_hubble_ui ? "hubble-ui" : null
    }
    
    tetragon = var.enable_tetragon ? {
      enabled          = true
      version         = var.tetragon_version
      grpc_enabled    = var.enable_tetragon_grpc
      operator_enabled = var.enable_tetragon_operator
      export_stdout   = var.enable_tetragon_stdout
    } : null
    
    network_policies = {
      enabled              = var.enable_network_policies
      default_deny_created = var.create_default_deny_policy
      cell_policies       = keys(var.cell_network_policies)
      cluster_policies    = keys(var.cluster_network_policies)
    }
  }
}

# Integration Points
output "cilium_agent_service_name" {
  description = "Name of the Cilium agent service"
  value       = "cilium"
}

output "cilium_operator_service_name" {
  description = "Name of the Cilium operator service"
  value       = "cilium-operator"
}

output "hubble_grpc_service" {
  description = "Hubble gRPC service information"
  value = var.enable_hubble ? {
    name      = "hubble-relay"
    namespace = kubernetes_namespace.cilium_system.metadata[0].name
    port      = 4245
  } : null
}

output "tetragon_grpc_service" {
  description = "Tetragon gRPC service information"
  value = var.enable_tetragon && var.enable_tetragon_grpc ? {
    name      = "tetragon"
    namespace = kubernetes_namespace.cilium_system.metadata[0].name
    port      = 54321
  } : null
}

# CNI Configuration
output "cni_config" {
  description = "CNI configuration information"
  value = {
    install       = var.install_cni
    chaining_mode = var.cni_chaining_mode
    provider      = var.provider
  }
} 