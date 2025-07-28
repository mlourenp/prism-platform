# Prism eBPF Observability Module
# Deploys Cilium for eBPF networking and Tetragon for runtime security
# Provides network policies, telemetry collection, and security enforcement

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Local variables for configuration
locals {
  name_prefix = var.name_prefix
  common_labels = merge(var.common_tags, {
    "prism.io/component" = "ebpf-observability"
    "prism.io/version"   = "v1.2"
    "app.kubernetes.io/managed-by" = "terraform"
  })
  
  # Cilium configuration based on environment and provider
  cilium_values = {
    cluster = {
      name = "${var.name_prefix}-${var.environment}"
      id   = var.cluster_id
    }
    
    # eBPF configuration
    bpf = {
      masquerade = var.enable_masquerade
      hostRouting = var.enable_host_routing
      preallocateMaps = true
      tproxy = var.enable_transparent_proxy
    }
    
    # IPAM configuration based on cloud provider
    ipam = var.cloud_provider == "aws" ? {
      mode = "eni"
    } : var.cloud_provider == "gcp" ? {
      mode = "kubernetes"
    } : var.cloud_provider == "azure" ? {
      mode = "azure"
    } : {
      mode = "kubernetes"
    }
    
    # Networking configuration
    networking = {
      enable = var.enable_cilium_networking
    }
    
    # Hubble for observability
    hubble = {
      enabled = var.enable_hubble
      listenAddress = ":4244"
      
      relay = {
        enabled = var.enable_hubble
        service = {
          type = "ClusterIP"
        }
      }
      
      ui = {
        enabled = var.enable_hubble_ui
        service = {
          type = var.hubble_ui_service_type
        }
      }
      
      metrics = {
        enabled = var.enable_metrics ? [
          "dns",
          "drop",
          "tcp",
          "flow",
          "port-distribution",
          "icmp",
          "http"
        ] : []
      }
    }
    
    # Operator configuration
    operator = {
      replicas = var.operator_replicas
      resources = var.operator_resources
    }
    
    # Agent configuration
    agent = {
      resources = var.agent_resources
    }
    
    # Encryption
    encryption = {
      enabled = var.enable_encryption
      type = var.encryption_type
    }
    
    # Load balancer configuration
    loadBalancer = {
      algorithm = var.load_balancer_algorithm
      mode = var.load_balancer_mode
    }
    
    # Policy enforcement
    policyEnforcementMode = var.policy_enforcement_mode
    
    # Prometheus metrics
    prometheus = {
      enabled = var.enable_prometheus_metrics
      serviceMonitor = {
        enabled = var.enable_service_monitor
      }
    }
    
    # Cloud provider specific configurations
    k8sServiceHost = var.k8s_service_host
    k8sServicePort = var.k8s_service_port
    
    # CNI configuration
    cni = {
      install = var.install_cni
      chainingMode = var.cni_chaining_mode
    }
  }
  
  # Tetragon configuration
  tetragon_values = {
    # Tetragon agent configuration
    tetragon = {
      enabled = var.enable_tetragon
      image = {
        repository = var.tetragon_image_repository
        tag = var.tetragon_version
      }
      
      # gRPC configuration
      grpc = {
        enabled = var.enable_tetragon_grpc
        address = "localhost:54321"
      }
      
      # Export configuration
      export = {
        allowlist = var.tetragon_export_allowlist
        denylist = var.tetragon_export_denylist
        filenames = var.tetragon_export_filenames
        stdout = {
          enabled = var.enable_tetragon_stdout
        }
      }
      
      # Process filtering
      processFilter = {
        enable = var.enable_process_filter
        filterSpecs = var.process_filter_specs
      }
      
      # Resources
      resources = var.tetragon_resources
    }
    
    # Tetragon operator
    tetragonOperator = {
      enabled = var.enable_tetragon_operator
      image = {
        repository = var.tetragon_operator_image_repository
        tag = var.tetragon_version
      }
      resources = var.tetragon_operator_resources
    }
  }
}

# Create cilium-system namespace
resource "kubernetes_namespace" "cilium_system" {
  metadata {
    name = var.cilium_namespace
    labels = merge(local.common_labels, {
      "name" = var.cilium_namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit" = "privileged"
      "pod-security.kubernetes.io/warn" = "privileged"
    })
  }
}

# Install Cilium
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_chart_version
  namespace  = kubernetes_namespace.cilium_system.metadata[0].name

  values = [yamlencode(local.cilium_values)]

  # Wait for deployment to be ready
  wait = true
  timeout = 600

  depends_on = [kubernetes_namespace.cilium_system]
}

# Install Tetragon for runtime security
resource "helm_release" "tetragon" {
  count = var.enable_tetragon ? 1 : 0
  
  name       = "tetragon"
  repository = "https://helm.cilium.io/"
  chart      = "tetragon"
  version    = var.tetragon_chart_version
  namespace  = kubernetes_namespace.cilium_system.metadata[0].name

  values = [yamlencode(local.tetragon_values)]

  wait = true
  timeout = 300

  depends_on = [helm_release.cilium]
}

# Create network policies for cell communication
resource "kubernetes_manifest" "cell_network_policies" {
  for_each = var.enable_network_policies ? var.cell_network_policies : {}
  
  manifest = {
    apiVersion = "cilium.io/v2"
    kind = "CiliumNetworkPolicy"
    metadata = {
      name = each.key
      namespace = each.value.namespace
      labels = local.common_labels
    }
    spec = each.value.spec
  }

  depends_on = [helm_release.cilium]
}

# Create cluster-wide network policies
resource "kubernetes_manifest" "cluster_network_policies" {
  for_each = var.enable_network_policies ? var.cluster_network_policies : {}
  
  manifest = {
    apiVersion = "cilium.io/v2"
    kind = "CiliumClusterwideNetworkPolicy"
    metadata = {
      name = each.key
      labels = local.common_labels
    }
    spec = each.value
  }

  depends_on = [helm_release.cilium]
}

# Create Tetragon tracing policies
resource "kubernetes_manifest" "tetragon_tracing_policies" {
  for_each = var.enable_tetragon ? var.tetragon_tracing_policies : {}
  
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind = "TracingPolicy"
    metadata = {
      name = each.key
      labels = local.common_labels
    }
    spec = each.value
  }

  depends_on = [helm_release.tetragon]
}

# Service monitor for Cilium metrics
resource "kubernetes_manifest" "cilium_service_monitor" {
  count = var.enable_service_monitor && var.enable_prometheus_metrics ? 1 : 0
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind = "ServiceMonitor"
    metadata = {
      name = "cilium-metrics"
      namespace = kubernetes_namespace.cilium_system.metadata[0].name
      labels = merge(local.common_labels, {
        "app.kubernetes.io/name" = "cilium"
      })
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "cilium-agent"
        }
      }
      endpoints = [
        {
          port = "prometheus"
          interval = "30s"
          path = "/metrics"
        }
      ]
    }
  }

  depends_on = [helm_release.cilium]
}

# Service monitor for Hubble metrics
resource "kubernetes_manifest" "hubble_service_monitor" {
  count = var.enable_service_monitor && var.enable_hubble && var.enable_metrics ? 1 : 0
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind = "ServiceMonitor"
    metadata = {
      name = "hubble-metrics"
      namespace = kubernetes_namespace.cilium_system.metadata[0].name
      labels = merge(local.common_labels, {
        "app.kubernetes.io/name" = "hubble"
      })
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "hubble"
        }
      }
      endpoints = [
        {
          port = "hubble-metrics"
          interval = "30s"
          path = "/metrics"
        }
      ]
    }
  }

  depends_on = [helm_release.cilium]
}

# Create Cilium ingress for Hubble UI
resource "kubernetes_manifest" "hubble_ingress" {
  count = var.enable_hubble_ui && var.enable_hubble_ingress ? 1 : 0
  
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind = "Ingress"
    metadata = {
      name = "hubble-ui"
      namespace = kubernetes_namespace.cilium_system.metadata[0].name
      labels = local.common_labels
      annotations = var.hubble_ingress_annotations
    }
    spec = {
      ingressClassName = var.hubble_ingress_class_name
      rules = [
        {
          host = var.hubble_ui_hostname
          http = {
            paths = [
              {
                path = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "hubble-ui"
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
      tls = var.enable_hubble_tls ? [
        {
          hosts = [var.hubble_ui_hostname]
          secretName = var.hubble_tls_secret_name
        }
      ] : []
    }
  }

  depends_on = [helm_release.cilium]
}

# Create default deny-all network policy template
resource "kubernetes_manifest" "default_deny_policy_template" {
  count = var.create_default_deny_policy ? 1 : 0
  
  manifest = {
    apiVersion = "cilium.io/v2"
    kind = "CiliumClusterwideNetworkPolicy"
    metadata = {
      name = "default-deny-all"
      labels = local.common_labels
    }
    spec = {
      description = "Default deny all traffic"
      endpointSelector = {}
      ingress = []
      egress = [
        {
          # Allow DNS
          toEndpoints = [
            {
              matchLabels = {
                "k8s:io.kubernetes.pod.namespace" = "kube-system"
                "k8s:k8s-app" = "kube-dns"
              }
            }
          ]
          toPorts = [
            {
              ports = [
                {
                  port = "53"
                  protocol = "UDP"
                }
              ]
            }
          ]
        },
        {
          # Allow HTTPS for external dependencies
          toFQDNs = [
            {
              matchName = "kubernetes.default.svc.cluster.local"
            }
          ]
          toPorts = [
            {
              ports = [
                {
                  port = "443"
                  protocol = "TCP"
                }
              ]
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.cilium]
} 