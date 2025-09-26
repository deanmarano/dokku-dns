# Cloudflare Provider Setup

This guide covers setting up Cloudflare as a DNS provider for the Dokku DNS plugin.

## Prerequisites

- Cloudflare account
- Domain added to Cloudflare
- Dokku DNS plugin installed

## Setup

### 1. Create API Token

**Recommended: Scoped API Token**
1. Go to Cloudflare Dashboard → My Profile → API Tokens
2. Click "Create Token"
3. Use "Custom token" template
4. Permissions:
   - Zone:Zone:Read
   - Zone:DNS:Edit
5. Zone Resources: Include → Specific zone → your-domain.com
6. Copy the generated token

### 2. Configure Plugin

```shell
# Set API token
dokku config:set --global CLOUDFLARE_API_TOKEN=your_api_token

# Verify setup
dokku dns:providers:verify cloudflare
```

### 3. Enable DNS Management

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
| `CLOUDFLARE_API_TOKEN` | API token (recommended) | None |
| `CLOUDFLARE_EMAIL` | Account email (legacy) | None |
| `CLOUDFLARE_API_KEY` | Global API key (legacy) | None |
| `CLOUDFLARE_API_BASE` | Custom API endpoint | `https://api.cloudflare.com/client/v4` |

### App-Specific Configuration

```shell
# Use different token for specific app
dokku config:set --no-restart myapp CLOUDFLARE_API_TOKEN=staging_token
```

## Troubleshooting

**Authentication Error:**
```shell
# Test API token
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

**Zone Not Found:**
```shell
# List zones accessible to token
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Check nameserver delegation
dig NS example.com
```

**Rate Limiting:**
Cloudflare free accounts have 1,200 requests per 5 minutes. The plugin handles rate limiting automatically.

## Multi-Provider Usage

```shell
# Cloudflare for personal domains
export CLOUDFLARE_API_TOKEN=personal_token
dokku dns:zones:enable personal.dev

# AWS for corporate domains
export AWS_ACCESS_KEY_ID=corporate_key
dokku dns:zones:enable corporate.com
```

## Legacy Global API Key (Not Recommended)

```shell
# If you must use global API key
dokku config:set --global CLOUDFLARE_EMAIL=user@example.com
dokku config:set --global CLOUDFLARE_API_KEY=your_global_key
```

Use scoped API tokens instead for better security.