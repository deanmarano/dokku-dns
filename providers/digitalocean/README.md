# DigitalOcean DNS Provider

This provider integrates with DigitalOcean's DNS service to manage DNS records for your Dokku applications.

## Features

- Full support for DigitalOcean DNS domains and records
- Automatic domain management using DigitalOcean API
- Record creation, updates, and deletion using DigitalOcean API v2
- Comprehensive error handling and API integration
- Batch operations support for efficient API usage
- Works alongside other DNS providers in multi-provider setups

## Setup

### 1. Create DigitalOcean API Token

1. Log in to your [DigitalOcean Control Panel](https://cloud.digitalocean.com/)
2. Navigate to **API** in the left sidebar
3. Click **Generate New Token** in the Personal access tokens section
4. Enter a token name (e.g., "dokku-dns")
5. Select appropriate scopes:
   - **Read** access for listing domains and records
   - **Write** access for creating, updating, and deleting records
6. Click **Generate Token**
7. **Important**: Copy the token immediately - it won't be shown again

### 2. Install Required Dependencies

The DigitalOcean provider requires `jq` for JSON parsing:

```bash
# On macOS (Homebrew)
brew install jq

# On Ubuntu/Debian
sudo apt-get update
sudo apt-get install jq

# On RHEL/CentOS/Fedora
sudo yum install jq
# or
sudo dnf install jq
```

### 3. Configure DigitalOcean API Token

#### Option A: Environment Variable (Recommended for Dokku)
```bash
# Set via Dokku config
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN="your_digitalocean_token_here"
```

#### Option B: Server Environment
```bash
# Add to /etc/environment or your shell profile
export DIGITALOCEAN_ACCESS_TOKEN="your_digitalocean_token_here"
```

### 4. Add Your Domain to DigitalOcean

Before using the DNS plugin, your domain must be added to DigitalOcean:

1. In the DigitalOcean Control Panel, go to **Networking** → **Domains**
2. Enter your domain name and click **Add Domain**
3. Update your domain registrar's nameservers to point to DigitalOcean:
   - ns1.digitalocean.com
   - ns2.digitalocean.com
   - ns3.digitalocean.com

### 5. Verify Setup

Test that the provider is working:

```bash
# Test provider configuration
dokku dns:providers:verify digitalocean

# List available domains
dokku dns:providers:zones digitalocean
```

## Configuration Options

### Required Environment Variables

- `DIGITALOCEAN_ACCESS_TOKEN`: Your DigitalOcean API token

### Optional Environment Variables

- `DIGITALOCEAN_API_URL`: Custom API endpoint (default: https://api.digitalocean.com/v2)

## DigitalOcean DNS Limitations

### Record Types
DigitalOcean DNS supports the following record types:
- A records (IPv4 addresses)
- AAAA records (IPv6 addresses)
- CNAME records (aliases)
- MX records (mail exchange)
- TXT records (text)
- NS records (nameservers)
- SRV records (service)

### TTL Values
- Minimum TTL: 30 seconds
- Maximum TTL: 2,147,483,647 seconds
- Default TTL used by this provider: 1800 seconds (30 minutes)

### API Rate Limits
DigitalOcean has API rate limits:
- 5,000 requests per hour per token
- Rate limit headers are included in API responses
- The provider will handle rate limiting gracefully

## Usage Examples

### Basic DNS Management

```bash
# Add an app to DNS management
dokku dns:apps:enable myapp

# Sync DNS records for an app
dokku dns:apps:sync myapp

# Remove an app from DNS management
dokku dns:apps:disable myapp
```

### Multi-Provider Setup

The DigitalOcean provider works seamlessly with other providers:

```bash
# Configure different providers for different domains
dokku config:set myapp DNS_PROVIDER=digitalocean
dokku config:set anotherapp DNS_PROVIDER=aws

# Or use global provider with per-app overrides
dokku config:set --global DNS_PROVIDER=digitalocean
dokku config:set specialapp DNS_PROVIDER=cloudflare
```

## Troubleshooting

### Common Issues

#### "Missing required environment variable: DIGITALOCEAN_ACCESS_TOKEN"
- Ensure your API token is set correctly
- Verify the token has the required permissions (read/write for domains)
- Check that the token hasn't expired

#### "Failed to connect to DigitalOcean API"
- Verify your internet connection
- Check if DIGITALOCEAN_API_URL is set correctly
- Ensure your firewall allows outbound HTTPS connections

#### "Zone not found"
- Verify the domain is added to your DigitalOcean account
- Check that the domain name is spelled correctly
- Ensure the domain is active in DigitalOcean DNS

#### "jq: command not found"
- Install jq using your system's package manager
- Verify jq is in your PATH

### Getting Help

1. Check the DigitalOcean API status: https://status.digitalocean.com/
2. Review your API token permissions in the DigitalOcean Control Panel
3. Test API connectivity manually:
   ```bash
   curl -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
        "https://api.digitalocean.com/v2/account"
   ```

## API Reference

This provider uses DigitalOcean's REST API v2. Key endpoints:

- **Domains**: `/v2/domains`
- **Domain Records**: `/v2/domains/{domain_name}/records`
- **Authentication**: Bearer token in Authorization header

For complete API documentation, visit:
https://docs.digitalocean.com/reference/api/api-reference/#tag/Domain-Records

## Security Notes

- Store your API token securely and never commit it to version control
- Consider using environment-specific tokens for different environments
- Regularly rotate your API tokens
- Monitor your DigitalOcean account for unexpected DNS changes
- Use the principle of least privilege when setting token permissions