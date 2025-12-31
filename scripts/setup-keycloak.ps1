#!/usr/bin/env pwsh
# Simple Keycloak configuration using kubectl exec

$ErrorActionPreference = 'Stop'

$namespace = 'owncloud'
$keycloakPod = kubectl get pods -n $namespace -l app=keycloak -o jsonpath='{.items[0].metadata.name}'
$adminPass = "IIHqAMkbXhZqxednDtQaIgtMTLzGW6qA"
$clientSecret = kubectl get secret -n $namespace ocis-secret -o jsonpath='{.data.oidc-client-secret}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "=== Configuring Keycloak for OCIS ===" -ForegroundColor Cyan

# Test login first
Write-Host "Testing admin login..." -ForegroundColor Yellow
kubectl exec -n $namespace $keycloakPod -- /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin --password $adminPass

# Create realm
Write-Host "`nCreating realm 'owncloud'..." -ForegroundColor Yellow
kubectl exec -n $namespace $keycloakPod -- /opt/keycloak/bin/kcadm.sh create realms -s realm=owncloud -s enabled=true -o 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 409) { 
    Write-Host "✓ Realm ready" -ForegroundColor Green 
}

# Create client
Write-Host "`nCreating OIDC client..." -ForegroundColor Yellow
kubectl exec -n $namespace $keycloakPod -- /opt/keycloak/bin/kcadm.sh create clients -r owncloud -s clientId=ocis -s enabled=true -s secret=$clientSecret -s publicClient=false -s standardFlowEnabled=true -s directAccessGrantsEnabled=true -s "redirectUris=[`"https://dev.lesaiglesbraves.online/*`"]" -s "webOrigins=[`"https://dev.lesaiglesbraves.online`"]" -o 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 409) { 
    Write-Host "✓ Client ready" -ForegroundColor Green 
}

# Create test user
Write-Host "`nCreating test user..." -ForegroundColor Yellow
kubectl exec -n $namespace $keycloakPod -- /opt/keycloak/bin/kcadm.sh create users -r owncloud -s username=testuser -s enabled=true -s email=test@lesaiglesbraves.online -o 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 409) { 
    Write-Host "✓ User ready" -ForegroundColor Green 
}

# Set password
Write-Host "`nSetting user password..." -ForegroundColor Yellow
kubectl exec -n $namespace $keycloakPod -- /opt/keycloak/bin/kcadm.sh set-password -r owncloud --username testuser --new-password Test@123 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { 
    Write-Host "✓ Password set" -ForegroundColor Green 
}

Write-Host "`n=== Configuration complete! ===" -ForegroundColor Green
Write-Host "`nTest login with:" -ForegroundColor Cyan
Write-Host "  Username: testuser" -ForegroundColor White
Write-Host "  Password: Test@123" -ForegroundColor White
Write-Host "`nKeycloak admin:" -ForegroundColor Cyan
Write-Host "  URL: https://dev.lesaiglesbraves.online/auth/admin" -ForegroundColor White
Write-Host "  Username: admin" -ForegroundColor White
Write-Host "  Password: $adminPass" -ForegroundColor White
