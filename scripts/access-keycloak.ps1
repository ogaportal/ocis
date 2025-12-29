#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Access Keycloak Admin Console
.DESCRIPTION
    This script creates a port-forward to access Keycloak admin console
#>

Write-Host "=== Keycloak Admin Console Access ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Setting up port forward to Keycloak..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Once connected, open your browser to:" -ForegroundColor Green
Write-Host "  http://localhost:8080/auth/admin" -ForegroundColor White
Write-Host ""
Write-Host "Try these credentials (one should work):" -ForegroundColor Yellow
Write-Host "  Username: admin" -ForegroundColor White
Write-Host "  Password: admin (default)" -ForegroundColor White
Write-Host "  Password: IIHqAMkbXhZqxednDtQaIgtMTLzGW6qA (from secret)" -ForegroundColor White
Write-Host ""
Write-Host "After logging in, you need to:" -ForegroundColor Cyan
Write-Host "  1. Create a new Realm called 'owncloud'" -ForegroundColor White
Write-Host "  2. In the owncloud realm, create a Client:" -ForegroundColor White
Write-Host "     - Client ID: ocis" -ForegroundColor White
Write-Host "     - Client Protocol: openid-connect" -ForegroundColor White
Write-Host "     - Access Type: confidential" -ForegroundColor White
Write-Host "     - Valid Redirect URIs: https://dev.lesaiglesbraves.online/*" -ForegroundColor White
Write-Host "     - Web Origins: https://dev.lesaiglesbraves.online" -ForegroundColor White
Write-Host "  3. Go to Credentials tab and set the Secret to:" -ForegroundColor White

$clientSecret = kubectl get secret -n owncloud ocis-secret -o jsonpath='{.data.oidc-client-secret}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "     $clientSecret" -ForegroundColor Yellow

Write-Host ""
Write-Host "Press Ctrl+C to stop the port forward when done." -ForegroundColor Red
Write-Host ""

kubectl port-forward -n owncloud svc/keycloak 8080:8080
