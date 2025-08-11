@{
    # Database connection info
    DbType     = 'MySql'
    DbServer   = 'localhost'
    DbPort     = 3306
    DbName     = 'system_health'
    DbUser     = ''            # to be set in secrets.psd1
    DbPassword = ''            # to be set in secrets.psd1

    # Alert thresholds (percent)
    CpuThreshold    = 85
    MemoryThreshold = 90
    DiskThreshold   = 80

    # Notification settings
    EmailFrom    = 'wapitie101@gmail.com'
    EmailTo      = 'axel.overath@gmail.com'
    SmtpServer   = 'smtp.gmail.com'
    SmtpPort     = 587                    # Gmail SMTP port (587 for TLS, 465 for SSL)
    UseSsl       = $true                  # Enable SSL/TLS encryption
    SmtpUsername = ''                     # Gmail username (usually same as EmailFrom) - set in secrets.psd1
    SmtpPassword = ''                     # Gmail app password - set in secrets.psd1

    # Automated collection settings
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

    # Threading
    MaxThreads   = 5

    # HTML Report settings (PSWriteHTML)
    Report = @{
        Enabled    = $false                              # Enable/disable HTML report generation
        OutputPath = '.\temp\SystemHealthReport.html'  # Relative or absolute path for HTML file
        Open       = $false                             # Auto-open report in default browser
    }
}
