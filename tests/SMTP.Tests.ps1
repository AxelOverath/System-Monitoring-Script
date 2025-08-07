# Test SMTP Configuration
param(
    [string]$ConfigPath = ".\config\config.psd1"
)

# Load config and secrets
$Config = Import-PowerShellDataFile -Path $ConfigPath
$secretsPath = Join-Path $PSScriptRoot 'config\secrets.psd1'
if (Test-Path $secretsPath) {
    $secrets = Import-PowerShellDataFile -Path $secretsPath
    $Config.SmtpUsername = $secrets.SmtpUsername
    $Config.SmtpPassword = $secrets.SmtpPassword
}

# Import alerting module
Import-Module ".\modules\Alerting.psm1" -Force

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
