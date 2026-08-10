#!/bin/bash
# OVHcloud DNS Provider Configuration

PROVIDER_NAME="ovh"
PROVIDER_DISPLAY_NAME="OVHcloud"
PROVIDER_DOCS_URL="https://help.ovhcloud.com/csm/en-dns-domain-name-ovhcloud-api?id=kb_article_view&sysparm_article=KB0062899"
PROVIDER_REQUIRED_ENV_VARS="OVH_APPLICATION_KEY OVH_APPLICATION_SECRET OVH_CONSUMER_KEY"
PROVIDER_OPTIONAL_ENV_VARS="OVH_API_ENDPOINT"
PROVIDER_CAPABILITIES="zones records"
PROVIDER_DEFAULT_TTL="300"

# OVHcloud's European API. Set OVH_API_ENDPOINT for another OVHcloud region.
OVH_API_ENDPOINT="${OVH_API_ENDPOINT:-https://eu.api.ovh.com/1.0}"
