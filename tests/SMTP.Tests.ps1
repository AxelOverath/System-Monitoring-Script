# Test SMTP Configuration
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\config.psd1")
)

# Load config and secrets
Write-Host "Looking for config file at: $ConfigPath"
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found at: $ConfigPath"
    exit 1
}

$Config = Import-PowerShellDataFile -Path $ConfigPath
$secretsPath = Join-Path $PSScriptRoot '..\config\secrets.psd1'
Write-Host "Looking for secrets file at: $secretsPath"
if (Test-Path $secretsPath) {
    Write-Host "Secrets file found, loading..."
    $secrets = Import-PowerShellDataFile -Path $secretsPath
    $Config.SmtpUsername = $secrets.SmtpUsername
    $Config.SmtpPassword = $secrets.SmtpPassword
    Write-Host "Loaded username: $($secrets.SmtpUsername)"
} else {
    Write-Warning "Secrets file not found at: $secretsPath"
}

# Import alerting module
Import-Module (Join-Path $PSScriptRoot "..\modules\Alerting.psm1") -Force

# Create a test alert
$testAlert = [PSCustomObject]@{
    Server    = 'TEST-SERVER'
    Metric    = 'CPU'
    Value     = 95
    Threshold = 85
    Timestamp = (Get-Date)
}

Write-Host "Testing SMTP configuration..."
Write-Host "From: $($Config.EmailFrom)"
Write-Host "To: $($Config.EmailTo)"
Write-Host "SMTP Server: $($Config.SmtpServer):$($Config.SmtpPort)"
Write-Host "Username: $($Config.SmtpUsername)"
Write-Host ""

# Test sending alert
Send-Alerts -Alerts @($testAlert) -Config $Config
