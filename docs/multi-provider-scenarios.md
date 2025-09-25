# Multi-Provider DNS Scenarios

This guide covers advanced multi-provider DNS configurations, including zone delegation, geographic distribution, failover strategies, and cost optimization across multiple DNS providers.

## Overview

The DNS plugin's multi-provider architecture allows you to:

- **Zone Delegation**: Different providers for different zones
- **Geographic Distribution**: Optimize DNS resolution by region
- **Provider Failover**: Backup DNS providers for resilience
- **Cost Optimization**: Balance features vs. cost across providers
- **Feature Specialization**: Use each provider's unique strengths

## Multi-Provider Setup

### Basic Configuration

```shell
# Configure multiple providers simultaneously
export AWS_ACCESS_KEY_ID=your_aws_key
export AWS_SECRET_ACCESS_KEY=your_aws_secret
export CLOUDFLARE_API_TOKEN=your_cloudflare_token

# Verify all providers
dokku dns:providers:verify aws
dokku dns:providers:verify cloudflare

# Enable zones from different providers
dokku dns:zones:enable corporate.com     # Managed by AWS Route53
dokku dns:zones:enable startup.dev       # Managed by Cloudflare
```

### Automatic Zone Discovery

The plugin automatically discovers which provider manages each zone:

```shell
# Check zone routing
dokku dns:zones

# Example output:
# Zone                Provider     Status    TTL
# corporate.com      aws          enabled   3600
# startup.dev        cloudflare   enabled   300
# internal.local     aws          disabled  300
```

## Common Scenarios

### Scenario 1: Corporate + Personal Domains

**Use Case**: Separate corporate domains (AWS) from personal projects (Cloudflare)

```shell
# Corporate domains on AWS Route53 (enterprise features)
dokku dns:zones:enable company.com
dokku dns:zones:enable corp-api.com
dokku dns:zones:ttl company.com 3600        # Higher TTL for stability

# Personal projects on Cloudflare (free tier)
dokku dns:zones:enable personal.dev
dokku dns:zones:enable hobby-site.com
dokku dns:zones:ttl personal.dev 300        # Lower TTL for flexibility

# Apps automatically use correct provider
dokku apps:create corporate-api
dokku domains:add corporate-api api.company.com    # → AWS Route53

dokku apps:create personal-blog
dokku domains:add personal-blog blog.personal.dev  # → Cloudflare
```

### Scenario 2: Geographic Distribution

**Use Case**: Optimize DNS resolution by geographic region

```shell
# US/Americas regions → AWS Route53 (US-based)
dokku dns:zones:enable myapp.com
dokku dns:zones:enable api-us.myapp.com

# Europe/Asia → Cloudflare (global network)
dokku dns:zones:enable eu.myapp.com
dokku dns:zones:enable asia.myapp.com

# Configure regional apps
dokku apps:create myapp-us
dokku domains:add myapp-us api-us.myapp.com

dokku apps:create myapp-eu
dokku domains:add myapp-eu eu.myapp.com
```

### Scenario 3: Environment Separation

**Use Case**: Different providers for different environments

```shell
# Production on AWS Route53 (enterprise SLA)
dokku dns:zones:enable prod.myapp.com
dokku dns:zones:ttl prod.myapp.com 3600

# Staging/Development on Cloudflare (cost-effective)
dokku dns:zones:enable staging.myapp.com
dokku dns:zones:enable dev.myapp.com
dokku dns:zones:ttl staging.myapp.com 300
dokku dns:zones:ttl dev.myapp.com 60

# Environment-specific apps
dokku apps:create myapp-prod
dokku domains:add myapp-prod api.prod.myapp.com

dokku apps:create myapp-staging
dokku domains:add myapp-staging api.staging.myapp.com
```

### Scenario 4: Feature Specialization

**Use Case**: Leverage unique provider features

```shell
# AWS Route53 for health checks and failover
dokku dns:zones:enable critical.myapp.com

# Cloudflare for CDN and DDoS protection
dokku dns:zones:enable static.myapp.com
dokku dns:zones:enable cdn.myapp.com

# Configure specialized apps
dokku apps:create api-server
dokku domains:add api-server api.critical.myapp.com  # → AWS health checks

dokku apps:create static-assets
dokku domains:add static-assets assets.cdn.myapp.com  # → Cloudflare CDN
```

## Advanced Configurations

### Provider-Specific TTL Strategies

```shell
# AWS Route53: Higher TTLs for stability
dokku dns:zones:ttl enterprise.com 7200

# Cloudflare: Lower TTLs for flexibility
dokku dns:zones:ttl startup.dev 300

# Development: Very low TTLs
dokku dns:zones:ttl dev.local 60
```

### Subdomain Delegation

```shell
# Main domain on one provider
dokku dns:zones:enable myapp.com          # AWS Route53

# API subdomain on another provider
dokku dns:zones:enable api.myapp.com      # Cloudflare

# Different apps use appropriate subdomains
dokku apps:create main-site
dokku domains:add main-site www.myapp.com

dokku apps:create api-service
dokku domains:add api-service api.myapp.com
```

### Failover and Redundancy

```shell
# Primary provider setup
dokku dns:zones:enable primary.com        # AWS Route53

# Monitor with health checks
dokku dns:apps:enable critical-app
dokku dns:apps:sync critical-app

# Manual failover to secondary provider
# (Automated failover requires external monitoring)
```

## Cost Optimization Strategies

### Provider Cost Comparison

| Feature | AWS Route53 | Cloudflare | Optimization |
|---------|-------------|------------|-------------|
| Hosted Zone | $0.50/month | Free | Use Cloudflare for personal projects |
| DNS Queries | $0.40/M queries | Free | Use Cloudflare for high-traffic sites |
| Health Checks | $0.50/check/month | Limited on free | Use AWS only where needed |
| Geo DNS | $0.70/query | Pro plan required | Choose based on usage |

### Cost-Optimized Setup

```shell
# High-traffic, cost-sensitive domains → Cloudflare
dokku dns:zones:enable blog.myapp.com         # Cloudflare (free queries)
dokku dns:zones:enable content.myapp.com      # Cloudflare (free queries)

# Critical business domains → AWS Route53
dokku dns:zones:enable api.business.com       # AWS (health checks)
dokku dns:zones:enable secure.business.com    # AWS (advanced features)

# Monitor costs
# AWS: CloudWatch billing alerts
# Cloudflare: Analytics dashboard
```

### Usage-Based Optimization

```shell
# Low-traffic domains
dokku dns:zones:enable personal.dev           # Cloudflare (free tier)

# Medium-traffic domains
dokku dns:zones:enable startup.com            # Cloudflare (pro if needed)

# High-traffic, critical domains
dokku dns:zones:enable enterprise.com         # AWS Route53 (full features)
```

## Operational Considerations

### Management Workflows

```shell
# Global operations work across all providers
dokku dns:sync-all                           # Syncs all zones
dokku dns:report                             # Shows all provider status

# Provider-specific operations
dokku dns:providers:verify aws               # Test AWS connectivity
dokku dns:providers:verify cloudflare       # Test Cloudflare connectivity
```

### Monitoring and Alerting

```shell
# Monitor all providers
dokku dns:zones                              # Check zone status

# Set up external monitoring
# - AWS CloudWatch for Route53 metrics
# - Cloudflare Analytics for query metrics
# - External DNS monitoring services
```

### Backup and Disaster Recovery

```shell
# Multi-provider reduces single point of failure
# Zone data automatically distributed
# Manual failover procedures:

# 1. Disable problematic zone
dokku dns:zones:disable problematic.com

# 2. Enable backup zone
dokku dns:zones:enable backup.com

# 3. Update application domains
dokku domains:add myapp backup.com
dokku dns:apps:sync myapp
```

## Security Considerations

### Credential Management

```shell
# Separate credentials for each provider
dokku config:set --global AWS_ACCESS_KEY_ID=aws_key
dokku config:set --global CLOUDFLARE_API_TOKEN=cf_token

# Environment-specific credentials
dokku config:set --no-restart myapp AWS_PROFILE=production
```

### Access Control

```shell
# Provider-specific access policies
# AWS IAM: Restrict to specific hosted zones
# Cloudflare: Use scoped API tokens

# Example AWS IAM policy for specific zones:
{
  "Effect": "Allow",
  "Action": [
    "route53:ChangeResourceRecordSets"
  ],
  "Resource": [
    "arn:aws:route53:::hostedzone/Z123456789",
    "arn:aws:route53:::hostedzone/Z987654321"
  ]
}
```

### Network Security

```shell
# IP restrictions where supported
# Cloudflare: API token IP filtering
# AWS: VPC endpoints for Route53 (if needed)

# Monitor for unusual activity
# Enable CloudTrail for AWS API calls
# Monitor Cloudflare API usage
```

## Performance Optimization

### Provider Selection by Use Case

**AWS Route53 Best For:**
- Enterprise applications requiring SLA
- Health checks and failover routing
- Integration with other AWS services
- Geo-location based routing

**Cloudflare Best For:**
- High-traffic websites (free queries)
- Global content distribution
- DDoS protection requirements
- Cost-sensitive applications

### DNS Resolution Optimization

```shell
# Optimize TTLs by provider and use case
dokku dns:zones:ttl api.enterprise.com 300      # AWS: Low TTL for failover
dokku dns:zones:ttl static.mysite.com 3600      # Cloudflare: High TTL for CDN

# Monitor resolution times
# Use DNS performance monitoring tools
# Adjust based on geographic user distribution
```

## Troubleshooting Multi-Provider Issues

### Common Issues

**1. Zone Routing Problems**
```shell
# Check zone discovery
dokku dns:zones

# Verify provider connectivity
dokku dns:providers:verify aws
dokku dns:providers:verify cloudflare

# Check zone ownership
dig NS example.com
```

**2. Conflicting Configurations**
```shell
# Each zone should have single provider
# Check for duplicate zone entries
dokku dns:zones | grep "example.com"

# Verify nameserver consistency
dig NS example.com @8.8.8.8
dig NS example.com @1.1.1.1
```

**3. Credential Issues**
```shell
# Test each provider separately
AWS_ACCESS_KEY_ID=test1 dokku dns:providers:verify aws
CLOUDFLARE_API_TOKEN=test2 dokku dns:providers:verify cloudflare

# Check credential scope and permissions
```

### Debug Mode

```shell
# Enable debug logging for troubleshooting
dokku config:set --global DNS_DEBUG=true

# Test specific provider operations
dokku dns:apps:sync myapp 2>&1 | grep -i error
```

## Migration Strategies

### Single to Multi-Provider

```shell
# Phase 1: Add second provider
export CLOUDFLARE_API_TOKEN=your_token
dokku dns:providers:verify cloudflare

# Phase 2: Migrate select zones
dokku dns:zones:enable new.domain.com        # Add to Cloudflare

# Phase 3: Gradually migrate domains
dokku domains:add myapp new.domain.com       # Add new domain
dokku dns:apps:sync myapp                    # Sync both domains
# Update application configuration
dokku domains:remove myapp old.domain.com    # Remove old domain
```

### Provider Migration

```shell
# Prepare new provider
dokku dns:providers:verify new-provider

# Enable zone on new provider
dokku dns:zones:enable migrating.com

# Test with staging first
dokku apps:create test-migration
dokku domains:add test-migration test.migrating.com
dokku dns:apps:sync test-migration

# Coordinate DNS cutover
# Update nameservers at registrar
# Monitor DNS propagation
```

## Best Practices Summary

### Strategic Planning
1. **Assess requirements** by domain/application
2. **Choose providers** based on features and cost
3. **Plan zone distribution** logically
4. **Implement gradually** with testing

### Operational Excellence
1. **Monitor all providers** continuously
2. **Document configurations** clearly
3. **Test failover procedures** regularly
4. **Keep credentials secure** and rotated

### Cost Management
1. **Review usage** monthly
2. **Optimize TTLs** for cost vs. flexibility
3. **Consider provider tiers** based on features needed
4. **Monitor query volumes** and adjust accordingly

---

**Next Steps**: After implementing multi-provider setups, consider [automation with triggers](workflows.md#automation--triggers) or reviewing [configuration options](configuration.md) for fine-tuning.