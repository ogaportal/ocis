# Script PowerShell simple pour creer et uploader les certificats vers Azure Key Vault
# Usage: .\scripts\create-certificates-simple.ps1 -Environment [dev|prod]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment
)

# Configuration
$DevDomain = "dev.lesaiglesbraves.online"
$ProdDomain = "prod.lesaiglesbraves.online"
$DevKeyVault = "owncloudkvdev"
$ProdKeyVault = "owncloudkvprod"

$Domain = if ($Environment -eq "dev") { $DevDomain } else { $ProdDomain }
$KeyVault = if ($Environment -eq "dev") { $DevKeyVault } else { $ProdKeyVault }

Write-Host "`n=== Generation et Upload des Certificats ===" -ForegroundColor Cyan
Write-Host "Environnement: $Environment" -ForegroundColor Green
Write-Host "Domaine: $Domain" -ForegroundColor Green
Write-Host "Key Vault: $KeyVault" -ForegroundColor Green
Write-Host ""

# Creer le repertoire temporaire
$CertDir = ".\certs-temp"
New-Item -ItemType Directory -Force -Path $CertDir | Out-Null

# Generer les certificats avec OpenSSL (via Git)
$gitBinPath = "C:\Program Files\Git\usr\bin"
$env:Path = "$env:Path;$gitBinPath"

Write-Host "[1/6] Generation du certificat Keycloak..." -ForegroundColor Yellow
& openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
    -keyout "$CertDir\keycloak-tls.key" `
    -out "$CertDir\keycloak-tls.crt" `
    -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/OU=IT/CN=$Domain" `
    -addext "subjectAltName=DNS:$Domain,DNS:*.$Domain" 2>$null

Write-Host "[2/6] Generation du certificat OCIS..." -ForegroundColor Yellow
& openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
    -keyout "$CertDir\ocis-tls.key" `
    -out "$CertDir\ocis-tls.crt" `
    -subj "/C=FR/ST=France/L=Paris/O=OwnCloud/OU=IT/CN=$Domain" `
    -addext "subjectAltName=DNS:$Domain,DNS:*.$Domain" 2>$null

# Creer des fichiers PFX pour Azure Key Vault
Write-Host "[3/6] Creation des fichiers PFX..." -ForegroundColor Yellow

# Keycloak PFX
& openssl pkcs12 -export `
    -out "$CertDir\keycloak-tls.pfx" `
    -inkey "$CertDir\keycloak-tls.key" `
    -in "$CertDir\keycloak-tls.crt" `
    -passout pass: 2>$null

# OCIS PFX
& openssl pkcs12 -export `
    -out "$CertDir\ocis-tls.pfx" `
    -inkey "$CertDir\ocis-tls.key" `
    -in "$CertDir\ocis-tls.crt" `
    -passout pass: 2>$null

Write-Host "[4/6] Upload du certificat Keycloak vers Key Vault..." -ForegroundColor Yellow
az keyvault certificate import `
    --vault-name $KeyVault `
    --name keycloak-tls-cert `
    --file "$CertDir\keycloak-tls.pfx" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK - Certificat Keycloak uploade" -ForegroundColor Green
} else {
    Write-Host "  ERREUR - Echec upload certificat Keycloak" -ForegroundColor Red
}

az keyvault secret set `
    --vault-name $KeyVault `
    --name keycloak-tls-key `
    --file "$CertDir\keycloak-tls.key" `
    --content-type "application/x-pem-file" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK - Cle privee Keycloak uploadee" -ForegroundColor Green
} else {
    Write-Host "  ERREUR - Echec upload cle Keycloak" -ForegroundColor Red
}

Write-Host "[5/6] Upload du certificat OCIS vers Key Vault..." -ForegroundColor Yellow
az keyvault certificate import `
    --vault-name $KeyVault `
    --name ocis-tls-cert `
    --file "$CertDir\ocis-tls.pfx" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK - Certificat OCIS uploade" -ForegroundColor Green
} else {
    Write-Host "  ERREUR - Echec upload certificat OCIS" -ForegroundColor Red
}

az keyvault secret set `
    --vault-name $KeyVault `
    --name ocis-tls-key `
    --file "$CertDir\ocis-tls.key" `
    --content-type "application/x-pem-file" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK - Cle privee OCIS uploadee" -ForegroundColor Green
} else {
    Write-Host "  ERREUR - Echec upload cle OCIS" -ForegroundColor Red
}

# Nettoyage
Write-Host "[6/6] Nettoyage des fichiers temporaires..." -ForegroundColor Yellow
Remove-Item -Recurse -Force $CertDir

Write-Host "`n=== Terminé avec succes! ===" -ForegroundColor Green
Write-Host "`nVerification des certificats dans Key Vault:" -ForegroundColor Cyan
az keyvault certificate list --vault-name $KeyVault --query "[?starts_with(name, 'keycloak-tls') || starts_with(name, 'ocis-tls')].{Name:name, Enabled:attributes.enabled}" --output table
