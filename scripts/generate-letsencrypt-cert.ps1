# Script pour générer un certificat Let's Encrypt et l'uploader dans Azure Key Vault
# Usage: .\scripts\generate-letsencrypt-cert.ps1 -Domain prod.lesaiglesbraves.online -KeyVaultName owncloudkvprod

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName
)

Write-Host "=== Génération de certificat Let's Encrypt ===" -ForegroundColor Cyan
Write-Host "Domaine: $Domain" -ForegroundColor Yellow
Write-Host "Key Vault: $KeyVaultName" -ForegroundColor Yellow
Write-Host ""

# Vérifier que certbot est installé
if (-not (Get-Command certbot -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Certbot n'est pas installe!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Installez-le avec:" -ForegroundColor Yellow
    Write-Host "  winget install Certbot.Certbot" -ForegroundColor Green
    Write-Host "OU" -ForegroundColor Yellow
    Write-Host "  choco install certbot" -ForegroundColor Green
    exit 1
}

Write-Host "[OK] Certbot est installe" -ForegroundColor Green
Write-Host ""

# Instructions pour l'utilisateur
Write-Host "[INFO] Instructions:" -ForegroundColor Cyan
Write-Host "1. Certbot va vous demander de creer un enregistrement DNS TXT" -ForegroundColor Yellow
Write-Host "2. Allez sur votre fournisseur DNS et creez l'enregistrement demande" -ForegroundColor Yellow
Write-Host "3. Attendez quelques minutes que le DNS se propage" -ForegroundColor Yellow
Write-Host "4. Appuyez sur Entree dans certbot pour continuer" -ForegroundColor Yellow
Write-Host ""

# Générer le certificat avec validation DNS
Write-Host "[INFO] Lancement de certbot..." -ForegroundColor Green
certbot certonly `
    --manual `
    --preferred-challenges dns `
    -d $Domain `
    --agree-tos `
    --email stephane.nzali@gmail.com `
    --no-eff-email

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors de la generation du certificat" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] Certificat genere avec succes!" -ForegroundColor Green
Write-Host ""

# Les certificats sont généralement dans C:\Certbot\live\<domain>\
$CertPath = "C:\Certbot\live\$Domain"

if (-not (Test-Path $CertPath)) {
    # Essayer le chemin Linux-style si on est dans WSL
    $CertPath = "/etc/letsencrypt/live/$Domain"
    
    if (-not (Test-Path $CertPath)) {
        Write-Host "[ERROR] Impossible de trouver les certificats generes" -ForegroundColor Red
        Write-Host "Cherchez manuellement dans:" -ForegroundColor Yellow
        Write-Host "  - C:\Certbot\live\$Domain\" -ForegroundColor White
        Write-Host "  - /etc/letsencrypt/live/$Domain/" -ForegroundColor White
        exit 1
    }
}

Write-Host "[INFO] Certificats trouves dans: $CertPath" -ForegroundColor Green
Write-Host ""

# Upload vers Azure Key Vault
Write-Host "[INFO] Upload vers Azure Key Vault..." -ForegroundColor Cyan

# Importer le certificat complet (cert + key)
Write-Host "Importing fullchain certificate..." -ForegroundColor Yellow
az keyvault certificate import `
    --vault-name $KeyVaultName `
    --name ocis-tls-cert `
    --file "$CertPath\fullchain.pem"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors de l'import du certificat" -ForegroundColor Red
    Write-Host ""
    Write-Host "Essayez manuellement avec:" -ForegroundColor Yellow
    Write-Host "  # Creer un fichier PFX" -ForegroundColor Green
    Write-Host "  openssl pkcs12 -export -out cert.pfx -inkey $CertPath\privkey.pem -in $CertPath\cert.pem -certfile $CertPath\chain.pem -passout pass:" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Importer dans Key Vault" -ForegroundColor Green
    Write-Host "  az keyvault certificate import --vault-name $KeyVaultName --name ocis-tls-cert --file cert.pfx" -ForegroundColor White
    exit 1
}

# Importer la clé privée comme secret
Write-Host "Importing private key..." -ForegroundColor Yellow
az keyvault secret set `
    --vault-name $KeyVaultName `
    --name ocis-tls-key `
    --file "$CertPath\privkey.pem" `
    --content-type "application/x-pem-file"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Avertissement: Erreur lors de l'import de la cle privee" -ForegroundColor Yellow
}

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
Write-Host ""
Write-Host "[NOTE] Le certificat Let's Encrypt doit etre renouvele tous les 90 jours" -ForegroundColor Yellow
