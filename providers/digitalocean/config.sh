#!/bin/bash
# DigitalOcean DNS Provider Configuration

# Provider metadata
PROVIDER_NAME="digitalocean"
PROVIDER_DISPLAY_NAME="DigitalOcean"
PROVIDER_DOCS_URL="https://docs.digitalocean.com/reference/api/api-reference/#tag/Domain-Records"

# Required environment variables for this provider
PROVIDER_REQUIRED_ENV_VARS="DIGITALOCEAN_ACCESS_TOKEN"

# Optional environment variables
PROVIDER_OPTIONAL_ENV_VARS="DIGITALOCEAN_API_URL"

# Provider capabilities (space-separated)
PROVIDER_CAPABILITIES="zones records batch"

# Default record TTL (in seconds)
PROVIDER_DEFAULT_TTL="1800"

# DigitalOcean API defaults
DIGITALOCEAN_API_URL="${DIGITALOCEAN_API_URL:-https://api.digitalocean.com/v2}"
