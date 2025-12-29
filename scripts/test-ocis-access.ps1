#!/usr/bin/env pwsh
# Script de test rapide pour OCIS

Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "    DIAGNOSTIC RAPIDE OCIS" -ForegroundColor Cyan
Write-Host "===============================================`n" -ForegroundColor Cyan

# Récupérer l'IP du LoadBalancer
Write-Host "[*] Vérification de l'infrastructure..." -ForegroundColor Yellow
$lbIP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null

if (-not $lbIP) {
    Write-Host "[!!] Impossible de récupérer l'IP du LoadBalancer" -ForegroundColor Red
    exit 1
}

Write-Host "   [OK] LoadBalancer IP: $lbIP" -ForegroundColor Green

# Vérifier les pods
Write-Host "`n[*] État des pods:" -ForegroundColor Yellow
kubectl get pods -n owncloud

# Test de connectivité
Write-Host "`n[*] Test de connectivité:" -ForegroundColor Yellow
$response = curl.exe -k -I -H "Host: dev.lesaiglesbraves.online" https://$lbIP/ 2>&1 | Select-String "HTTP/" | Select-Object -First 1

if ($response -match "200") {
    Write-Host "   [OK] Application accessible (HTTP 200 OK)" -ForegroundColor Green
} else {
    Write-Host "   [!!] Problème de connexion: $response" -ForegroundColor Red
}

# Vérifier DNS
Write-Host "`n[*] Vérification DNS:" -ForegroundColor Yellow
$dnsResult = nslookup dev.lesaiglesbraves.online 2>&1 | Select-String "Address:" | Select-Object -Last 1
Write-Host "   $dnsResult" -ForegroundColor White

# Récupérer le mot de passe admin
Write-Host "`n[*] Identifiants d'accès:" -ForegroundColor Cyan
$password = kubectl get secret ocis-secret -n owncloud -o jsonpath='{.data.admin-password}' 2>$null
if ($password) {
    $decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
    Write-Host "   URL: https://dev.lesaiglesbraves.online" -ForegroundColor Yellow
    Write-Host "   Utilisateur: admin" -ForegroundColor White
    Write-Host "   Mot de passe: $decodedPassword`n" -ForegroundColor White
}
