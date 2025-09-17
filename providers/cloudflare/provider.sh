#!/bin/bash
# Cloudflare DNS Provider Implementation
# Uses Cloudflare API v4 for DNS zone and record management

# Load provider configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Helper function for Cloudflare API calls
_cloudflare_api_call() {
  local method="$1"
  local endpoint="$2"
  local data="$3"

  local curl_args=(
    -s
    -X "$method"
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
    -H "Content-Type: application/json"
  )

  if [[ -n "$data" ]]; then
    curl_args+=(-d "$data")
  fi

  curl "${curl_args[@]}" "${CLOUDFLARE_API_BASE}${endpoint}"
}

# Helper function to check API response for errors
_check_cloudflare_response() {
  local response="$1"
  local context="$2"

  if ! echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    local errors
    errors=$(echo "$response" | jq -r '.errors[]?.message // "Unknown error"' 2>/dev/null)
    echo "Cloudflare API error in $context: $errors" >&2
    return 1
  fi

  return 0
}

# REQUIRED: Validate that provider credentials are properly configured
provider_validate_credentials() {
  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    echo "Missing required environment variable: CLOUDFLARE_API_TOKEN" >&2
    echo "Get your API token from: https://dash.cloudflare.com/profile/api-tokens" >&2
    return 1
  fi

  # Test API connectivity by getting user details
  local response
  response=$(_cloudflare_api_call "GET" "/user")

  if ! _check_cloudflare_response "$response" "credential validation"; then
    echo "Cloudflare API authentication failed. Check your CLOUDFLARE_API_TOKEN." >&2
    return 1
  fi

  return 0
}

# REQUIRED: List all DNS zones available to the configured account
provider_list_zones() {
  local response
  response=$(_cloudflare_api_call "GET" "/zones")

  if ! _check_cloudflare_response "$response" "zone listing"; then
    return 1
  fi

  # Extract zone names from response
  echo "$response" | jq -r '.result[].name' 2>/dev/null
  return 0
}

# REQUIRED: Get the provider-specific zone identifier
provider_get_zone_id() {
  local zone_name="$1"

  if [[ -z "$zone_name" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  # Find the zone that matches or is a parent of the requested domain
  local response
  response=$(_cloudflare_api_call "GET" "/zones?name=$zone_name")

  if ! _check_cloudflare_response "$response" "zone lookup"; then
    return 1
  fi

  local zone_id
  zone_id=$(echo "$response" | jq -r ".result[] | select(.name==\"$zone_name\") | .id" 2>/dev/null)

  if [[ -z "$zone_id" ]] || [[ "$zone_id" == "null" ]]; then
    # Try to find parent zone if exact match not found
    local parent_domain="$zone_name"
    while [[ "$parent_domain" == *.* ]]; do
      parent_domain="${parent_domain#*.}"
      response=$(_cloudflare_api_call "GET" "/zones?name=$parent_domain")

      if _check_cloudflare_response "$response" "parent zone lookup"; then
        zone_id=$(echo "$response" | jq -r ".result[] | select(.name==\"$parent_domain\") | .id" 2>/dev/null)
        if [[ -n "$zone_id" ]] && [[ "$zone_id" != "null" ]]; then
          echo "$zone_id"
          return 0
        fi
      fi
    done

    echo "Zone not found: $zone_name" >&2
    return 1
  fi

  echo "$zone_id"
  return 0
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

  local response
  response=$(_cloudflare_api_call "GET" "/zones/$zone_id/dns_records?name=$record_name&type=$record_type")

  if ! _check_cloudflare_response "$response" "record lookup"; then
    return 1
  fi

  local record_value
  record_value=$(echo "$response" | jq -r ".result[] | select(.name==\"$record_name\" and .type==\"$record_type\") | .content" 2>/dev/null)

  if [[ -z "$record_value" ]] || [[ "$record_value" == "null" ]]; then
    echo "Record not found: $record_name ($record_type)" >&2
    return 1
  fi

  echo "$record_value"
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

  # Check if record already exists
  local existing_response
  existing_response=$(_cloudflare_api_call "GET" "/zones/$zone_id/dns_records?name=$record_name&type=$record_type")

  local record_id
  if _check_cloudflare_response "$existing_response" "existing record check"; then
    record_id=$(echo "$existing_response" | jq -r ".result[] | select(.name==\"$record_name\" and .type==\"$record_type\") | .id" 2>/dev/null)
  fi

  local data
  data=$(jq -n \
    --arg name "$record_name" \
    --arg type "$record_type" \
    --arg content "$record_value" \
    --argjson ttl "$ttl" \
    '{name: $name, type: $type, content: $content, ttl: $ttl}')

  local response
  if [[ -n "$record_id" ]] && [[ "$record_id" != "null" ]]; then
    # Update existing record
    response=$(_cloudflare_api_call "PUT" "/zones/$zone_id/dns_records/$record_id" "$data")
    local action="Updated"
  else
    # Create new record
    response=$(_cloudflare_api_call "POST" "/zones/$zone_id/dns_records" "$data")
    local action="Created"
  fi

  if ! _check_cloudflare_response "$response" "record creation/update"; then
    echo "Failed to create/update record: $record_name" >&2
    return 1
  fi

  echo "$action record: $record_name -> $record_value (TTL: $ttl)"
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

  # Find the record to delete
  local response
  response=$(_cloudflare_api_call "GET" "/zones/$zone_id/dns_records?name=$record_name&type=$record_type")

  if ! _check_cloudflare_response "$response" "record lookup for deletion"; then
    return 1
  fi

  local record_id
  record_id=$(echo "$response" | jq -r ".result[] | select(.name==\"$record_name\" and .type==\"$record_type\") | .id" 2>/dev/null)

  if [[ -z "$record_id" ]] || [[ "$record_id" == "null" ]]; then
    echo "Record not found for deletion: $record_name ($record_type)" >&2
    return 1
  fi

  # Delete the record
  local delete_response
  delete_response=$(_cloudflare_api_call "DELETE" "/zones/$zone_id/dns_records/$record_id")

  if ! _check_cloudflare_response "$delete_response" "record deletion"; then
    echo "Failed to delete record: $record_name ($record_type)" >&2
    return 1
  fi

  echo "Deleted record: $record_name ($record_type)"
  return 0
}

# OPTIONAL: Provider-specific environment setup
provider_setup_env() {
  # Set default API base if not already set
  export CLOUDFLARE_API_BASE="${CLOUDFLARE_API_BASE:-https://api.cloudflare.com/client/v4}"

  # Validate that jq is available for JSON processing
  if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: jq is required for Cloudflare provider but not found" >&2
    echo "Install jq: https://stedolan.github.io/jq/download/" >&2
    return 1
  fi

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

  # Cloudflare doesn't have a native batch API for DNS records,
  # so we fall back to individual record creation
  local line success_count=0 total_count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    local record_name record_type record_value ttl
    read -r record_name record_type record_value ttl <<<"$line"

    total_count=$((total_count + 1))
    if provider_create_record "$zone_id" "$record_name" "$record_type" "$record_value" "$ttl"; then
      success_count=$((success_count + 1))
    else
      echo "Batch operation failed on record: $record_name" >&2
    fi
  done <"$records_file"

  echo "Batch operation complete: $success_count/$total_count records processed"
  [[ $success_count -eq $total_count ]]
}
