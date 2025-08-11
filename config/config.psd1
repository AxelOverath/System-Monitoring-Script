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
        Enabled    = $false                              # Enable/disable HTML report generation        
        OutputPath = '.\temp\SystemHealthReport.html'  # Relative or absolute path for HTML file
        Open       = $false                             # Auto-open report in default browser
    }
}
