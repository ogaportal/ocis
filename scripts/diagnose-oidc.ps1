#!/usr/bin/env pwsh
# Complete OIDC Configuration Diagnostic

Write-Host @"

=============================================================================
    DIAGNOSTIC COMPLET - CONFIGURATION OIDC
=============================================================================

"@ -ForegroundColor Cyan

# Get OCIS config
Write-Host "=== Configuration OCIS ===" -ForegroundColor Yellow
kubectl exec -n owncloud deployment/ocis -- printenv | Select-String "WEB_OIDC|PROXY_OIDC|OCIS_OIDC" | Sort-Object

# Get Keycloak client config
Write-Host "`n=== Configuration Keycloak Client ===" -ForegroundColor Yellow
$namespace = 'owncloud'
$keycloakPod = kubectl get pods -n $namespace -l app=keycloak -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n $namespace $keycloakPod -- /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin --password IIHqAMkbXhZqxednDtQaIgtMTLzGW6qA 2>&1 | Out-Null

$clientUuid = kubectl exec -n $namespace $keycloakPod -- /opt/keycloak/bin/kcadm.sh get clients -r owncloud -q clientId=ocis --fields id --format csv --noquotes

$clientConfig = kubectl exec -n $namespace $keycloakPod -- /opt/keycloak/bin/kcadm.sh get clients/$clientUuid -r owncloud 2>&1 | ConvertFrom-Json

Write-Host "Client ID: $($clientConfig.clientId)" -ForegroundColor White
Write-Host "Public Client: $($clientConfig.publicClient)" -ForegroundColor White
Write-Host "Client Authenticator: $($clientConfig.clientAuthenticatorType)" -ForegroundColor White
Write-Host "Standard Flow: $($clientConfig.standardFlowEnabled)" -ForegroundColor White
Write-Host "Direct Access Grants: $($clientConfig.directAccessGrantsEnabled)" -ForegroundColor White
Write-Host "Redirect URIs: $($clientConfig.redirectUris -join ', ')" -ForegroundColor White
Write-Host "Web Origins: $($clientConfig.webOrigins -join ', ')" -ForegroundColor White

# Check secret
$clientSecretObj = kubectl exec -n $namespace $keycloakPod -- /opt/keycloak/bin/kcadm.sh get clients/$clientUuid/client-secret -r owncloud 2>&1 | ConvertFrom-Json
Write-Host "Client Secret Match: $(if ($clientSecretObj.value -eq 'Hn1f8sotn4E6Z5Yn/la4eY+MlidAZh1m4S7OGvpiMLw=') { '✓ YES' } else { '✗ NO' })" -ForegroundColor $(if ($clientSecretObj.value -eq 'Hn1f8sotn4E6Z5Yn/la4eY+MlidAZh1m4S7OGvpiMLw=') { 'Green' } else { 'Red' })

# Test OIDC endpoint
Write-Host "`n=== Test Endpoints OIDC ===" -ForegroundColor Yellow
Write-Host "Testing .well-known endpoint..." -ForegroundColor White
kubectl exec -n owncloud deployment/ocis -- curl -s http://keycloak:8080/auth/realms/owncloud/.well-known/openid-configuration | ConvertFrom-Json | Select-Object issuer, authorization_endpoint, token_endpoint | Format-List

# Recent logs
Write-Host "`n=== Recent Keycloak Errors ===" -ForegroundColor Yellow
kubectl logs -n owncloud deployment/keycloak --tail=20 | Select-String "ERROR|invalid_client" | Select-Object -Last 5

Write-Host @"

=============================================================================
    INSTRUCTIONS DE TEST
=============================================================================

1. Allez sur: https://dev.lesaiglesbraves.online
2. Vous serez redirigé vers Keycloak
3. Connectez-vous avec: testuser / Test@123
4. Si erreur 401, vérifiez que:
   - Le Redirect URI dans Keycloak contient EXACTEMENT:
     https://dev.lesaiglesbraves.online/*
   - Le Web Origin contient EXACTEMENT:
     https://dev.lesaiglesbraves.online

Pour accéder à Keycloak Admin:
    kubectl port-forward -n owncloud svc/keycloak 8080:8080
    http://localhost:8080/auth/admin
    admin / IIHqAMkbXhZqxednDtQaIgtMTLzGW6qA

=============================================================================

"@ -ForegroundColor Cyan
