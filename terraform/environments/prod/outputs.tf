output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.rg.name
}

output "keyvault_name" {
  description = "Name of the Key Vault"
  value       = data.azurerm_key_vault.kv.name
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.aks.storage_account_name
}

output "kube_config" {
  description = "Kubernetes configuration"
  value       = module.aks.kube_config
  sensitive   = true
}
