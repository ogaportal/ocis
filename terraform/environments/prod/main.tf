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
    storage_account_name = "owncloudsastateprod"
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

# Azure Database for PostgreSQL
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "owncloud-db-prod"
  resource_group_name    = data.azurerm_resource_group.rg.name
  location               = var.location
  version                = "15"
  
  administrator_login    = "owncloudadmin"
  administrator_password = random_password.db_password.result
  
  sku_name   = "B_Standard_B2ms"  # Burstable tier, larger for prod
  storage_mb = 65536              # 64 GB
  
  backup_retention_days             = 30
  geo_redundant_backup_enabled      = true
  publicly_accessible              = false
  ssl_enforcement_enabled           = true
  ssl_minimum_tls_version_enforced  = "TLSEnforcementDisabled"
  
  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    Project     = "ownCloud-OCIS"
  }
}

# Random password for PostgreSQL admin
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# PostgreSQL Database for Keycloak
resource "azurerm_postgresql_flexible_server_database" "keycloak" {
  name            = "keycloak"
  server_id       = azurerm_postgresql_flexible_server.postgres.id
  charset         = "UTF8"
  collation       = "en_US.utf8"
}

# PostgreSQL Database for OCIS
resource "azurerm_postgresql_flexible_server_database" "ocis" {
  name            = "ocis"
  server_id       = azurerm_postgresql_flexible_server.postgres.id
  charset         = "UTF8"
  collation       = "en_US.utf8"
}

# Firewall rule to allow AKS cluster to connect
resource "azurerm_postgresql_flexible_server_firewall_rule" "aks" {
  name             = "allow-aks"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Store DB password in Key Vault
resource "azurerm_key_vault_secret" "db_password" {
  name         = "postgres-admin-password"
  value        = random_password.db_password.result
  key_vault_id = data.azurerm_key_vault.kv.id
}

# Store DB host in Key Vault
resource "azurerm_key_vault_secret" "db_host" {
  name         = "postgres-host"
  value        = azurerm_postgresql_flexible_server.postgres.fqdn
  key_vault_id = data.azurerm_key_vault.kv.id
}

# Store DB username in Key Vault
resource "azurerm_key_vault_secret" "db_username" {
  name         = "postgres-admin-user"
  value        = azurerm_postgresql_flexible_server.postgres.administrator_login
  key_vault_id = data.azurerm_key_vault.kv.id
}
