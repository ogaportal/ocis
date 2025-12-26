terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                        = "default"
    node_count                  = var.node_count
    vm_size                     = var.vm_size
    os_disk_size_gb             = 30
    type                        = "VirtualMachineScaleSets"
    enable_auto_scaling         = false
    temporary_name_for_rotation = "tempnp"
    max_surge                   = 0
    max_unavailable             = 1
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "calico"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = var.tags
}

# Grant AKS access to Key Vault
resource "azurerm_role_assignment" "aks_keyvault" {
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = var.keyvault_id
}

# Grant AKS access to Storage Account
resource "azurerm_role_assignment" "aks_storage" {
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = azurerm_storage_account.ocis.id
}

resource "azurerm_storage_account" "ocis" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  
  blob_properties {
    versioning_enabled = true
  }

  tags = var.tags
}

resource "azurerm_storage_container" "ocis_data" {
  name                  = "ocis-data"
  storage_account_name  = azurerm_storage_account.ocis.name
  container_access_type = "private"
}
