@{
    # Database connection info
    DbType     = 'MySql'
    DbServer   = 'localhost'
    DbPort     = 3306
    DbName     = 'system_health'
    DbUser     = '' # Set in secrets.psd1
    DbPassword = '' # Set in secrets.psd1

    # Alert thresholds (percent)
    CpuThreshold    = 85
    MemoryThreshold = 90
    DiskThreshold   = 80

    # Notification settings
    EmailFrom    = 'alerts@contoso.com'
    EmailTo      = 'admin@contoso.com'
    SmtpServer   = 'smtp.contoso.local'
    
    # Automated collection settings
     Schedule = @{ 
        Frequency  = 'Daily';    # 'Hourly', 'Daily', or 'Weekly'
        Time       = '03:00';    # HH:mm, used for Daily/Weekly
        DaysOfWeek = @('Monday'); # Only if Frequency = 'Weekly'
        TaskName   = 'SystemHealthCheck'
    }

    # Threading
    MaxThreads   = 5
}
