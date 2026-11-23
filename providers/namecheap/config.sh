#!/bin/bash
# Namecheap DNS Provider Configuration

# Provider metadata
PROVIDER_NAME="namecheap"
PROVIDER_DISPLAY_NAME="Namecheap"
PROVIDER_DOCS_URL="https://www.namecheap.com/support/api/methods/domains-dns/"

# Required environment variables for this provider
PROVIDER_REQUIRED_ENV_VARS="NAMECHEAP_API_USER NAMECHEAP_API_KEY"

# Optional environment variables
PROVIDER_OPTIONAL_ENV_VARS="NAMECHEAP_CLIENT_IP"

# Provider capabilities (space-separated)
PROVIDER_CAPABILITIES="zones records"

# Default record TTL (in seconds)
PROVIDER_DEFAULT_TTL="300"

# Namecheap API settings
NAMECHEAP_API_BASE="https://api.namecheap.com/xml.response"
