<#
.SYNOPSIS
    Registers or updates a Scheduled Task based on the schedule defined in Config.Schedule.
.DESCRIPTION
    Loads configuration and secrets, reads Schedule settings (Frequency, Time, DaysOfWeek, TaskName),
    and creates/updates a Windows Scheduled Task to run Invoke-SystemHealthCheck.ps1 accordingly.
    
    Supported Frequencies:
    - 'Minutes': Runs every X minutes (Time = number of minutes, e.g., '5' for every 5 minutes)
    - 'Hourly': Runs every hour
    - 'Daily': Runs once per day at specified time (Time = 'HH:mm' format)
    - 'Weekly': Runs on specified days at specified time (Time = 'HH:mm', DaysOfWeek required)
    
.PARAMETER ConfigPath
    Path to the Config.psd1 file containing the Schedule hashtable and DB creds.
.EXAMPLE
    .\Register-ScheduledHealthCheck.ps1 -ConfigPath ..\config\Config.psd1
.EXAMPLE
    # For every 10 minutes monitoring, set in config.psd1:
    # Schedule = @{ Frequency = 'Minutes'; Time = '10'; TaskName = 'SystemHealthCheck' }
.EXAMPLE
    # For daily monitoring at 3 AM, set in config.psd1:
    # Schedule = @{ Frequency = 'Daily'; Time = '03:00'; TaskName = 'SystemHealthCheck' }
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath
)

# 1. Load main config
$Config = Import-PowerShellDataFile -Path $ConfigPath

# 2. Merge secrets for Database User/Password if present
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
$absoluteConfigPath = Resolve-Path $ConfigPath | Select-Object -ExpandProperty Path
$workingDirectory = Split-Path $PSScriptRoot -Parent

# 5. Define scheduled task action
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument (
    "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ConfigPath `"$absoluteConfigPath`""
) -WorkingDirectory $workingDirectory

# 6. Create trigger based on Frequency
switch ($freq) {
    'Minutes' {
        # For minute-based scheduling, use the Time field as minutes interval
        # e.g., Time = '5' means every 5 minutes, Time = '15' means every 15 minutes
        try {
            $minuteInterval = [int]$time
            if ($minuteInterval -lt 1 -or $minuteInterval -gt 59) {
                Throw "Minutes interval must be between 1 and 59. Got: $minuteInterval"
            }
        } catch {
            Throw "For 'Minutes' frequency, Time must be a valid number (1-59). Got: $time"
        }
        
        # Run once now, repeat every X minutes indefinitely (omitting RepetitionDuration makes it indefinite)
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
            -RepetitionInterval (New-TimeSpan -Minutes $minuteInterval)
        Write-Host "Scheduled to run every $minuteInterval minute$(if($minuteInterval -ne 1){'s'})."
    }
    'Hourly' {
        # Run once now, repeat every hour indefinitely
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
            -RepetitionInterval (New-TimeSpan -Hours 1)
        Write-Host "Scheduled to run every hour."
    }
    'Daily' {
        $ts = [TimeSpan]::Parse($time)
        $trigger = New-ScheduledTaskTrigger -Daily -At $ts
        Write-Host "Scheduled to run daily at $time."
    }
    'Weekly' {
        $ts = [TimeSpan]::Parse($time)
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $days -At $ts
        Write-Host "Scheduled to run weekly on $($days -join ', ') at $time."
    }
    default {
        Throw "Unsupported schedule frequency: $freq. Supported values: 'Minutes', 'Hourly', 'Daily', 'Weekly'"
    }
}

# 7. Register or update task
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Set-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User $currentUser
    Write-Host "Updated Scheduled Task '$taskName' ($freq schedule)."
} else {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Description 'Runs the system health check script' -User $currentUser
    Write-Host "Created Scheduled Task '$taskName' ($freq schedule)."
}
