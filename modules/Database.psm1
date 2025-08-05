<#
.SYNOPSIS
    MySQL helper module for XAMPP: unified metric storage function.
.DESCRIPTION
    Defines a single Save-SystemMetrics function that handles:
      - Connecting to MySQL
      - Inserting each metric row
      - Disconnecting from MySQL
    Configuration is passed via a hashtable with DbUser, DbPassword, DbName, DbServer, DbPort.
#>

function Save-SystemMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Metrics,
        [Parameter(Mandatory)][hashtable]$DbConfig
    )

    # Build connection string
    $cs = "Server=$($DbConfig.DbServer);Port=$($DbConfig.DbPort);Database=$($DbConfig.DbName);Uid=$($DbConfig.DbUser);Pwd=$($DbConfig.DbPassword);"

    # Open connection
    $conn = New-Object MySql.Data.MySqlClient.MySqlConnection($cs)
    $conn.Open()

    # Prepare command template
    $colNames = 'server, cpu_pct, mem_pct, disk_pct, timestamp'
    $paramList = '@server, @cpu, @mem, @disk, @ts'
    $sql = "INSERT INTO metrics ($colNames) VALUES ($paramList)"
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql

    foreach ($row in $Metrics) {
        # Clear previous parameters
        $cmd.Parameters.Clear()

        # Add parameters
        $cmd.Parameters.AddWithValue('@server', $row.Server) | Out-Null
        $cmd.Parameters.AddWithValue('@cpu',    $row.CPUUsagePercent)    | Out-Null
        $cmd.Parameters.AddWithValue('@mem',    $row.MemoryUsagePercent) | Out-Null
        $cmd.Parameters.AddWithValue('@disk',   $row.DiskUsagePercent)   | Out-Null
        $cmd.Parameters.AddWithValue('@ts',     $row.Timestamp)         | Out-Null

        # Execute
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Close connection
    $conn.Close()
    $conn.Dispose()
}

Export-ModuleMember -Function Save-SystemMetrics
