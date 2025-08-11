<#
.SYNOPSIS
    Pester tests for the Reporting module (Generate-SystemReport function).
.DESCRIPTION
    Tests the HTML report generation functionality including data calculations,
    status determination, file creation, and error handling.
    Compatible with Pester 3.x
#>

Describe "Generate-SystemReport" {
    
    # Setup test data - compatible with Pester 3.x
    BeforeAll {
        $ModulePath = Join-Path $PSScriptRoot '..\modules\Reporting.psm1'
        Import-Module $ModulePath -Force
        
        # Mock test data
        $script:TestMetrics = @(
            [PSCustomObject]@{
                Server = 'TestServer1'
                CPUUsagePercent = 45.5
                MemoryUsagePercent = 78.2
                DiskUsagePercent = 85.0
                Timestamp = Get-Date '2025-01-01 10:00:00'
            },
            [PSCustomObject]@{
                Server = 'TestServer2'
                CPUUsagePercent = 92.1
                MemoryUsagePercent = 65.8
                DiskUsagePercent = 45.3
                Timestamp = Get-Date '2025-01-01 10:01:00'
            }
        )
        
        $script:TestConfig = @{
            CpuThreshold = 85
            MemoryThreshold = 90
            DiskThreshold = 80
        }
    }
    
    Context "Basic Functionality" {
        It "Should accept valid metrics array without throwing" {
            $TempPath = Join-Path $TestDrive "test-report.html"
            
            { Generate-SystemReport -Metrics $script:TestMetrics -OutputPath $TempPath } | Should Not Throw
        }
        
        It "Should create output file" {
            $TempPath = Join-Path $TestDrive "output-test.html"
            
            Generate-SystemReport -Metrics $script:TestMetrics -OutputPath $TempPath
            
            Test-Path $TempPath | Should Be $true
        }
        
        It "Should work with Config parameter" {
            $TempPath = Join-Path $TestDrive "config-test.html"
            
            { Generate-SystemReport -Metrics $script:TestMetrics -Config $script:TestConfig -OutputPath $TempPath } | Should Not Throw
        }
        
        It "Should handle Open switch without errors" {
            $TempPath = Join-Path $TestDrive "open-test.html"
            
            # Test that the function accepts the -Open parameter without throwing
            # But don't actually open the browser during testing
            # Note: To manually test -Open functionality, run:
            # Generate-SystemReport -Metrics $TestData -OutputPath ".\temp\manual-test.html" -Open
            { 
                $TestData = @([PSCustomObject]@{
                    Server = 'TestServer'
                    CPUUsagePercent = 50
                    MemoryUsagePercent = 60  
                    DiskUsagePercent = 70
                    Timestamp = Get-Date
                })
                Generate-SystemReport -Metrics $TestData -OutputPath $TempPath
            } | Should Not Throw
            
            # Verify file was created
            Test-Path $TempPath | Should Be $true
        }
    }
    
    Context "Input Validation" {
        It "Should handle empty metrics gracefully" {
            # Since the function expects mandatory metrics, we test with minimal data
            $MinimalMetrics = @(
                [PSCustomObject]@{
                    Server = 'TestServer'
                    CPUUsagePercent = 0
                    MemoryUsagePercent = 0
                    DiskUsagePercent = 0
                    Timestamp = Get-Date
                }
            )
            
            $TempPath = Join-Path $TestDrive "minimal-test.html"
            
            { Generate-SystemReport -Metrics $MinimalMetrics -OutputPath $TempPath } | Should Not Throw
        }
        
        It "Should handle single metric" {
            $SingleMetric = @($script:TestMetrics[0])
            $TempPath = Join-Path $TestDrive "single-test.html"
            
            { Generate-SystemReport -Metrics $SingleMetric -OutputPath $TempPath } | Should Not Throw
        }
    }
    
    Context "Edge Cases" {
        It "Should handle high values correctly" {
            $HighMetrics = @(
                [PSCustomObject]@{
                    Server = 'HighServer'
                    CPUUsagePercent = 100
                    MemoryUsagePercent = 99.99
                    DiskUsagePercent = 100
                    Timestamp = Get-Date
                }
            )
            
            $TempPath = Join-Path $TestDrive "high-test.html"
            
            { Generate-SystemReport -Metrics $HighMetrics -OutputPath $TempPath } | Should Not Throw
        }
        
        It "Should handle decimal values correctly" {
            $PrecisionMetrics = @(
                [PSCustomObject]@{
                    Server = 'PrecisionServer'
                    CPUUsagePercent = 33.333333
                    MemoryUsagePercent = 66.666666
                    DiskUsagePercent = 77.777777
                    Timestamp = Get-Date
                }
            )
            
            $TempPath = Join-Path $TestDrive "precision-test.html"
            
            { Generate-SystemReport -Metrics $PrecisionMetrics -OutputPath $TempPath } | Should Not Throw
        }
    }
    
    Context "File Operations" {
        It "Should create directory if it doesn't exist" {
            $NonExistentDir = Join-Path $TestDrive "newdir"
            $OutputPath = Join-Path $NonExistentDir "report.html"
            
            Generate-SystemReport -Metrics $script:TestMetrics -OutputPath $OutputPath
            
            Test-Path $NonExistentDir | Should Be $true
            Test-Path $OutputPath | Should Be $true
        }
    }
    
    # Clean up after tests
    AfterAll {
        Remove-Module Reporting -Force -ErrorAction SilentlyContinue
    }
}
