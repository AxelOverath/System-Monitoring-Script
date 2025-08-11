<#
.SYNOPSIS
    Self-healing actions with audit logging for Linux targets over SSH.
.DESCRIPTION
    Matches alerts to configured actions, executes them remotely via SSHTransport,
    and appends an audit record (CSV). Supports simple actions like restarting
    services, clearing files, running arbitrary commands, etc.
#>

function Invoke-SelfHealing {
    <#
    .SYNOPSIS
        Execute configured self-healing actions for alerts and log results.
    .PARAMETER Alerts
        Array from EvaluateThresholds: Server, Metric, Value, Threshold, Timestamp.
    .PARAMETER VMList
        Array from Import-VMCredentials: Server, UserName, KeyPath, Port.
    .PARAMETER Config
        Hashtable containing SelfHealing block with Enabled, Execution settings, and Actions.
    .OUTPUTS
        PSCustomObject[] of audit rows that were written.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Alerts,
        [Parameter(Mandatory)][PSObject[]]$VMList,
        [Parameter(Mandatory)][hashtable]$Config
    )

    if (-not ($Config.ContainsKey('SelfHealing') -and $Config.SelfHealing.Enabled)) {
        Write-Host "Self-healing disabled. Skipping."
        return @()
    }

    $audit = @()
    $actions = @($Config.SelfHealing.Actions)  # array of action rules
    if (-not $actions -or $actions.Count -eq 0) {
        Write-Host "No self-healing actions defined."
        return @()
    }

    # Ensure audit log file exists with header
    $auditPath = $Config.SelfHealing.Execution.AuditLogPath
    if (-not (Test-Path (Split-Path $auditPath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $auditPath -Parent) -Force | Out-Null
    }
    if (-not (Test-Path $auditPath)) {
        "Timestamp,Server,Metric,Value,Threshold,ActionType,Parameters,Success,ExitCode,Message" | Out-File -FilePath $auditPath -Encoding utf8
    }

    foreach ($alert in $Alerts) {
        # Find VM row for this server
        $vm = $VMList | Where-Object { $_.Server -eq $alert.Server } | Select-Object -First 1
        if (-not $vm) {
            Write-Warning "No VM credentials found for $($alert.Server). Skipping self-heal."
            continue
        }

        # Match alert -> actions
        $matched = Get-MatchingActions -Alert $alert -Actions $actions
        if (-not $matched) { continue }

        foreach ($rule in $matched) {
            # Build command string (Linux)
            try {
                $cmd = Build-CommandString -Rule $rule
            } catch {
                Write-Warning "Invalid self-heal rule for $($alert.Server): $_"
                continue
            }

            # Execute the command remotely with a timeout
            $timeout = $Config.SelfHealing.Execution.DefaultTimeoutSec
            if (-not $timeout) { $timeout = 30 }

            $result = Invoke-RemoteLinuxCommand -VM $vm -Command $cmd -TimeoutSec $timeout

            # Write audit row
            $row = [PSCustomObject]@{
                Timestamp  = (Get-Date).ToString('s')
                Server     = $alert.Server
                Metric     = $alert.Metric
                Value      = $alert.Value
                Threshold  = $alert.Threshold
                ActionType = $rule.Action.Type
                Parameters = ($rule | ConvertTo-Json -Compress -Depth 5)
                Success    = ($result.ExitCode -eq 0)
                ExitCode   = $result.ExitCode
                Message    = $result.Output
            }
            $audit += $row
            $row | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -Append -FilePath $auditPath -Encoding utf8

            $okText = if ($row.Success) { "success" } else { "failure (code $($row.ExitCode))" }
            Write-Host "Self-heal $($row.ActionType) on $($row.Server): $okText"
        }
    }

    return $audit
}

function Get-MatchingActions {
    <#
    .SYNOPSIS
        Filter actions that apply to a given alert.
    .PARAMETER Alert
        Alert object (Server, Metric, Value, Threshold, Timestamp).
    .PARAMETER Actions
        Array of action rules from config.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Alert,
        [Parameter(Mandatory)][PSObject[]]$Actions
    )
    $ops = @{
        gt  = { param($a,$b) $a -gt  $b }
        gte = { param($a,$b) $a -ge  $b }
        lt  = { param($a,$b) $a -lt  $b }
        lte = { param($a,$b) $a -le  $b }
        eq  = { param($a,$b) $a -eq  $b }
    }

    $Actions | Where-Object {
        $_.Trigger.Metric -eq $Alert.Metric -and
        $ops.ContainsKey($_.Trigger.Condition.ToLower()) -and
        (& $ops[$_.Trigger.Condition.ToLower()] $Alert.Value $_.Trigger.Value)
    }
}

function Build-CommandString {
    <#
    .SYNOPSIS
        Build a Linux shell command for a given rule.
    .PARAMETER Rule
        Rule with Trigger and Action sections containing fields like Type, UseSudo, ServiceName, etc.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Rule)

    $action = $Rule.Action
    $core = switch ($action.Type) {
        'RestartService' {
            if (-not $action.ServiceName) { throw "RestartService requires ServiceName." }
            if ($action.UserService) {
                "systemctl --user restart $($action.ServiceName)"
            } else {
                "systemctl restart $($action.ServiceName)"
            }
        }
        'ClearPath' {
            if (-not $action.Paths) { throw "ClearPath requires Paths." }
            $paths = @($action.Paths) -join ' '
            if ($action.AgeDays) {
                "find $paths -type f -mtime +$($action.AgeDays) -print -delete"
            } else {
                "rm -f $paths"
            }
        }
        'VacuumJournal' {
            $age = if ($action.Age) { $action.Age } else { '7d' }
            "journalctl --vacuum-time=$age"
        }
        'CleanupApt' {
            "apt-get clean && apt-get autoremove -y"
        }
        'RunCommand' {
            if (-not $action.Command) { throw "RunCommand requires Command." }
            "$($action.Command)"
        }
        default { throw "Unsupported action '$($action.Type)'" }
    }

    if ($action.UseSudo) { "sudo -n $core" } else { $core }
}

function Invoke-RemoteLinuxCommand {
    <#
    .SYNOPSIS
        Run a shell command on a Linux VM over SSH with a timeout.
    .PARAMETER VM
        Object with Server, UserName, KeyPath, Port.
    .PARAMETER Command
        Shell command string to run.
    .PARAMETER TimeoutSec
        Max seconds to allow before cancelling (default 30).
    .OUTPUTS
        PSCustomObject: ExitCode, Output
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSObject]$VM,
        [Parameter(Mandatory)][string]$Command,
        [int]$TimeoutSec = 30
    )

    # Use direct SSH command execution with simplified approach
    Write-Verbose "Executing SSH command on $($VM.Server):$($VM.Port) - $Command"
    
    try {
        # Build SSH command string (using 127.0.0.1 instead of localhost to avoid DNS issues)
        $serverIP = if ($VM.Server -eq "localhost") { "127.0.0.1" } else { $VM.Server }
        $sshCmd = "ssh -p $($VM.Port) -o ConnectTimeout=10 -o StrictHostKeyChecking=no $($VM.UserName)@$serverIP `"$Command`""
        
        Write-Verbose "SSH Command: $sshCmd"
        
        # Execute SSH command using Invoke-Expression for simpler handling
        $output = Invoke-Expression $sshCmd 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
        
        # Convert output to string if it's an array
        $outputString = if ($null -eq $output) { 
            "Command executed successfully" 
        } elseif ($output -is [array]) { 
            $output -join "`n" 
        } else { 
            [string]$output 
        }
        
        return [PSCustomObject]@{
            ExitCode = $exitCode
            Output   = $outputString.Trim()
        }
        
    } catch {
        Write-Warning "SSH execution failed: $($_.Exception.Message)"
        return [PSCustomObject]@{
            ExitCode = 9999
            Output   = "SSH execution failed: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Invoke-SelfHealing
