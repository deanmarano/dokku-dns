## 🔄 Common Workflows

### Single App Setup
```shell
# 1. Create your app and add domains
dokku apps:create myapp
dokku domains:add myapp example.com www.example.com

# 2. Enable DNS management
dokku dns:apps:enable myapp

# 3. Sync DNS records
dokku dns:apps:sync myapp

# 4. Verify everything works
dokku dns:report myapp
```

### Multi-App Management
```shell
# Enable DNS for multiple apps
dokku dns:apps:enable app1
dokku dns:apps:enable app2
dokku dns:apps:enable app3

# Sync all at once
dokku dns:sync-all

# Check status of all apps
dokku dns:report
```

### Zone Management Workflow
```shell
# List available zones
dokku dns:zones

# Enable zones for automatic management
dokku dns:zones:enable example.com
dokku dns:zones:enable api.example.com

# Now new apps with domains in these zones will be auto-managed
dokku apps:create newapp
dokku domains:add newapp blog.example.com
# DNS records are automatically created!
```

### Advanced Multi-Provider Setup
```shell
# Set up multiple providers
export AWS_ACCESS_KEY_ID=your_aws_key
export AWS_SECRET_ACCESS_KEY=your_aws_secret
export CLOUDFLARE_API_TOKEN=your_cloudflare_token

# Verify both providers
dokku dns:providers:verify aws
dokku dns:providers:verify cloudflare

# Enable zones from different providers
dokku dns:zones:enable example.com      # AWS Route53
dokku dns:zones:enable mysite.dev       # Cloudflare

# Apps automatically use the right provider based on domain
dokku apps:create corporate
dokku domains:add corporate corp.example.com  # Uses AWS
dokku apps:create personal
dokku domains:add personal me.mysite.dev      # Uses Cloudflare
```

## 🕒 TTL Management Hierarchy

DNS TTL (Time-To-Live) can be configured at three levels with inheritance:

```
Global TTL (300s default)
├── Zone TTL (overrides global)
│   ├── example.com → 3600s
│   └── mysite.dev → 1800s
└── Domain TTL (overrides zone and global)
    ├── api.example.com → 60s (low TTL for API)
    └── cdn.mysite.dev → 86400s (high TTL for CDN)
```

**TTL Configuration Examples:**
```shell
# Set global default TTL
dokku dns:ttl 300

# Set zone-specific TTL
dokku dns:zones:ttl example.com 3600

# Set domain-specific TTL when enabling
dokku dns:apps:enable myapp api.example.com --ttl 60

# Check TTL hierarchy
dokku dns:report myapp  # Shows effective TTL for each domain
```

## 💡 Best Practices

### DNS Management Strategy
- **Enable zones first**: Use `dokku dns:zones:enable` to enable automatic management for your domains
- **Use triggers**: Enable `dokku dns:triggers:enable` for automatic DNS updates during app lifecycle events
- **Monitor with reports**: Regular `dokku dns:report` checks help catch DNS issues early
- **Set appropriate TTLs**: Use lower TTLs (60-300s) for development, higher (3600s+) for production

### Performance Optimization
- **Batch operations**: Use `dokku dns:sync-all` instead of individual syncs for multiple apps
- **Zone-level TTL**: Set reasonable TTLs at the zone level to avoid per-domain configuration
- **Provider selection**: Choose providers based on your geographic needs and API rate limits

### Security Considerations
- **Credential management**: Use IAM roles or limited-scope API tokens rather than root credentials
- **Regular audits**: Periodically run `dokku dns:sync:deletions` to clean up orphaned records
- **Access control**: Limit DNS management permissions to necessary team members only

### Multi-Provider Tips
- **Geographic distribution**: Use different providers for different geographic regions
- **Failover strategy**: Configure backup providers for critical domains
- **Cost optimization**: Balance features, reliability, and cost across providers
- **Zone delegation**: Organize domains logically across providers based on function

## 📚 Provider Setup Guides

- **[AWS Route53 Setup Guide](aws-provider.md)** - Complete setup with IAM policies and best practices
- **[Cloudflare Setup Guide](cloudflare-provider.md)** - API token creation and configuration
- **[DigitalOcean Setup Guide](digital-ocean-provider.md)** - DNS API setup and usage
- **[Multi-Provider Guide](multi-provider-scenarios.md)** - Advanced multi-provider configurations

## 🔧 Advanced Configuration

For advanced configuration options, environment variables, and troubleshooting, see:
- **[Configuration Reference](configuration.md)** - All configuration options and environment variables
- **[FAQ](FAQ.md)** - Frequently asked questions and common issues
- **[Troubleshooting Guide](troubleshooting.md)** - Error resolution and debugging

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](../CONTRIBUTING.md) for details on:
- Reporting bugs and requesting features
- Setting up the development environment
- Running tests and submitting pull requests
- Adding new DNS provider support

## 🆘 Support

- **Documentation**: Check the [docs/](./) directory for detailed guides
- **Issues**: Report bugs and request features on [GitHub Issues](https://github.com/deanmarano/dokku-dns/issues)
- **Community**: Join the discussion in the [Dokku community](https://webchat.libera.chat/?channels=dokku)
- **FAQ**: Check our [FAQ](FAQ.md) for common questions and solutions

---

**Need help getting started?** Check out the [Quick Start guide](../#-quick-start-5-minutes) or browse the provider setup guides for detailed configuration instructions.