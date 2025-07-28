# Prism Service Mesh Module
# Deploys Istio service mesh with eBPF acceleration via Merbridge
# Supports multi-cloud and bare-metal deployments

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
    "prism.io/component" = "service-mesh"
    "prism.io/version"   = "v1.2"
    "app.kubernetes.io/managed-by" = "terraform"
  })
  
  # Istio configuration based on environment
  istio_values = {
    global = {
      meshID = var.mesh_id
      network = var.network_name
      hub = var.istio_hub
      tag = var.istio_version
      
      # Multi-cluster configuration
      meshNetworks = var.enable_multi_cluster ? {
        for network in var.mesh_networks : network.name => {
          endpoints = [
            {
              fromRegistry = network.registry
            }
          ]
          gateways = [
            {
              service = "istio-eastwestgateway"
              port = 15443
            }
          ]
        }
      } : {}
    }
    
    pilot = {
      env = {
        # Enable cross-cluster workload discovery
        ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY = var.enable_multi_cluster
        # Optimize for eBPF acceleration
        PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION = true
        # Enhanced observability
        PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_DISCOVERY = true
      }
      
      # Resource configuration based on cluster size
      resources = {
        requests = {
          cpu = var.pilot_resources.cpu_request
          memory = var.pilot_resources.memory_request
        }
        limits = {
          cpu = var.pilot_resources.cpu_limit
          memory = var.pilot_resources.memory_limit
        }
      }
    }
    
    # Ingress gateway configuration
    gateways = {
      istio-ingressgateway = {
        enabled = var.enable_ingress_gateway
        service = {
          type = var.ingress_gateway_type
          loadBalancerSourceRanges = var.ingress_source_ranges
        }
        
        # Multi-cloud load balancer annotations
        serviceAnnotations = var.cloud_provider == "aws" ? {
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "tcp"
        } : var.cloud_provider == "gcp" ? {
          "cloud.google.com/neg" = jsonencode({ ingress = true })
          "cloud.google.com/backend-config" = jsonencode({ 
            default = "istio-backendconfig" 
          })
        } : var.cloud_provider == "azure" ? {
          "service.beta.kubernetes.io/azure-load-balancer-internal" = "false"
        } : {}
      }
      
      # East-west gateway for multi-cluster
      istio-eastwestgateway = var.enable_multi_cluster ? {
        enabled = true
        service = {
          type = "LoadBalancer"
          ports = [
            {
              port = 15021
              targetPort = 15021
              name = "status-port"
            },
            {
              port = 15443
              targetPort = 15443
              name = "tls"
            }
          ]
        }
      } : null
    }
    
    # eBPF acceleration with Merbridge
    values = var.enable_ebpf_acceleration ? {
      pilot = {
        env = {
          # Enable eBPF mode for CNI
          PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION = true
        }
      }
    } : {}
  }
}

# Create istio-system namespace
resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = var.istio_namespace
    labels = merge(local.common_labels, {
      "istio-injection" = "disabled"
      "name" = var.istio_namespace
    })
  }
}

# Install Istio base (CRDs and cluster-wide resources)
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_chart_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      global = {
        istioNamespace = var.istio_namespace
        meshID = var.mesh_id
        network = var.network_name
      }
    })
  ]

  depends_on = [kubernetes_namespace.istio_system]
}

# Install Istio discovery (control plane)
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_chart_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [yamlencode(local.istio_values)]

  depends_on = [helm_release.istio_base]
}

# Install Istio ingress gateway
resource "helm_release" "istio_ingress" {
  count = var.enable_ingress_gateway ? 1 : 0
  
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_chart_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      service = {
        type = var.ingress_gateway_type
        annotations = local.istio_values.gateways.istio-ingressgateway.serviceAnnotations
      }
      resources = var.gateway_resources
    })
  ]

  depends_on = [helm_release.istiod]
}

# Install east-west gateway for multi-cluster
resource "helm_release" "istio_eastwest" {
  count = var.enable_multi_cluster ? 1 : 0
  
  name       = "istio-eastwestgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_chart_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      service = local.istio_values.gateways.istio-eastwestgateway.service
      resources = var.gateway_resources
    })
  ]

  depends_on = [helm_release.istiod]
}

# Deploy Merbridge for eBPF acceleration (if enabled)
resource "kubernetes_manifest" "merbridge_daemonset" {
  count = var.enable_ebpf_acceleration ? 1 : 0
  
  manifest = {
    apiVersion = "apps/v1"
    kind = "DaemonSet"
    metadata = {
      name = "merbridge"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
      labels = merge(local.common_labels, {
        "app" = "merbridge"
      })
    }
    spec = {
      selector = {
        matchLabels = {
          app = "merbridge"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "merbridge"
          }
        }
        spec = {
          hostNetwork = true
          hostPID = true
          serviceAccountName = "merbridge"
          priorityClassName = "system-node-critical"
          
          containers = [
            {
              name = "merbridge"
              image = "${var.merbridge_image}:${var.merbridge_version}"
              imagePullPolicy = "IfNotPresent"
              
              securityContext = {
                privileged = true
                capabilities = {
                  add = ["SYS_ADMIN", "SYS_RESOURCE", "NET_ADMIN"]
                }
              }
              
              env = [
                {
                  name = "MODE"
                  value = "istio"
                },
                {
                  name = "ISTIO_NAMESPACE"
                  value = var.istio_namespace
                },
                {
                  name = "CNI_MODE"
                  value = var.cni_mode
                }
              ]
              
              volumeMounts = [
                {
                  name = "host-proc"
                  mountPath = "/host/proc"
                  readOnly = true
                },
                {
                  name = "host-sys"
                  mountPath = "/host/sys"
                  readOnly = true
                },
                {
                  name = "host-var-run"
                  mountPath = "/host/var/run"
                }
              ]
              
              resources = var.merbridge_resources
            }
          ]
          
          volumes = [
            {
              name = "host-proc"
              hostPath = {
                path = "/proc"
              }
            },
            {
              name = "host-sys"
              hostPath = {
                path = "/sys"
              }
            },
            {
              name = "host-var-run"
              hostPath = {
                path = "/var/run"
              }
            }
          ]
          
          nodeSelector = var.merbridge_node_selector
          tolerations = var.merbridge_tolerations
        }
      }
    }
  }

  depends_on = [
    helm_release.istiod,
    kubernetes_service_account.merbridge
  ]
}

# Service account for Merbridge
resource "kubernetes_service_account" "merbridge" {
  count = var.enable_ebpf_acceleration ? 1 : 0
  
  metadata {
    name = "merbridge"
    namespace = kubernetes_namespace.istio_system.metadata[0].name
    labels = local.common_labels
  }
}

# ClusterRole for Merbridge
resource "kubernetes_cluster_role" "merbridge" {
  count = var.enable_ebpf_acceleration ? 1 : 0
  
  metadata {
    name = "merbridge"
    labels = local.common_labels
  }

  rule {
    api_groups = [""]
    resources = ["pods", "nodes", "services", "endpoints"]
    verbs = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.istio.io"]
    resources = ["*"]
    verbs = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding for Merbridge
resource "kubernetes_cluster_role_binding" "merbridge" {
  count = var.enable_ebpf_acceleration ? 1 : 0
  
  metadata {
    name = "merbridge"
    labels = local.common_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = kubernetes_cluster_role.merbridge[0].metadata[0].name
  }

  subject {
    kind = "ServiceAccount"
    name = kubernetes_service_account.merbridge[0].metadata[0].name
    namespace = kubernetes_namespace.istio_system.metadata[0].name
  }
}

# PeerAuthentication for mTLS
resource "kubernetes_manifest" "default_peer_authentication" {
  manifest = {
    apiVersion = "security.istio.io/v1beta1"
    kind = "PeerAuthentication"
    metadata = {
      name = "default"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
      labels = local.common_labels
    }
    spec = {
      mtls = {
        mode = var.mtls_mode
      }
    }
  }

  depends_on = [helm_release.istiod]
}

# Telemetry configuration for observability
resource "kubernetes_manifest" "default_telemetry" {
  count = var.enable_telemetry ? 1 : 0
  
  manifest = {
    apiVersion = "telemetry.istio.io/v1alpha1"
    kind = "Telemetry"
    metadata = {
      name = "default"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
      labels = local.common_labels
    }
    spec = {
      metrics = [
        {
          providers = [
            {
              name = "prometheus"
            }
          ]
        }
      ]
      tracing = var.enable_tracing ? [
        {
          providers = [
            {
              name = "jaeger"
            }
          ]
        }
      ] : []
    }
  }

  depends_on = [helm_release.istiod]
} 