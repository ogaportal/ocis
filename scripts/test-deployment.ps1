# Script de test pour valider la configuration avant de pusher
# Usage: .\scripts\test-deployment.ps1 -Environment dev|prod

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod", "both")]
    [string]$Environment = "both"
)

Write-Host "=== Test de configuration oCIS ===" -ForegroundColor Cyan
Write-Host ""

function Test-KustomizationFile {
    param([string]$Env)
    
    Write-Host "Testing $Env environment..." -ForegroundColor Yellow
    
    $kustomizationPath = "k8s\overlays\$Env\kustomization.yaml"
    
    if (!(Test-Path $kustomizationPath)) {
        Write-Host "  [FAIL] File not found: $kustomizationPath" -ForegroundColor Red
        return $false
    }
    
    $content = Get-Content -Path $kustomizationPath -Raw
    
    # Vérifier que le placeholder existe
    if ($content -match '__ADMIN_PASSWORD__') {
        Write-Host "  [OK] Placeholder __ADMIN_PASSWORD__ found" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Placeholder __ADMIN_PASSWORD__ NOT found" -ForegroundColor Red
        Write-Host "        The kustomization.yaml should contain: admin-password=__ADMIN_PASSWORD__" -ForegroundColor Yellow
        return $false
    }
    
    # Vérifier qu'il n'y a pas de mot de passe en clair
    if ($content -match 'admin-password=(?!__ADMIN_PASSWORD__)\w+') {
        Write-Host "  [FAIL] Plain text password found in kustomization.yaml!" -ForegroundColor Red
        Write-Host "        NEVER commit passwords in clear text!" -ForegroundColor Yellow
        return $false
    } else {
        Write-Host "  [OK] No plain text password found" -ForegroundColor Green
    }
    
    # Tester que kustomize peut builder
    Write-Host "  Testing kustomize build..." -ForegroundColor Gray
    $tempFile = [System.IO.Path]::GetTempFileName()
    
    try {
        # Remplacer le placeholder pour le test
        $testContent = $content -replace '__ADMIN_PASSWORD__', 'TestPassword123'
        $testDir = "k8s\overlays\$Env-test"
        
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        $testContent | Set-Content -Path "$testDir\kustomization.yaml" -NoNewline
        
        kubectl kustomize $testDir > $tempFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Kustomize build successful" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Kustomize build failed" -ForegroundColor Red
            Get-Content $tempFile | Write-Host -ForegroundColor Red
            return $false
        }
        
        Remove-Item -Path $testDir -Recurse -Force
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }
    
    Write-Host "  [SUCCESS] $Env environment configuration is valid" -ForegroundColor Green
    Write-Host ""
    return $true
}

function Test-ScriptExists {
    Write-Host "Checking deployment script..." -ForegroundColor Yellow
    
    if (Test-Path "scripts\deploy-with-password.ps1") {
        Write-Host "  [OK] deploy-with-password.ps1 exists" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] deploy-with-password.ps1 not found" -ForegroundColor Red
        return $false
    }
    
    Write-Host ""
    return $true
}

function Show-GitHubSecretsReminder {
    Write-Host "=== GitHub Secrets Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Before pushing to GitHub, make sure you have configured these secrets:" -ForegroundColor Yellow
    Write-Host "  1. Go to: Settings → Secrets and variables → Actions" -ForegroundColor White
    Write-Host "  2. Create these secrets:" -ForegroundColor White
    Write-Host "     - OCIS_ADMIN_PASSWORD_DEV" -ForegroundColor Green
    Write-Host "     - OCIS_ADMIN_PASSWORD_PROD" -ForegroundColor Green
    Write-Host ""
    Write-Host "Without these secrets, the pipeline will FAIL!" -ForegroundColor Red
    Write-Host ""
}

# Run tests
$allPassed = $true

if (!( Test-ScriptExists)) {
    $allPassed = $false
}

if ($Environment -eq "both" -or $Environment -eq "dev") {
    if (!(Test-KustomizationFile -Env "dev")) {
        $allPassed = $false
    }
}

if ($Environment -eq "both" -or $Environment -eq "prod") {
    if (!(Test-KustomizationFile -Env "prod")) {
        $allPassed = $false
    }
}

Show-GitHubSecretsReminder

if ($allPassed) {
    Write-Host "=== ALL TESTS PASSED ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now:" -ForegroundColor Cyan
    Write-Host "  1. Commit your changes: git add . && git commit -m 'feat: Secure password management'" -ForegroundColor White
    Write-Host "  2. Push to GitHub: git push" -ForegroundColor White
    Write-Host "  3. The pipeline will deploy automatically" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host "=== TESTS FAILED ===" -ForegroundColor Red
    Write-Host "Please fix the issues above before committing" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
