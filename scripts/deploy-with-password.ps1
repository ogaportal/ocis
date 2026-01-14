# Script pour déployer oCIS avec un mot de passe spécifique
# Usage: .\scripts\deploy-with-password.ps1 -Environment dev|prod -AdminPassword "YourPassword"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword
)

Write-Host "🚀 Deploying oCIS to $Environment with custom admin password..." -ForegroundColor Cyan

# Vérifier que kubectl est connecté au bon cluster
$currentContext = kubectl config current-context
Write-Host "Current kubectl context: $currentContext" -ForegroundColor Yellow

# Créer un fichier kustomization temporaire avec le mot de passe
$kustomizationPath = "k8s\overlays\$Environment\kustomization.yaml"
$tempKustomization = "k8s\overlays\$Environment\kustomization-temp.yaml"

# Lire le fichier kustomization original
$content = Get-Content -Path $kustomizationPath -Raw

# Remplacer le placeholder par le mot de passe réel
$content = $content -replace '__ADMIN_PASSWORD__', $AdminPassword

# Écrire le fichier temporaire
$content | Set-Content -Path $tempKustomization -NoNewline

# Créer un fichier kustomization qui pointe vers le temporaire
$tempDir = "k8s\overlays\$Environment-temp"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copier tous les fichiers nécessaires
Copy-Item -Path $tempKustomization -Destination "$tempDir\kustomization.yaml"

# Déployer avec kubectl
Write-Host "📦 Applying Kubernetes manifests..." -ForegroundColor Cyan
kubectl apply -k $tempDir

# Nettoyer
Remove-Item -Path $tempDir -Recurse -Force
Remove-Item -Path $tempKustomization -Force

Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Waiting for pod to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=ready pod -l app=ocis -n owncloud --timeout=120s

# Vérifier les variables d'environnement
Write-Host ""
Write-Host "🔍 Verifying admin password in pod..." -ForegroundColor Cyan
$podName = kubectl get pods -n owncloud -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n owncloud $podName -- env | Select-String "ADMIN_PASSWORD"

Write-Host ""
Write-Host "🎉 Deployment successful!" -ForegroundColor Green
Write-Host "You can now login to https://$Environment.lesaiglesbraves.online" -ForegroundColor Cyan
Write-Host "Username: admin" -ForegroundColor Yellow
Write-Host "Password: $AdminPassword" -ForegroundColor Yellow
