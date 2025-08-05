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
    
    # Threading
    MaxThreads   = 5
}
