# DigitalOcean DNS Provider

The DigitalOcean provider enables DNS management through DigitalOcean's DNS service for your Dokku applications.

## Prerequisites

- DigitalOcean account with API access
- Domain registered and added to DigitalOcean DNS
- Dokku DNS plugin installed
- `jq` command-line tool installed

## Installation

The DigitalOcean provider is included with the DNS plugin. Verify it's available:

```shell
# Check available providers
cat /var/lib/dokku/plugins/available/dns/providers/available
```

## Setup

### 1. Create DigitalOcean API Token

1. Go to [DigitalOcean Control Panel → API](https://cloud.digitalocean.com/account/api/tokens)
2. Click "Generate New Token"
3. Set Token Name: "Dokku DNS Plugin"
4. Select Scopes: **Read** and **Write**
5. Set Expiration (recommended: 90 days or no expiration)
6. Copy the generated token securely

### 2. Add Domain to DigitalOcean DNS

1. Go to **Networking → Domains** in DigitalOcean
2. Enter your domain name and click "Add Domain"
3. Update nameservers at your domain registrar to:
   - `ns1.digitalocean.com`
   - `ns2.digitalocean.com`
   - `ns3.digitalocean.com`
4. Wait for DNS propagation (up to 48 hours)

### 3. Configure Provider Credentials

```shell
# Set DigitalOcean API token globally
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=your_api_token_here

# Optional: Set default region
dokku config:set --global AWS_DEFAULT_REGION=us-east-1
```

### 4. Enable DNS Management

```shell
# Enable DNS management for a domain
dokku dns:zones:enable example.com

# Enable DNS for an application
dokku dns:apps:enable myapp

# Sync DNS records for the app
dokku dns:apps:sync myapp
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DIGITALOCEAN_ACCESS_TOKEN` | DigitalOcean API token | None | Yes |
| `DIGITALOCEAN_API_URL` | Custom API endpoint | `https://api.digitalocean.com/v2` | No |

### App-Specific Configuration

```shell
# Use different token for specific app
dokku config:set --no-restart myapp DIGITALOCEAN_ACCESS_TOKEN=staging_token

# Check app configuration
dokku dns:apps:report myapp
```

## Commands

### Management Commands

```shell
# Enable DNS for a zone
dokku dns:zones:enable example.com

# Enable DNS for an application
dokku dns:apps:enable myapp

# Sync DNS records
dokku dns:apps:sync myapp

# View DNS status
dokku dns:report [app]

# Sync all managed domains
dokku dns:sync-all
```

### Verification Commands

```shell
# Test provider connectivity (Note: currently only AWS supported)
dokku dns:providers:verify

# View DNS configuration
dokku dns:apps:report myapp
```

## Dependencies

The DigitalOcean provider requires:

- **jq** - JSON parsing tool
  ```shell
  # Ubuntu/Debian
  sudo apt-get install jq

  # macOS
  brew install jq

  # CentOS/RHEL
  sudo yum install jq
  ```

## Troubleshooting

**Authentication Error:**
```shell
# Test API token
curl -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
  "https://api.digitalocean.com/v2/account"
```

**Domain Not Found:**
```shell
# List domains accessible to token
curl -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
  "https://api.digitalocean.com/v2/domains"

# Check nameserver delegation
dig NS example.com
```

### Common Errors

**"jq: command not found"**
- Install jq using your system's package manager
- Verify jq is in your PATH: `which jq`

**"Domain not found"**
- Ensure domain is added to DigitalOcean DNS
- Verify API token has correct permissions
- Check domain spelling and format

**"Rate limit exceeded"**
- DigitalOcean limits: 5,000 requests per hour per token
- The plugin automatically handles rate limiting
- Consider using multiple tokens for high-traffic scenarios

## Multi-Provider Setup

DigitalOcean can be used alongside other providers:

```shell
# Configure DigitalOcean for development domains
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=dev_token
dokku dns:zones:enable dev.example.com

# Configure AWS for production domains
dokku config:set --global AWS_ACCESS_KEY_ID=prod_key
dokku config:set --global AWS_SECRET_ACCESS_KEY=prod_secret
dokku dns:zones:enable example.com

# Apps automatically use the appropriate provider based on domain
dokku dns:apps:enable myapp
```

## Performance Notes

- **Batch operations**: Multiple DNS changes are batched when possible
- **Caching**: Zone information is cached to reduce API calls
- **Error handling**: Automatic retry with exponential backoff
- **Rate limiting**: Built-in respect for DigitalOcean API limits

## Status

✅ **Fully Implemented** - The DigitalOcean provider is complete and production-ready with comprehensive test coverage.

**Note**: The `dokku dns:providers:verify` command currently only supports AWS. DigitalOcean verification happens automatically when credentials are configured correctly.