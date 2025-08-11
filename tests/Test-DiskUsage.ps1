#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create or remove test files to simulate disk usage for testing purposes.

.DESCRIPTION
    This script helps test the disk monitoring and cleanup functionality by:
    - Creating large test files to increase disk usage
    - Removing test files to restore normal disk usage
    - Supporting different disk usage levels for testing thresholds

.PARAMETER Action
    Either 'Create' to add test files or 'Remove' to clean them up.

.PARAMETER TargetPercent
    Target disk usage percentage (80, 85, 90, 95, 98).

.PARAMETER VMPort
    SSH port for the target VM (2222 or 2223).

.PARAMETER KeyPath
    Path to SSH private key file.

.EXAMPLE
    .\Test-DiskUsage.ps1 -Action Create -TargetPercent 95 -VMPort 2222
    .\Test-DiskUsage.ps1 -Action Remove -VMPort 2222
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Create', 'Remove')]
    [string]$Action,
    
    [ValidateSet(80, 85, 90, 95, 98)]
    [int]$TargetPercent = 90,
    
    [ValidateSet(2222, 2223)]
    [int]$VMPort = 2222,
    
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_rsa"
)

$SSHTarget = "axel@127.0.0.1"

function Get-CurrentDiskUsage {
    $result = ssh -i $KeyPath -p $VMPort $SSHTarget 'df -h / | grep "/dev/sda2" | grep -o "[0-9]*%" | tr -d "%"'
    return [int]$result
}

function Get-RequiredFileSize {
    param([int]$CurrentPercent, [int]$TargetPercent)
    
    # Rough calculation: each GB ≈ 4% on a 25GB disk
    $percentDiff = $TargetPercent - $CurrentPercent
    $sizeGB = [math]::Max(1, [math]::Ceiling($percentDiff / 4.0))
    return $sizeGB
}

if ($Action -eq 'Create') {
    Write-Host "🔍 Checking current disk usage on VM port $VMPort..."
    $currentUsage = Get-CurrentDiskUsage
    Write-Host "Current disk usage: $currentUsage%"
    
    if ($currentUsage -ge $TargetPercent) {
        Write-Host "✅ Already at or above target usage ($TargetPercent%)"
        exit 0
    }
    
    $requiredSize = Get-RequiredFileSize -CurrentPercent $currentUsage -TargetPercent $TargetPercent
    Write-Host "📁 Creating ${requiredSize}GB test file to reach $TargetPercent%..."
    
    $commands = @(
        "mkdir -p ~/test_disk_usage",
        "dd if=/dev/zero of=~/test_disk_usage/testfile_${TargetPercent}pct.bin bs=1M count=$($requiredSize * 1024) 2>/dev/null",
        "echo 'Test file created'",
        "df -h / | grep '/dev/sda2'"
    )
    
    $command = $commands -join " && "
    ssh -i $KeyPath -p $VMPort $SSHTarget $command
    
    $newUsage = Get-CurrentDiskUsage
    Write-Host "✅ New disk usage: $newUsage%"
    
} elseif ($Action -eq 'Remove') {
    Write-Host "🧹 Removing all test files from VM port $VMPort..."
    
    $commands = @(
        "echo 'Before cleanup:'",
        "df -h / | grep '/dev/sda2'",
        "rm -rf ~/test_disk_usage",
        "echo 'After cleanup:'",
        "df -h / | grep '/dev/sda2'"
    )
    
    $command = $commands -join " && "
    ssh -i $KeyPath -p $VMPort $SSHTarget $command
    
    Write-Host "✅ Test files removed"
}

Write-Host ""
Write-Host "💡 Quick reference:"
Write-Host "   80% = Basic disk alert threshold"
Write-Host "   85% = Docker basic cleanup trigger"
Write-Host "   90% = Docker aggressive cleanup trigger" 
Write-Host "   95% = Emergency cleanup trigger"
Write-Host "   98% = Near-full disk simulation"
