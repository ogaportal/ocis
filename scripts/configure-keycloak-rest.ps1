#!/usr/bin/env pwsh
# Direct Keycloak REST API configuration
param(
    [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'

$namespace = 'owncloud'
$keycloakPod = kubectl get pods -n $namespace -l app=keycloak -o jsonpath='{.items[0].metadata.name}'

# Get secrets
$clientSecret = kubectl get secret -n $namespace ocis-secret -o jsonpath='{.data.oidc-client-secret}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "=== Configuration Keycloak via REST API ===" -ForegroundColor Cyan

# Port forward to access Keycloak API
Write-Host "`nStarting port forward to Keycloak..." -ForegroundColor Yellow
$portForwardJob = Start-Job -ScriptBlock {
    kubectl port-forward -n owncloud svc/keycloak 8080:8080
}

Start-Sleep -Seconds 5

try {
    # Login and get access token - using default admin/admin since KEYCLOAK_ADMIN_PASSWORD isn't working
    Write-Host "`nTrying to get admin token..." -ForegroundColor Yellow
    
    $body = @{
        grant_type = "password"
        client_id = "admin-cli"
        username = "admin"
        password = "admin"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "http://localhost:8080/auth/realms/master/protocol/openid-connect/token" `
        -Method Post `
        -ContentType "application/x-www-form-urlencoded" `
        -Body "grant_type=password&client_id=admin-cli&username=admin&password=admin"
    
    $token = $response.access_token
    Write-Host "✓ Got access token!" -ForegroundColor Green

    # Create realm
    Write-Host "`nCreating realm 'owncloud'..." -ForegroundColor Yellow
    
    $realmBody = @{
        realm = "owncloud"
        enabled = $true
        displayName = "ownCloud"
        registrationAllowed = $true
        registrationEmailAsUsername = $true
        rememberMe = $true
        verifyEmail = $false
        loginWithEmailAllowed = $true
        duplicateEmailsAllowed = $false
        resetPasswordAllowed = $true
        editUsernameAllowed = $false
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "http://localhost:8080/auth/admin/realms" `
            -Method Post `
            -Headers @{Authorization = "Bearer $token"; "Content-Type" = "application/json"} `
            -Body $realmBody
        Write-Host "✓ Realm created!" -ForegroundColor Green
    } catch {
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Host "✓ Realm already exists" -ForegroundColor Yellow
        } else {
            throw
        }
    }

    # Create OIDC client
    Write-Host "`nCreating OIDC client 'ocis'..." -ForegroundColor Yellow
    
    $redirectUrl = if ($Environment -eq 'dev') { "https://dev.lesaiglesbraves.online/*" } else { "https://lesaiglesbraves.online/*" }
    $webOrigin = if ($Environment -eq 'dev') { "https://dev.lesaiglesbraves.online" } else { "https://lesaiglesbraves.online" }
    
    $clientBody = @{
        clientId = "ocis"
        enabled = $true
        clientAuthenticatorType = "client-secret"
        secret = $clientSecret
        publicClient = $false
        protocol = "openid-connect"
        standardFlowEnabled = $true
        implicitFlowEnabled = $false
        directAccessGrantsEnabled = $true
        serviceAccountsEnabled = $false
        redirectUris = @($redirectUrl)
        webOrigins = @($webOrigin)
        baseUrl = $webOrigin
        fullScopeAllowed = $true
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "http://localhost:8080/auth/admin/realms/owncloud/clients" `
            -Method Post `
            -Headers @{Authorization = "Bearer $token"; "Content-Type" = "application/json"} `
            -Body $clientBody
        Write-Host "✓ Client created!" -ForegroundColor Green
    } catch {
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Host "✓ Client already exists" -ForegroundColor Yellow
        } else {
            throw
        }
    }

    # Create test user
    Write-Host "`nCreating test user..." -ForegroundColor Yellow
    
    $userBody = @{
        username = "testuser"
        email = "test@lesaiglesbraves.online"
        firstName = "Test"
        lastName = "User"
        enabled = $true
        emailVerified = $true
        credentials = @(
            @{
                type = "password"
                value = "Test@123"
                temporary = $false
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod -Uri "http://localhost:8080/auth/admin/realms/owncloud/users" `
            -Method Post `
            -Headers @{Authorization = "Bearer $token"; "Content-Type" = "application/json"} `
            -Body $userBody
        Write-Host "✓ User created!" -ForegroundColor Green
    } catch {
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Host "✓ User already exists" -ForegroundColor Yellow
        } else {
            throw
        }
    }

    Write-Host "`n=== Configuration terminée! ===" -ForegroundColor Green
    Write-Host "`nRésumé:" -ForegroundColor Cyan
    Write-Host "  Realm: owncloud" -ForegroundColor White
    Write-Host "  Client ID: ocis" -ForegroundColor White
    Write-Host "  Client Secret: $clientSecret" -ForegroundColor White
    Write-Host "  Redirect URL: $redirectUrl" -ForegroundColor White
    Write-Host "  OIDC Issuer: $webOrigin/auth/realms/owncloud" -ForegroundColor White
    Write-Host "`nUtilisateur test:" -ForegroundColor Cyan
    Write-Host "  Username: testuser" -ForegroundColor White
    Write-Host "  Email: test@lesaiglesbraves.online" -ForegroundColor White
    Write-Host "  Password: Test@123" -ForegroundColor White

} finally {
    Write-Host "`nStopping port forward..." -ForegroundColor Yellow
    Stop-Job $portForwardJob
    Remove-Job $portForwardJob
}
