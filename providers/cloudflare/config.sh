#!/bin/bash
# Cloudflare DNS Provider Configuration

# Provider metadata
PROVIDER_NAME="cloudflare"
PROVIDER_DISPLAY_NAME="Cloudflare"
PROVIDER_DOCS_URL="https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-list-dns-records"

# Required environment variables for this provider
PROVIDER_REQUIRED_ENV_VARS="CLOUDFLARE_API_TOKEN"

# Optional environment variables
PROVIDER_OPTIONAL_ENV_VARS="CLOUDFLARE_ZONE_ID"

# Provider capabilities (space-separated)
PROVIDER_CAPABILITIES="zones records batch"

# Default record TTL (in seconds)
PROVIDER_DEFAULT_TTL="300"

# Cloudflare API settings
CLOUDFLARE_API_BASE="https://api.cloudflare.com/client/v4"