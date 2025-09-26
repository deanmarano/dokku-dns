# Configuration Reference

This document covers all configuration options, environment variables, and advanced settings available in the DNS plugin.

## Environment Variables

### Core Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DOKKU_DNS_SERVER_IP` | Override server IP detection | Auto-detected | `1.2.3.4` |
| `DNS_DEBUG` | Enable debug logging | `false` | `true` |
| `DNS_DISABLE_PULL` | Disable Docker image pulls | `false` | `true` |

**Usage:**
```shell
# Set server IP override
dokku config:set --global DOKKU_DNS_SERVER_IP=203.0.113.10

# Enable debug logging
dokku config:set --global DNS_DEBUG=true
```

### AWS Route53 Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | None | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | None | `wJalrX...` |
| `AWS_DEFAULT_REGION` | AWS default region | `us-east-1` | `eu-west-1` |
| `AWS_PROFILE` | AWS CLI profile | `default` | `production` |
| `AWS_SESSION_TOKEN` | AWS session token (temporary credentials) | None | `FwoG...` |

**Usage:**
```shell
# Basic AWS setup
dokku config:set --global AWS_ACCESS_KEY_ID=your_access_key
dokku config:set --global AWS_SECRET_ACCESS_KEY=your_secret_key
dokku config:set --global AWS_DEFAULT_REGION=us-west-2

# Using AWS profiles
dokku config:set --global AWS_PROFILE=production

# App-specific AWS configuration
dokku config:set --no-restart myapp AWS_PROFILE=staging
```

### Cloudflare Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token (recommended) | None | `token_string` |
| `CLOUDFLARE_EMAIL` | Cloudflare account email (legacy) | None | `user@example.com` |
| `CLOUDFLARE_API_KEY` | Cloudflare global API key (legacy) | None | `key_string` |
| `CLOUDFLARE_API_BASE` | Custom API endpoint | `https://api.cloudflare.com/client/v4` | Custom URL |

**Usage:**
```shell
# Recommended: API Token
dokku config:set --global CLOUDFLARE_API_TOKEN=your_api_token

# Legacy: Global API Key (not recommended)
dokku config:set --global CLOUDFLARE_EMAIL=user@example.com
dokku config:set --global CLOUDFLARE_API_KEY=your_global_key
```

### DigitalOcean Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DIGITALOCEAN_ACCESS_TOKEN` | DigitalOcean API token | None | `dop_v1_...` |
| `DIGITALOCEAN_API_URL` | Custom API endpoint | `https://api.digitalocean.com/v2` | Custom URL |

## TTL Configuration

### TTL Hierarchy

The DNS plugin supports three levels of TTL configuration with inheritance:

```
Global TTL (300s default)
├── Zone TTL (overrides global)
└── Domain TTL (overrides zone and global)
```

### Global TTL

**Default:** 300 seconds (5 minutes)

```shell
# Get current global TTL
dokku dns:ttl

# Set global TTL
dokku dns:ttl 600

# Valid range: 60-86400 seconds (1 minute to 24 hours)
```

### Zone TTL

**Default:** Inherits from global TTL

```shell
# Get zone TTL
dokku dns:zones:ttl example.com

# Set zone TTL
dokku dns:zones:ttl example.com 3600

# Remove zone TTL (inherit from global)
dokku dns:zones:ttl example.com --unset
```

### Domain TTL

**Default:** Inherits from zone or global TTL

```shell
# Set domain-specific TTL during app enable
dokku dns:apps:enable myapp api.example.com --ttl 60

# Domain TTL is stored per app/domain combination
# Check effective TTL in dns:report
dokku dns:report myapp
```

### TTL Best Practices

| Use Case | Recommended TTL | Reason |
|----------|----------------|---------|
| Development | 60-300s | Quick changes |
| Staging | 300-900s | Moderate flexibility |
| Production (stable) | 3600-7200s | Reduce query load |
| Production (changing) | 300-600s | Allow updates |
| CDN/Static content | 86400s | Maximum caching |
| API endpoints | 300s | Load balancing flexibility |

```shell
# Example TTL configuration
dokku dns:ttl 300                              # Global default
dokku dns:zones:ttl production.com 3600        # Stable production
dokku dns:zones:ttl dev.example.com 60         # Development
dokku dns:apps:enable api api.production.com --ttl 300  # API flexibility
```

## Zone Management

### Zone Enablement

Zones must be enabled before automatic DNS management:

```shell
# Enable zone for automatic management
dokku dns:zones:enable example.com

# Disable zone (stops automatic management)
dokku dns:zones:disable example.com

# Enable all zones with active domains
dokku dns:zones:enable --all

# Check zone status
dokku dns:zones
```

### Zone Configuration Storage

Zone settings are stored in:
```
/var/lib/dokku/services/dns/
├── ENABLED_ZONES           # List of enabled zones
├── zones/
│   ├── example.com/
│   │   └── TTL             # Zone-specific TTL
│   └── api.example.com/
│       └── TTL
```

## App Configuration

### App-Specific DNS Settings

```shell
# App DNS domains are stored in:
/var/lib/dokku/services/dns/myapp/
├── DOMAINS                 # List of managed domains
└── domains/
    ├── example.com/
    │   └── TTL             # Domain-specific TTL
    └── api.example.com/
        └── TTL
```

### App Environment Variables

```shell
# Override DNS provider for specific app
dokku config:set --no-restart myapp AWS_PROFILE=staging
dokku config:set --no-restart myapp CLOUDFLARE_API_TOKEN=staging_token

# Override server IP for specific app
dokku config:set --no-restart myapp DOKKU_DNS_SERVER_IP=192.168.1.100
```

## Automation Configuration

### Trigger Management

Control automatic DNS management during app lifecycle events:

```shell
# Enable automatic management
dokku dns:triggers:enable

# Disable automatic management
dokku dns:triggers:disable

# Check trigger status
dokku dns:triggers
```

**Trigger configuration stored in:**
```
/var/lib/dokku/services/dns/TRIGGERS_ENABLED
```

### Cron Automation

**Schedule automated DNS synchronization:**

```shell
# Enable cron with default schedule (hourly)
dokku dns:cron --enable

# Enable with custom schedule (every 5 minutes)
dokku dns:cron --enable --schedule "*/5 * * * *"

# Disable cron
dokku dns:cron --disable

# Check cron status
dokku dns:cron
```

**Cron schedule format (standard crontab):**
```
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday)
# │ │ │ │ │
# * * * * *
```

**Common schedules:**
```shell
# Every 5 minutes
dokku dns:cron --schedule "*/5 * * * *"

# Every hour
dokku dns:cron --schedule "0 * * * *"

# Daily at 2 AM
dokku dns:cron --schedule "0 2 * * *"

# Twice daily (6 AM and 6 PM)
dokku dns:cron --schedule "0 6,18 * * *"
```

## Advanced Configuration

### Multi-Provider Configuration

```shell
# Configure multiple providers simultaneously
export AWS_ACCESS_KEY_ID=aws_key
export AWS_SECRET_ACCESS_KEY=aws_secret
export CLOUDFLARE_API_TOKEN=cf_token

# Provider-specific app configuration
dokku config:set --no-restart corporate-app AWS_PROFILE=production
dokku config:set --no-restart personal-app CLOUDFLARE_API_TOKEN=personal_token
```

### Network Configuration

```shell
# Custom DNS resolution timeout
export DNS_RESOLUTION_TIMEOUT=10

# Custom API request timeout
export DNS_API_TIMEOUT=30

# Custom retry configuration
export DNS_RETRY_COUNT=5
export DNS_RETRY_DELAY=3
```

### Debug and Logging Configuration

```shell
# Enable comprehensive debug logging
dokku config:set --global DNS_DEBUG=true

# Custom log levels (if supported in future)
dokku config:set --global DNS_LOG_LEVEL=DEBUG

# Custom log file location
dokku config:set --global DNS_LOG_FILE=/var/log/dokku-dns.log
```

## Security Configuration

### Credential Security

**Best Practices:**

1. **Use minimal permissions:**
   ```shell
   # AWS: Create IAM user with Route53-only permissions
   # Cloudflare: Use scoped API tokens, not global keys
   ```

2. **Rotate credentials regularly:**
   ```shell
   # Set up credential rotation schedule
   # Test new credentials before removing old ones
   ```

3. **Use environment-specific credentials:**
   ```shell
   # Different credentials for different environments
   dokku config:set --no-restart staging-app AWS_PROFILE=staging
   dokku config:set --no-restart prod-app AWS_PROFILE=production
   ```

### Access Control

```shell
# Restrict plugin access to specific users
# Use Dokku's user management system
# Consider using sudo restrictions for DNS operations
```

## Performance Configuration

### API Rate Limiting

**AWS Route53:**
- Limit: 5 requests per second per account
- Plugin handles automatically with exponential backoff

**Cloudflare:**
- Free: 1,200 requests per 5 minutes
- Pro+: Higher limits available
- Plugin handles automatically

### Optimization Settings

```shell
# Batch operations for better performance
dokku dns:sync-all                    # More efficient than individual syncs

# Optimize TTL settings for performance
dokku dns:zones:ttl static.com 7200   # Higher TTL for static content
dokku dns:zones:ttl api.com 300       # Lower TTL for API endpoints
```

## Backup and Recovery Configuration

### Configuration Backup

```shell
# Backup DNS plugin configuration
sudo tar -czf dns-backup.tar.gz /var/lib/dokku/services/dns/

# Backup individual components
sudo cp -r /var/lib/dokku/services/dns/zones/ ~/dns-zones-backup/
sudo cp /var/lib/dokku/services/dns/ENABLED_ZONES ~/enabled-zones-backup
```

### Recovery Procedures

```shell
# Restore from backup
sudo tar -xzf dns-backup.tar.gz -C /

# Verify configuration after restore
dokku dns:zones
dokku dns:report
```

## Migration Configuration

### Provider Migration

```shell
# Gradual migration approach
# 1. Configure new provider
export NEW_PROVIDER_CREDENTIALS=...

# 2. Enable zones on new provider
dokku dns:zones:enable new-zone.com

# 3. Migrate apps gradually
dokku domains:add myapp new-zone.com
dokku dns:apps:sync myapp

# 4. Remove old domains after verification
dokku domains:remove myapp old-zone.com
```

### Version Migration

```shell
# Check current plugin version
dokku dns:version

# Backup before upgrade
sudo tar -czf dns-backup-pre-upgrade.tar.gz /var/lib/dokku/services/dns/

# Update plugin
sudo dokku plugin:update dns

# Verify after upgrade
dokku dns:providers:verify
dokku dns:report
```

## Configuration Validation

### Health Check Commands

```shell
# Verify provider connectivity
dokku dns:providers:verify aws
dokku dns:providers:verify cloudflare

# Check zone configuration
dokku dns:zones

# Verify app configuration
dokku dns:report myapp

# Test DNS resolution
dig example.com @8.8.8.8
dig example.com @1.1.1.1
```

### Configuration Troubleshooting

```shell
# Common validation steps
# 1. Check credentials
dokku config:show --global | grep AWS
dokku config:show --global | grep CLOUDFLARE

# 2. Verify zone delegation
dig NS example.com

# 3. Test API connectivity
dokku dns:providers:verify

# 4. Check file permissions
sudo ls -la /var/lib/dokku/services/dns/

# 5. Verify Dokku domains
dokku domains:report myapp
```

## Configuration Examples

### Single Provider Setup

```shell
# AWS Route53 only
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
dokku config:set --global AWS_DEFAULT_REGION=us-east-1

# Enable zones and apps
dokku dns:zones:enable example.com
dokku dns:apps:enable myapp
```

### Multi-Provider Setup

```shell
# Multiple providers
export AWS_ACCESS_KEY_ID=aws_key
export AWS_SECRET_ACCESS_KEY=aws_secret
export CLOUDFLARE_API_TOKEN=cf_token

# Zone distribution
dokku dns:zones:enable corporate.com    # AWS
dokku dns:zones:enable personal.dev     # Cloudflare

# App distribution
dokku dns:apps:enable corporate-app
dokku dns:apps:enable personal-blog
```

### High-Availability Setup

```shell
# Primary provider
export AWS_ACCESS_KEY_ID=primary_key
export AWS_SECRET_ACCESS_KEY=primary_secret

# Backup provider (for manual failover)
export CLOUDFLARE_API_TOKEN=backup_token

# Monitoring setup
dokku dns:cron --enable --schedule "*/5 * * * *"
```

### Development Environment

```shell
# Development-optimized settings
dokku config:set --global DNS_DEBUG=true
dokku dns:ttl 60                      # Quick changes
dokku dns:zones:enable dev.example.com
dokku dns:triggers:enable             # Automatic updates
```

---

**Related Documentation:**
- [Provider Setup Guides](aws-provider.md) - Provider-specific configuration
- [FAQ](FAQ.md) - Common configuration questions
- [Troubleshooting](troubleshooting.md) - Configuration issue resolution