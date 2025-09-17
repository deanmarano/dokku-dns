#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# AWS Provider Sync Functions
# DNS record synchronization operations for AWS Route53

dns_provider_aws_sync_app() {
  local APP="$1"
  local PLUGIN_DATA_ROOT="${DNS_ROOT:-${DOKKU_LIB_ROOT:-/var/lib/dokku}/services/dns}"
  local APP_DOMAINS_FILE="$PLUGIN_DATA_ROOT/$APP/DOMAINS"
  local APP_DOMAINS=""

  if [[ -f "$APP_DOMAINS_FILE" ]]; then
    APP_DOMAINS=$(tr '\n' ' ' <"$APP_DOMAINS_FILE" 2>/dev/null)
  fi

  if [[ -z "$APP_DOMAINS" ]]; then
    echo "No DNS-managed domains found for app: $APP"
    return 0
  fi

  # Get server IP
  local SERVER_IP
  SERVER_IP=$(get_server_ip)

  if [[ -z "$SERVER_IP" ]] || [[ "$SERVER_IP" == "Unknown" ]]; then
    echo "Error: Unable to determine server IP address"
    return 1
  fi

  echo "Syncing domains for app '$APP' to server IP: $SERVER_IP"

  # Sync each domain (no zone enablement checking for explicit sync operations)
  local domains_synced=0

  for DOMAIN in $APP_DOMAINS; do
    [[ -z "$DOMAIN" ]] && continue

    echo "Syncing domain: $DOMAIN"

    # Get hosted zone ID for this domain
    local zone_id
    zone_id=$(dns_provider_aws_get_hosted_zone_id "$DOMAIN")
    if [[ -z "$zone_id" ]]; then
      echo "Error: No hosted zone found for $DOMAIN"
      continue
    fi

    # Create or update A record in Route53
    local change_batch="{
            \"Changes\": [{
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                    \"Name\": \"$DOMAIN\",
                    \"Type\": \"A\",
                    \"TTL\": 300,
                    \"ResourceRecords\": [{\"Value\": \"$SERVER_IP\"}]
                }
            }]
        }"

    if aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" --change-batch "$change_batch" >/dev/null 2>&1; then
      echo "DNS record created: $DOMAIN -> $SERVER_IP"
      domains_synced=$((domains_synced + 1))
    else
      echo "Error: Failed to create DNS record for $DOMAIN"
    fi
  done

  return 0
}
