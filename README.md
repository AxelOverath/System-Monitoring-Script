# System Monitoring Script

A comprehensive PowerShell-based system monitoring solution with **automated self-healing capabilities** that collects system metrics from remote servers via SSH, stores them in a MySQL database, generates interactive HTML reports, and automatically remediate common issues.

## 🚀 Features

- **Real-time Metrics Collection**: Accurate CPU, Memory, and Disk usage statistics via SSH
- **Automated Self-Healing**: Progressive remediation actions based on severity levels
- **Database Storage**: Persistent storage in MySQL database for historical tracking
- **Interactive HTML Reports**: Modern dashboard with charts and visualizations using PSWriteHTML
- **Multi-Level Alerting**: Configurable thresholds with email notifications
- **Docker Cleanup**: Automated Docker container, image, and volume cleanup
- **SSH Connectivity**: Secure remote monitoring via SSH with key-based authentication
- **Automated Scheduling**: Built-in Windows Task Scheduler integration
- **Progressive Cleanup**: Escalating cleanup actions based on resource usage severity
- **Comprehensive Testing**: Full test suite with disk usage simulation tools

## 📁 Project Structure

```
System-Monitoring-Script/
├── config/
│   ├── config.psd1           # Main configuration with self-healing rules
│   ├── secrets.psd1          # Sensitive data (credentials)
│   └── vm_credentials.csv    # Server SSH connection details
├── docs/
│   └── Architecture.md       # System architecture documentation
├── modules/
│   ├── Alerting.psm1        # Email alerting functionality
│   ├── Database.psm1        # MySQL database operations
│   ├── DataCollector.psm1   # SSH-based metrics collection
│   ├── Reporting.psm1       # HTML report generation with PSWriteHTML
│   └── SelfHealing.psm1     # Automated remediation actions
├── scripts/
│   ├── Invoke-SystemHealthCheck.ps1     # Main monitoring script
│   └── Register-ScheduledHealthCheck.ps1 # Task scheduler setup
├── tests/
│   ├── Database.Tests.ps1    # Database module tests
│   ├── DataCollector.Tests.ps1 # Data collection tests
│   ├── SMTP.Tests.ps1        # Email functionality tests
│   └── Test-DiskUsage.ps1    # Disk usage simulation tool
└── README.md
```

## 🛠️ Prerequisites

### Software Requirements
- **PowerShell 7.0+** (recommended) or **PowerShell 5.1+**
- **MySQL Server** (local or remote instance)
- **PSWriteHTML Module** (for HTML report generation)
- **SSH Client** (built into Windows 10/11 and PowerShell 7+)

### Server Requirements
- **SSH access** to Linux/Unix servers with key-based authentication
- **Network connectivity** between monitoring server and target systems
- **Docker** (optional, for Docker cleanup features)

## 📦 Installation & Setup

### 1. Clone the Repository
```powershell
git clone https://github.com/AxelOverath/System-Monitoring-Script.git
cd System-Monitoring-Script

# Install required PowerShell module
Install-Module PSWriteHTML -Scope CurrentUser
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

CREATE TABLE self_healing_audit (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME NOT NULL,
    server VARCHAR(255) NOT NULL,
    metric VARCHAR(50) NOT NULL,
    value DECIMAL(5,2) NOT NULL,
    action_type VARCHAR(100) NOT NULL,
    success BOOLEAN NOT NULL,
    INDEX idx_timestamp (timestamp),
    INDEX idx_server (server)
);
```

### 3. SSH Key Setup
```powershell
# Generate SSH key pair (if needed)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# Copy public key to target servers
ssh-copy-id -i ~/.ssh/id_rsa.pub user@target-server
```

### 4. Configure Settings

#### Main Configuration (`config/config.psd1`)
```powershell
@{
    # Database configuration
    Database = @{
        Type     = 'MySql'
        Server   = 'localhost'
        Port     = 3306
        Name     = 'system_health'
        User     = ''            # Set in secrets.psd1
        Password = ''            # Set in secrets.psd1
    }
    
    # Alert threshold configuration (percent)
    Thresholds = @{
        Cpu    = 85
        Memory = 90
        Disk   = 80
    }
    
    # Email notification configuration
    Email = @{
        Enabled      = $true
        From         = 'monitoring@yourcompany.com'
        To           = 'alerts@yourcompany.com'
        SmtpServer   = 'smtp.gmail.com'
        SmtpPort     = 587
        UseSsl       = $true
        SmtpUsername = ''        # Set in secrets.psd1
        SmtpPassword = ''        # Set in secrets.psd1
    }
    
    # Self-healing configuration with progressive actions
    SelfHealing = @{
        Enabled = $true
        DefaultTimeoutSec = 30
        AuditLogPath = '.\temp\selfhealing_audit.csv'
        
        # Progressive remediation rules
        Rules = @(
            # CPU Management - Restart service when CPU > 85%
            @{
                Trigger = @{
                    Metric    = 'CPU'
                    Condition = 'gt'
                    Value     = 85
                }
                Action = @{
                    Type        = 'RestartService'
                    ServiceName = 'nginx'
                    UserService = $true  # systemctl --user
                }
            },
            
            # Disk Management - Progressive cleanup based on severity
            @{
                Trigger = @{ Metric = 'Disk'; Condition = 'gt'; Value = 80 }
                Action = @{
                    Type    = 'RunCommand'
                    Command = 'df -h && echo "Disk usage checked"'
                }
            },
            @{
                Trigger = @{ Metric = 'Disk'; Condition = 'gt'; Value = 85 }
                Action = @{
                    Type    = 'RunCommand'
                    Command = 'docker system prune -f && docker volume prune -f'
                }
            },
            @{
                Trigger = @{ Metric = 'Disk'; Condition = 'gt'; Value = 90 }
                Action = @{
                    Type    = 'RunCommand'
                    Command = 'docker system prune -af --volumes && docker image prune -af'
                }
            },
            @{
                Trigger = @{ Metric = 'Disk'; Condition = 'gt'; Value = 95 }
                Action = @{
                    Type    = 'RunCommand'
                    Command = 'find /tmp -user $USER -type f -mtime +1 -delete 2>/dev/null; docker container prune -f'
                }
            }
        )
    }
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
192.168.1.100,admin,,C:\Users\username\.ssh\id_rsa,22
vm1.domain.com,root,,C:\Users\username\.ssh\id_rsa,2222
vm2.domain.com,ubuntu,,C:\Users\username\.ssh\id_rsa,2223
```

## 🔧 Usage

### Manual Execution
```powershell
# Navigate to project directory
cd C:\Users\username\Documents\GitHub\System-Monitoring-Script

# Run system health check
pwsh -ExecutionPolicy Bypass -File .\scripts\Invoke-SystemHealthCheck.ps1 -ConfigPath .\config\config.psd1

# Test specific functionality
.\tests\SMTP.Tests.ps1
```

### Automated Scheduling
```powershell
# Register scheduled task (run as Administrator)
.\scripts\Register-ScheduledHealthCheck.ps1 -ConfigPath .\config\config.psd1
```

### Testing Tools
```powershell
# Simulate disk usage for testing self-healing
.\tests\Test-DiskUsage.ps1 -Action Create -TargetPercent 90 -VMPort 2222

# Clean up test files
.\tests\Test-DiskUsage.ps1 -Action Remove -VMPort 2222

# Run comprehensive tests
Invoke-Pester .\tests\ -Verbose
```

## 🤖 Self-Healing Capabilities

The system includes **automated remediation** with progressive escalation:

### Progressive Disk Cleanup Strategy
- **80%+ Disk Usage**: Diagnostic reporting (`df -h`)
- **85%+ Disk Usage**: Basic Docker cleanup (`docker system prune -f`)
- **90%+ Disk Usage**: Aggressive Docker cleanup (`docker system prune -af --volumes`)
- **95%+ Disk Usage**: Emergency cleanup (temp files + containers)

### CPU Management
- **85%+ CPU Usage**: Restart configured services (nginx, apache, etc.)
- **UserService Support**: `systemctl --user` commands for user services

### Memory Management
- **90%+ Memory Usage**: Clear system caches and buffers

### Audit Logging
All self-healing actions are logged to:
- **Database**: `self_healing_audit` table
- **CSV File**: `.\temp\selfhealing_audit.csv`
- **HTML Reports**: Actions included in monitoring dashboard

## 📊 Monitoring Dashboard

### Interactive HTML Reports
- **Real-time Metrics**: Current CPU, Memory, and Disk usage with status indicators
- **Historical Charts**: Visual trends and patterns
- **Threshold Analysis**: Color-coded alerts and violation reports
- **Self-Healing Actions**: Audit trail of automated remediation
- **Export Options**: Excel, CSV, and PDF export functionality

### Key Performance Indicators
- **System Health Score**: Overall health percentage
- **Alert Summary**: Active alerts and threshold violations
- **Remediation Success Rate**: Self-healing effectiveness metrics
- **Resource Utilization**: Peak and average usage statistics

## 🧪 Testing Framework

### Disk Usage Simulation
```powershell
# Test different alert thresholds
.\tests\Test-DiskUsage.ps1 -Action Create -TargetPercent 85 -VMPort 2222  # Trigger basic cleanup
.\tests\Test-DiskUsage.ps1 -Action Create -TargetPercent 90 -VMPort 2222  # Trigger aggressive cleanup
.\tests\Test-DiskUsage.ps1 -Action Create -TargetPercent 95 -VMPort 2222  # Trigger emergency cleanup
```

### Validation Tests
- **SSH Connectivity**: Verify remote access to all servers
- **Database Operations**: Test MySQL connection and data storage
- **Email Notifications**: Validate SMTP configuration
- **Self-Healing Actions**: Test remediation effectiveness

## ⚡ Performance Features

### Accurate CPU Metrics
- **Fixed CPU Calculation**: Uses actual CPU percentage instead of load average
- **Real-time Monitoring**: Direct parsing of `/proc/stat` and `top` output
- **Threshold Accuracy**: Prevents false positive alerts

### Efficient Data Collection
- **Multi-threading**: Parallel collection from multiple servers
- **SSH Optimization**: Direct SSH commands without PowerShell Remoting overhead
- **Connection Pooling**: Reuse SSH connections for multiple commands

### Smart Cleanup
- **Docker-focused**: Targets the largest space consumers
- **Progressive Escalation**: More aggressive cleanup as usage increases
- **User Data Protection**: Never removes user files or important data

## 🔒 Security Considerations

- **SSH Key Authentication**: Secure, password-less remote access
- **Credential Separation**: Sensitive data isolated in `secrets.psd1`
- **Minimal Privileges**: Self-healing uses user-level permissions
- **Audit Trail**: Complete logging of all automated actions
- **Network Security**: SSH encryption for all remote communications

## 🚨 Troubleshooting

### Common Issues

#### SSH Connection Failures
```powershell
# Test SSH connectivity
ssh -i C:\Users\username\.ssh\id_rsa -p 2222 username@127.0.0.1

# Check SSH key permissions
icacls C:\Users\username\.ssh\id_rsa /inheritance:r /grant:r "$env:USERNAME:F"
```

#### Self-Healing Not Working
```powershell
# Check self-healing configuration
Get-Content .\config\config.psd1 | Select-String "SelfHealing" -A 20

# Verify audit logs
Get-Content .\temp\selfhealing_audit.csv | Select-Object -Last 10
```

#### Database Connection Issues
```powershell
# Test MySQL connection
Test-NetConnection -ComputerName localhost -Port 3306

# Verify credentials in secrets.psd1
```

## 📈 Monitoring Best Practices

### Threshold Configuration
- **CPU**: 85% (allows for normal spikes)
- **Memory**: 90% (prevents OOM conditions)  
- **Disk**: 80% (provides cleanup buffer)

### Self-Healing Guidelines
- **Test in Development**: Use `Test-DiskUsage.ps1` to validate actions
- **Monitor Audit Logs**: Review self-healing effectiveness
- **Gradual Rollout**: Start with safe actions, add aggressive cleanup gradually
- **Regular Validation**: Ensure cleanup actions remain effective

### Performance Optimization
- **Schedule Frequency**: Balance monitoring needs vs. system load
- **Parallel Jobs**: Adjust `MaxThreads` based on server count
- **Historical Data**: Implement database retention policies

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This project was developed with assistance from GitHub Copilot, which provided guidance on:
- PowerShell best practices and module design
- SSH-based remote monitoring techniques  
- Self-healing automation strategies
- Progressive remediation patterns
- Testing frameworks and validation tools
