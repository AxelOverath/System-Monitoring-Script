# tests/Database.Tests.ps1
# Pester v3 syntax

Describe "Save-SystemMetrics" {
    BeforeAll {
        # Import the module first
        Import-Module "$PSScriptRoot\..\modules\Database.psm1" -Force
    }

    InModuleScope Database {
        # Fake parameters collection
        $fakeParams = New-Object PSObject
        $fakeParams | Add-Member NoteProperty Count 0
        $fakeParams | Add-Member NoteProperty InternalCollection @()
        $fakeParams | Add-Member ScriptMethod Clear {
            $this.InternalCollection = @()
            $this.Count = 0
        } -Force
        $fakeParams | Add-Member ScriptMethod AddWithValue {
            param($name,$value)
            $this.InternalCollection += [PSCustomObject]@{Name=$name;Value=$value}
            $this.Count = $this.InternalCollection.Count
            return $null
        } -Force

        # Fake command object
        $fakeCmd = New-Object PSObject
        $fakeCmd | Add-Member NoteProperty Parameters $fakeParams
        $fakeCmd | Add-Member NoteProperty CommandText ""
        $fakeCmd | Add-Member ScriptMethod ExecuteNonQuery {
            return 1
        } -Force

        # Fake connection object
        $fakeConn = New-Object PSObject
        $fakeConn | Add-Member ScriptMethod Open      { } -Force
        $fakeConn | Add-Member ScriptMethod CreateCommand { return $fakeCmd } -Force
        $fakeConn | Add-Member ScriptMethod Close     { } -Force
        $fakeConn | Add-Member ScriptMethod Dispose   { } -Force

        Mock New-Object {
            param([string]$TypeName, [object[]]$ArgumentList)
            if ($TypeName -eq 'MySql.Data.MySqlClient.MySqlConnection') { 
                return $fakeConn 
            }
            else { 
                & (Get-Command -Name 'New-Object' -CommandType Cmdlet) -TypeName $TypeName -ArgumentList $ArgumentList 
            }
        }
    
        Context "with valid metrics and config" {
            It "should insert correct number of parameter values" {
                # Prepare sample metrics
                $metrics = @(
                    [PSCustomObject]@{ Server='vm1'; CPUUsagePercent=10; MemoryUsagePercent=20; DiskUsagePercent=30; Timestamp=(Get-Date) },
                    [PSCustomObject]@{ Server='vm2'; CPUUsagePercent=40; MemoryUsagePercent=50; DiskUsagePercent=60; Timestamp=(Get-Date) }
                )
                # Sample config
                $cfg = @{ DbServer='s'; DbPort=1; DbName='db'; DbUser='u'; DbPassword='p' }

                # Invoke
                Save-SystemMetrics -Metrics $metrics -DbConfig $cfg | Out-Null

                # Should have 5 parameters for the last processed row (since Clear() is called between rows)
                $fakeCmd.Parameters.Count | Should Not Be 0
                $fakeCmd.Parameters.Count | Should Be 5
            }
        }
    }
}
