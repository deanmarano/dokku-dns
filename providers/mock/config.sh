#!/bin/bash
# Mock Provider Configuration (for testing)

# Provider metadata
PROVIDER_NAME="mock"
PROVIDER_DISPLAY_NAME="Mock DNS Provider"
PROVIDER_DOCS_URL="https://github.com/deanmarano/dokku-dns/blob/main/providers/INTERFACE.md"

# Required environment variables for this provider
PROVIDER_REQUIRED_ENV_VARS="MOCK_API_KEY"

# Optional environment variables
PROVIDER_OPTIONAL_ENV_VARS="MOCK_API_ENDPOINT"

# Provider capabilities (space-separated)
PROVIDER_CAPABILITIES="zones records batch"

# Default record TTL (in seconds)
PROVIDER_DEFAULT_TTL="300"
