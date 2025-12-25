# Scripts PowerShell pour gérer les certificats SSL/TLS vers Azure Key Vault
# Usage: .\scripts\manage-certificates.ps1 -Environment [dev|prod] -Action [create|delete|verify]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "delete", "verify")]
    [string]$Action
)

# Configuration
$DevDomain = "dev.lesaiglesbraves.online"
$ProdDomain = "prod.lesaiglesbraves.online"
$DevKeyVault = "owncloudkvdev"
$ProdKeyVault = "owncloudkvprod"

# Fonction pour afficher les messages
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

# Fonction pour vérifier les prérequis
function Test-Prerequisites {
    Write-Info "Vérification des prérequis..."
    
    # Vérifier Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Azure CLI n'est pas installé. Installez-le depuis: https://docs.microsoft.com/cli/azure/install-azure-cli"
    }
    
    # Vérifier OpenSSL
    if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "OpenSSL n'est pas installé. Installez-le depuis: https://slproweb.com/products/Win32OpenSSL.html"
    }
    
    # Vérifier la connexion Azure
    $account = az account show 2>$null
    if (-not $account) {
        Write-ErrorMsg "Vous n'êtes pas connecté à Azure. Exécutez: az login"
    }
    
    Write-Info "✓ Tous les prérequis sont satisfaits"
}

# Fonction pour générer les certificats auto-signés
function New-Certificates {
    param(
        [string]$Domain
    )
    
    Write-Info "Génération des certificats pour le domaine: $Domain"
    
    $CertDir = ".\certs"
    
    # Créer le répertoire pour les certificats
    New-Item -ItemType Directory -Force -Path $CertDir | Out-Null
    
    # Générer le certificat Keycloak
    Write-Info "Génération du certificat Keycloak..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
        -keyout "$CertDir\keycloak-tls-key.pem" `
        -out "$CertDir\keycloak-tls-cert.pem" `
        -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/OU=IT/CN=$Domain" `
        -addext "subjectAltName=DNS:$Domain,DNS:*.$Domain" 2>$null
    
    # Générer le certificat OCIS
    Write-Info "Génération du certificat OCIS..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
        -keyout "$CertDir\ocis-tls-key.pem" `
        -out "$CertDir\ocis-tls-cert.pem" `
        -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/OU=IT/CN=$Domain" `
        -addext "subjectAltName=DNS:$Domain,DNS:*.$Domain" 2>$null
    
    Write-Info "✓ Certificats générés avec succès dans $CertDir"
}

# Fonction pour uploader les certificats vers Azure Key Vault
function Upload-Certificates {
    param(
        [string]$KeyVault
    )
    
    Write-Info "Upload des certificats vers Key Vault: $KeyVault"
    
    $CertDir = ".\certs"
    
    # Upload Keycloak certificate
    Write-Info "Upload du certificat Keycloak..."
    az keyvault certificate import `
        --vault-name $KeyVault `
        --name keycloak-tls-cert `
        --file "$CertDir\keycloak-tls-cert.pem" | Out-Null
    
    az keyvault secret set `
        --vault-name $KeyVault `
        --name keycloak-tls-key `
        --file "$CertDir\keycloak-tls-key.pem" `
        --content-type "application/x-pem-file" | Out-Null
    
    # Upload OCIS certificate
    Write-Info "Upload du certificat OCIS..."
    az keyvault certificate import `
        --vault-name $KeyVault `
        --name ocis-tls-cert `
        --file "$CertDir\ocis-tls-cert.pem" | Out-Null
    
    az keyvault secret set `
        --vault-name $KeyVault `
        --name ocis-tls-key `
        --file "$CertDir\ocis-tls-key.pem" `
        --content-type "application/x-pem-file" | Out-Null
    
    Write-Info "✓ Certificats uploadés avec succès"
    
    # Nettoyer les fichiers temporaires
    Remove-Item -Recurse -Force $CertDir
    Write-Info "✓ Fichiers temporaires nettoyés"
}

# Fonction pour supprimer les certificats d'Azure Key Vault
function Remove-Certificates {
    param(
        [string]$KeyVault
    )
    
    Write-Warn "Suppression des certificats du Key Vault: $KeyVault"
    
    # Supprimer les certificats Keycloak
    az keyvault certificate delete `
        --vault-name $KeyVault `
        --name keycloak-tls-cert 2>$null | Out-Null
    
    az keyvault secret delete `
        --vault-name $KeyVault `
        --name keycloak-tls-key 2>$null | Out-Null
    
    # Supprimer les certificats OCIS
    az keyvault certificate delete `
        --vault-name $KeyVault `
        --name ocis-tls-cert 2>$null | Out-Null
    
    az keyvault secret delete `
        --vault-name $KeyVault `
        --name ocis-tls-key 2>$null | Out-Null
    
    Write-Info "✓ Certificats supprimés"
}

# Fonction pour vérifier les certificats dans Azure Key Vault
function Test-Certificates {
    param(
        [string]$KeyVault
    )
    
    Write-Info "Vérification des certificats dans Key Vault: $KeyVault"
    
    Write-Host "`n=== Certificats ===" -ForegroundColor Cyan
    az keyvault certificate list `
        --vault-name $KeyVault `
        --query "[?starts_with(name, 'keycloak-tls') || starts_with(name, 'ocis-tls')].{Name:name, Enabled:attributes.enabled, Expires:attributes.expires}" `
        --output table
    
    Write-Host "`n=== Secrets (Clés privées) ===" -ForegroundColor Cyan
    az keyvault secret list `
        --vault-name $KeyVault `
        --query "[?starts_with(name, 'keycloak-tls') || starts_with(name, 'ocis-tls')].{Name:name, Enabled:attributes.enabled, Expires:attributes.expires}" `
        --output table
}

# Script principal
Write-Host "`n=== Gestion des Certificats SSL/TLS ===" -ForegroundColor Cyan

# Définir les variables selon l'environnement
$Domain = if ($Environment -eq "dev") { $DevDomain } else { $ProdDomain }
$KeyVault = if ($Environment -eq "dev") { $DevKeyVault } else { $ProdKeyVault }

Write-Info "Environnement: $Environment"
Write-Info "Domaine: $Domain"
Write-Info "Key Vault: $KeyVault"
Write-Host ""

# Vérifier les prérequis
Test-Prerequisites

# Exécuter l'action demandée
switch ($Action) {
    "create" {
        New-Certificates -Domain $Domain
        Upload-Certificates -KeyVault $KeyVault
        Test-Certificates -KeyVault $KeyVault
        Write-Info "✓ Création des certificats terminée avec succès!"
    }
    "delete" {
        $confirmation = Read-Host "Êtes-vous sûr de vouloir supprimer les certificats? (y/N)"
        if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
            Remove-Certificates -KeyVault $KeyVault
            Write-Info "✓ Suppression des certificats terminée"
        } else {
            Write-Info "Opération annulée"
        }
    }
    "verify" {
        Test-Certificates -KeyVault $KeyVault
    }
}

Write-Host ""
