# Script pour deployer oCIS avec un mot de passe specifique
# Usage: .\scripts\deploy-with-password.ps1 -Environment dev|prod -AdminPassword "YourPassword"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword
)

Write-Host "Deploying oCIS to $Environment with custom admin password..." -ForegroundColor Cyan

# Verifier que kubectl est connecte au bon cluster
$currentContext = kubectl config current-context
Write-Host "Current kubectl context: $currentContext" -ForegroundColor Yellow

# Creer un repertoire temporaire avec la configuration modifiee
$overlayDir = "k8s\overlays\$Environment"
$tempDir = "k8s\overlays\$Environment-temp"

if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Lire et modifier le kustomization.yaml
$kustomizationContent = Get-Content -Path "$overlayDir\kustomization.yaml" -Raw
$kustomizationContent = $kustomizationContent -replace '__ADMIN_PASSWORD__', $AdminPassword

# Ecrire dans le repertoire temporaire
$kustomizationContent | Set-Content -Path "$tempDir\kustomization.yaml" -NoNewline

# Appliquer la configuration
Write-Host "Applying Kubernetes manifests..." -ForegroundColor Cyan
kubectl apply -k $tempDir

if ($LASTEXITCODE -ne 0) {
    Write-Host "Deployment failed!" -ForegroundColor Red
    Remove-Item -Path $tempDir -Recurse -Force
    exit 1
}

# Supprimer le deployment pour forcer la recreation avec le nouveau secret
Write-Host "Restarting deployment..." -ForegroundColor Cyan
kubectl delete deployment ocis -n owncloud --ignore-not-found=true
Start-Sleep -Seconds 5

# Reappliquer pour recreer le deployment
kubectl apply -k $tempDir

# Nettoyer
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Waiting for pod to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=ready pod -l app=ocis -n owncloud --timeout=180s

if ($LASTEXITCODE -eq 0) {
    # Verifier les variables d'environnement
    Write-Host ""
    Write-Host "Verifying admin password in pod..." -ForegroundColor Cyan
    $podName = kubectl get pods -n owncloud -o jsonpath='{.items[0].metadata.name}'
    kubectl exec -n owncloud $podName -- env | Select-String "ADMIN_PASSWORD"
    
    Write-Host ""
    Write-Host "Deployment successful!" -ForegroundColor Green
    Write-Host "You can now login to https://$Environment.lesaiglesbraves.online" -ForegroundColor Cyan
    Write-Host "Username: admin" -ForegroundColor Yellow
    Write-Host "Password: $AdminPassword" -ForegroundColor Yellow
} else {
    Write-Host "Pod did not become ready in time. Check the logs:" -ForegroundColor Yellow
    Write-Host "kubectl logs -n owncloud -l app=ocis --tail=50" -ForegroundColor Gray
}
