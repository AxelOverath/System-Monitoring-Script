# System Monitoring Script

A comprehensive PowerShell-based system monitoring solution that collects system metrics from Linux servers, stores them in a MySQL database, and sends email alerts when thresholds are exceeded.

##  Features

- **Real-time Metrics Collection**: Collect CPU, Memory, and Disk usage statistics
- **Database Storage**: Store metrics in MySQL database for historical tracking
- **Threshold-based Alerting**: Configurable thresholds with email notifications
- **Automated Scheduling**: Built-in task scheduler integration
- **Secure Configuration**: Separate secrets management for sensitive data
- **Comprehensive Testing**: Full test suite with Pester framework

##  Project Structure

```
System-Monitoring-Script/
 config/
    config.psd1           # Main configuration file
    secrets.psd1          # Sensitive data (credentials)
    vm_credentials.csv    # Server connection details
 docs/
    Architecture.md       # System architecture documentation
 modules/
    Alerting.psm1        # Email alerting functionality
    Database.psm1        # MySQL database operations
    DataCollector.psm1   # System metrics collection
 scripts/
    Invoke-SystemHealthCheck.ps1     # Main monitoring script
    Register-ScheduledHealthCheck.ps1 # Task scheduler setup
 tests/
    Database.Tests.ps1    # Database module tests
    DataCollector.Tests.ps1 # Data collection tests
    SMTP.Tests.ps1        # Email functionality tests
 README.md
```

##  Prerequisites

### Software Requirements
- **PowerShell 5.1+** or **PowerShell Core 7+**
- **MySQL Server** (XAMPP, standalone MySQL, or cloud instance)
- **MySQL .NET Connector** (included with XAMPP)
- **Pester 3.4.0+** (for running tests)

### Server Requirements
- **SSH access** to Linux servers for remote monitoring
- **PowerShell Remoting** enabled for Windows servers
- **Network connectivity** between monitoring server and target systems

##  Installation & Setup

### 1. Clone the Repository
```powershell
git clone https://github.com/AxelOverath/System-Monitoring-Script.git
cd System-Monitoring-Script
```

### 2. Configure MySQL Database
```sql
CREATE DATABASE system_health;
USE system_health;

CREATE TABLE metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    server VARCHAR(255) NOT NULL,
    cpu_pct DECIMAL(5,2),
    mem_pct DECIMAL(5,2),
    disk_pct DECIMAL(5,2),
    timestamp DATETIME NOT NULL
);
```

### 3. Configure Settings

#### Main Configuration (`config/config.psd1`)
```powershell
@{
    # Database Settings
    DbServer   = 'localhost'
    DbPort     = 3306
    DbName     = 'system_health'
    
    # Alert Thresholds (%)
    CpuThreshold    = 85
    MemoryThreshold = 90
    DiskThreshold   = 80
    
    # Email Settings
    EmailFrom    = 'your-email@gmail.com'
    EmailTo      = 'alerts@yourcompany.com'
    SmtpServer   = 'smtp.gmail.com'
    SmtpPort     = 587
    UseSsl       = $true
}
```

#### Secrets Configuration (`config/secrets.psd1`)
```powershell
@{
    # Database Credentials
    DbUser     = 'root'
    DbPassword = 'your-mysql-password'
    
    # SMTP Authentication
    SmtpUsername = 'your-email@gmail.com'
    SmtpPassword = 'your-gmail-app-password'
}
```

#### Server Credentials (`config/vm_credentials.csv`)
```csv
Server,Username,Password,KeyPath,Port
server1.domain.com,admin,,/path/to/ssh/key,22
server2.domain.com,root,,/home/user/.ssh/id_rsa,2222
```

### 4. Gmail SMTP Setup

For Gmail SMTP authentication:

1. **Enable 2-Factor Authentication** on your Gmail account
2. **Generate App Password**:
   - Go to Google Account Security  2-Step Verification
   - Click "App passwords"
   - Select "Mail" and generate password
3. **Use the 16-character app password** in `secrets.psd1`

##  Usage

### Manual Execution
```powershell
# Run system health check
.\scripts\Invoke-SystemHealthCheck.ps1 -ConfigPath .\config\config.psd1

# Test SMTP configuration
.\tests\SMTP.Tests.ps1
```

### Automated Scheduling
```powershell
# Register scheduled task (run as Administrator)
.\scripts\Register-ScheduledHealthCheck.ps1 -ConfigPath .\config\config.psd1
```

### Running Tests
```powershell
# Run all tests
Invoke-Pester .\tests\

# Run specific test
Invoke-Pester .\tests\Database.Tests.ps1 -Verbose
```

##  Configuration Options

### Alert Thresholds
Customize monitoring thresholds in `config.psd1`:
- `CpuThreshold`: CPU usage percentage (default: 85%)
- `MemoryThreshold`: Memory usage percentage (default: 90%)
- `DiskThreshold`: Disk usage percentage (default: 80%)

### Scheduling Options
Configure automated collection frequency:
```powershell
Schedule = @{
    Frequency  = 'Daily'        # 'Hourly', 'Daily', 'Weekly'
    Time       = '03:00'        # HH:mm format
    DaysOfWeek = @('Monday')    # For weekly scheduling
    TaskName   = 'SystemHealthCheck'
}
```

### Multi-threading
Adjust concurrent job limits:
```powershell
MaxThreads = 5  # Maximum parallel collection jobs
```

##  Monitoring Dashboard

The system provides:
- **Real-time Metrics**: Current CPU, Memory, and Disk usage
- **Historical Data**: All metrics stored in MySQL with timestamps
- **Alert Notifications**: Email alerts when thresholds are exceeded
- **Job Status**: Background job monitoring and status reporting

##  Troubleshooting

### Common Issues

#### MySQL Connection Errors
```powershell
# Verify MySQL service is running
Get-Service -Name "MySQL*"

# Test database connection
Test-NetConnection -ComputerName localhost -Port 3306
```

#### SMTP Authentication Failures
```powershell
# Test SMTP configuration
.\tests\SMTP.Tests.ps1

# Verify app password is correct (16 characters)
```

#### SSH Connection Issues
```powershell
# Test SSH connectivity
Test-NetConnection -ComputerName server.domain.com -Port 22

# Verify SSH key permissions (Linux)
chmod 600 /path/to/ssh/key
```

##  Performance Optimization

### Large Scale Deployments
- Increase `MaxThreads` for more concurrent monitoring
- Implement database indexing on timestamp and server columns
- Consider database partitioning for historical data
- Use connection pooling for high-frequency monitoring

### Network Optimization
- Configure SSH connection multiplexing
- Implement connection caching
- Use compression for remote data collection

##  Testing

The project includes comprehensive tests:

- **Unit Tests**: Individual module functionality
- **Integration Tests**: End-to-end workflow testing
- **SMTP Tests**: Email notification verification
- **Database Tests**: MySQL connection and data storage

Run tests before deployment:
```powershell
# Full test suite
Invoke-Pester .\tests\ -PassThru

# Code coverage analysis
Invoke-Pester .\tests\ -CodeCoverage .\modules\*.psm1
```

##  Security Considerations

- **Credential Management**: Use `secrets.psd1` for sensitive data
- **SSH Key Security**: Proper key permissions and rotation
- **Database Security**: Use dedicated monitoring user with minimal privileges
- **Email Security**: App passwords instead of account passwords
- **Network Security**: VPN or secure network segments for monitoring traffic

##  License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

##  Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

##  Support

For support and questions:
- Create an issue on GitHub
- Check the [Architecture Documentation](docs/Architecture.md)
- Review the test files for usage examples

##  Acknowledgments

This project was developed with assistance from OpenAI's ChatGPT, which provided guidance on PowerShell best practices, testing frameworks, and system architecture design.
