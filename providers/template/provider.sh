#!/bin/bash
# DNS Provider Template
# Copy this file and implement the functions for your DNS provider

# Load provider configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# REQUIRED: Validate that provider credentials are properly configured
provider_validate_credentials() {
  # Example implementation:
  # Check if required environment variables are set
  if [[ -z "${TEMPLATE_API_KEY:-}" ]] || [[ -z "${TEMPLATE_API_SECRET:-}" ]]; then
    echo "Missing required environment variables: TEMPLATE_API_KEY, TEMPLATE_API_SECRET" >&2
    return 1
  fi

  # Test API connectivity (customize for your provider)
  # if ! curl -s -f "https://api.template.com/auth/test" \
  #     -H "Authorization: Bearer $TEMPLATE_API_KEY" >/dev/null; then
  #     echo "API authentication failed" >&2
  #     return 1
  # fi

  return 0
}

# REQUIRED: List all DNS zones available to the configured account
provider_list_zones() {
  # Example implementation:
  # Call your provider's API to list zones
  # Output one zone name per line to stdout

  # curl -s "https://api.template.com/zones" \
  #     -H "Authorization: Bearer $TEMPLATE_API_KEY" \
  #     | jq -r '.[].name'

  echo "example.com"
  echo "test.org"
  return 0
}

# REQUIRED: Get the provider-specific zone identifier
provider_get_zone_id() {
  local zone_name="$1"

  if [[ -z "$zone_name" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  # Example implementation:
  # Query your provider's API for the zone ID
  # local zone_id
  # zone_id=$(curl -s "https://api.template.com/zones" \
  #     -H "Authorization: Bearer $TEMPLATE_API_KEY" \
  #     | jq -r ".[] | select(.name==\"$zone_name\") | .id")

  # if [[ -z "$zone_id" ]] || [[ "$zone_id" == "null" ]]; then
  #     echo "Zone not found: $zone_name" >&2
  #     return 1
  # fi

  # echo "$zone_id"

  # Template implementation:
  if [[ "$zone_name" == "example.com" ]]; then
    echo "zone123456"
    return 0
  elif [[ "$zone_name" == "test.org" ]]; then
    echo "zone789012"
    return 0
  else
    echo "Zone not found: $zone_name" >&2
    return 1
  fi
}

# REQUIRED: Get current DNS record value
provider_get_record() {
  local zone_id="$1"
  local record_name="$2"
  local record_type="$3"

  if [[ -z "$zone_id" ]] || [[ -z "$record_name" ]] || [[ -z "$record_type" ]]; then
    echo "Zone ID, record name, and record type are required" >&2
    return 1
  fi

  # Example implementation:
  # Query your provider's API for the record
  # local record_value
  # record_value=$(curl -s "https://api.template.com/zones/$zone_id/records" \
  #     -H "Authorization: Bearer $TEMPLATE_API_KEY" \
  #     | jq -r ".[] | select(.name==\"$record_name\" and .type==\"$record_type\") | .value")

  # if [[ -z "$record_value" ]] || [[ "$record_value" == "null" ]]; then
  #     echo "Record not found: $record_name ($record_type)" >&2
  #     return 1
  # fi

  # echo "$record_value"

  # Template implementation:
  echo "192.168.1.100"
  return 0
}

# REQUIRED: Create or update a DNS record
provider_create_record() {
  local zone_id="$1"
  local record_name="$2"
  local record_type="$3"
  local record_value="$4"
  local ttl="${5:-${PROVIDER_DEFAULT_TTL:-300}}"

  if [[ -z "$zone_id" ]] || [[ -z "$record_name" ]] || [[ -z "$record_type" ]] || [[ -z "$record_value" ]]; then
    echo "Zone ID, record name, record type, and record value are required" >&2
    return 1
  fi

  # Example implementation:
  # Create/update record via your provider's API
  # local response
  # response=$(curl -s -X POST "https://api.template.com/zones/$zone_id/records" \
  #     -H "Authorization: Bearer $TEMPLATE_API_KEY" \
  #     -H "Content-Type: application/json" \
  #     -d "{\"name\":\"$record_name\",\"type\":\"$record_type\",\"value\":\"$record_value\",\"ttl\":$ttl}")

  # if ! echo "$response" | jq -e '.success' >/dev/null; then
  #     echo "Failed to create record: $record_name" >&2
  #     return 1
  # fi

  # Template implementation:
  echo "Created record: $record_name -> $record_value (TTL: $ttl)"
  return 0
}

# REQUIRED: Delete a DNS record
provider_delete_record() {
  local zone_id="$1"
  local record_name="$2"
  local record_type="$3"

  if [[ -z "$zone_id" ]] || [[ -z "$record_name" ]] || [[ -z "$record_type" ]]; then
    echo "Zone ID, record name, and record type are required" >&2
    return 1
  fi

  # Example implementation:
  # Delete record via your provider's API
  # local record_id
  # record_id=$(curl -s "https://api.template.com/zones/$zone_id/records" \
  #     -H "Authorization: Bearer $TEMPLATE_API_KEY" \
  #     | jq -r ".[] | select(.name==\"$record_name\" and .type==\"$record_type\") | .id")

  # if [[ -z "$record_id" ]] || [[ "$record_id" == "null" ]]; then
  #     echo "Record not found for deletion: $record_name" >&2
  #     return 1
  # fi

  # local response
  # response=$(curl -s -X DELETE "https://api.template.com/zones/$zone_id/records/$record_id" \
  #     -H "Authorization: Bearer $TEMPLATE_API_KEY")

  # if ! echo "$response" | jq -e '.success' >/dev/null; then
  #     echo "Failed to delete record: $record_name" >&2
  #     return 1
  # fi

  # Template implementation:
  echo "Deleted record: $record_name ($record_type)"
  return 0
}

# OPTIONAL: Provider-specific environment setup
provider_setup_env() {
  # Perform any provider-specific initialization
  # This is called once when the provider is loaded

  # Example: Set default API endpoint
  # export TEMPLATE_API_ENDPOINT="${TEMPLATE_API_ENDPOINT:-https://api.template.com}"

  return 0
}

# OPTIONAL: Batch create multiple records (optimization)
provider_batch_create_records() {
  local zone_id="$1"
  local records_file="$2"

  if [[ -z "$zone_id" ]] || [[ -z "$records_file" ]] || [[ ! -f "$records_file" ]]; then
    echo "Zone ID and valid records file are required" >&2
    return 1
  fi

  # Example implementation:
  # Build batch request from records file
  # Each line format: "record_name record_type record_value ttl"

  # Default implementation: fallback to individual record creation
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    local record_name record_type record_value ttl
    read -r record_name record_type record_value ttl <<<"$line"

    if ! provider_create_record "$zone_id" "$record_name" "$record_type" "$record_value" "$ttl"; then
      echo "Batch operation failed on record: $record_name" >&2
      return 1
    fi
  done <"$records_file"

  return 0
}
