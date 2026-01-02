# Manage AKS Clusters - Start/Stop/Status
# This script helps reduce Azure costs by stopping clusters when not in use

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('start', 'stop', 'status', 'start-all', 'stop-all')]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'prod', 'all')]
    [string]$Environment = 'all'
)

# Cluster configurations
$clusters = @{
    'dev' = @{
        ResourceGroup = 'owncloud-rg-dev'
        ClusterName = 'owncloud-aks-dev'
        Description = 'Development Environment'
    }
    'prod' = @{
        ResourceGroup = 'owncloud-rg-prod'
        ClusterName = 'owncloud-aks-prod'
        Description = 'Production Environment'
    }
}

function Get-ClusterStatus {
    param($ResourceGroup, $ClusterName)
    
    $result = az aks show --resource-group $ResourceGroup --name $ClusterName --query "{powerState:powerState.code, provisioningState:provisioningState}" -o json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        return @{powerState="ERROR"; provisioningState="ERROR"}
    }
    
    return ($result | ConvertFrom-Json)
}

function Stop-AKSCluster {
    param($ResourceGroup, $ClusterName, $Description)
    
    Write-Host "`n[$ClusterName] Stopping $Description..." -ForegroundColor Yellow
    
    $status = Get-ClusterStatus -ResourceGroup $ResourceGroup -ClusterName $ClusterName
    
    if ($status.powerState -eq "ERROR") {
        Write-Host "  ✗ Error getting cluster status" -ForegroundColor Red
        return
    }
    
    # Check if already stopped
    if ($status.powerState -eq "Stopped" -and $status.provisioningState -eq "Succeeded") {
        Write-Host "  ✓ Already stopped" -ForegroundColor Gray
        return
    }
    
    # Check if stop operation is in progress
    if ($status.powerState -eq "Stopped" -and $status.provisioningState -eq "Stopping") {
        Write-Host "  ⏳ Stop operation already in progress..." -ForegroundColor Cyan
        Write-Host "  Wait 1-2 minutes for it to complete" -ForegroundColor White
        return
    }
    
    # Check if any other operation is in progress
    if ($status.provisioningState -ne "Succeeded") {
        Write-Host "  ⏳ Cluster is busy (state: $($status.provisioningState))" -ForegroundColor Yellow
        Write-Host "  Wait for current operation to complete" -ForegroundColor White
        return
    }
    
    Write-Host "  Current status: $($status.powerState)" -ForegroundColor White
    Write-Host "  Stopping cluster (this may take 2-3 minutes)..." -ForegroundColor Yellow
    
    $ErrorActionPreference = "Continue"
    az aks stop --resource-group $ResourceGroup --name $ClusterName --no-wait 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Stop command sent successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to stop cluster" -ForegroundColor Red
        az aks stop --resource-group $ResourceGroup --name $ClusterName --no-wait
    }
}

function Start-AKSCluster {
    param($ResourceGroup, $ClusterName, $Description)
    
    Write-Host "`n[$ClusterName] Starting $Description..." -ForegroundColor Yellow
    
    $status = Get-ClusterStatus -ResourceGroup $ResourceGroup -ClusterName $ClusterName
    
    if ($status.powerState -eq "ERROR") {
        Write-Host "  ✗ Error getting cluster status" -ForegroundColor Red
        return
    }
    
    # Check if already running
    if ($status.powerState -eq "Running" -and $status.provisioningState -eq "Succeeded") {
        Write-Host "  ✓ Already running" -ForegroundColor Gray
        return
    }
    
    # Check if start operation is in progress
    if ($status.powerState -eq "Running" -and $status.provisioningState -eq "Starting") {
        Write-Host "  ⏳ Start operation already in progress..." -ForegroundColor Cyan
        Write-Host "  Wait 5-7 minutes for it to complete" -ForegroundColor White
        return
    }
    
    # Check if any other operation is in progress
    if ($status.provisioningState -ne "Succeeded") {
        Write-Host "  ⏳ Cluster is busy (state: $($status.provisioningState))" -ForegroundColor Yellow
        Write-Host "  Wait for current operation to complete" -ForegroundColor White
        return
    }
    
    Write-Host "  Current status: $($status.powerState)" -ForegroundColor White
    Write-Host "  Starting cluster (this may take 5-7 minutes)..." -ForegroundColor Yellow
    
    $ErrorActionPreference = "Continue"
    az aks start --resource-group $ResourceGroup --name $ClusterName --no-wait 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Start command sent successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to start cluster" -ForegroundColor Red
        az aks start --resource-group $ResourceGroup --name $ClusterName --no-wait
    }
}

function Show-ClusterStatus {
    param($ResourceGroup, $ClusterName, $Description)
    
    $status = Get-ClusterStatus -ResourceGroup $ResourceGroup -ClusterName $ClusterName
    
    $powerStateColor = switch ($status.powerState) {
        "Running" { "Green" }
        "Stopped" { "Yellow" }
        "ERROR" { "Red" }
        default { "Gray" }
    }
    
    Write-Host "  [$ClusterName] " -NoNewline -ForegroundColor White
    Write-Host "$Description" -NoNewline -ForegroundColor Gray
    Write-Host " → " -NoNewline
    Write-Host "$($status.powerState)" -ForegroundColor $powerStateColor
    
    # Show provisioning state if not Succeeded
    if ($status.provisioningState -ne "Succeeded" -and $status.provisioningState -ne "ERROR") {
        Write-Host "    State: $($status.provisioningState)" -ForegroundColor Cyan
    }
    
    if ($status.powerState -eq "Running" -and $status.provisioningState -eq "Succeeded") {
        # Get node count
        $nodeCount = az aks show --resource-group $ResourceGroup --name $ClusterName --query "agentPoolProfiles[0].count" -o tsv 2>$null
        if ($nodeCount) {
            Write-Host "    Nodes: $nodeCount" -ForegroundColor Gray
        }
    }
}

function Get-EstimatedCost {
    param($Status)
    
    # Rough estimates (adjust based on your VM SKUs)
    # Standard_D2s_v3 ~ $70/month per node
    $devNodes = 2
    $prodNodes = 2
    $costPerNodePerMonth = 70
    
    if ($Status -eq "Running") {
        $totalCost = ($devNodes + $prodNodes) * $costPerNodePerMonth
        return $totalCost
    } else {
        return 0
    }
}

# Main script
Write-Host "
================================================================
         AKS Cluster Management - Cost Optimization
================================================================
" -ForegroundColor Cyan

# Determine which clusters to process
$clustersToProcess = @()
if ($Environment -eq 'all' -or $Action -like '*-all') {
    $clustersToProcess = @('dev', 'prod')
} else {
    $clustersToProcess = @($Environment)
}

switch -Wildcard ($Action) {
    'stop*' {
        Write-Host "WARNING: Stopping AKS Clusters" -ForegroundColor Yellow
        Write-Host "This will stop all running nodes and save costs." -ForegroundColor White
        Write-Host ""
        
        foreach ($env in $clustersToProcess) {
            $cluster = $clusters[$env]
            Stop-AKSCluster -ResourceGroup $cluster.ResourceGroup -ClusterName $cluster.ClusterName -Description $cluster.Description
        }
        
        Write-Host "`n[NOTE] Cost Impact:" -ForegroundColor Cyan
        Write-Host "   When stopped, you only pay for:" -ForegroundColor White
        Write-Host "   • Disk storage (PVCs) - ~`$10-20/month" -ForegroundColor Gray
        Write-Host "   • Azure managed services (minimal)" -ForegroundColor Gray
        Write-Host "`n   Estimated monthly savings: ~`$140-280" -ForegroundColor Green
        Write-Host "`n[NOTE] Stop operations are asynchronous" -ForegroundColor Yellow
        Write-Host "   Use 'status' action in a few minutes to verify" -ForegroundColor White
    }
    
    'start*' {
        Write-Host "STARTING AKS Clusters" -ForegroundColor Green
        Write-Host ""
        
        foreach ($env in $clustersToProcess) {
            $cluster = $clusters[$env]
            Start-AKSCluster -ResourceGroup $cluster.ResourceGroup -ClusterName $cluster.ClusterName -Description $cluster.Description
        }
        
        Write-Host "`n[NOTE] Start operations take 5-7 minutes" -ForegroundColor Yellow
        Write-Host "   Use 'status' action to monitor progress" -ForegroundColor White
        Write-Host "`n[INFO] After clusters start:" -ForegroundColor Cyan
        Write-Host "   • All pods will restart automatically" -ForegroundColor White
        Write-Host "   • PVCs are preserved (data safe)" -ForegroundColor White
        Write-Host "   • Services will be accessible in ~10 minutes" -ForegroundColor White
    }
    
    'status' {
        Write-Host "Cluster Status" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($env in $clustersToProcess) {
            $cluster = $clusters[$env]
            Show-ClusterStatus -ResourceGroup $cluster.ResourceGroup -ClusterName $cluster.ClusterName -Description $cluster.Description
        }
        
        Write-Host "`n[COST] Estimation:" -ForegroundColor Cyan
        
        $allStopped = $true
        foreach ($env in @('dev', 'prod')) {
            $cluster = $clusters[$env]
            $status = Get-ClusterStatus -ResourceGroup $cluster.ResourceGroup -ClusterName $cluster.ClusterName
            if ($status -eq "Running") {
                $allStopped = $false
                break
            }
        }
        
        if ($allStopped) {
            Write-Host "   Current: ~`$20/month (storage only)" -ForegroundColor Green
            Write-Host "   If started: ~`$280/month" -ForegroundColor Yellow
        } else {
            Write-Host "   Current: ~`$280/month (running)" -ForegroundColor Yellow
            Write-Host "   If stopped: ~`$20/month (storage only)" -ForegroundColor Green
            Write-Host "`n   [TIP] Potential savings: ~`$260/month" -ForegroundColor Cyan
        }
    }
}

Write-Host "

===============================================================

[USAGE] Examples:

  # Stop all clusters (save costs)
  .\scripts\manage-aks-clusters.ps1 -Action stop-all

  # Stop only dev
  .\scripts\manage-aks-clusters.ps1 -Action stop -Environment dev

  # Start all clusters
  .\scripts\manage-aks-clusters.ps1 -Action start-all

  # Check status
  .\scripts\manage-aks-clusters.ps1 -Action status

===============================================================
" -ForegroundColor Gray

Write-Host ""
