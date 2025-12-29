#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fix Keycloak OIDC Client Configuration
.DESCRIPTION
    Guide to fix the ocis client configuration in Keycloak admin console
#>

$clientSecret = kubectl get secret -n owncloud ocis-secret -o jsonpath='{.data.oidc-client-secret}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host @"

=============================================================================
    KEYCLOAK CLIENT CONFIGURATION - FIX GUIDE
=============================================================================

ÉTAPE 1: Démarrer le port-forward (dans un terminal séparé)
---------------------------------------------------------
Ouvrez un nouveau terminal PowerShell et exécutez:
    kubectl port-forward -n owncloud svc/keycloak 8080:8080


ÉTAPE 2: Accéder à Keycloak Admin Console
---------------------------------------------------------
URL: http://localhost:8080/auth/admin

Credentials:
    Username: admin
    Password: IIHqAMkbXhZqxednDtQaIgtMTLzGW6qA


ÉTAPE 3: Configurer le client OIDC
---------------------------------------------------------
1. En haut à gauche, sélectionner le realm: owncloud

2. Menu de gauche: Clients

3. Cliquer sur le client: ocis

4. Onglet Settings:
   ✓ Client ID: ocis
   ✓ Client Protocol: openid-connect
   ✓ Access Type: confidential
   ✓ Standard Flow Enabled: ON
   ✓ Direct Access Grants Enabled: ON
   ✓ Valid Redirect URIs: https://dev.lesaiglesbraves.online/*
   ✓ Web Origins: https://dev.lesaiglesbraves.online
   
   Cliquer sur SAVE

5. Onglet Credentials:
   ✓ Client Authenticator: Client Id and Secret
   ✓ Secret: $clientSecret
   
   Cliquer sur SAVE


ÉTAPE 4: Vérifier l'utilisateur test
---------------------------------------------------------
1. Menu de gauche: Users

2. Cliquer sur: testuser

3. Onglet Credentials:
   - Set Password: Test@123
   - Temporary: OFF
   
   Cliquer sur Set Password


ÉTAPE 5: Tester la connexion
---------------------------------------------------------
1. Fermez le port-forward (Ctrl+C dans le terminal)

2. Ouvrez votre navigateur sur: https://dev.lesaiglesbraves.online

3. Connectez-vous avec:
   Username: testuser
   Password: Test@123

Vous devriez être redirigé vers OCIS après l'authentification!

=============================================================================

"@ -ForegroundColor Cyan

Write-Host "`nVoulez-vous démarrer le port-forward maintenant? (Ctrl+C pour arrêter)" -ForegroundColor Yellow
Write-Host ""
kubectl port-forward -n owncloud svc/keycloak 8080:8080
