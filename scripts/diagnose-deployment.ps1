#!/usr/bin/env pwsh
# Script de diagnostic pour les problèmes de déploiement OCIS/Keycloak
# Usage: .\scripts\diagnose-deployment.ps1

Write-Host "`n=== Diagnostic de déploiement OCIS/Keycloak ===" -ForegroundColor Cyan
Write-Host ""

# 1. Vérifier l'état des pods
Write-Host "1. État des pods" -ForegroundColor Yellow
kubectl get pods -n owncloud
Write-Host ""

# 2. Vérifier le secrets-sync-pod
Write-Host "2. Diagnostic du secrets-sync-pod" -ForegroundColor Yellow
$syncPodExists = kubectl get pod secrets-sync-pod -n owncloud 2>$null
if ($syncPodExists) {
    Write-Host "Pod exists. Status:" -ForegroundColor Green
    kubectl get pod secrets-sync-pod -n owncloud
    
    Write-Host "`nEvents du pod:" -ForegroundColor Green
    kubectl describe pod secrets-sync-pod -n owncloud | Select-String -Pattern "Events:" -Context 0,20
    
    $status = kubectl get pod secrets-sync-pod -n owncloud -o jsonpath='{.status.phase}'
    if ($status -ne "Running") {
        Write-Host "`nLogs du pod:" -ForegroundColor Green
        kubectl logs secrets-sync-pod -n owncloud 2>&1
    }
} else {
    Write-Host "⚠️ secrets-sync-pod n'existe pas!" -ForegroundColor Red
}
Write-Host ""

# 3. Vérifier les secrets TLS
Write-Host "3. Secrets TLS" -ForegroundColor Yellow
$ocisSecret = kubectl get secret ocis-tls -n owncloud 2>$null
$keycloakSecret = kubectl get secret keycloak-tls -n owncloud 2>$null

if ($ocisSecret) {
    Write-Host "✅ ocis-tls existe" -ForegroundColor Green
    kubectl describe secret ocis-tls -n owncloud | Select-String -Pattern "Type|Data"
} else {
    Write-Host "❌ ocis-tls n'existe pas" -ForegroundColor Red
}

if ($keycloakSecret) {
    Write-Host "✅ keycloak-tls existe" -ForegroundColor Green
    kubectl describe secret keycloak-tls -n owncloud | Select-String -Pattern "Type|Data"
} else {
    Write-Host "❌ keycloak-tls n'existe pas" -ForegroundColor Red
}
Write-Host ""

# 4. Vérifier le CSI Driver
Write-Host "4. CSI Driver" -ForegroundColor Yellow
kubectl get pods -n kube-system | Select-String -Pattern "csi-secrets"
Write-Host "`nDerniers logs du CSI Driver:"
kubectl logs -n kube-system -l app=csi-secrets-store-provider-azure --tail=20 2>&1
Write-Host ""

# 5. Vérifier les SecretProviderClass
Write-Host "5. SecretProviderClass" -ForegroundColor Yellow
kubectl get secretproviderclass -n owncloud
Write-Host "`nConfiguration de ocis-keyvault-certs:"
kubectl get secretproviderclass ocis-keyvault-certs -n owncloud -o yaml | Select-String -Pattern "keyvaultName|tenantId|userAssignedIdentityID" -Context 0,1
Write-Host ""

# 6. Vérifier les logs des pods en CrashLoopBackOff
Write-Host "6. Logs des pods en erreur" -ForegroundColor Yellow
$failedPods = kubectl get pods -n owncloud --field-selector=status.phase!=Running,status.phase!=Succeeded -o name 2>$null

if ($failedPods) {
    foreach ($pod in $failedPods) {
        $podName = $pod.Split('/')[1]
        if ($podName -notmatch "secrets-sync-pod") {
            Write-Host "`n--- Logs de $podName ---" -ForegroundColor Cyan
            kubectl logs $podName -n owncloud --tail=30 2>&1
        }
    }
} else {
    Write-Host "✅ Aucun pod en erreur" -ForegroundColor Green
}
Write-Host ""

# 7. Événements récents
Write-Host "7. Événements récents (30 derniers)" -ForegroundColor Yellow
kubectl get events -n owncloud --sort-by='.lastTimestamp' | Select-Object -Last 30
Write-Host ""

# 8. Résumé et recommandations
Write-Host "8. Résumé et recommandations" -ForegroundColor Yellow

$hasOcisTls = $null -ne $ocisSecret
$hasKeycloakTls = $null -ne $keycloakSecret
$syncPodRunning = $syncPodExists -and ((kubectl get pod secrets-sync-pod -n owncloud -o jsonpath='{.status.phase}') -eq "Running")

Write-Host "`nÉtat actuel:" -ForegroundColor Green
Write-Host "  - Secrets TLS OCIS: $(if ($hasOcisTls) { '✅' } else { '❌' })"
Write-Host "  - Secrets TLS Keycloak: $(if ($hasKeycloakTls) { '✅' } else { '❌' })"
Write-Host "  - secrets-sync-pod: $(if ($syncPodRunning) { '✅ Running' } elseif ($syncPodExists) { '⚠️ Exists but not Running' } else { '❌ Does not exist' })"

Write-Host "`nRecommandations:" -ForegroundColor Green

if (-not $hasOcisTls -or -not $hasKeycloakTls) {
    Write-Host "  1. Les secrets TLS ne sont pas créés. Vérifier:" -ForegroundColor Yellow
    Write-Host "     - Les certificats existent dans Key Vault:" -ForegroundColor White
    Write-Host "       az keyvault certificate list --vault-name owncloudkvdev" -ForegroundColor Gray
    Write-Host "     - Le Managed Identity a les bonnes permissions" -ForegroundColor White
    Write-Host "     - La configuration du SecretProviderClass est correcte" -ForegroundColor White
}

if ($syncPodExists -and -not $syncPodRunning) {
    Write-Host "  2. Le secrets-sync-pod existe mais ne démarre pas. Actions:" -ForegroundColor Yellow
    Write-Host "     - Supprimer et recréer le pod:" -ForegroundColor White
    Write-Host "       kubectl delete pod secrets-sync-pod -n owncloud" -ForegroundColor Gray
    Write-Host "       kubectl apply -k k8s/overlays/dev" -ForegroundColor Gray
}

if ($failedPods -and ($failedPods | Where-Object { $_ -match "keycloak|ocis" })) {
    Write-Host "  3. Les pods applicatifs crashent. Vérifier:" -ForegroundColor Yellow
    Write-Host "     - Les variables d'environnement dans les ConfigMaps" -ForegroundColor White
    Write-Host "     - Les connexions aux bases de données" -ForegroundColor White
    Write-Host "     - Les logs ci-dessus pour identifier l'erreur" -ForegroundColor White
}

Write-Host "`n=== Fin du diagnostic ===" -ForegroundColor Cyan
