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

# 1a. Load secrets (DbUser/DbPassword and SMTP credentials)
$secretsPath = Join-Path $PSScriptRoot '..\config\secrets.psd1'
if (Test-Path $secretsPath) {
    $secrets = Import-PowerShellDataFile -Path $secretsPath
    $Config.DbUser       = $secrets.DbUser
    $Config.DbPassword   = $secrets.DbPassword
    $Config.SmtpUsername = $secrets.SmtpUsername
    $Config.SmtpPassword = $secrets.SmtpPassword
}

# 2. Import modules
Import-Module (Join-Path $PSScriptRoot '..\modules\DataCollector.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\modules\Database.psm1')     -Force
Import-Module (Join-Path $PSScriptRoot '..\modules\Alerting.psm1')     -Force
Import-Module (Join-Path $PSScriptRoot '..\modules\Reporting.psm1')    -Force

# 3. Load VM credentials
$vmList = Import-VMCredentials -Path (Join-Path $PSScriptRoot '..\config\vm_credentials.csv')

# 4. Start collection jobs
$jobs = Start-SystemMetricsJobs -VMList $vmList -MaxThreads $Config.MaxThreads

# 5. Retrieve job results
$metrics = Get-SystemMetricsFromJobs -Jobs $jobs

# 6. Display collected metrics
Write-Host "Collected system metrics:`n"
$metrics | Format-Table Server,CPUUsagePercent,MemoryUsagePercent,DiskUsagePercent,Timestamp -AutoSize

# 7. Persist to database
Save-SystemMetrics -Metrics $metrics -DbConfig $Config

# 8. Threshold-based alerts & notifications
$alerts = Evaluate-Thresholds -Metrics $metrics -Thresholds $Config
Send-Alerts -Alerts $alerts -Config $Config

# 9. Generate HTML report (PSWriteHTML)
#    Uses Config.Report if present; otherwise falls back to defaults.
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
    Write-Host "HTML report written to: $reportPath"
}
