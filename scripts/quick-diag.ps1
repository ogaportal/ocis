#!/usr/bin/env pwsh
# Script pour diagnostiquer rapidement les pods OCIS et Keycloak en crash
# Usage: .\scripts\quick-diag.ps1

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("ocis", "keycloak", "all")]
    [string]$App = "all"
)

Write-Host "`n=== Diagnostic Rapide des Pods ===" -ForegroundColor Cyan

function Show-PodLogs {
    param(
        [string]$Label
    )
    
    Write-Host "`n--- Pods avec label: $Label ---" -ForegroundColor Yellow
    $pods = kubectl get pods -n owncloud -l "app=$Label" -o name 2>$null
    
    if ($pods) {
        foreach ($pod in $pods) {
            $podName = $pod.Split('/')[1]
            Write-Host "`nPod: $podName" -ForegroundColor Green
            Write-Host "Status:" -ForegroundColor White
            kubectl get pod $podName -n owncloud -o jsonpath='{.status.phase}' 2>&1
            Write-Host ""
            
            Write-Host "`nDerniers logs (50 lignes):" -ForegroundColor White
            kubectl logs $podName -n owncloud --tail=50 2>&1
            
            Write-Host "`nLogs du conteneur précédent (si crash):" -ForegroundColor White
            kubectl logs $podName -n owncloud --previous --tail=30 2>&1
            
            Write-Host "`n" -ForegroundColor Gray
            Write-Host "=" * 80 -ForegroundColor Gray
        }
    } else {
        Write-Host "Aucun pod trouvé avec ce label" -ForegroundColor Red
    }
}

if ($App -eq "all" -or $App -eq "ocis") {
    Show-PodLogs -Label "ocis"
}

if ($App -eq "all" -or $App -eq "keycloak") {
    Show-PodLogs -Label "keycloak"
}

# Vérifier les secrets
Write-Host "`n--- Secrets TLS ---" -ForegroundColor Yellow
kubectl get secrets -n owncloud | Select-String -Pattern "tls"

# Vérifier les ConfigMaps
Write-Host "`n--- ConfigMaps ---" -ForegroundColor Yellow
kubectl get configmaps -n owncloud

Write-Host "`n=== Fin du diagnostic ===" -ForegroundColor Cyan
