output "telemetry_enabled" {
  description = "Whether telemetry is enabled"
  value       = var.enable_telemetry
}

output "cluster_id" {
  description = "Unique cluster identifier used for telemetry"
  value       = local.cluster_id
}

output "privacy_level" {
  description = "Current privacy level configuration"
  value       = var.privacy_level
}

output "telemetry_endpoint" {
  description = "Telemetry collection endpoint"
  value       = var.telemetry_endpoint
}

output "namespace" {
  description = "Namespace where telemetry agent is deployed"
  value       = var.namespace
}

output "service_name" {
  description = "Name of the telemetry agent service"
  value       = var.enable_telemetry ? kubernetes_service.telemetry_agent[0].metadata[0].name : null
}

output "service_port" {
  description = "Port of the telemetry agent service"
  value       = var.enable_telemetry ? 8080 : null
}

output "metrics_port" {
  description = "Port for Prometheus metrics"
  value       = var.enable_telemetry ? 9090 : null
}

output "config_map_name" {
  description = "Name of the telemetry configuration ConfigMap"
  value       = kubernetes_config_map.telemetry_config.metadata[0].name
}

output "service_account_name" {
  description = "Name of the telemetry agent service account"
  value       = kubernetes_service_account.telemetry_agent.metadata[0].name
}

output "privacy_configuration" {
  description = "Current privacy configuration settings"
  value = {
    level                        = var.privacy_level
    collect_cluster_info         = local.current_privacy_config.collect_cluster_info
    collect_node_metrics         = local.current_privacy_config.collect_node_metrics
    collect_resource_usage       = local.current_privacy_config.collect_resource_usage
    collect_workload_types       = local.current_privacy_config.collect_workload_types
    collect_network_policies     = local.current_privacy_config.collect_network_policies
    collect_performance_metrics  = local.current_privacy_config.collect_performance_metrics
    anonymize_data              = local.current_privacy_config.anonymize_data
    hash_identifiers            = local.current_privacy_config.hash_identifiers
  }
}

output "data_collection_summary" {
  description = "Summary of what data is being collected"
  value = {
    infrastructure_metrics = var.enable_telemetry && local.current_privacy_config.collect_cluster_info
    resource_usage        = var.enable_telemetry && local.current_privacy_config.collect_resource_usage
    workload_information  = var.enable_telemetry && local.current_privacy_config.collect_workload_types
    network_policies      = var.enable_telemetry && local.current_privacy_config.collect_network_policies
    performance_metrics   = var.enable_telemetry && local.current_privacy_config.collect_performance_metrics
    anonymized           = local.current_privacy_config.anonymize_data
  }
}

output "management_commands" {
  description = "Commands for managing the telemetry agent"
  value = {
    enable_telemetry = "kubectl patch configmap ${kubernetes_config_map.telemetry_config.metadata[0].name} -n ${var.namespace} --patch '{\"data\":{\"enabled\":\"true\"}}'"
    disable_telemetry = "kubectl patch configmap ${kubernetes_config_map.telemetry_config.metadata[0].name} -n ${var.namespace} --patch '{\"data\":{\"enabled\":\"false\"}}'"
    restart_agent = var.enable_telemetry ? "kubectl rollout restart deployment/${kubernetes_deployment.telemetry_agent[0].metadata[0].name} -n ${var.namespace}" : "Telemetry agent not deployed"
    view_logs = var.enable_telemetry ? "kubectl logs -n ${var.namespace} deployment/${kubernetes_deployment.telemetry_agent[0].metadata[0].name}" : "Telemetry agent not deployed"
    check_status = "kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=telemetry-agent"
  }
}

output "privacy_compliance" {
  description = "Privacy compliance information"
  value = {
    gdpr_compliant    = true
    data_minimization = local.current_privacy_config.anonymize_data
    right_to_erasure  = "DELETE ${var.telemetry_endpoint}/../data/${local.cluster_id}"
    consent_recorded  = true
    opt_out_available = true
  }
}

output "api_endpoints" {
  description = "Available API endpoints for telemetry management"
  value = {
    data_collection    = var.telemetry_endpoint
    recommendations   = "${replace(var.telemetry_endpoint, "/v1/collect", "")}/v1/recommendations/${local.cluster_id}"
    consent_management = "${replace(var.telemetry_endpoint, "/v1/collect", "")}/v1/consent"
    data_deletion     = "${replace(var.telemetry_endpoint, "/v1/collect", "")}/v1/data/${local.cluster_id}"
  }
} 