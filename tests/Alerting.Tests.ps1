# Pester Tests for Alerting Module
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
Import-Module "$here\..\modules\Alerting.psm1" -Force

Describe "Alerting Module Tests" {
    
    Context "Send-Alerts with Email Enabled" {
        BeforeEach {
            $testConfig = @{
                Email = @{
                    Enabled = $true
                    From = 'test@example.com'
                    To = 'admin@example.com'
                    SmtpServer = 'smtp.example.com'
                    SmtpPort = 587
                    UseSsl = $true
                    SmtpUsername = 'testuser'
                    SmtpPassword = 'testpass'
                }
            }
            
            $testAlerts = @(
                [PSCustomObject]@{
                    Server = 'TEST-SERVER'
                    Metric = 'CPU'
                    Value = 95
                    Threshold = 85
                    Timestamp = (Get-Date)
                }
            )
            
            # Mock Send-MailMessage to avoid actual email sending
            Mock -CommandName Send-MailMessage -ModuleName Alerting -MockWith { }
        }
        
        It "sends email when enabled and alerts exist" {
            Send-Alerts -Alerts $testAlerts -Config $testConfig
            Assert-MockCalled Send-MailMessage -ModuleName Alerting -Times 1
        }
        
        It "does not send email when no alerts exist" {
            # Mock fresh for this test
            Mock -CommandName Send-MailMessage -ModuleName Alerting -MockWith { }
            Send-Alerts -Alerts $null -Config $testConfig
            Assert-MockCalled Send-MailMessage -ModuleName Alerting -Times 0 -Scope It
        }
    }
    
    Context "Send-Alerts with Email Disabled" {
        BeforeEach {
            $testConfig = @{
                Email = @{
                    Enabled = $false
                    From = 'test@example.com'
                    To = 'admin@example.com'
                    SmtpServer = 'smtp.example.com'
                    SmtpPort = 587
                    UseSsl = $true
                    SmtpUsername = 'testuser'
                    SmtpPassword = 'testpass'
                }
            }
            
            $testAlerts = @(
                [PSCustomObject]@{
                    Server = 'TEST-SERVER'
                    Metric = 'CPU'
                    Value = 95
                    Threshold = 85
                    Timestamp = (Get-Date)
                }
            )
            
            # Mock Send-MailMessage to verify it's not called
            Mock -CommandName Send-MailMessage -ModuleName Alerting -MockWith { }
        }
        
        It "does not send email when disabled even with alerts" {
            Send-Alerts -Alerts $testAlerts -Config $testConfig
            Assert-MockCalled Send-MailMessage -ModuleName Alerting -Times 0
        }
    }
}
