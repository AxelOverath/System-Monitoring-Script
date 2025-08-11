<#
.SYNOPSIS
    Comprehensive SelfHealing functionality test
.DESCRIPTION
    Loads configuration, attempts real data collection, evaluates thresholds, and tests SelfHealing with both real and mock data
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath
)

# 1. Load config
$Config = Import-PowerShellDataFile -Path $ConfigPath

# 1a. Load secrets
$secretsPath = Join-Path $PSScriptRoot '..\config\secrets.psd1'
if (Test-Path $secretsPath) {
    $secrets = Import-PowerShellDataFile -Path $secretsPath
    $Config.Database.User            = $secrets.DbUser
    $Config.Database.Password        = $secrets.DbPassword
    $Config.Email.SmtpUsername       = $secrets.SmtpUsername
    $Config.Email.SmtpPassword       = $secrets.SmtpPassword
}

# 2. Import necessary modules (skip Reporting to avoid syntax errors)
Import-Module (Join-Path $PSScriptRoot '..\modules\DataCollector.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\modules\Alerting.psm1')     -Force
Import-Module (Join-Path $PSScriptRoot '..\modules\SelfHealing.psm1') -Force

# 3. Load VM credentials
$vmList = Import-VMCredentials -Path (Join-Path $PSScriptRoot '..\config\vm_credentials.csv')

Write-Host "=== Comprehensive SelfHealing Test ==="
Write-Host "VM Count: $($vmList.Count)"
Write-Host "VMs: $($vmList.Server -join ', ')"
Write-Host ""

# 4. Try to collect real data first
Write-Host "Attempting real data collection..."
$jobs = Start-SystemMetricsJobs -VMList $vmList -MaxThreads $Config.Threading.MaxThreads
$metrics = Get-SystemMetricsFromJobs -Jobs $jobs

if ($metrics -and $metrics.Count -gt 0) {
    Write-Host "[SUCCESS] Real metrics collected from $($metrics.Count) server(s)"
    $metrics | Format-Table Server,CPUUsagePercent,MemoryUsagePercent,DiskUsagePercent,Timestamp -AutoSize
    
    # Evaluate real thresholds
    $alerts = Evaluate-Thresholds -Metrics $metrics -Thresholds $Config
    
    if ($alerts.Count -gt 0) {
        Write-Host "[ALERT] Found $($alerts.Count) real alert(s):"
        $alerts | Format-Table Server,Metric,Value,Threshold -AutoSize
        
        # Test SelfHealing with real alerts
        if ($Config.ContainsKey('SelfHealing') -and $Config.SelfHealing.Enabled) {
            Write-Host "[HEALING] Executing SelfHealing actions..."
            $auditResults = Invoke-SelfHealing -Alerts $alerts -VMList $vmList -Config $Config
            
            if ($auditResults.Count -gt 0) {
                Write-Host "[SUCCESS] SelfHealing actions executed:"
                $auditResults | Format-Table Timestamp,Server,Metric,Value,ActionType,Success -AutoSize
            }
        }
    } else {
        Write-Host "[OK] No threshold violations detected in real data"
    }
} else {
    Write-Host "[FALLBACK] Real data collection failed. Using mock data for SelfHealing test..."
    
    # Create mock data with your 94% disk usage scenario
    $mockMetrics = @(
        [PSCustomObject]@{
            Server              = 'localhost'
            CPUUsagePercent     = 25
            MemoryUsagePercent  = 45
            DiskUsagePercent    = 94  # Your high disk usage VM
            Timestamp           = Get-Date
        }
    )
    
    Write-Host "[MOCK] Mock metrics:"
    $mockMetrics | Format-Table Server,CPUUsagePercent,MemoryUsagePercent,DiskUsagePercent,Timestamp -AutoSize
    
    # Evaluate mock thresholds
    $alerts = Evaluate-Thresholds -Metrics $mockMetrics -Thresholds $Config
    $alertCount = @($alerts).Count
    
    if ($alertCount -gt 0) {
        Write-Host "[ALERT] Found $alertCount alert(s) from mock data:"
        $alerts | Format-Table Server,Metric,Value,Threshold -AutoSize
        
        # Test SelfHealing with mock alerts  
        if ($Config.ContainsKey('SelfHealing') -and $Config.SelfHealing.Enabled) {
            Write-Host "[HEALING] Executing SelfHealing actions..."
            $auditResults = Invoke-SelfHealing -Alerts @($alerts) -VMList $vmList -Config $Config
            
            if (@($auditResults).Count -gt 0) {
                Write-Host "[SUCCESS] SelfHealing actions executed:"
                $auditResults | Format-Table Timestamp,Server,Metric,Value,ActionType,Success -AutoSize
            }
        }
    } else {
        Write-Host "[INFO] No alerts generated from mock data"
    }
}

Write-Host ""
Write-Host "=== Test Completed ==="
