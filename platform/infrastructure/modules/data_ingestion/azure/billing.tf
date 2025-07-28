variable "storage_account_name" {
  description = "The name of the Azure Storage Account where cost exports are stored."
  type        = string
}

variable "container_name" {
  description = "The name of the Blob Container within the Storage Account where cost exports are stored."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group where the Storage Account resides."
  type        = string
}

variable "principal_id" {
  description = "The ID of the Azure AD principal (e.g., Managed Identity, Service Principal) that needs access to read the cost exports."
  type        = string
}

variable "role_definition_name" {
  description = "The name of the role to assign (e.g., 'Storage Blob Data Reader')."
  type        = string
  default     = "Storage Blob Data Reader"
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

data "azurerm_storage_account" "cost_export_storage" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

# Role Assignment to allow the principal to read from the specific container
# The scope is down to the container level for least privilege.
# Format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Storage/storageAccounts/{storageAccountName}/blobServices/default/containers/{containerName}
resource "azurerm_role_assignment" "cost_export_container_reader" {
  scope                = "${data.azurerm_storage_account.cost_export_storage.id}/blobServices/default/containers/${var.container_name}"
  role_definition_name = var.role_definition_name
  principal_id         = var.principal_id
  # Skip service principal AAD check if principal_id is for a managed identity
  # For User or Group, this can be true. For Service Principal or Managed Identity, should be false or not set.
  # Defaulting to false as it's safer for non-user principals.
  # Consider making this configurable if various principal types with different needs are common.
  # skip_service_principal_aad_check = false
}

output "role_assignment_id" {
  description = "The ID of the role assignment for the cost export container."
  value       = azurerm_role_assignment.cost_export_container_reader.id
}

output "storage_account_id" {
  description = "The ID of the Azure Storage Account for cost exports."
  value       = data.azurerm_storage_account.cost_export_storage.id
}
