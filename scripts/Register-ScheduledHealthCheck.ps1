<#
.SYNOPSIS
    Registers or updates a Scheduled Task based on the schedule defined in Config.Schedule.
.DESCRIPTION
    Loads configuration and secrets, reads Schedule settings (Frequency, Time, DaysOfWeek, TaskName),
    and creates/updates a Windows Scheduled Task to run Invoke-SystemHealthCheck.ps1 accordingly.
.PARAMETER ConfigPath
    Path to the Config.psd1 file containing the Schedule hashtable and DB creds.
.EXAMPLE
    .\Register-ScheduledHealthCheck.ps1 -ConfigPath ..\config\Config.psd1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath
)

# 1. Load main config
$Config = Import-PowerShellDataFile -Path $ConfigPath

# 2. Merge secrets for DbUser/DbPassword if present
$secretsPath = Join-Path $PSScriptRoot '..\config\secrets.psd1'
if (Test-Path $secretsPath) {
    $secrets = Import-PowerShellDataFile -Path $secretsPath
    foreach ($key in $secrets.Keys) { $Config[$key] = $secrets[$key] }
}

# 3. Extract schedule settings
$sch      = $Config.Schedule
$freq     = $sch.Frequency
$time     = $sch.Time
$days     = $sch.DaysOfWeek
$taskName = $sch.TaskName

# 4. Resolve script path for health check
$scriptPath = Join-Path $PSScriptRoot 'Invoke-SystemHealthCheck.ps1'

# 5. Define scheduled task action
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument (
    "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ConfigPath `"$ConfigPath`""
)

# 6. Create trigger based on Frequency
switch ($freq) {
    'Hourly' {
        # Run once now, repeat every hour indefinitely
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) \
            -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration ([TimeSpan]::MaxValue)
    }
    'Daily' {
        $ts = [TimeSpan]::Parse($time)
        $trigger = New-ScheduledTaskTrigger -Daily -At $ts
    }
    'Weekly' {
        $ts = [TimeSpan]::Parse($time)
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $days -At $ts
    }
    default {
        Throw "Unsupported schedule frequency: $freq"
    }
}

# 7. Register or update task
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Set-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger
    Write-Host "Updated Scheduled Task '$taskName' ($freq schedule)."
} else {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Description 'Runs the system health check script' -User 'SYSTEM'
    Write-Host "Created Scheduled Task '$taskName' ($freq schedule)."
}
