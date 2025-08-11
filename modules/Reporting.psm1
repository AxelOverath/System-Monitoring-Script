<#
.SYNOPSIS
    HTML reporting with PSWriteHTML for system metrics.
.DESCRIPTION
    Generates a clean, interactive HTML report with charts and tables
    using PSWriteHTML. The report includes a summary tab, per-metric
    charts (CPU/Memory/Disk), and a raw data table.
.PARAMETER Metrics
    Array of PSCustomObjects with Server, CPUUsagePercent, MemoryUsagePercent,
    DiskUsagePercent, Timestamp.
.PARAMETER Config
    Hashtable for thresholds (optional) and other metadata.
.PARAMETER OutputPath
    Where to write the HTML file. Defaults to ..\temp\SystemHealthReport.html.
.PARAMETER Open
    If supplied, opens the report in your default browser.
.EXAMPLE
    Generate-SystemReport -Metrics $metrics -Config $Config -OutputPath ..\temp\report.html -Open
#>
function Generate-SystemReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Metrics,
        [Parameter()][hashtable]$Config,
        [Parameter()][string]$OutputPath = (Join-Path $PSScriptRoot '..\temp\SystemHealthReport.html'),
        [switch]$Open
    )

    # Ensure PSWriteHTML is available
    try {
        Import-Module PSWriteHTML -ErrorAction Stop
    } catch {
        Throw "PSWriteHTML module not found. Install it with: Install-Module PSWriteHTML -Scope CurrentUser"
    }

    if (-not (Test-Path (Split-Path $OutputPath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $OutputPath -Parent) -Force | Out-Null
    }

    # Prepare datasets and calculations
    $labels = $Metrics | ForEach-Object { $_.Server }
    $cpu    = $Metrics | ForEach-Object { [double]$_.CPUUsagePercent }
    $mem    = $Metrics | ForEach-Object { [double]$_.MemoryUsagePercent }
    $disk   = $Metrics | ForEach-Object { [double]$_.DiskUsagePercent }

    $avgCPU  = if ($cpu.Count)  { [Math]::Round(($cpu  | Measure-Object -Average).Average, 2) } else { 0 }
    $avgMEM  = if ($mem.Count)  { [Math]::Round(($mem  | Measure-Object -Average).Average, 2) } else { 0 }
    $avgDISK = if ($disk.Count) { [Math]::Round(($disk | Measure-Object -Average).Average, 2) } else { 0 }
    
    $maxCPU  = if ($cpu.Count)  { ($cpu  | Measure-Object -Maximum).Maximum } else { 0 }
    $maxMEM  = if ($mem.Count)  { ($mem  | Measure-Object -Maximum).Maximum } else { 0 }
    $maxDISK = if ($disk.Count) { ($disk | Measure-Object -Maximum).Maximum } else { 0 }

    # Determine health status colors and icons
    $cpuStatus = if ($avgCPU -gt 85) { @{Color='#FF4444'; Icon='fas fa-exclamation-triangle'; Status='Critical'} } 
                 elseif ($avgCPU -gt 70) { @{Color='#FFA500'; Icon='fas fa-exclamation-circle'; Status='Warning'} } 
                 else { @{Color='#4CAF50'; Icon='fas fa-check-circle'; Status='Good'} }
    
    $memStatus = if ($avgMEM -gt 90) { @{Color='#FF4444'; Icon='fas fa-exclamation-triangle'; Status='Critical'} } 
                 elseif ($avgMEM -gt 75) { @{Color='#FFA500'; Icon='fas fa-exclamation-circle'; Status='Warning'} } 
                 else { @{Color='#4CAF50'; Icon='fas fa-check-circle'; Status='Good'} }
    
    $diskStatus = if ($avgDISK -gt 80) { @{Color='#FF4444'; Icon='fas fa-exclamation-triangle'; Status='Critical'} } 
                  elseif ($avgDISK -gt 60) { @{Color='#FFA500'; Icon='fas fa-exclamation-circle'; Status='Warning'} } 
                  else { @{Color='#4CAF50'; Icon='fas fa-check-circle'; Status='Good'} }

    New-HTML -TitleText "🖥️ System Health Dashboard" -FilePath $OutputPath -Online {
        # Custom CSS for modern styling
        New-HTMLHeader {
            New-HTMLText -Text @"
<style>
    body { 
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
        background: #3E3F29;
        margin: 0;
        padding: 20px;
    }
    .main-container { 
        background: white; 
        border-radius: 15px; 
        box-shadow: 0 20px 40px rgba(0,0,0,0.1);
        overflow: hidden;
    }
    .metric-card {
        background: white;
        border-radius: 10px;
        padding: 20px;
        margin: 15px;
        box-shadow: 0 5px 15px rgba(0,0,0,0.08);
        transition: transform 0.2s ease;
        border-left: 4px solid;
    }
    .metric-card:hover {
        transform: translateY(-5px);
        box-shadow: 0 10px 25px rgba(0,0,0,0.15);
    }
    .metric-value {
        font-size: 2.5em;
        font-weight: bold;
        margin: 10px 0;
    }
    .metric-label {
        color: #666;
        font-size: 1.1em;
        text-transform: uppercase;
        letter-spacing: 1px;
    }
    .status-badge {
        display: inline-block;
        padding: 5px 15px;
        border-radius: 20px;
        color: white;
        font-weight: bold;
        margin-top: 10px;
    }
    .chart-container {
        background: white;
        border-radius: 10px;
        padding: 20px;
        margin: 15px;
        box-shadow: 0 5px 15px rgba(0,0,0,0.08);
    }
    .section-title {
        color: #2c3e50;
        font-size: 1.5em;
        font-weight: bold;
        margin-bottom: 20px;
        border-bottom: 3px solid #3498db;
        padding-bottom: 10px;
    }
</style>
"@ -Color White
        }

        # Global table options
        New-HTMLTableOption -DataStore JavaScript -DateTimeFormat 'MMM dd, yyyy HH:mm:ss'

        New-HTMLTab -Name '📊 Dashboard'{

            # KPI Cards Row
            New-HTMLSection -HeaderText '📈 Key Performance Indicators' -CanCollapse -BackgroundColor Beige -HeaderBackgroundColor LightSlateGray -HeaderTextSize 15{
                New-HTMLPanel {
                    New-HTMLText -Text @"
<div style='display: flex; flex-wrap: wrap; justify-content: space-around;'>
    <div class='metric-card' style='border-left-color: $($cpuStatus.Color); flex: 1; min-width: 250px;'>
        <div class='metric-label'><i class='$($cpuStatus.Icon)'></i> CPU Usage</div>
        <div class='metric-value' style='color: $($cpuStatus.Color);'>$avgCPU%</div>
        <div>Average across $($labels.Count) server$(if($labels.Count -ne 1){'s'})</div>
        <div>Peak: $maxCPU%</div>
        <span class='status-badge' style='background-color: $($cpuStatus.Color);'>$($cpuStatus.Status)</span>
    </div>
    <div class='metric-card' style='border-left-color: $($memStatus.Color); flex: 1; min-width: 250px;'>
        <div class='metric-label'><i class='$($memStatus.Icon)'></i> Memory Usage</div>
        <div class='metric-value' style='color: $($memStatus.Color);'>$avgMEM%</div>
        <div>Average across $($labels.Count) server$(if($labels.Count -ne 1){'s'})</div>
        <div>Peak: $maxMEM%</div>
        <span class='status-badge' style='background-color: $($memStatus.Color);'>$($memStatus.Status)</span>
    </div>
    <div class='metric-card' style='border-left-color: $($diskStatus.Color); flex: 1; min-width: 250px;'>
        <div class='metric-label'><i class='$($diskStatus.Icon)'></i> Disk Usage</div>
        <div class='metric-value' style='color: $($diskStatus.Color);'>$avgDISK%</div>
        <div>Average across $($labels.Count) server$(if($labels.Count -ne 1){'s'})</div>
        <div>Peak: $maxDISK%</div>
        <span class='status-badge' style='background-color: $($diskStatus.Color);'>$($diskStatus.Status)</span>
    </div>
</div>
"@ -Color White
                }
            }

            # Charts Section
            New-HTMLSection -HeaderText '📊 Performance Charts' -CanCollapse -BackgroundColor Beige -HeaderBackgroundColor LightSlateGray -HeaderTextSize 15{
                New-HTMLPanel {
                    New-HTMLChart -Title 'System Resource Usage Overview' -TitleAlignment center {
                        New-ChartDonut -Name 'CPU' -Value $avgCPU -Color '#FF6B6B'
                        New-ChartDonut -Name 'Memory' -Value $avgMEM -Color '#4ECDC4'  
                        New-ChartDonut -Name 'Disk' -Value $avgDISK -Color '#45B7D1'
                    }
                }
                New-HTMLPanel {
                    New-HTMLChart -Title 'Server Comparison - All Metrics' -TitleAlignment center {
                        New-ChartLine -Name 'CPU %' -Value $cpu -Color '#FF6B6B'
                        New-ChartLine -Name 'Memory %' -Value $mem -Color '#4ECDC4'
                        New-ChartLine -Name 'Disk %' -Value $disk -Color '#45B7D1'
                        New-ChartAxisX -Names $labels
                    }
                }
            }

            # Detailed Data Table
            New-HTMLSection -HeaderText '📋 Detailed Metrics' -CanCollapse -BackgroundColor Beige -HeaderBackgroundColor LightSlateGray -HeaderTextSize 15{
                New-HTMLTable -DataTable $Metrics -PagingLength 15 -Filtering -SearchBuilder -Buttons @('copyHtml5', 'excelHtml5', 'csvHtml5', 'pdfHtml5') {
                    New-HTMLTableCondition -Name 'CPUUsagePercent' -ComparisonType number -Operator gt -Value 85 -BackgroundColor '#ffebee' -Color '#c62828'
                    New-HTMLTableCondition -Name 'CPUUsagePercent' -ComparisonType number -Operator gt -Value 70 -BackgroundColor '#fff3e0' -Color '#ef6c00'
                    New-HTMLTableCondition -Name 'MemoryUsagePercent' -ComparisonType number -Operator gt -Value 90 -BackgroundColor '#ffebee' -Color '#c62828'
                    New-HTMLTableCondition -Name 'MemoryUsagePercent' -ComparisonType number -Operator gt -Value 75 -BackgroundColor '#fff3e0' -Color '#ef6c00'
                    New-HTMLTableCondition -Name 'DiskUsagePercent' -ComparisonType number -Operator gt -Value 80 -BackgroundColor '#ffebee' -Color '#c62828'
                    New-HTMLTableCondition -Name 'DiskUsagePercent' -ComparisonType number -Operator gt -Value 60 -BackgroundColor '#fff3e0' -Color '#ef6c00'
                }
            }
        }

        New-HTMLTab -Name '📈 Individual Metrics' {
            New-HTMLSection -HeaderText '🖥️ CPU Performance Analysis' -CanCollapse -BackgroundColor Beige -HeaderBackgroundColor LightSlateGray -HeaderTextSize 15{
                New-HTMLPanel {
                    New-HTMLChart -Title 'CPU Usage by Server' -TitleAlignment center {
                        New-ChartBar -Name 'CPU Usage %' -Value $cpu -Color @('#FF6B6B', '#FF8E8E', '#FFB1B1')
                        New-ChartAxisX -Names $labels
                    }
                }
            }

            New-HTMLSection -HeaderText '🧠 Memory Performance Analysis' -CanCollapse -BackgroundColor Beige -HeaderBackgroundColor LightSlateGray -HeaderTextSize 15{
                New-HTMLPanel {
                    New-HTMLChart -Title 'Memory Usage by Server' -TitleAlignment center {
                        New-ChartBar -Name 'Memory Usage %' -Value $mem -Color @('#4ECDC4', '#70D4CD', '#93DCD6')
                        New-ChartAxisX -Names $labels
                    }
                }
            }

            New-HTMLSection -HeaderText '💾 Disk Performance Analysis' -CanCollapse -BackgroundColor Beige -HeaderBackgroundColor LightSlateGray -HeaderTextSize 15{
                New-HTMLPanel {
                    New-HTMLChart -Title 'Disk Usage by Server' -TitleAlignment center {
                        New-ChartBar -Name 'Disk Usage %' -Value $disk -Color @('#45B7D1', '#68C5DA', '#8BD3E3')
                        New-ChartAxisX -Names $labels
                    }
                }
            }

            # Threshold Analysis
            if ($Config) {
                New-HTMLSection -HeaderText '⚠️ Threshold Analysis' -CanCollapse -BackgroundColor Beige -HeaderBackgroundColor LightSlateGray -HeaderTextSize 15{
                    $thresholdData = @()
                    foreach ($metric in $Metrics) {
                        $alerts = @()
                        if ($metric.CPUUsagePercent -gt $Config.CpuThreshold) { $alerts += "CPU: $($metric.CPUUsagePercent)% > $($Config.CpuThreshold)%" }
                        if ($metric.MemoryUsagePercent -gt $Config.MemoryThreshold) { $alerts += "Memory: $($metric.MemoryUsagePercent)% > $($Config.MemoryThreshold)%" }
                        if ($metric.DiskUsagePercent -gt $Config.DiskThreshold) { $alerts += "Disk: $($metric.DiskUsagePercent)% > $($Config.DiskThreshold)%" }
                        
                        $thresholdData += [PSCustomObject]@{
                            Server = $metric.Server
                            Status = if ($alerts.Count -gt 0) { "⚠️ ALERT" } else { "✅ OK" }
                            Alerts = if ($alerts.Count -gt 0) { $alerts -join "; " } else { "All metrics within thresholds" }
                            Timestamp = $metric.Timestamp
                        }
                    }
                    New-HTMLTable -DataTable $thresholdData -PagingLength 10 {
                        New-HTMLTableCondition -Name 'Status' -ComparisonType string -Operator eq -Value '⚠️ ALERT' -BackgroundColor '#ffebee' -Color '#c62828'
                        New-HTMLTableCondition -Name 'Status' -ComparisonType string -Operator eq -Value '✅ OK' -BackgroundColor '#e8f5e8' -Color '#2e7d32'
                    }
                }
            }
        }
    } -ShowHTML:$Open
}

Export-ModuleMember -Function Generate-SystemReport
