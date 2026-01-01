#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diagnose Grafana deployment issues in AKS cluster
.DESCRIPTION
    Checks Grafana pod status, service, ingress, and logs
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'prod'
)

$ErrorActionPreference = 'Continue'

Write-Host "🔍 Diagnosing Grafana in $Environment environment..." -ForegroundColor Cyan

# Get AKS credentials
$clusterName = "owncloud-aks-$Environment"
$resourceGroup = "owncloud-rg-$Environment"

Write-Host "`n📡 Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $resourceGroup --name $clusterName --overwrite-existing

Write-Host "`n=== Grafana Pods ===" -ForegroundColor Green
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o wide

Write-Host "`n=== Grafana Pod Details ===" -ForegroundColor Green
$grafanaPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>$null
if ($grafanaPod) {
    Write-Host "Pod: $grafanaPod"
    kubectl describe pod $grafanaPod -n monitoring | Select-String -Pattern "Status:|Ready:|Events:" -Context 0,5
} else {
    Write-Host "⚠️ No Grafana pod found!" -ForegroundColor Red
}

Write-Host "`n=== Grafana Service ===" -ForegroundColor Green
kubectl get svc -n monitoring -l app.kubernetes.io/name=grafana

Write-Host "`n=== Grafana Ingress ===" -ForegroundColor Green
kubectl get ingress -n monitoring

Write-Host "`n=== Grafana Ingress Details ===" -ForegroundColor Green
kubectl describe ingress -n monitoring | Select-String -Pattern "Host:|Backend:|Events:" -Context 0,3

Write-Host "`n=== Grafana Endpoints ===" -ForegroundColor Green
kubectl get endpoints -n monitoring -l app.kubernetes.io/name=grafana

Write-Host "`n=== Recent Grafana Logs ===" -ForegroundColor Green
if ($grafanaPod) {
    kubectl logs $grafanaPod -n monitoring --tail=30
} else {
    Write-Host "⚠️ Cannot get logs - pod not found" -ForegroundColor Red
}

Write-Host "`n=== Helm Release Status ===" -ForegroundColor Green
helm status prometheus -n monitoring 2>$null

Write-Host "`n=== All Monitoring Pods ===" -ForegroundColor Green
kubectl get pods -n monitoring -o wide

Write-Host "`n=== Certificate Status ===" -ForegroundColor Green
kubectl get certificate -n monitoring

Write-Host "`n✅ Diagnosis complete" -ForegroundColor Cyan
