<#
.SYNOPSIS
    Module for importing VM credentials and collecting system metrics via SSH key authentication with connectivity checks.
.DESCRIPTION
    Contains functions to load VM connection details from a CSV (including required KeyPath and optional Port)
    and to gather CPU, memory, and disk usage from Linux servers via PowerShell SSH remoting.
    Includes a ping check to skip unreachable hosts and logs progress per-VM.
    **Only key-based SSH is supported non-interactively.**
#>

<#
.SYNOPSIS
    Imports VM connection info from a CSV file.
.DESCRIPTION
    Reads a CSV with columns: Server, Username, KeyPath, [Port].
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
    if (-Not (Test-Path $Path)) {
        Throw "VM credentials file not found at path $Path"
    }
    Import-Csv -Path $Path | ForEach-Object {
        # Normalize KeyPath: must be provided for SSH key auth
        if (-not $_.PSObject.Properties.Match('KeyPath') -or [string]::IsNullOrWhiteSpace($_.KeyPath)) {
            Throw "KeyPath is required for non-interactive SSH sessions (Server: $($_.Server))"
        }
        $keyPath = $_.KeyPath
        # Parse Port: default to 22 if missing or invalid
        $port = 22
        if ($_.PSObject.Properties.Match('Port')) {
            $p = 0; if ([int]::TryParse($_.Port, [ref]$p)) { $port = $p }
        }
        [PSCustomObject]@{
            Server   = $_.Server
            UserName = $_.Username
            KeyPath  = $keyPath
            Port     = $port
        }
    }
}

<#
.SYNOPSIS
    Collects CPU, memory, and disk usage metrics from Linux servers.
.DESCRIPTION
    Performs a ping check, then connects via SSHTransport PSSession to each VM using key authentication.
.PARAMETER VMList
    Array of objects from Import-VMCredentials with Server, UserName, KeyPath, Port.
.OUTPUTS
    PSCustomObject with Server, CPUUsagePercent, MemoryUsagePercent, DiskUsagePercent.
.EXAMPLE
    $metrics = Collect-SystemMetrics -VMList $vmList
#>
function Collect-SystemMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSObject[]]$VMList
    )

    $results = @()
    foreach ($vm in $VMList) {
        Write-Host "Testing connectivity to $($vm.Server) on port $($vm.Port)..."
        if (-not (Test-Connection -ComputerName $vm.Server -Count 1 -Quiet)) {
            Write-Warning "Unable to reach $($vm.Server). Skipping."
            continue
        }
        Write-Host "Establishing SSH key-based session to $($vm.Server)..."
        try {
            $session = New-PSSession -HostName $vm.Server -Port $vm.Port -UserName $vm.UserName \
                -KeyFilePath $vm.KeyPath -SSHTransport
            Write-Host "Connected to $($vm.Server). Gathering metrics..."

            $script = {
                param($ServerName)
                $load = (Get-Content -Path /proc/loadavg -Raw) -split '\s+' | Select-Object -First 1
                $cores = (Get-Content -Path /proc/cpuinfo | Where-Object { $_ -match '^processor' }).Count
                $cpuPercent = [math]::Round(([double]$load / $cores) * 100, 2)

                $memInfo = Get-Content -Path /proc/meminfo | ForEach-Object {
                    if ($_ -match '^(MemTotal|MemAvailable):\s+(\d+)') {
                        @{ Key = $matches[1]; Value = [int]$matches[2] }
                    }
                }
                $totalMem = ($memInfo | Where-Object Key -eq 'MemTotal').Value
                $availMem = ($memInfo | Where-Object Key -eq 'MemAvailable').Value
                $memPercent = [math]::Round((($totalMem - $availMem) / $totalMem) * 100, 2)

                $diskLine = df --output=pcent / | Select-Object -Last 1
                $diskPercent = [math]::Round([double]($diskLine.TrimEnd('%')), 2)

                [PSCustomObject]@{
                    Server             = $ServerName
                    CPUUsagePercent    = $cpuPercent
                    MemoryUsagePercent = $memPercent
                    DiskUsagePercent   = $diskPercent
                }
            }

            $metric = Invoke-Command -Session $session -ScriptBlock $script -ArgumentList $vm.Server
            $results += $metric
            Write-Host "Metrics collected for $($vm.Server)."
        } catch {
            Write-Warning "Failed to collect metrics from $($vm.Server): $_"
        } finally {
            if ($session) { Remove-PSSession -Session $session -ErrorAction SilentlyContinue }
        }
    }
    return $results
}

Export-ModuleMember -Function Import-VMCredentials, Collect-SystemMetrics
