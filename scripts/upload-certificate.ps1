# Script simplifié pour uploader un certificat Let's Encrypt généré manuellement
# Usage: .\scripts\upload-certificate.ps1 -CertPath "C:\path\to\cert" -KeyVaultName owncloudkvprod

param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName
)

Write-Host "=== Upload de certificat vers Azure Key Vault ===" -ForegroundColor Cyan
Write-Host "Chemin certificat: $CertPath" -ForegroundColor Yellow
Write-Host "Key Vault: $KeyVaultName" -ForegroundColor Yellow
Write-Host ""

# Vérifier que le dossier existe
if (-not (Test-Path $CertPath)) {
    Write-Host "[ERROR] Le chemin $CertPath n'existe pas!" -ForegroundColor Red
    exit 1
}

# Chercher les fichiers de certificat
$certFile = Get-ChildItem -Path $CertPath -Filter "*.crt" -ErrorAction SilentlyContinue | Select-Object -First 1
$keyFile = Get-ChildItem -Path $CertPath -Filter "*.key" -ErrorAction SilentlyContinue | Select-Object -First 1
$pemCertFile = Get-ChildItem -Path $CertPath -Filter "cert.pem" -ErrorAction SilentlyContinue | Select-Object -First 1
$pemKeyFile = Get-ChildItem -Path $CertPath -Filter "privkey.pem" -ErrorAction SilentlyContinue | Select-Object -First 1
$fullchainFile = Get-ChildItem -Path $CertPath -Filter "fullchain.pem" -ErrorAction SilentlyContinue | Select-Object -First 1

# Déterminer les fichiers à utiliser
if ($pemCertFile -and $pemKeyFile) {
    $certToUse = $pemCertFile.FullName
    $keyToUse = $pemKeyFile.FullName
    $chainToUse = if ($fullchainFile) { $fullchainFile.FullName } else { $pemCertFile.FullName }
} elseif ($certFile -and $keyFile) {
    $certToUse = $certFile.FullName
    $keyToUse = $keyFile.FullName
    $chainToUse = $certFile.FullName
} else {
    Write-Host "[ERROR] Impossible de trouver les fichiers de certificat!" -ForegroundColor Red
    Write-Host "Le dossier doit contenir:" -ForegroundColor Yellow
    Write-Host "  - cert.pem et privkey.pem (format Let's Encrypt)" -ForegroundColor White
    Write-Host "  OU" -ForegroundColor Yellow
    Write-Host "  - *.crt et *.key" -ForegroundColor White
    exit 1
}

Write-Host "[INFO] Fichiers detectes:" -ForegroundColor Green
Write-Host "  Certificat: $certToUse" -ForegroundColor White
Write-Host "  Cle privee: $keyToUse" -ForegroundColor White
Write-Host ""

# Créer un fichier PFX temporaire
$tempPfx = Join-Path $env:TEMP "temp-cert.pfx"
Write-Host "[INFO] Creation du fichier PFX..." -ForegroundColor Cyan

# Utiliser OpenSSL pour créer le PFX (vérifier que OpenSSL est disponible)
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] OpenSSL n'est pas installe!" -ForegroundColor Red
    Write-Host "OpenSSL est requis pour convertir les certificats." -ForegroundColor Yellow
    Write-Host "Installez-le depuis Git for Windows ou utilisez WSL." -ForegroundColor Yellow
    exit 1
}

# Créer le PFX sans mot de passe
& openssl pkcs12 -export -out $tempPfx -inkey $keyToUse -in $certToUse -passout pass:

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors de la creation du fichier PFX" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Fichier PFX cree" -ForegroundColor Green
Write-Host ""

# Upload vers Azure Key Vault
Write-Host "[INFO] Upload du certificat vers Key Vault..." -ForegroundColor Cyan

az keyvault certificate import `
    --vault-name $KeyVaultName `
    --name ocis-tls-cert `
    --file $tempPfx

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors de l'import du certificat" -ForegroundColor Red
    Remove-Item $tempPfx -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "[OK] Certificat importe" -ForegroundColor Green

# Importer la clé privée comme secret
Write-Host "[INFO] Upload de la cle privee..." -ForegroundColor Cyan

az keyvault secret set `
    --vault-name $KeyVaultName `
    --name ocis-tls-key `
    --file $keyToUse `
    --content-type "application/x-pem-file"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Erreur lors de l'import de la cle privee" -ForegroundColor Yellow
}

# Nettoyer
Remove-Item $tempPfx -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[OK] Certificat uploade avec succes dans $KeyVaultName!" -ForegroundColor Green
Write-Host ""

# Vérifier
Write-Host "[INFO] Verification..." -ForegroundColor Cyan
az keyvault certificate show --vault-name $KeyVaultName --name ocis-tls-cert --query "{Name:name, Expires:attributes.expires}" -o table

Write-Host ""
Write-Host "[SUCCESS] Termine!" -ForegroundColor Green
Write-Host ""
Write-Host "Prochaines etapes:" -ForegroundColor Yellow
Write-Host "1. Redeployez l'application pour forcer la synchronisation du certificat:" -ForegroundColor White
Write-Host "   kubectl delete pod -n owncloud -l app=ocis" -ForegroundColor Green
Write-Host "   kubectl delete pod -n owncloud secrets-sync-pod" -ForegroundColor Green
Write-Host ""
Write-Host "2. Verifiez que le certificat est synchronise:" -ForegroundColor White
Write-Host "   kubectl get secret ocis-tls -n owncloud" -ForegroundColor Green
