# DigitalOcean Provider Setup

This guide covers setting up DigitalOcean as a DNS provider for the Dokku DNS plugin.

## Prerequisites

- DigitalOcean account
- Domain added to DigitalOcean DNS
- Dokku DNS plugin installed

## Setup

### 1. Create API Token

1. Go to DigitalOcean Control Panel → API
2. Click "Generate New Token"
3. Set Token Name: "Dokku DNS Plugin"
4. Select Scopes: "Read" and "Write"
5. Set Expiration (optional)
6. Copy the generated token

### 2. Add Domain to DigitalOcean

1. Go to Networking → Domains
2. Enter your domain name
3. Click "Add Domain"
4. Update nameservers at your domain registrar:
   - ns1.digitalocean.com
   - ns2.digitalocean.com
   - ns3.digitalocean.com

### 3. Configure Plugin

```shell
# Set API token
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=your_api_token

# Verify setup
dokku dns:providers:verify digitalocean
```

### 4. Enable DNS Management

```shell
# Enable zones
dokku dns:zones:enable example.com

# Enable app
dokku dns:apps:enable myapp
dokku dns:apps:sync myapp
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DIGITALOCEAN_ACCESS_TOKEN` | DigitalOcean API token | None |
| `DIGITALOCEAN_API_URL` | Custom API endpoint | `https://api.digitalocean.com/v2` |

### App-Specific Configuration

```shell
# Use different token for specific app
dokku config:set --no-restart myapp DIGITALOCEAN_ACCESS_TOKEN=staging_token
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

**Rate Limiting:**
DigitalOcean has 5,000 requests per hour per API token. The plugin handles rate limiting automatically.

## Multi-Provider Usage

```shell
# DigitalOcean for startup domains
export DIGITALOCEAN_ACCESS_TOKEN=startup_token
dokku dns:zones:enable startup.app

# AWS for corporate domains
export AWS_ACCESS_KEY_ID=corporate_key
dokku dns:zones:enable corporate.com
```