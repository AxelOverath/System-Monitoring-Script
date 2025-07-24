@{
    # Database connection info
    DbServer    = 'sql01.contoso.local'
    DbName      = 'SystemHealth'

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
