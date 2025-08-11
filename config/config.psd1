@{
    # Database configuration
    Database = @{
        Type     = 'MySql'
        Server   = 'localhost'
        Port     = 3306
        Name     = 'system_health'
        User     = ''            # to be set in secrets.psd1
        Password = ''            # to be set in secrets.psd1
    }

    # Alert threshold configuration (percent)
    Thresholds = @{
        Cpu    = 85
        Memory = 90
        Disk   = 80
    }

    # Email notification configuration
    Email = @{
        Enabled      = $true                     # Enable/disable email notifications
        From         = 'wapitie101@gmail.com'
        To           = 'axel.overath@gmail.com'
        SmtpServer   = 'smtp.gmail.com'
        SmtpPort     = 587                       # Gmail SMTP port (587 for TLS, 465 for SSL)
        UseSsl       = $true                     # Enable SSL/TLS encryption
        SmtpUsername = ''                        # Gmail username (usually same as EmailFrom) - set in secrets.psd1
        SmtpPassword = ''                        # Gmail app password - set in secrets.psd1
    }

    # Automated collection schedule configuration
    Schedule = @{ 
        Frequency  = 'Minutes'        # 'Minutes', 'Hourly', 'Daily', or 'Weekly'
        Time       = '2'        # HH:mm for Daily/Weekly OR minutes (1-59) for Minutes frequency
        DaysOfWeek = @('Monday')    # Only if Frequency = 'Weekly'
        TaskName   = 'SystemHealthCheck'
        
        # Examples:
        # For every 10 minutes: Frequency = 'Minutes', Time = '10'
        # For every hour:       Frequency = 'Hourly', Time = '00:00' (ignored)
        # For daily at 3 AM:    Frequency = 'Daily', Time = '03:00'
        # For weekly Monday 3AM: Frequency = 'Weekly', Time = '03:00', DaysOfWeek = @('Monday')
    }

    # Threading configuration
    Threading = @{
        MaxThreads = 5
    }

    # HTML Report configuration (PSWriteHTML)
    Report = @{
        Enabled    = $true                              # Enable/disable HTML report generation        
        OutputPath = '.\temp\SystemHealthReport.html'  # Relative or absolute path for HTML file
        Open       = $true                             # Auto-open report in default browser
    }
    # Self-healing configuration
    SelfHealing = @{
        Enabled = $true                                  # Enable/disable self-healing actions
        
        # Execution settings
        Execution = @{
            DefaultTimeoutSec = 30                       # Default timeout for remote commands
            AuditLogPath      = '.\temp\selfhealing_audit.csv'  # Audit log file path
        }
        
        # Action rules: when Metric compares to Value using Condition, run Action
        Actions = @(
            # CPU Management - Restart user service when CPU > 90%
            @{
                Trigger = @{
                    Metric    = 'CPU'
                    Condition = 'gt'                     # gt,gte,lt,lte,eq
                    Value     = 90
                }
                Action = @{
                    Type        = 'RestartService'
                    ServiceName = 'dbus'
                    UserService = $true                  # Use systemctl --user
                    UseSudo     = $false
                }
            },
            
            # Disk Management - Show disk usage when Disk > 80%
            @{
                Trigger = @{
                    Metric    = 'Disk'
                    Condition = 'gt'
                    Value     = 80
                }
                Action = @{
                    Type    = 'RunCommand'
                    Command = 'df -h && echo "Disk usage checked"'
                    UseSudo = $false
                }
            },
            
            # Disk Cleanup - Clean package cache when Disk > 85%
            @{
                Trigger = @{
                    Metric    = 'Disk'
                    Condition = 'gt'
                    Value     = 85
                }
                Action = @{
                    Type    = 'RunCommand'
                    Command = 'docker system prune -f && docker volume prune -f && echo "Docker cleanup completed"'
                    UseSudo = $false
                }
            },
            
            # Disk Cleanup - Docker cleanup when Disk > 90%
            @{
                Trigger = @{
                    Metric    = 'Disk'
                    Condition = 'gt'
                    Value     = 90
                }
                Action = @{
                    Type    = 'RunCommand'
                    Command = 'docker system prune -af --volumes && docker image prune -af && echo "Aggressive Docker cleanup completed"'
                    UseSudo = $false
                }
            },
            
            # Memory Management - Clear memory caches when Memory > 90%
            @{
                Trigger = @{
                    Metric    = 'Memory'
                    Condition = 'gt'
                    Value     = 90
                }
                Action = @{
                    Type    = 'RunCommand'
                    Command = 'sync; echo 3 > /proc/sys/vm/drop_caches'
                    UseSudo = $false
                }
            },
            
            # Disk Cleanup - Clean temp files when Disk > 95%
            @{
                Trigger = @{
                    Metric    = 'Disk'
                    Condition = 'gt'
                    Value     = 95
                }
                Action = @{
                    Type    = 'RunCommand'
                    Command = 'find /tmp -user $USER -type f -mtime +1 -delete 2>/dev/null; docker container prune -f && echo "Emergency cleanup completed"'
                    UseSudo = $false
                }
            }
        )
    }

}
