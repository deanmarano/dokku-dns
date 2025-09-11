#!/bin/bash
# Provider Configuration Template
# Copy this file and customize for your provider

# Provider metadata
PROVIDER_NAME="template"
PROVIDER_DISPLAY_NAME="Template Provider"
PROVIDER_DOCS_URL="https://example.com/dns-api-docs"

# Required environment variables for this provider
PROVIDER_REQUIRED_ENV_VARS="TEMPLATE_API_KEY TEMPLATE_API_SECRET"

# Optional environment variables
PROVIDER_OPTIONAL_ENV_VARS="TEMPLATE_API_REGION TEMPLATE_API_ENDPOINT"

# Provider capabilities (space-separated)
PROVIDER_CAPABILITIES="zones records batch"

# Default record TTL (in seconds)
PROVIDER_DEFAULT_TTL="300"