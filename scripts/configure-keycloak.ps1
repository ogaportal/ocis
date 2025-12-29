#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure Keycloak with ownCloud realm and OIDC client
.DESCRIPTION
    This script creates the owncloud realm and configures an OIDC client for OCIS integration
.PARAMETER Environment
    Environment (dev/prod)
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'

# Configuration
$namespace = 'owncloud'
$keycloakPod = kubectl get pods -n $namespace -l app=keycloak -o jsonpath='{.items[0].metadata.name}' 2>$null

if (-not $keycloakPod) {
    Write-Error "Keycloak pod not found in namespace $namespace"
    exit 1
}

Write-Host "=== Configuration Keycloak pour OCIS ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Green
Write-Host "Keycloak Pod: $keycloakPod" -ForegroundColor Green

# Get admin credentials
$adminUser = kubectl get secret -n $namespace keycloak-secret -o jsonpath='{.data.admin-username}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
$adminPass = kubectl get secret -n $namespace keycloak-secret -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "`nAdmin User: $adminUser" -ForegroundColor Yellow

# Get OIDC client secret from OCIS secret
$clientSecret = kubectl get secret -n $namespace ocis-secret -o jsonpath='{.data.oidc-client-secret}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Set redirect URLs based on environment
$redirectUrl = switch ($Environment) {
    'dev' { 'https://dev.lesaiglesbraves.online/*' }
    'prod' { 'https://lesaiglesbraves.online/*' }
}

$webOrigin = switch ($Environment) {
    'dev' { 'https://dev.lesaiglesbraves.online' }
    'prod' { 'https://lesaiglesbraves.online' }
}

Write-Host "`n=== Étape 1: Connexion à Keycloak ===" -ForegroundColor Cyan

# Create a script inside the pod
$scriptContent = @"
#!/bin/bash
set -e

# Login
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user $adminUser --password '$adminPass'

# Create realm
/opt/keycloak/bin/kcadm.sh create realms -s realm=owncloud -s enabled=true -s displayName='ownCloud' -s registrationAllowed=true -s registrationEmailAsUsername=true -s rememberMe=true -s verifyEmail=false -s loginWithEmailAllowed=true -s duplicateEmailsAllowed=false -s resetPasswordAllowed=true -s editUsernameAllowed=false -o 2>/dev/null || echo 'Realm already exists'

# Create client
/opt/keycloak/bin/kcadm.sh create clients -r owncloud -s clientId=ocis -s enabled=true -s clientAuthenticatorType=client-secret -s secret='$clientSecret' -s publicClient=false -s protocol=openid-connect -s standardFlowEnabled=true -s implicitFlowEnabled=false -s directAccessGrantsEnabled=true -s serviceAccountsEnabled=false -s 'redirectUris=["$redirectUrl"]' -s 'webOrigins=["$webOrigin"]' -s baseUrl=$webOrigin -s fullScopeAllowed=true -o 2>/dev/null || echo 'Client already exists'

# Create test user
/opt/keycloak/bin/kcadm.sh create users -r owncloud -s username=testuser -s email=test@lesaiglesbraves.online -s firstName=Test -s lastName=User -s enabled=true -s emailVerified=true -o 2>/dev/null || echo 'User already exists'

# Set password
USER_ID=`$(/opt/keycloak/bin/kcadm.sh get users -r owncloud -q username=testuser --fields id --format csv --noquotes)`
if [ ! -z "`$USER_ID" ]; then
  /opt/keycloak/bin/kcadm.sh set-password -r owncloud --username testuser --new-password 'Test@123'
  echo 'Password set successfully'
fi

echo 'Configuration completed!'
"@

# Copy script to pod
Write-Host "Création du script de configuration..." -ForegroundColor Yellow
$scriptContent | kubectl exec -i -n $namespace $keycloakPod -- sh -c 'cat > /tmp/configure-keycloak.sh'

# Make it executable and run it
Write-Host "Exécution du script de configuration..." -ForegroundColor Yellow
kubectl exec -n $namespace $keycloakPod -- chmod +x /tmp/configure-keycloak.sh
kubectl exec -n $namespace $keycloakPod -- /tmp/configure-keycloak.sh

Write-Host "`n=== Configuration Keycloak terminée! ===" -ForegroundColor Green
Write-Host "`nRésumé:" -ForegroundColor Cyan
Write-Host "  Realm: owncloud" -ForegroundColor White
Write-Host "  Client ID: ocis" -ForegroundColor White
Write-Host "  Client Secret: $clientSecret" -ForegroundColor White
Write-Host "  Redirect URL: $redirectUrl" -ForegroundColor White
Write-Host "  OIDC Issuer: $webOrigin/auth/realms/owncloud" -ForegroundColor White
Write-Host "`nUtilisateur test créé:" -ForegroundColor Cyan
Write-Host "  Username: testuser" -ForegroundColor White
Write-Host "  Email: test@lesaiglesbraves.online" -ForegroundColor White
Write-Host "  Password: Test@123" -ForegroundColor White
Write-Host "`nProchaine étape: Activer OIDC dans OCIS" -ForegroundColor Yellow
