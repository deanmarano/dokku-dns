# Cloudflare Provider Setup Guide

Cloudflare is a popular DNS provider offering fast global DNS resolution with additional security and performance features. This guide covers complete setup, configuration, and best practices for using Cloudflare with the DNS plugin.

## Prerequisites

- Cloudflare account (free tier available)
- Domain(s) added to Cloudflare
- Dokku DNS plugin installed

## Quick Setup

### 1. Create API Token

**Recommended: Scoped API Token**
```shell
# 1. Go to Cloudflare Dashboard > My Profile > API Tokens
# 2. Click "Create Token"
# 3. Use "Custom token" template with these permissions:
#    - Zone:Zone:Read
#    - Zone:DNS:Edit
# 4. Set Zone Resources to include your zones
# 5. Add IP Address Filtering (optional but recommended)
```

**Alternative: Global API Key (Less Secure)**
```shell
# Only use if you need legacy compatibility
# Found in Cloudflare Dashboard > My Profile > API Tokens > Global API Key
```

### 2. Configure Cloudflare Credentials

```shell
# Set API token in Dokku
dokku config:set --global CLOUDFLARE_API_TOKEN=your_api_token_here

# Alternative: Global API Key method (not recommended)
dokku config:set --global CLOUDFLARE_EMAIL=your_email@example.com
dokku config:set --global CLOUDFLARE_API_KEY=your_global_api_key
```

### 3. Add Domain to Cloudflare

```shell
# 1. Go to Cloudflare Dashboard
# 2. Click "Add a Site"
# 3. Enter your domain name
# 4. Choose a plan (Free is sufficient for DNS)
# 5. Update nameservers at your domain registrar:
#    - Remove old nameservers
#    - Add Cloudflare nameservers (e.g., brad.ns.cloudflare.com)
```

### 4. Verify Setup

```shell
# Test Cloudflare provider connectivity
dokku dns:providers:verify cloudflare

# Check available zones
dokku dns:zones

# Enable zones for management
dokku dns:zones:enable example.com
```

## API Token Configuration

### Recommended Token Permissions

**Minimal Permissions for DNS Plugin:**
```
Zone:Zone:Read        # List and read zone information
Zone:DNS:Edit         # Create, update, delete DNS records
```

**Zone Resources:**
- Include: Specific zones (example.com, api.example.com)
- Or: All zones from account (if you manage many domains)

**IP Address Filtering (Optional):**
```
# Add your server's IP address for additional security
1.2.3.4/32
```

### Creating Token via API

```shell
# Create API token programmatically
curl -X POST "https://api.cloudflare.com/client/v4/user/tokens" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
     -H "Content-Type: application/json" \
     --data '{
       "name": "Dokku DNS Plugin",
       "policies": [
         {
           "effect": "allow",
           "resources": {
             "com.cloudflare.api.account.zone.*": "*"
           },
           "permission_groups": [
             {
               "id": "zone:read",
               "name": "Zone:Read"
             },
             {
               "id": "dns_records:edit",
               "name": "Zone:DNS:Edit"
             }
           ]
         }
       ]
     }'
```

## Advanced Configuration

### Custom API Endpoint

```shell
# Use custom Cloudflare API endpoint (rare)
dokku config:set --global CLOUDFLARE_API_BASE=https://api.cloudflare.com/client/v4
```

### Multiple Cloudflare Accounts

```shell
# Use different tokens for different zones
dokku config:set myapp CLOUDFLARE_API_TOKEN=token_for_specific_zone
```

### Zone-Specific Configuration

```shell
# Different TTL settings per zone
dokku dns:zones:ttl example.com 300      # Low TTL for frequently changing records
dokku dns:zones:ttl static.example.com 3600  # High TTL for static content
```

## Cloudflare-Specific Features

### Proxy Mode vs DNS-Only

**DNS-Only Mode (Gray Cloud):**
```shell
# DNS plugin creates records in DNS-only mode by default
# Records point directly to your server
dokku dns:apps:sync myapp
```

**Proxy Mode (Orange Cloud):**
```shell
# Enable through Cloudflare Dashboard after DNS sync
# Provides CDN, DDoS protection, SSL termination
# Note: May require additional configuration for WebSockets, etc.
```

### SSL/TLS Configuration

```shell
# Cloudflare SSL modes:
# - Off: No encryption between visitor and Cloudflare
# - Flexible: Encryption between visitor and Cloudflare only
# - Full: End-to-end encryption (self-signed OK)
# - Full (strict): End-to-end with valid certificate
```

### Performance Optimization

```shell
# Enable caching rules in Cloudflare Dashboard
# Set up page rules for static content
# Configure browser cache TTL
```

## Performance and Scaling

### API Rate Limits

- **Free Plan**: 1,200 requests per 5 minutes
- **Pro Plan**: 1,200 requests per 5 minutes
- **Business Plan**: 1,500 requests per 5 minutes
- **Enterprise**: Higher limits available

```shell
# DNS plugin includes automatic retry logic
# Monitor usage in Cloudflare Dashboard > Analytics > API
```

### Global Network Benefits

- Cloudflare's global anycast network provides fast DNS resolution
- 250+ data centers worldwide
- Built-in DDoS protection at DNS level

## Troubleshooting

### Common Issues

**1. API Token Permissions**
```shell
# Test token permissions
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"

# Expected response:
# {"result":{"id":"token_id","status":"active"},"success":true}
```

**2. Zone Not Found**
```shell
# List zones accessible to your token
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"

# Check zone status (must be "active")
dokku dns:providers:verify cloudflare
```

**3. DNS Record Creation Fails**
```shell
# Check if zone is using Cloudflare nameservers
dig NS example.com

# Verify zone is active in Cloudflare
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | \
     jq '.result[] | {name: .name, status: .status}'
```

**4. Rate Limiting**
```shell
# Check rate limit headers
curl -I -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"

# Look for:
# X-RateLimit-Limit: 1200
# X-RateLimit-Remaining: 1150
# X-RateLimit-Reset: 1609459200
```

### Debug Mode

```shell
# Enable verbose logging
dokku config:set --global CLOUDFLARE_DEBUG=1

# Test with curl
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
     -H "Content-Type: application/json"
```

## Security Best Practices

### 1. Token Security

```shell
# Use scoped tokens instead of global API key
# Rotate tokens regularly (monthly recommended)
# Store tokens securely (avoid plain text files)

# Create new token
# Update Dokku config
dokku config:set --global CLOUDFLARE_API_TOKEN=new_token
# Test functionality
dokku dns:providers:verify cloudflare
# Delete old token from Cloudflare dashboard
```

### 2. IP Restrictions

```shell
# Add IP filtering to API tokens
# Restrict to your server's IP address
# Use CIDR notation for multiple IPs: 1.2.3.0/24
```

### 3. Monitoring

```shell
# Enable security events in Cloudflare Dashboard
# Set up alerts for API usage anomalies
# Monitor DNS query patterns
```

### 4. Two-Factor Authentication

```shell
# Enable 2FA on your Cloudflare account
# Use authenticator app rather than SMS
# Keep backup codes secure
```

## Cost Optimization

### Free Plan Features

- Unlimited DNS queries
- Basic DDoS protection
- Shared SSL certificate
- 3 page rules
- Basic analytics

### Paid Plan Benefits

- **Pro ($20/month)**:
  - 20 page rules
  - Advanced analytics
  - Image optimization

- **Business ($200/month)**:
  - 50 page rules
  - Custom SSL certificates
  - Advanced security features

```shell
# Monitor usage to determine if upgrade needed
# Check analytics in Cloudflare Dashboard
```

## Integration Examples

### Development Setup

```shell
# Use different tokens for dev/staging
dokku config:set --global CLOUDFLARE_API_TOKEN_DEV=dev_token

# Lower TTLs for development
dokku dns:zones:ttl dev.example.com 60
```

### Production Setup

```shell
# Separate zones for production
dokku dns:zones:enable example.com
dokku dns:zones:ttl example.com 300

# Enable proxy mode for performance (after initial setup)
# Configure via Cloudflare Dashboard
```

### Multi-Environment

```shell
# Different zones for different environments
dokku dns:zones:enable staging.example.com    # Staging
dokku dns:zones:enable prod.example.com       # Production
dokku dns:zones:enable dev.example.com        # Development
```

## Monitoring and Analytics

### DNS Analytics

```shell
# Access via Cloudflare Dashboard > Analytics > DNS
# Monitor query volume, response times, and geography

# API access to analytics (Pro plan and above)
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/analytics/dashboard" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
```

### Health Monitoring

```shell
# Set up health checks in Cloudflare
# Configure email alerts for DNS issues
# Monitor uptime and performance
```

## Backup and Migration

### Export Zone Records

```shell
# Export all DNS records for backup
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" > backup.json
```

### Zone Migration

```shell
# Import records from other providers
# Use Cloudflare's BIND file import
# Or use API for programmatic migration
```

## Advanced Features

### Load Balancing

```shell
# Configure load balancing in Cloudflare Dashboard
# Use health checks and failover rules
# Integrate with DNS plugin for automated updates
```

### Workers Integration

```shell
# Use Cloudflare Workers for edge computing
# Combine with DNS management for dynamic routing
# Implement custom DNS responses
```

## Support and Resources

- **Cloudflare API Documentation**: https://api.cloudflare.com/
- **Cloudflare Community**: https://community.cloudflare.com/
- **Status Page**: https://www.cloudflarestatus.com/
- **DNS Learning Center**: https://www.cloudflare.com/learning/dns/

---

**Next Steps**: After setting up Cloudflare, consider configuring [multi-provider setups](multi-provider-scenarios.md) or enabling [automated DNS management](workflows.md#automation--triggers).