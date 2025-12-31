#!/usr/bin/env pwsh
# Script to generate and apply OCIS secrets to fix JWT secret error

Write-Host "Generating random secrets for applications..." -ForegroundColor Cyan

# Generate random secrets using OpenSSL (from Git for Windows)
$jwtSecret = & "C:\Program Files\Git\usr\bin\openssl.exe" rand -base64 32
$transferSecret = & "C:\Program Files\Git\usr\bin\openssl.exe" rand -base64 32
$machineAuthApiKey = & "C:\Program Files\Git\usr\bin\openssl.exe" rand -base64 32
$systemUserApiKey = & "C:\Program Files\Git\usr\bin\openssl.exe" rand -base64 32
$ocisAdminPassword = & "C:\Program Files\Git\usr\bin\openssl.exe" rand -base64 24
$keycloakAdminPassword = & "C:\Program Files\Git\usr\bin\openssl.exe" rand -base64 24
$oidcClientSecret = & "C:\Program Files\Git\usr\bin\openssl.exe" rand -base64 32

Write-Host "Secrets generated" -ForegroundColor Green

Write-Host "`nDeleting existing secrets..." -ForegroundColor Cyan
kubectl delete secret ocis-secret -n owncloud --ignore-not-found=true
kubectl delete secret keycloak-secret -n owncloud --ignore-not-found=true

Write-Host "`nCreating new secrets with generated values..." -ForegroundColor Cyan

# Create ocis-secret
kubectl create secret generic ocis-secret -n owncloud `
  --from-literal=admin-user-id=admin `
  --from-literal=admin-password="$ocisAdminPassword" `
  --from-literal=oidc-client-id=ocis `
  --from-literal=oidc-client-secret="$oidcClientSecret" `
  --from-literal=jwt-secret="$jwtSecret" `
  --from-literal=transfer-secret="$transferSecret" `
  --from-literal=machine-auth-api-key="$machineAuthApiKey" `
  --from-literal=system-user-api-key="$systemUserApiKey"

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK ocis-secret created successfully" -ForegroundColor Green
} else {
    Write-Host "ERROR Failed to create ocis-secret" -ForegroundColor Red
    exit 1
}

# Create keycloak-secret
kubectl create secret generic keycloak-secret -n owncloud `
  --from-literal=admin-username=admin `
  --from-literal=admin-password="$keycloakAdminPassword"

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK keycloak-secret created successfully" -ForegroundColor Green
} else {
    Write-Host "ERROR Failed to create keycloak-secret" -ForegroundColor Red
    exit 1
}

Write-Host "`nRestarting OCIS deployment..." -ForegroundColor Cyan
kubectl rollout restart deployment/ocis -n owncloud

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK OCIS deployment restart initiated" -ForegroundColor Green
} else {
    Write-Host "ERROR Failed to restart OCIS deployment" -ForegroundColor Red
    exit 1
}

Write-Host "`nWaiting for OCIS deployment to be ready..." -ForegroundColor Cyan
kubectl rollout status deployment/ocis -n owncloud --timeout=300s

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK OCIS is now ready!" -ForegroundColor Green
} else {
    Write-Host "WARNING OCIS deployment timeout or error" -ForegroundColor Yellow
    Write-Host "`nShowing OCIS pod status:" -ForegroundColor Cyan
    kubectl get pods -n owncloud -l app=ocis
    Write-Host "`nShowing recent OCIS logs:" -ForegroundColor Cyan
    kubectl logs -n owncloud -l app=ocis --tail=50
}

Write-Host "`nIMPORTANT: Save these credentials securely!" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Yellow
Write-Host "OCIS Admin Password:     $ocisAdminPassword" -ForegroundColor White
Write-Host "Keycloak Admin Password: $keycloakAdminPassword" -ForegroundColor White
Write-Host "===========================================" -ForegroundColor Yellow
