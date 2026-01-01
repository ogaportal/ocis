# Backup and Restore OCIS Users
# This script helps backup user data from OCIS for disaster recovery

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('backup', 'restore', 'list')]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$BackupFile
)

# Environment configuration
if ($Environment -eq 'prod') {
    $ResourceGroup = 'owncloud-rg-prod'
    $ClusterName = 'owncloud-aks-prod'
} else {
    $ResourceGroup = 'owncloud-rg-dev'
    $ClusterName = 'owncloud-aks-dev'
}

Write-Host "=== OCIS User Backup/Restore - $Environment ===" -ForegroundColor Cyan

# Connect to cluster
Write-Host "`nConnecting to $ClusterName..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing | Out-Null

# Get OCIS pod name
$podName = kubectl get pod -n owncloud -l app=ocis -o jsonpath="{.items[0].metadata.name}"
if (-not $podName) {
    Write-Host "ERROR: No OCIS pod found!" -ForegroundColor Red
    exit 1
}

Write-Host "OCIS Pod: $podName" -ForegroundColor White

switch ($Action) {
    'backup' {
        if (-not $BackupFile) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $BackupFile = "ocis-backup-$Environment-$timestamp.tar.gz"
        }
        
        Write-Host "`nCreating backup of OCIS data..." -ForegroundColor Yellow
        Write-Host "Backup file: $BackupFile" -ForegroundColor White
        
        # Create tar archive inside the pod
        kubectl exec -n owncloud $podName -- tar czf /tmp/ocis-backup.tar.gz -C /var/lib/ocis .
        
        # Copy to local machine
        kubectl cp owncloud/${podName}:/tmp/ocis-backup.tar.gz $BackupFile
        
        # Clean up
        kubectl exec -n owncloud $podName -- rm /tmp/ocis-backup.tar.gz
        
        $fileSize = (Get-Item $BackupFile).Length / 1MB
        Write-Host "`n✓ Backup completed successfully!" -ForegroundColor Green
        Write-Host "  File: $BackupFile" -ForegroundColor White
        Write-Host "  Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White
        
        Write-Host "`nBackup includes:" -ForegroundColor Cyan
        Write-Host "  • IDM (user database)" -ForegroundColor White
        Write-Host "  • Storage (user files)" -ForegroundColor White
        Write-Host "  • IDP (identity provider)" -ForegroundColor White
        Write-Host "  • NATS (messaging)" -ForegroundColor White
    }
    
    'restore' {
        if (-not $BackupFile -or -not (Test-Path $BackupFile)) {
            Write-Host "ERROR: Backup file not found: $BackupFile" -ForegroundColor Red
            Write-Host "Usage: -Action restore -BackupFile <path-to-backup.tar.gz>" -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "`n⚠️  WARNING: This will overwrite all current OCIS data!" -ForegroundColor Yellow
        Write-Host "Backup file: $BackupFile" -ForegroundColor White
        $confirm = Read-Host "Type 'YES' to continue"
        
        if ($confirm -ne 'YES') {
            Write-Host "Restore cancelled." -ForegroundColor Yellow
            exit 0
        }
        
        Write-Host "`nRestoring OCIS data..." -ForegroundColor Yellow
        
        # Copy backup to pod
        kubectl cp $BackupFile owncloud/${podName}:/tmp/ocis-backup.tar.gz
        
        # Stop OCIS services (optional, depends on your setup)
        # kubectl exec -n owncloud $podName -- pkill ocis
        
        # Extract backup
        kubectl exec -n owncloud $podName -- sh -c "cd /var/lib/ocis && rm -rf * && tar xzf /tmp/ocis-backup.tar.gz"
        
        # Clean up
        kubectl exec -n owncloud $podName -- rm /tmp/ocis-backup.tar.gz
        
        Write-Host "`n✓ Restore completed!" -ForegroundColor Green
        Write-Host "⚠️  You may need to restart the OCIS pod for changes to take effect:" -ForegroundColor Yellow
        Write-Host "   kubectl delete pod -n owncloud $podName" -ForegroundColor White
    }
    
    'list' {
        Write-Host "`nCurrent OCIS data directories:" -ForegroundColor Yellow
        kubectl exec -n owncloud $podName -- ls -lh /var/lib/ocis/
        
        Write-Host "`nStorage usage:" -ForegroundColor Yellow
        kubectl exec -n owncloud $podName -- du -sh /var/lib/ocis/*
    }
}

Write-Host ""
