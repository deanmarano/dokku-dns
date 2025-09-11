#!/bin/bash
# AWS Route53 Provider Configuration

# Provider metadata
PROVIDER_NAME="aws"
PROVIDER_DISPLAY_NAME="AWS Route53"
PROVIDER_DOCS_URL="https://docs.aws.amazon.com/route53/"

# Required environment variables for this provider
PROVIDER_REQUIRED_ENV_VARS="AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"

# Optional environment variables
PROVIDER_OPTIONAL_ENV_VARS="AWS_DEFAULT_REGION AWS_SESSION_TOKEN AWS_PROFILE"

# Provider capabilities (space-separated)
PROVIDER_CAPABILITIES="zones records batch"

# Default record TTL (in seconds)
PROVIDER_DEFAULT_TTL="300"