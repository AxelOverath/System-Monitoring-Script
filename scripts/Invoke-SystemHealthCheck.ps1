<#
.SYNOPSIS
    Run a full system‐health check and store/report results.
.DESCRIPTION
    Loads configuration (and secrets), runs DataCollector jobs, displays metrics,
    persists to the database, evaluates thresholds, sends email alerts, and
    generates an HTML report via PSWriteHTML.
.PARAMETER ConfigPath
    Path to the Config.psd1 file.
.EXAMPLE
    .\Invoke-SystemHealthCheck.ps1 -ConfigPath .\config\Config.psd1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath
)

# 1. Load config
$Config = Import-PowerShellDataFile -Path $ConfigPath

# 1a. Load secrets (Database User/Password and SMTP credentials)
$secretsPath = Join-Path $PSScriptRoot '..\config\secrets.psd1'
if (Test-Path $secretsPath) {
    $secrets = Import-PowerShellDataFile -Path $secretsPath
    $Config.Database.User            = $secrets.DbUser
    $Config.Database.Password        = $secrets.DbPassword
    $Config.Email.SmtpUsername       = $secrets.SmtpUsername
    $Config.Email.SmtpPassword       = $secrets.SmtpPassword
}

# 2. Import modules
Import-Module (Join-Path $PSScriptRoot '..\modules\DataCollector.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\modules\Database.psm1')     -Force
Import-Module (Join-Path $PSScriptRoot '..\modules\Alerting.psm1')     -Force
Import-Module (Join-Path $PSScriptRoot '..\modules\SelfHealing.psm1')  -Force
# Import PSWriteHTML for reporting
try {
    $psWriteHTMLPath = "C:\Users\axelo\Documents\PowerShell\Modules\PSWriteHTML\1.38.0\PSWriteHTML.psd1"
    if (Test-Path $psWriteHTMLPath) {
        Import-Module $psWriteHTMLPath -Force -Global
        Write-Host "PSWriteHTML module loaded successfully from: $psWriteHTMLPath" -ForegroundColor Green
    } else {
        Import-Module PSWriteHTML -Force -Global
        Write-Host "PSWriteHTML module loaded successfully" -ForegroundColor Green
    }
} catch {
    Write-Warning "PSWriteHTML module not available. Install with: Install-Module PSWriteHTML -Scope CurrentUser"
}
Import-Module (Join-Path $PSScriptRoot '..\modules\Reporting.psm1')    -Force  


# 3. Load VM credentials
$vmList = Import-VMCredentials -Path (Join-Path $PSScriptRoot '..\config\vm_credentials.csv')

# 4. Start collection jobs
$jobs = Start-SystemMetricsJobs -VMList $vmList -MaxThreads $Config.Threading.MaxThreads

# 5. Retrieve job results
$metrics = Get-SystemMetricsFromJobs -Jobs $jobs

# 6. Display collected metrics
Write-Host "Collected system metrics:`n"
if ($metrics -and $metrics.Count -gt 0) {
    $metrics | Format-Table Server,CPUUsagePercent,MemoryUsagePercent,DiskUsagePercent,Timestamp -AutoSize
} else {
    Write-Warning "No metrics were collected from the configured VMs. Please check VM connectivity and credentials."
}

# 7. Save to database
if ($metrics -and $metrics.Count -gt 0) {
    try {
        Save-SystemMetrics -Metrics $metrics -DbConfig $Config.Database
        Write-Host "Metrics saved to database successfully" -ForegroundColor Green
    } catch {
        Write-Warning "Database operation failed but continuing with alerting and reporting"
    }
} else {
    Write-Host "No metrics to save to database" -ForegroundColor Yellow
}

# 8. Threshold-based alerts & notifications
if ($metrics -and $metrics.Count -gt 0) {
    $alerts = Evaluate-Thresholds -Metrics $metrics -Thresholds $Config
    Write-Host "Generated $(@($alerts).Count) alert(s) from metrics" -ForegroundColor Cyan
    
    if (@($alerts).Count -gt 0) {
        $alerts | Format-Table Server,Metric,Value,Threshold -AutoSize
        Send-Alerts -Alerts $alerts -Config $Config
    } else {
        Write-Host "No threshold violations detected" -ForegroundColor Green
    }

    # 8a. Self-healing actions for threshold violations
    if ($Config.ContainsKey('SelfHealing') -and $Config.SelfHealing.Enabled -and @($alerts).Count -gt 0) {
        Write-Host "Evaluating self-healing triggers for $(@($alerts).Count) alert(s)..." -ForegroundColor Green
        $auditResults = Invoke-SelfHealing -Alerts @($alerts) -VMList $vmList -Config $Config
        
        if (@($auditResults).Count -gt 0) {
            Write-Host "Self-healing actions completed:" -ForegroundColor Green
            $auditResults | Format-Table Timestamp,Server,Metric,Value,ActionType,Success -AutoSize
        }
    } else {
        if (-not ($Config.ContainsKey('SelfHealing') -and $Config.SelfHealing.Enabled)) {
            Write-Host "SelfHealing is disabled in configuration" -ForegroundColor Yellow
        } elseif (@($alerts).Count -eq 0) {
            Write-Host "No alerts to trigger SelfHealing" -ForegroundColor Green
        }
    }
} else {
    Write-Host "No metrics available for threshold evaluation" -ForegroundColor Yellow
}

# 9. Generate HTML report (if enabled and metrics are available)
if ($metrics -and $metrics.Count -gt 0) {
    $reportEnabled = $true
    $reportPath    = Join-Path $PSScriptRoot '..\temp\SystemHealthReport.html'
    $reportOpen    = $false

    if ($Config.ContainsKey('Report')) {
        if ($null -ne $Config.Report.Enabled) { $reportEnabled = [bool]$Config.Report.Enabled }
        if ($Config.Report.OutputPath)        { $reportPath    = $Config.Report.OutputPath }
        if ($null -ne $Config.Report.Open)    { $reportOpen    = [bool]$Config.Report.Open }
    }

    if ($reportEnabled) {
        # Ensure output folder exists
        $outDir = Split-Path -Path $reportPath -Parent
        if ($outDir -and -not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }

        Generate-SystemReport -Metrics $metrics -Config $Config -OutputPath $reportPath -Open:$reportOpen
        Write-Host "HTML report written to: $reportPath" -ForegroundColor Green

    }
} else {
    Write-Host "No metrics available for report generation" -ForegroundColor Yellow
}

Write-Host "`nSystem health check completed!" -ForegroundColor Green
