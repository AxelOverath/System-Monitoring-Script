<#
.SYNOPSIS
    Module for importing VM credentials and collecting system metrics via parallel PowerShell jobs.
.DESCRIPTION
    Reads VM connection details from a CSV (Server, Username, KeyPath, Port) and spins up
    background jobs for each Linux VM. Includes connectivity checks and logs progress.
    Provides job-based collection, allowing later retrieval for database insertion.
#>

<#
.SYNOPSIS
    Imports VM connection info from a CSV file.
.DESCRIPTION
    Reads CSV columns: Server, Username, KeyPath, [Port].
    Returns PSCustomObjects with Server, UserName, KeyPath, and Port.
.PARAMETER Path
    Path to the CSV file.
.EXAMPLE
    $vmList = Import-VMCredentials -Path .\config\vm_credentials.csv
#>
function Import-VMCredentials {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path $Path)) {
        Throw "VM credentials file not found: $Path"
    }
    Import-Csv -Path $Path | ForEach-Object {
        if (-not $_.KeyPath) { Throw "KeyPath is required for $($_.Server)" }
        $port = 22
        if ($_.Port -and [int]::TryParse($_.Port, [ref]$port)) { $port = [int]$_.Port }
        [PSCustomObject]@{
            Server   = $_.Server
            UserName = $_.Username
            KeyPath  = $_.KeyPath
            Port     = $port
        }
    }
}

<#
.SYNOPSIS
    Starts background jobs to collect system metrics for each VM, with a per-job timeout.
.DESCRIPTION
    For each VM (Server, UserName, KeyPath, Port), checks reachability, spins a job that
    SSHes in, gathers metrics, and returns PSCustomObjects. A watchdog timer stops any job
    that exceeds -JobTimeoutSec to prevent indefinite hangs.
.PARAMETER VMList
    Array of VM info objects from Import-VMCredentials.
.PARAMETER JobTimeoutSec
    Seconds to allow each job to run before being stopped (default 45).
.OUTPUTS
    Job[] array of PowerShell jobs.
#>
function Start-SystemMetricsJobs {
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSObject[]]$VMList,
        [int]$JobTimeoutSec = 15
    )

    $jobs = @()
    foreach ($vm in $VMList) {
        Write-Host "Checking connectivity to $($vm.Server)..."
        if (-not (Test-Connection -ComputerName $vm.Server -Count 1 -Quiet)) {
            Write-Warning "Host unreachable: $($vm.Server), skipping job creation."
            continue
        }

        Write-Host "Starting job for $($vm.Server)..."
        $job = Start-Job -Name "Metrics_$($vm.Server)" -ArgumentList $vm -ScriptBlock {
            param($vm)
            try {
                $session = New-PSSession -HostName $vm.Server `
                    -Port $vm.Port `
                    -UserName $vm.UserName `
                    -KeyFilePath $vm.KeyPath `
                    -SSHTransport

                $script = {
                    param($Name)
                    $load = (Get-Content /proc/loadavg -Raw) -split '\s+' | Select-Object -First 1
                    $cores = (Get-Content /proc/cpuinfo | Where-Object { $_ -match '^processor' }).Count
                    $cpu = [math]::Round(([double]$load / $cores) * 100, 2)

                    $memInfo = Get-Content /proc/meminfo | ForEach-Object {
                        if ($_ -match '^(MemTotal|MemAvailable):\s+(\d+)') { @{ Key = $matches[1]; Value = [int]$matches[2] } }
                    }
                    $total = ($memInfo | Where-Object Key -eq 'MemTotal').Value
                    $avail = ($memInfo | Where-Object Key -eq 'MemAvailable').Value
                    $mem = [math]::Round((($total - $avail) / $total) * 100, 2)

                    $diskPct = df --output=pcent / | Select-Object -Last 1 | ForEach-Object { [math]::Round([double]($_.TrimEnd('%')),2) }

                    [PSCustomObject]@{
                        Server             = $Name
                        CPUUsagePercent    = $cpu
                        MemoryUsagePercent = $mem
                        DiskUsagePercent   = $diskPct
                        Timestamp          = (Get-Date)
                    }
                }

                $res = Invoke-Command -Session $session -ScriptBlock $script -ArgumentList $vm.Server
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
                return $res
            } catch {
                Write-Warning "Job error on $($vm.Server): $_"
            }
        }
        
        # Add custom properties to track timeout
        $job | Add-Member -MemberType NoteProperty -Name 'StartTime' -Value (Get-Date)
        $job | Add-Member -MemberType NoteProperty -Name 'TimeoutSeconds' -Value $JobTimeoutSec
        $job | Add-Member -MemberType NoteProperty -Name 'ServerName' -Value $vm.Server
        
        $jobs += $job
    }
    return $jobs
}


<#
.SYNOPSIS
    Collects results from metric-gathering jobs.
.DESCRIPTION
    Takes an array of jobs returned by Start-SystemMetricsJobs, waits for completion,
    retrieves the output PSCustomObjects, and cleans up the jobs.
.PARAMETER Jobs
    Array of Job objects.
.OUTPUTS
    PSCustomObject[]: Combined array of metric objects from all jobs.
.EXAMPLE
    $metrics = Get-SystemMetricsFromJobs -Jobs $jobs
#>
function Get-SystemMetricsFromJobs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Management.Automation.Job[]]$Jobs
    )

    $metrics = @()
    foreach ($job in $Jobs) {
        Write-Host "Waiting for job $($job.Name)..."
        
        # Check if job has timeout information
        $timeoutSeconds = if ($job.PSObject.Properties['TimeoutSeconds']) { $job.TimeoutSeconds } else { 30 }
        $startTime = if ($job.PSObject.Properties['StartTime']) { $job.StartTime } else { Get-Date }
        $serverName = if ($job.PSObject.Properties['ServerName']) { $job.ServerName } else { $job.Name }
        
        # Wait for job with timeout
        $waitResult = $null
        try {
            $waitResult = Wait-Job -Job $job -Timeout $timeoutSeconds
        } catch {
            Write-Warning "Error waiting for job $($job.Name): $_"
        }
        
        # Check if job completed or timed out
        if ($job.State -eq 'Running') {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            Write-Warning "Job '$($job.Name)' for server '$serverName' timed out after $([math]::Round($elapsed, 1)) seconds. Stopping job."
            Stop-Job -Job $job -ErrorAction SilentlyContinue
        } elseif ($job.State -eq 'Completed') {
            Write-Host "Job '$($job.Name)' completed successfully."
            $out = Receive-Job -Job $job -ErrorAction SilentlyContinue
            if ($out) { 
                $metrics += $out 
                Write-Host "Retrieved metrics for $serverName"
            } else {
                Write-Warning "No output received from job '$($job.Name)' for server '$serverName'"
            }
        } elseif ($job.State -eq 'Failed') {
            Write-Warning "Job '$($job.Name)' for server '$serverName' failed."
            $errorInfo = Receive-Job -Job $job -ErrorAction SilentlyContinue
            if ($errorInfo) {
                Write-Warning "Job error details: $errorInfo"
            }
        } else {
            Write-Warning "Job '$($job.Name)' for server '$serverName' ended with state: $($job.State)"
        }
        
        # Clean up job
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "Collected metrics from $($metrics.Count) servers"
    return $metrics
}

Export-ModuleMember -Function Import-VMCredentials, Start-SystemMetricsJobs, Get-SystemMetricsFromJobs
