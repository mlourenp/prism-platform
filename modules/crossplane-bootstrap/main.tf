# Crossplane Bootstrap Module - Based on Existing Platform Patterns
# Installs Crossplane and configures multi-cloud providers using production-ready patterns

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Note: Management cluster is created in main.tf - this module assumes it exists
# and connects to it via Kubernetes and Helm providers

# Create Crossplane system namespace
resource "kubernetes_namespace" "crossplane_system" {
  metadata {
    name = var.kubernetes_namespace
    labels = {
      "prism.io/managed-by" = "crossplane-bootstrap"
      "prism.io/version"    = var.crossplane_version
    }
  }
}

# Install Crossplane via Helm
resource "helm_release" "crossplane" {
  name       = "crossplane"
  repository = "https://charts.crossplane.io/stable"
  chart      = "crossplane"
  version    = var.crossplane_version
  namespace  = kubernetes_namespace.crossplane_system.metadata[0].name

  set {
    name  = "resourcesCrossplane.limits.cpu"
    value = var.crossplane_resources.limits.cpu
  }
  
  set {
    name  = "resourcesCrossplane.limits.memory"
    value = var.crossplane_resources.limits.memory
  }
  
  set {
    name  = "resourcesCrossplane.requests.cpu"
    value = var.crossplane_resources.requests.cpu
  }
  
  set {
    name  = "resourcesCrossplane.requests.memory"
    value = var.crossplane_resources.requests.memory
  }
}

# Install Crossplane using existing Crossplane definitions
resource "kubernetes_manifest" "crossplane_providers" {
  for_each = fileset("${path.module}/../../platform/definitions/crossplane", "*.yaml")
  
  depends_on = [helm_release.crossplane]
  
  manifest = yamldecode(templatefile(
    "${path.module}/../../platform/definitions/crossplane/${each.value}",
    {
      aws_region            = var.aws_region
      gcp_project_id        = var.gcp_project_id
      azure_subscription_id = var.azure_subscription_id
    }
  ))
}

# Create generalized cell definitions (not CD-specific)
resource "kubernetes_manifest" "cell_definitions" {
  for_each = {
    logic        = "logic-cell-composition.yaml"
    channel      = "channel-cell-composition.yaml"
    security     = "security-cell-composition.yaml"
    observability = "observability-cell-composition.yaml"
    external     = "external-cell-composition.yaml"
    data         = "data-cell-composition.yaml"
    integration  = "integration-cell-composition.yaml"
    legacy       = "legacy-cell-composition.yaml"
  }
  
  depends_on = [kubernetes_manifest.crossplane_providers]
  
  manifest = yamldecode(file(
    "${path.module}/../../platform/definitions/cells/${each.key}/${each.value}"
  ))
}

# Create composite resource definition for generic cells
resource "kubernetes_manifest" "cell_crd" {
  depends_on = [helm_release.crossplane]
  
  manifest = {
    apiVersion = "apiextensions.crossplane.io/v1"
    kind       = "CompositeResourceDefinition"
    metadata = {
      name = "cells.prism.io"
      labels = {
        "prism.io/managed-by" = "crossplane-bootstrap"
      }
    }
    spec = {
      group = "prism.io"
      names = {
        kind   = "Cell"
        plural = "cells"
      }
      versions = [{
        name    = "v1alpha1"
        served  = true
        referenceable = true
        schema = {
          openAPIV3Schema = {
            type = "object"
            properties = {
              spec = {
                type = "object"
                properties = {
                  cellId = {
                    type = "string"
                    description = "Unique identifier for the cell"
                  }
                  cellType = {
                    type = "string"
                    enum = ["logic", "channel", "security", "observability", "external", "data", "integration", "legacy"]
                    description = "Type of cell to create"
                  }
                  resources = {
                    type = "object"
                    properties = {
                      cpu = {
                        type = "string"
                        default = "1000m"
                      }
                      memory = {
                        type = "string"
                        default = "2Gi"
                      }
                    }
                  }
                  provider = {
                    type = "string"
                    enum = ["aws", "gcp", "azure", "oracle", "ibm", "baremetal"]
                    description = "Cloud provider for the cell"
                  }
                  region = {
                    type = "string"
                    description = "Cloud provider region"
                  }
                }
                required = ["cellId", "cellType", "provider"]
              }
              status = {
                type = "object"
                properties = {
                  conditions = {
                    type = "array"
                    items = {
                      type = "object"
                    }
                  }
                }
              }
            }
          }
        }
      }]
    }
  }
}

# Output information for other modules
locals {
  crossplane_namespace = "crossplane-system"
  enabled_providers = compact([
    var.aws_region != "" ? "aws" : "",
    var.gcp_project_id != "" ? "gcp" : "",
    var.azure_subscription_id != "" ? "azure" : "",
    var.oci_tenancy_ocid != "" ? "oci" : "",
    var.ibm_api_key != "" ? "ibm" : ""
  ])
} 