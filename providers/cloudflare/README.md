# Cloudflare DNS Provider

This provider integrates with Cloudflare's DNS service via their API v4 to manage DNS records for your Dokku applications.

## Features

- Full support for DNS zone and record management
- Automatic zone detection (finds parent zones for subdomains)
- Record creation, updates, and deletion
- Comprehensive error handling and rate limiting
- Batch operations support
- Works alongside other DNS providers in multi-provider setups

## Setup

### 1. Get Cloudflare API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use the "Edit zone DNS" template or create a custom token with:
   - **Permissions:**
     - Zone:DNS:Edit
     - Zone:Zone:Read
   - **Zone Resources:**
     - Include: All zones (or specific zones you want to manage)

### 2. Configure Environment

Set your Cloudflare API token:

```bash
# Set the API token
export CLOUDFLARE_API_TOKEN="your_api_token_here"

# Optional: Set specific zone ID if you only want to manage one zone
export CLOUDFLARE_ZONE_ID="your_zone_id_here"
```

### 3. Verify Setup

Test that your credentials work:

```bash
dokku dns:providers:verify
```

This should show Cloudflare as available and list your zones.

## Usage

### Basic Commands

```bash
# List available zones
dokku dns:zones

# Enable a zone for DNS management
dokku dns:zones:enable example.com

# Add an app to DNS management
dokku dns:apps:enable myapp

# Sync DNS records for an app
dokku dns:apps:sync myapp

# View DNS status
dokku dns:report myapp
```

### Multi-Provider Setup

You can use Cloudflare alongside other providers like AWS Route53:

```bash
# Assign specific zones to Cloudflare
dokku dns:providers:assign example.com cloudflare
dokku dns:providers:assign test.org cloudflare

# AWS can handle other zones
dokku dns:providers:assign production.net aws

# Check provider assignments
dokku dns:providers:status
```

## Supported Operations

### Zone Management
- List all zones in your Cloudflare account
- Find zone IDs for domains (including parent zone lookup)
- Enable/disable zones for DNS management

### Record Management
- Create A records for app domains
- Update existing records when app IPs change
- Delete records when apps are removed
- Support for custom TTL values
- Batch operations for multiple records

### Error Handling
- Comprehensive API error reporting
- Automatic retry logic (respects Cloudflare rate limits)
- Clear error messages for common issues
- Graceful handling of missing zones/records

## API Rate Limits

Cloudflare has generous rate limits for DNS operations:
- 1,200 requests per 5 minutes per user
- The provider includes automatic error handling for rate limit responses

## Troubleshooting

### Common Issues

**Authentication Failed:**
```
Cloudflare API authentication failed. Check your CLOUDFLARE_API_TOKEN.
```
- Verify your API token is correct
- Check that the token has the required permissions
- Ensure the token hasn't expired

**Zone Not Found:**
```
Zone not found: subdomain.example.com
```
- The provider automatically looks for parent zones
- Make sure `example.com` is added to your Cloudflare account
- Check that the zone is active (not just DNS-only)

**Missing jq:**
```
Warning: jq is required for Cloudflare provider but not found
```
- Install jq: `sudo apt-get install jq` (Ubuntu/Debian)
- Or download from: https://stedolan.github.io/jq/download/

### Debug Mode

Enable debug output to see API calls:

```bash
export DEBUG=1
dokku dns:apps:sync myapp
```

This will show the actual Cloudflare API requests and responses.

## Security Notes

- Store your API token securely (use environment variables or secrets management)
- Use minimal scope tokens (only DNS permissions for specific zones)
- Regularly rotate your API tokens
- Monitor your Cloudflare audit logs for unexpected changes

## Limitations

- No support for advanced record types (only A, AAAA, CNAME, TXT)
- Batch operations are simulated (no native Cloudflare batch API)
- Requires internet connectivity to Cloudflare's API

## Contributing

This provider follows the standard DNS provider interface. See `providers/INTERFACE.md` for implementation details.

Report issues at: https://github.com/dokku/dokku-dns/issues