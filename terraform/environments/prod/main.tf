terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "owncloud-rg-prod"
    storage_account_name = "owncloudtfstateprod"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

# Reference to existing resource group
data "azurerm_resource_group" "rg" {
  name = "owncloud-rg-prod"
}

# Reference to existing Key Vault
data "azurerm_key_vault" "kv" {
  name                = "owncloudkvprod"
  resource_group_name = data.azurerm_resource_group.rg.name
}

module "aks" {
  source = "../../modules/aks"

  cluster_name         = "owncloud-aks-prod"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  dns_prefix           = "owncloud-prod"
  kubernetes_version   = var.kubernetes_version
  node_count           = var.node_count
  vm_size              = var.vm_size
  keyvault_id          = data.azurerm_key_vault.kv.id
  storage_account_name = "owncloudstorageprod"

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    Project     = "ownCloud-OCIS"
  }
}

# Create a secret in Key Vault for storage account key
resource "azurerm_key_vault_secret" "storage_key" {
  name         = "storage-account-key"
  value        = module.aks.storage_account_key
  key_vault_id = data.azurerm_key_vault.kv.id
}

# Create a secret in Key Vault for storage account name
resource "azurerm_key_vault_secret" "storage_name" {
  name         = "storage-account-name"
  value        = module.aks.storage_account_name
  key_vault_id = data.azurerm_key_vault.kv.id
}
