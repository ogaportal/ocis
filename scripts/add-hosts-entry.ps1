#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ajoute une entrée au fichier hosts Windows
.DESCRIPTION
    Ajoute l'IP du LoadBalancer OCIS au fichier hosts pour contourner le DNS
#>

param(
    [string]$IP = "172.199.208.226",
    [string]$Hostname = "dev.lesaiglesbraves.online"
)

# Vérifier les privilèges administrateur
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ Ce script nécessite les privilèges administrateur" -ForegroundColor Red
    Write-Host "`n💡 Relancez PowerShell en tant qu'administrateur:" -ForegroundColor Yellow
    Write-Host "   1. Clic droit sur PowerShell" -ForegroundColor White
    Write-Host "   2. 'Exécuter en tant qu'administrateur'" -ForegroundColor White
    Write-Host "   3. Exécutez: .\scripts\add-hosts-entry.ps1`n" -ForegroundColor White
    exit 1
}

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$entry = "$IP $Hostname"

Write-Host "=== Configuration du fichier hosts ===" -ForegroundColor Cyan

# Vérifier si l'entrée existe déjà
$content = Get-Content $hostsPath -ErrorAction SilentlyContinue
$existingEntry = $content | Select-String -Pattern $Hostname

if ($existingEntry) {
    Write-Host "`n⚠️  Une entrée pour '$Hostname' existe déjà:" -ForegroundColor Yellow
    Write-Host "   $existingEntry" -ForegroundColor Gray
    
    $replace = Read-Host "`nVoulez-vous la remplacer? (o/N)"
    if ($replace -eq 'o' -or $replace -eq 'O') {
        # Supprimer l'ancienne entrée
        $newContent = $content | Where-Object { $_ -notmatch $Hostname }
        $newContent | Set-Content $hostsPath -Force
        Write-Host "✓ Ancienne entrée supprimée" -ForegroundColor Green
    } else {
        Write-Host "❌ Opération annulée" -ForegroundColor Red
        exit 0
    }
}

# Ajouter la nouvelle entrée
Add-Content -Path $hostsPath -Value "`n# OCIS Development - Ajouté le $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -Force
Add-Content -Path $hostsPath -Value $entry -Force

Write-Host "`n✓ Entrée ajoutée avec succès!" -ForegroundColor Green
Write-Host "  $entry`n" -ForegroundColor White

# Vider le cache DNS
Write-Host "=== Vidage du cache DNS ===" -ForegroundColor Cyan
ipconfig /flushdns | Out-Null
Write-Host "✓ Cache DNS vidé`n" -ForegroundColor Green

# Vérifier l'entrée
Write-Host "=== Vérification ===" -ForegroundColor Cyan
$result = Get-Content $hostsPath | Select-String $Hostname
Write-Host $result -ForegroundColor White

Write-Host "`n✅ Configuration terminée!" -ForegroundColor Green
Write-Host "`n📋 Vous pouvez maintenant accéder à OCIS via:" -ForegroundColor Cyan
Write-Host "   https://$Hostname`n" -ForegroundColor Yellow
Write-Host "🔐 Identifiants:" -ForegroundColor Cyan
Write-Host "   Utilisateur: admin" -ForegroundColor White
Write-Host "   Mot de passe: ZIGPz/7gqXIL4vi2Ep2yqDmp37CtjEvH`n" -ForegroundColor White
