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
    Starts background jobs to collect system metrics for each VM.
.DESCRIPTION
    For each VM object (Server, UserName, KeyPath, Port), tests connectivity and
    starts a PowerShell job that establishes an SSHTransport session, gathers CPU,
    memory, and disk metrics, and returns them as PSCustomObjects.
.PARAMETER VMList
    Array of VM info objects from Import-VMCredentials.
.OUTPUTS
    Job[]: Array of PowerShell Job objects representing the background tasks.
.EXAMPLE
    $jobs = Start-SystemMetricsJobs -VMList $vmList
#>
function Start-SystemMetricsJobs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSObject[]]$VMList
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
        $null = Wait-Job -Job $job
        $out = Receive-Job -Job $job -ErrorAction SilentlyContinue
        if ($out) { $metrics += $out }
        Remove-Job -Job $job -Force
    }
    return $metrics
}

Export-ModuleMember -Function Import-VMCredentials, Start-SystemMetricsJobs, Get-SystemMetricsFromJobs
