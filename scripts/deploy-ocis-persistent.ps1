# Deploy OCIS to AKS with Persistent Storage
# This script deploys OCIS using Kustomize with proper configuration for persistent data storage

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$AdminPassword
)

Write-Host "=== Deploying OCIS to $Environment environment ===" -ForegroundColor Cyan

# Load environment-specific variables
if ($Environment -eq 'prod') {
    $ResourceGroup = 'owncloud-rg-prod'
    $ClusterName = 'owncloud-aks-prod'
    $OverlayPath = 'k8s/overlays/prod'
} else {
    $ResourceGroup = 'owncloud-rg-dev'
    $ClusterName = 'owncloud-aks-dev'
    $OverlayPath = 'k8s/overlays/dev'
}

Write-Host "`n1. Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get AKS credentials" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Verifying cluster connection..." -ForegroundColor Yellow
kubectl cluster-info | Select-Object -First 2
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Cannot connect to cluster" -ForegroundColor Red
    exit 1
}

Write-Host "`n3. Creating namespace (if not exists)..." -ForegroundColor Yellow
kubectl create namespace owncloud --dry-run=client -o yaml | kubectl apply -f -

Write-Host "`n4. Checking existing PVCs..." -ForegroundColor Yellow
kubectl get pvc -n owncloud

Write-Host "`n5. Building Kustomize configuration..." -ForegroundColor Yellow
$kustomizeYaml = kustomize build $OverlayPath

# Optional: Replace admin password if provided
if ($AdminPassword) {
    Write-Host "`n6. Updating admin password in configuration..." -ForegroundColor Yellow
    # This would require a more complex approach with sed or yq
    # For now, we'll assume passwords are managed via secrets
    Write-Host "   Note: Admin password should be updated in Azure Key Vault or kustomization.yaml" -ForegroundColor Yellow
}

Write-Host "`n6. Applying OCIS configuration with persistent storage..." -ForegroundColor Yellow
$kustomizeYaml | kubectl apply -f -

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to apply configuration" -ForegroundColor Red
    exit 1
}

Write-Host "`n7. Waiting for PVC to be bound..." -ForegroundColor Yellow
$maxRetries = 30
$retryCount = 0
while ($retryCount -lt $maxRetries) {
    $pvcStatus = (kubectl get pvc ocis-data-pvc -n owncloud -o jsonpath="{.status.phase}" 2>&1) | Out-String
    $pvcStatus = $pvcStatus.Trim()
    if ($pvcStatus -eq "Bound") {
        Write-Host "   ✓ PVC ocis-data-pvc is bound!" -ForegroundColor Green
        break
    }
    Write-Host "   Waiting for PVC to bind... ($retryCount/$maxRetries)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    $retryCount++
}

if ($retryCount -ge $maxRetries) {
    Write-Host "   WARNING: PVC did not bind within timeout" -ForegroundColor Yellow
    kubectl describe pvc ocis-data-pvc -n owncloud
}

Write-Host "`n8. Checking PVC details..." -ForegroundColor Yellow
kubectl get pvc -n owncloud
kubectl get pv | Select-String "ocis-data"

Write-Host "`n9. Waiting for OCIS pod to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=ocis -n owncloud --timeout=300s

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✓ OCIS deployed successfully!" -ForegroundColor Green
    
    Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor White
    Write-Host "Namespace: owncloud" -ForegroundColor White
    
    Write-Host "`nPods:" -ForegroundColor Yellow
    kubectl get pods -n owncloud
    
    Write-Host "`nPersistent Volumes:" -ForegroundColor Yellow
    kubectl get pvc -n owncloud
    
    Write-Host "`nServices:" -ForegroundColor Yellow
    kubectl get svc -n owncloud
    
    Write-Host "`nIngress:" -ForegroundColor Yellow
    kubectl get ingress -n owncloud
    
    Write-Host "`n📝 Important Notes:" -ForegroundColor Cyan
    Write-Host "   • User data is now persisted in PVC 'ocis-data-pvc'" -ForegroundColor White
    Write-Host "   • Users and files will survive pod restarts and redeployments" -ForegroundColor White
    Write-Host "   • PVC size: 50Gi (Azure Premium SSD)" -ForegroundColor White
    Write-Host "   • Backup the PVC regularly using Azure snapshots" -ForegroundColor White
    
} else {
    Write-Host "`n✗ OCIS deployment failed or timed out" -ForegroundColor Red
    Write-Host "`nPod status:" -ForegroundColor Yellow
    kubectl get pods -n owncloud
    
    Write-Host "`nPod events:" -ForegroundColor Yellow
    kubectl describe pod -l app=ocis -n owncloud | Select-String -Pattern "Events:" -Context 0,20
    
    Write-Host "`nPod logs:" -ForegroundColor Yellow
    kubectl logs -l app=ocis -n owncloud --tail=50
    
    exit 1
}

Write-Host "`n✓ Deployment complete!" -ForegroundColor Green
