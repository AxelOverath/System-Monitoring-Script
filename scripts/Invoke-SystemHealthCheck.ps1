<#
.SYNOPSIS
    Run a full system‐health check and report (partial, DataCollector only).
.DESCRIPTION
    Loads configuration, imports DataCollector, loads VM credentials, collects metrics,
    and displays results. Other steps (DB, alerting, reporting) are commented out until implemented.
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
. "$ConfigPath"

# 2. Import DataCollector module
Import-Module "$PSScriptRoot\..\modules\DataCollector.psm1"

# 3. [Optional] Import VM credentials module if separate
# (already part of DataCollector)
# # Import-Module "$PSScriptRoot\..\modules\Credentials.psm1"

# 4. Load VM credentials from CSV
# Adjust path as needed; CSV must have headers: Server,Username,Password,KeyPath
$vmCreds = Import-VMCredentials -Path "$PSScriptRoot\..\config\vm_credentials.csv"

# 5. Collect metrics (DataCollector)
$metrics = Collect-SystemMetrics -VMList $vmCreds -Threads $Config:MaxThreads

# Display results
Write-Host "Collected system metrics:`n"
$metrics | Format-Table -AutoSize

# --- Further steps (commented out) ---
# 6. Import additional modules
# Import-Module "$PSScriptRoot\..\modules\Database.psm1"
# Import-Module "$PSScriptRoot\..\modules\Alerting.psm1"
# Import-Module "$PSScriptRoot\..\modules\SelfHealing.psm1"
# Import-Module "$PSScriptRoot\..\modules\Reporting.psm1"

# 7. Store to DB
# Save-MetricsToDatabase -Data $metrics -ConnectionString $Config:DbServer

# 8. Evaluate alerts
# $alerts = Evaluate-Thresholds -Metrics $metrics -Thresholds $Config

# 9. Notify & remediate
# Send-Alerts -Alerts $alerts -Config $Config
# Invoke-SelfHealing -Alerts $alerts -Config $Config

# 10. Generate report
# Generate-SystemReport -Metrics $metrics -OutputFolder (Join-Path $PSScriptRoot '../temp')
