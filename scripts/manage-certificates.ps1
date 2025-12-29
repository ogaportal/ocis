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

# Fonction pour verifier les prerequis
function Test-Prerequisites {
    Write-Info "Verification des prerequis..."
    
    # Verifier Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Azure CLI n'est pas installe. Installez-le depuis: https://docs.microsoft.com/cli/azure/install-azure-cli"
    }
    
    # Verifier OpenSSL - chercher dans plusieurs emplacements
    $script:opensslCmd = $null
    
    # 1. Chercher dans le PATH
    $script:opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
    
    # 2. Chercher dans Git for Windows
    if (-not $script:opensslCmd) {
        $gitPath = Get-Command git -ErrorAction SilentlyContinue
        if ($gitPath) {
            $gitBinPath = Split-Path -Parent $gitPath.Source
            $gitOpenSSLPath = Join-Path (Split-Path -Parent $gitBinPath) 'usr\bin\openssl.exe'
            if (Test-Path $gitOpenSSLPath) {
                Write-Info "OpenSSL trouve dans Git: $gitOpenSSLPath"
                # Ajouter au PATH pour cette session
                $env:Path = "$env:Path;$(Split-Path -Parent $gitOpenSSLPath)"
                $script:opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
            }
        }
    }
    
    if (-not $script:opensslCmd) {
        Write-ErrorMsg "OpenSSL n'est pas installe. Installez-le depuis: https://slproweb.com/products/Win32OpenSSL.html ou utilisez Git for Windows"
    }
    
    # Verifier la connexion Azure
    $account = az account show 2>$null
    if (-not $account) {
        Write-ErrorMsg "Vous n'etes pas connecte a Azure. Executez: az login"
    }
    
    Write-Info "Tous les prerequis sont satisfaits"
}

# Fonction pour generer les certificats auto-signes
function New-Certificates {
    param(
        [string]$Domain
    )
    
    Write-Info "Generation des certificats pour le domaine: $Domain"
    
    $CertDir = ".\certs"
    
    # Creer le repertoire pour les certificats
    New-Item -ItemType Directory -Force -Path $CertDir | Out-Null
    
    # Generer le certificat Keycloak
    Write-Info "Generation du certificat Keycloak..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
        -keyout "$CertDir\keycloak-tls-key.pem" `
        -out "$CertDir\keycloak-tls-cert.pem" `
        -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/OU=IT/CN=$Domain" `
        -addext "subjectAltName=DNS:$Domain,DNS:*.$Domain" 2>$null
    
    # Generer le certificat OCIS
    Write-Info "Generation du certificat OCIS..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
        -keyout "$CertDir\ocis-tls-key.pem" `
        -out "$CertDir\ocis-tls-cert.pem" `
        -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/OU=IT/CN=$Domain" `
        -addext "subjectAltName=DNS:$Domain,DNS:*.$Domain" 2>$null
    
    Write-Info "Certificats generes avec succes dans $CertDir"
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
    
    Write-Info "Certificats uploades avec succes"
    
    # Nettoyer les fichiers temporaires
    Remove-Item -Recurse -Force $CertDir
    Write-Info "Fichiers temporaires nettoyes"
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
    
    Write-Info "Certificats supprimes"
}

# Fonction pour verifier les certificats dans Azure Key Vault
function Test-Certificates {
    param(
        [string]$KeyVault
    )
    
    Write-Info "Verification des certificats dans Key Vault: $KeyVault"
    
    Write-Host "`n=== Certificats ===" -ForegroundColor Cyan
    az keyvault certificate list `
        --vault-name $KeyVault `
        --query '[?starts_with(name, `keycloak-tls`) || starts_with(name, `ocis-tls`)].{Name:name, Enabled:attributes.enabled, Expires:attributes.expires}' `
        --output table
    
    Write-Host "`n=== Secrets (Clés privées) ===" -ForegroundColor Cyan
    az keyvault secret list `
        --vault-name $KeyVault `
        --query '[?starts_with(name, `keycloak-tls`) || starts_with(name, `ocis-tls`)].{Name:name, Enabled:attributes.enabled, Expires:attributes.expires}' `
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
    'create' {
        New-Certificates -Domain $Domain
        Upload-Certificates -KeyVault $KeyVault
        Test-Certificates -KeyVault $KeyVault
        Write-Info "Creation des certificats terminee avec succes!"
    }
    'delete' {
        $confirmation = Read-Host "Etes-vous sur de vouloir supprimer les certificats? (y/N)"
        if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
            Remove-Certificates -KeyVault $KeyVault
            Write-Info "Suppression des certificats terminee"
        } else {
            Write-Info "Operation annulee"
        }
    }
    'verify' {
        Test-Certificates -KeyVault $KeyVault
    }
}

Write-Host ""
