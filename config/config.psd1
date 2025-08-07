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
        Frequency  = 'Daily'        # 'Hourly', 'Daily', or 'Weekly'
        Time       = '03:00'        # HH:mm, used for Daily/Weekly
        DaysOfWeek = @('Monday')    # Only if Frequency = 'Weekly'
        TaskName   = 'SystemHealthCheck'
    }

    # Threading
    MaxThreads   = 5
}
