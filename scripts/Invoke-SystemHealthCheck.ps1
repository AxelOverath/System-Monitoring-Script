<#
.SYNOPSIS
    Run a full system‐health check (partial, DataCollector only using jobs).
.DESCRIPTION
    Loads configuration, imports DataCollector, loads VM credentials, starts metric jobs,
    retrieves metrics, and displays results. Other steps (DB, alerting, reporting) are
    commented out until implemented.
.PARAMETER ConfigPath
    Path to the Config.psd1 file.
.EXAMPLE
    .\Invoke-SystemHealthCheck.ps1 -ConfigPath .\config\Config.psd1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath
)

# 1. Load config without emitting to pipeline
#    Import-PowerShellDataFile returns the hashtable from the .psd1
$Config = Import-PowerShellDataFile -Path $ConfigPath

# 1a. Load secrets if present
$secretsPath = Join-Path $PSScriptRoot '..\config\secrets.psd1'
if (Test-Path $secretsPath) {
    $secrets = Import-PowerShellDataFile -Path $secretsPath
    # Merge just the DB creds into $Config
    $Config.DbUser     = $secrets.DbUser
    $Config.DbPassword = $secrets.DbPassword
}

# 2. Import DataCollector module (with job functions)
Import-Module "$PSScriptRoot\..\modules\DataCollector.psm1"

# 3. Load VM credentials from CSV
#    CSV must have headers: Server,Username,KeyPath,Port
$vmList = Import-VMCredentials -Path "$PSScriptRoot\..\config\vm_credentials.csv"

# 4. Start collection jobs
$jobs = Start-SystemMetricsJobs -VMList $vmList

# 5. Retrieve job results
$metrics = Get-SystemMetricsFromJobs -Jobs $jobs

# Display results
Write-Host "Collected system metrics:`n"
$metrics | Format-Table Server,CPUUsagePercent,MemoryUsagePercent,DiskUsagePercent,Timestamp -AutoSize

# 6. Import additional modules
 Import-Module "$PSScriptRoot\..\modules\Database.psm1"
 # Import-Module "$PSScriptRoot\..\modules\Alerting.psm1"
 # Import-Module "$PSScriptRoot\..\modules\SelfHealing.psm1"
 # Import-Module "$PSScriptRoot\..\modules\Reporting.psm1"

# 7. Store to DB
 Save-SystemMetrics -Metrics $metrics -DbConfig $Config


## --- Further steps (commented out) ---
# 8. Evaluate alerts
# $alerts = Evaluate-Thresholds -Metrics $metrics -Thresholds $Config
#
# 9. Notify & remediate
# Send-Alerts -Alerts $alerts -Config $Config
# Invoke-SelfHealing -Alerts $alerts -Config $Config
#
# 10. Generate report
# Generate-SystemReport -Metrics $metrics -OutputFolder (Join-Path $PSScriptRoot '../temp')
