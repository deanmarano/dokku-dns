# DigitalOcean Provider Setup Guide

DigitalOcean DNS provides a simple, reliable DNS service with competitive pricing and excellent API documentation. This guide covers the complete setup and configuration process for using DigitalOcean as your DNS provider.

## Prerequisites

- DigitalOcean account
- Domain(s) added to DigitalOcean DNS
- Dokku DNS plugin installed

## Quick Setup

### 1. Create API Token

**Personal Access Token:**
```shell
# 1. Go to DigitalOcean Control Panel > API
# 2. Click "Generate New Token"
# 3. Set Token Name: "Dokku DNS Plugin"
# 4. Select Scopes: "Read" and "Write"
# 5. Set Expiration (optional)
# 6. Copy the generated token
```

### 2. Configure DigitalOcean Credentials

```shell
# Set API token in Dokku
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=your_api_token_here
```

### 3. Add Domain to DigitalOcean

```shell
# Via DigitalOcean Control Panel:
# 1. Go to Networking > Domains
# 2. Enter your domain name
# 3. Click "Add Domain"
# 4. Update nameservers at your domain registrar:
#    - ns1.digitalocean.com
#    - ns2.digitalocean.com
#    - ns3.digitalocean.com
```

### 4. Verify Setup

```shell
# Test DigitalOcean provider connectivity
dokku dns:providers:verify digitalocean

# Check available zones
dokku dns:zones

# Enable zones for management
dokku dns:zones:enable example.com
```

## API Integration

### DigitalOcean DNS API Features

**API Endpoints (v2):**
- `GET /v2/domains` - List all domains
- `GET /v2/domains/{domain}/records` - List domain records
- `POST /v2/domains/{domain}/records` - Create DNS record
- `PUT /v2/domains/{domain}/records/{record_id}` - Update DNS record
- `DELETE /v2/domains/{domain}/records/{record_id}` - Delete DNS record

**Supported Record Types:**
- A, AAAA, CNAME, MX, TXT, NS, SRV, SOA

**Rate Limits:**
- 5,000 requests per hour per API token
- Burst limit: 250 requests per minute

### Implementation

**Provider Functions (Implemented):**
```bash
# Required provider interface functions
provider_validate_credentials()     # Test API token validity
provider_list_zones()              # List available domains
provider_get_zone_id()            # Get domain info
provider_get_record()             # Retrieve DNS record
provider_create_record()          # Create/update DNS record
provider_delete_record()          # Delete DNS record
```

## Configuration Options

### Basic Configuration

```shell
# Primary API token
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=dop_v1_abc123...

# Optional: Custom API endpoint
dokku config:set --global DIGITALOCEAN_API_URL=https://api.digitalocean.com/v2
```

### Advanced Configuration

```shell
# Request timeout (seconds)
dokku config:set --global DIGITALOCEAN_TIMEOUT=30

# Custom User-Agent for API requests (if needed)
dokku config:set --global DIGITALOCEAN_USER_AGENT="Dokku-DNS/1.0"
```

## Features

### Core DNS Management

```shell
# Enable DigitalOcean DNS for a zone
dokku dns:zones:enable example.com

# Sync app domains to DigitalOcean DNS
dokku dns:apps:enable myapp
dokku dns:apps:sync myapp

# Check DNS status
dokku dns:report myapp
```

### Multi-Provider Integration

```shell
# Use alongside other providers
export AWS_ACCESS_KEY_ID=your_aws_key
export DIGITALOCEAN_ACCESS_TOKEN=your_do_token

# Different zones with different providers
dokku dns:zones:enable corporate.com      # AWS Route53
dokku dns:zones:enable startup.dev        # DigitalOcean DNS
```

## Troubleshooting

### Common Issues

**1. Invalid API Token**
```shell
# Test token validity
curl -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
  "https://api.digitalocean.com/v2/account"
```

**2. Domain Not Found**
```shell
# List domains accessible to token
curl -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
  "https://api.digitalocean.com/v2/domains"
```

**3. Rate Limiting**
```shell
# Check rate limit headers
curl -I -X GET \
  -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
  "https://api.digitalocean.com/v2/domains"

# Look for:
# X-RateLimit-Limit: 5000
# X-RateLimit-Remaining: 4999
# X-RateLimit-Reset: 1609459200
```

## Security Best Practices

### 1. Token Security

```shell
# Generate scoped tokens when available
# Rotate tokens regularly (quarterly)
# Use environment variables, avoid hardcoding
# Enable team access controls
```

### 2. Network Security

```shell
# Use trusted networks when possible
# Monitor API usage in DO Control Panel
# Set up alerts for unusual activity
```

### 3. Access Control

```shell
# Use team accounts for shared access
# Implement least-privilege access
# Regular access reviews
```

## Cost Structure

### DigitalOcean DNS Pricing (Current)

- **DNS Hosting**: Free
- **DNS Queries**: $2.00 per million queries
- **Additional Features**:
  - Load balancing: Starting at $12/month
  - Monitoring: Starting at $6/month

```shell
# Cost monitoring
# Track query volume in DO Control Panel
# Set up billing alerts
```

## Performance Characteristics

### Network Performance

- **Anycast Network**: Global DNS resolution
- **Response Time**: Typically < 20ms globally
- **Uptime**: 99.99% SLA
- **Locations**: Multiple global PoPs

### API Performance

- **Response Time**: < 200ms for most operations
- **Batch Operations**: Support for bulk record operations
- **Caching**: Intelligent caching for better performance

## Integration Examples

### Development Environment

```shell
# Use DigitalOcean for development domains
dokku config:set --global DIGITALOCEAN_TOKEN=dev_token
dokku dns:zones:enable dev.myapp.com
dokku dns:zones:ttl dev.myapp.com 60  # Low TTL for development
```

### Production Environment

```shell
# Production setup with higher TTLs
dokku dns:zones:enable myapp.com
dokku dns:zones:ttl myapp.com 300

# Enable automatic management
dokku dns:triggers:enable
```

### Hybrid Cloud Setup

```shell
# Use different providers for different purposes
dokku dns:zones:enable corporate.com     # AWS for enterprise
dokku dns:zones:enable hobby.dev         # DigitalOcean for personal
```

## Monitoring and Analytics

### Built-in Monitoring

```shell
# Query analytics in DO Control Panel
# DNS resolution monitoring
# Performance metrics and alerts
```

### API Monitoring

```shell
# Track API usage
curl -X GET \
  -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
  "https://api.digitalocean.com/v2/account"

# Monitor rate limit usage
# Set up alerts for high usage
```

## Migration Planning

### From Other Providers

```shell
# Export existing DNS records
# Plan migration strategy
# Test with staging domains first
# Coordinate nameserver updates
```

### Backup and Recovery

```shell
# Regular DNS record backups
curl -X GET \
  -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
  "https://api.digitalocean.com/v2/domains/example.com/records" > backup.json

# Disaster recovery procedures
# Multi-provider redundancy
```


## Resources and Documentation

- **DigitalOcean API Documentation**: https://docs.digitalocean.com/reference/api/
- **DNS API Reference**: https://docs.digitalocean.com/reference/api/api-reference/#tag/Domains
- **Community Tutorials**: https://www.digitalocean.com/community/tags/dns
- **Status Page**: https://status.digitalocean.com/

## Contributing

Want to improve the DigitalOcean provider? Check out:

- **Provider Interface Spec**: [Provider Interface Documentation](../providers/INTERFACE.md)
- **Contributing Guide**: [CONTRIBUTING.md](../CONTRIBUTING.md)

**Enhancement Areas:**
- Performance optimizations
- Advanced error handling
- Additional monitoring capabilities
- Enhanced batch operations

---

**Status**: ✅ **Fully Implemented and Available**

The DigitalOcean provider is production-ready and actively maintained. See the [Contributing Guide](../CONTRIBUTING.md) for details on how to contribute improvements.