# Frequently Asked Questions (FAQ)

## Installation and Setup

### Q: How do I install the DNS plugin?

**A:** Install directly from GitHub:
```shell
sudo dokku plugin:install https://github.com/deanmarano/dokku-dns.git --name dns
```

### Q: Which DNS providers are supported?

**A:** Currently supported providers:
- **AWS Route53** - Enterprise-grade with health checks and failover
- **Cloudflare** - Global CDN with free tier and DDoS protection
- **DigitalOcean DNS** - Simple, reliable DNS with competitive pricing

### Q: Do I need to use a specific Dokku version?

**A:** Yes, the plugin requires Dokku 0.19.x or newer for full functionality.

## Provider Configuration

### Q: How do I configure AWS Route53?

**A:** Three methods available:

**Method 1: Environment Variables (Recommended)**
```shell
dokku config:set --global AWS_ACCESS_KEY_ID=your_key
dokku config:set --global AWS_SECRET_ACCESS_KEY=your_secret
```

**Method 2: AWS CLI**
```shell
aws configure  # Then no additional setup needed
```

**Method 3: IAM Roles (EC2/ECS)**
```shell
# Attach IAM role with Route53 permissions - auto-detected
```

### Q: How do I configure Cloudflare?

**A:** Create an API token with Zone:Read and DNS:Edit permissions:
```shell
dokku config:set --global CLOUDFLARE_API_TOKEN=your_api_token
```

### Q: How do I configure DigitalOcean?

**A:** Create a Personal Access Token with read/write permissions:
```shell
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=your_api_token
```

### Q: Can I use multiple DNS providers simultaneously?

**A:** Yes! The plugin automatically routes domains to the appropriate provider based on which provider manages each zone:
```shell
export AWS_ACCESS_KEY_ID=aws_key
export CLOUDFLARE_API_TOKEN=cf_token
export DIGITALOCEAN_ACCESS_TOKEN=do_token
dokku dns:zones:enable corporate.com    # Uses AWS
dokku dns:zones:enable personal.dev     # Uses Cloudflare
dokku dns:zones:enable startup.app      # Uses DigitalOcean
```

## DNS Management

### Q: How do I enable DNS management for my app?

**A:** Simple two-step process:
```shell
# 1. Enable DNS management
dokku dns:apps:enable myapp

# 2. Sync DNS records
dokku dns:apps:sync myapp
```

### Q: Do I need to manually create hosted zones?

**A:** Yes, you need to create hosted zones in your DNS provider first:
- **AWS Route53**: Create hosted zone via AWS Console or CLI
- **Cloudflare**: Add domain to Cloudflare dashboard

The plugin will discover existing zones automatically.

### Q: How do I add specific domains instead of all app domains?

**A:** Specify domains explicitly:
```shell
dokku dns:apps:enable myapp example.com api.example.com
```

### Q: How do I check if DNS is working correctly?

**A:** Use the report command:
```shell
# Check specific app
dokku dns:report myapp

# Check all apps
dokku dns:report
```

## DNS Propagation and Timing

### Q: How long does DNS propagation take?

**A:** DNS propagation depends on TTL settings:
- **Low TTL (60-300s)**: Changes visible within 5-10 minutes
- **High TTL (3600s+)**: Changes may take 1-4 hours globally
- **Default TTL**: 300 seconds (5 minutes)

### Q: How do I make DNS changes faster?

**A:** Lower the TTL before making changes:
```shell
# Lower TTL temporarily
dokku dns:zones:ttl example.com 60

# Make your changes
dokku dns:apps:sync myapp

# Increase TTL after changes propagate
dokku dns:zones:ttl example.com 3600
```

### Q: What's the difference between global, zone, and domain TTL?

**A:** TTL hierarchy (most specific wins):
```
Global TTL (300s default)
├── Zone TTL (overrides global)
└── Domain TTL (overrides zone and global)
```

**Examples:**
```shell
dokku dns:ttl 300                              # Global default
dokku dns:zones:ttl example.com 3600           # Zone-specific
dokku dns:apps:enable myapp api.example.com --ttl 60  # Domain-specific
```

## Multi-Provider and Zone Management

### Q: How does multi-provider zone routing work?

**A:** The plugin automatically discovers which provider manages each zone:
1. Plugin queries all configured providers
2. Finds which provider hosts each zone
3. Routes DNS operations to the correct provider
4. No manual configuration needed

### Q: How do I enable automatic DNS management?

**A:** Enable triggers for automatic lifecycle management:
```shell
dokku dns:triggers:enable
```

This automatically creates/updates DNS records when you:
- Add/remove domains from apps
- Create/delete apps
- Rename apps

### Q: How do I enable zones for automatic management?

**A:** Use the zones:enable command:
```shell
# Enable specific zone
dokku dns:zones:enable example.com

# Check which zones are enabled
dokku dns:zones
```

## Troubleshooting

### Q: I get "No hosted zone found" errors. What's wrong?

**A:** Common causes and solutions:

1. **Zone doesn't exist**: Create hosted zone in your DNS provider
2. **Wrong nameservers**: Update domain registrar to use provider's nameservers
3. **Credential issues**: Verify provider credentials with `dokku dns:providers:verify`
4. **Zone not enabled**: Enable zone with `dokku dns:zones:enable example.com`

### Q: DNS records aren't being created. What should I check?

**A:** Debugging steps:
```shell
# 1. Verify provider connectivity
dokku dns:providers:verify aws
dokku dns:providers:verify cloudflare

# 2. Check zone status
dokku dns:zones

# 3. Enable zone if needed
dokku dns:zones:enable example.com

# 4. Check app domains
dokku domains:report myapp

# 5. Try sync with verbose output
dokku dns:apps:sync myapp
```

### Q: How do I debug DNS issues?

**A:** Enable debug logging:
```shell
# Enable debug mode
dokku config:set --global DNS_DEBUG=true

# Check provider verification
dokku dns:providers:verify aws 2>&1 | grep -i error

# Test specific operations
dokku dns:apps:sync myapp 2>&1
```

### Q: My DNS records point to the wrong IP. How do I fix this?

**A:** The plugin uses automatic IP detection. To override:
```shell
# Set specific server IP
dokku config:set --global DOKKU_DNS_SERVER_IP=1.2.3.4

# Then sync records
dokku dns:apps:sync myapp
```

## Performance and Scaling

### Q: Can I sync multiple apps at once?

**A:** Yes, use the bulk sync command:
```shell
dokku dns:sync-all
```

This is more efficient than individual syncs, especially for AWS Route53 which batches operations by hosted zone.

### Q: Are there API rate limits I should worry about?

**A:** Each provider has different limits:

**AWS Route53:**
- 5 requests per second per account
- Plugin includes automatic retry with exponential backoff

**Cloudflare:**
- 1,200 requests per 5 minutes (free plan)
- Plugin handles rate limiting automatically

### Q: How do I optimize for high-traffic sites?

**A:** Several strategies:

1. **Use appropriate TTLs**:
   ```shell
   dokku dns:zones:ttl example.com 3600  # Higher TTL = fewer queries
   ```

2. **Choose cost-effective providers**:
   - Cloudflare: Free DNS queries
   - AWS Route53: $0.40 per million queries

3. **Use CDN-friendly providers**:
   - Cloudflare: Built-in CDN and DDoS protection

## Automation and Lifecycle

### Q: How do I set up automated DNS sync?

**A:** Multiple automation options:

**Option 1: Triggers (Recommended)**
```shell
dokku dns:triggers:enable
# Automatically manages DNS during app lifecycle events
```

**Option 2: Cron Jobs**
```shell
dokku dns:cron --enable --schedule "*/5 * * * *"
# Syncs all apps every 5 minutes
```

**Option 3: Manual Scheduling**
```shell
# Add to system crontab
echo "*/5 * * * * dokku dns:sync-all" | sudo tee -a /etc/crontab
```

### Q: What happens when I delete an app?

**A:** Depends on your trigger settings:

**With triggers enabled**:
- DNS records are automatically removed
- Orphaned records are cleaned up

**Without triggers**:
- DNS records remain (manual cleanup needed)
- Use `dokku dns:sync:deletions` to clean up

### Q: How do I clean up orphaned DNS records?

**A:** Use the deletion sync command:
```shell
# Clean up all zones
dokku dns:sync:deletions

# Clean up specific zone
dokku dns:sync:deletions example.com
```

## Security and Best Practices

### Q: How should I manage DNS credentials securely?

**A:** Security best practices:

1. **Use minimal permissions**:
   - AWS: Create IAM user with only Route53 permissions
   - Cloudflare: Use scoped API tokens, not global API key

2. **Rotate credentials regularly**:
   ```shell
   # Generate new credentials
   # Update Dokku config
   dokku config:set --global AWS_ACCESS_KEY_ID=new_key
   # Delete old credentials
   ```

3. **Use environment-specific credentials**:
   ```shell
   # Different credentials for different environments
   dokku config:set --no-restart staging-app AWS_PROFILE=staging
   ```

### Q: Should I use global API keys or scoped tokens?

**A:** Always use scoped tokens when available:

**Cloudflare**: Use custom API tokens with minimal permissions
```
Zone:Zone:Read + Zone:DNS:Edit for specific zones
```

**AWS**: Use IAM users with minimal policies
```json
{
  "Action": [
    "route53:ListHostedZones",
    "route53:ChangeResourceRecordSets"
  ]
}
```

### Q: How do I monitor DNS operations?

**A:** Several monitoring approaches:

1. **Built-in reporting**:
   ```shell
   dokku dns:report  # Regular status checks
   ```

2. **Provider dashboards**:
   - AWS CloudWatch for Route53 metrics
   - Cloudflare Analytics for query metrics

3. **External monitoring**:
   - DNS monitoring services
   - Uptime monitoring tools
   - Custom health check scripts

## Cost and Billing

### Q: What are the costs for different providers?

**A:** Approximate costs (as of 2024):

**AWS Route53:**
- Hosted zone: $0.50/month per zone
- DNS queries: $0.40 per million queries
- Health checks: $0.50/month per check

**Cloudflare:**
- DNS hosting: Free
- DNS queries: Free on all plans
- Pro plan: $20/month (advanced features)

### Q: How do I optimize DNS costs?

**A:** Cost optimization strategies:

1. **Use free providers for high-traffic sites**:
   ```shell
   dokku dns:zones:enable blog.mysite.com  # Cloudflare for free queries
   ```

2. **Use paid providers only where needed**:
   ```shell
   dokku dns:zones:enable api.business.com  # AWS for health checks
   ```

3. **Optimize TTL settings**:
   ```shell
   dokku dns:zones:ttl static.mysite.com 7200  # Higher TTL = fewer queries
   ```

## Migration and Upgrades

### Q: How do I migrate from another DNS solution?

**A:** Migration steps:

1. **Export current DNS records** from existing provider
2. **Set up new provider** with DNS plugin
3. **Test with staging domains** first
4. **Migrate production domains** during maintenance window
5. **Update nameservers** at domain registrar
6. **Monitor DNS propagation**

### Q: How do I upgrade the DNS plugin?

**A:** Standard Dokku plugin upgrade:
```shell
sudo dokku plugin:update dns
```

### Q: Will upgrading break my existing DNS setup?

**A:** The plugin maintains backward compatibility:
- Existing configurations are preserved
- DNS records remain unchanged
- Provider credentials are maintained

Always test upgrades in staging first.

## Getting Help

### Q: Where can I get additional support?

**A:** Multiple support channels:

1. **Documentation**: Check the [docs/](../) directory
2. **GitHub Issues**: [Report bugs and request features](https://github.com/deanmarano/dokku-dns/issues)
3. **Dokku Community**: [Join the discussion](https://webchat.libera.chat/?channels=dokku)
4. **Provider Documentation**: AWS Route53, Cloudflare docs

### Q: How do I report bugs or request features?

**A:** Use GitHub Issues with:
- Clear description of the problem
- Steps to reproduce
- Expected vs. actual behavior
- Relevant configuration (sanitized)
- DNS plugin version (`dokku dns:version`)

### Q: How can I contribute to the project?

**A:** Several ways to contribute:
- Report bugs and test fixes
- Improve documentation
- Add new DNS provider support
- Submit performance optimizations
- Help other users in issues/discussions

See [Contributing Guidelines](../CONTRIBUTING.md) for details.

---

**Still have questions?** Check the provider-specific setup guides:
- [AWS Route53 Setup](aws-provider.md)
- [Cloudflare Setup](cloudflare-provider.md)
- [Multi-Provider Scenarios](multi-provider-scenarios.md)