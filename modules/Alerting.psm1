<#
.SYNOPSIS
    Threshold-based alert evaluation and email notifications.
.DESCRIPTION
    Provides functions to compare collected metrics against configured thresholds
    and to send email alerts when thresholds are exceeded.
#>

<#
.SYNOPSIS
    Evaluates metrics against threshold values.
.PARAMETER Metrics
    Array of metric PSCustomObjects with properties: Server, CPUUsagePercent,
    MemoryUsagePercent, DiskUsagePercent, Timestamp.
.PARAMETER Thresholds
    Hashtable containing threshold values: CpuThreshold, MemoryThreshold, DiskThreshold.
.OUTPUTS
    PSCustomObject[] of alerts with properties: Server, Metric, Value, Threshold, Timestamp.
.EXAMPLE
    $alerts = EvaluateThresholds -Metrics $metrics -Thresholds $Config
#>
function EvaluateThresholds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Metrics,
        [Parameter(Mandatory)][hashtable]$Thresholds
    )
    $alerts = @()

    foreach ($m in $Metrics) {
        if ($m.CPUUsagePercent -gt $Thresholds.CpuThreshold) {
            $alerts += [PSCustomObject]@{
                Server    = $m.Server
                Metric    = 'CPU'
                Value     = $m.CPUUsagePercent
                Threshold = $Thresholds.CpuThreshold
                Timestamp = $m.Timestamp
            }
        }
        if ($m.MemoryUsagePercent -gt $Thresholds.MemoryThreshold) {
            $alerts += [PSCustomObject]@{
                Server    = $m.Server
                Metric    = 'Memory'
                Value     = $m.MemoryUsagePercent
                Threshold = $Thresholds.MemoryThreshold
                Timestamp = $m.Timestamp
            }
        }
        if ($m.DiskUsagePercent -gt $Thresholds.DiskThreshold) {
            $alerts += [PSCustomObject]@{
                Server    = $m.Server
                Metric    = 'Disk'
                Value     = $m.DiskUsagePercent
                Threshold = $Thresholds.DiskThreshold
                Timestamp = $m.Timestamp
            }
        }
    }
    return $alerts
}

<#
.SYNOPSIS
    Sends email notifications for triggered alerts.
.PARAMETER Alerts
    Array of alert PSCustomObjects from Evaluate-Thresholds.
.PARAMETER Config
    Hashtable containing EmailFrom, EmailTo, SmtpServer settings.
.EXAMPLE
    Send-Alerts -Alerts $alerts -Config $Config
#>
function Send-Alerts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Alerts,
        [Parameter(Mandatory)][hashtable]$Config
    )
    if (-not $Alerts -or $Alerts.Count -eq 0) {
        Write-Host "No alerts to send."
        return
    }

    $subject = "[ALERT] System Health Threshold Exceeded"

    $body = "The following system health alerts were triggered:`n`n"
    foreach ($a in $Alerts) {
        $body += "Server: $($a.Server) - Metric: $($a.Metric) - Value: $($a.Value)% (Threshold: $($a.Threshold)%) at $($a.Timestamp)`n"
    }

    try {
        # Create credential object if username and password are provided
        $credential = $null
        if ($Config.SmtpUsername -and $Config.SmtpPassword) {
            $securePassword = ConvertTo-SecureString $Config.SmtpPassword -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($Config.SmtpUsername, $securePassword)
        }

        $mailParams = @{
            From       = $Config.EmailFrom
            To         = $Config.EmailTo
            Subject    = $subject
            Body       = $body
            SmtpServer = $Config.SmtpServer
            BodyAsHtml = $false
        }

        # Add port if specified
        if ($Config.SmtpPort) {
            $mailParams.Port = $Config.SmtpPort
        }

        # Add credentials if available
        if ($credential) {
            $mailParams.Credential = $credential
        }

        # Add TLS/SSL if specified
        if ($Config.UseSsl) {
            $mailParams.UseSsl = $Config.UseSsl
        }

        Send-MailMessage @mailParams
        Write-Host "Alert email sent successfully to $($Config.EmailTo)"
    }
    catch {
        Write-Warning "Failed to send alert email: $_"
        Write-Host "Alert details that failed to send:"
        foreach ($a in $Alerts) {
            Write-Host "  - $($a.Server): $($a.Metric) = $($a.Value)% (Threshold: $($a.Threshold)%)"
        }
    }
}

Export-ModuleMember -Function EvaluateThresholds, Send-Alerts
