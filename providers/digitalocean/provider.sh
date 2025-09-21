#!/bin/bash
# DigitalOcean DNS Provider Implementation

# Load provider configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Helper function to make DigitalOcean API calls
_do_api_call() {
  local method="$1"
  local endpoint="$2"
  local data="$3"

  local curl_args=(
    -s
    -X "$method"
    -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN"
    -H "Content-Type: application/json"
  )

  if [[ -n "$data" ]]; then
    curl_args+=(-d "$data")
  fi

  curl "${curl_args[@]}" "$DIGITALOCEAN_API_URL$endpoint"
}

# REQUIRED: Validate that provider credentials are properly configured
provider_validate_credentials() {
  # Check if required environment variables are set
  if [[ -z "${DIGITALOCEAN_ACCESS_TOKEN:-}" ]]; then
    echo "Missing required environment variable: DIGITALOCEAN_ACCESS_TOKEN" >&2
    echo "Get your token from: https://cloud.digitalocean.com/account/api/tokens" >&2
    return 1
  fi

  # Test API connectivity
  local response
  response=$(_do_api_call GET "/account" 2>/dev/null)

  if [[ -z "$response" ]]; then
    echo "Failed to connect to DigitalOcean API" >&2
    return 1
  fi

  # Check if the response contains an error (DigitalOcean returns {id: "Unauthorized"} for auth failures)
  local account_id
  account_id=$(echo "$response" | jq -r '.account.uuid // empty' 2>/dev/null)

  if [[ -n "$account_id" ]]; then
    return 0
  else
    # Check for specific error patterns
    local error_id error_message
    error_id=$(echo "$response" | jq -r '.id // empty' 2>/dev/null)
    error_message=$(echo "$response" | jq -r '.message // "Authentication failed"' 2>/dev/null || echo "Authentication failed")

    if [[ "$error_id" == "Unauthorized" ]]; then
      echo "DigitalOcean API authentication failed: $error_message" >&2
    else
      echo "DigitalOcean API error: $error_message" >&2
    fi
    return 1
  fi
}

# REQUIRED: List all DNS zones available to the configured account
provider_list_zones() {
  local response
  response=$(_do_api_call GET "/domains")

  if [[ -z "$response" ]]; then
    echo "Failed to list domains from DigitalOcean API" >&2
    return 1
  fi

  # Extract domain names from the response
  echo "$response" | jq -r '.domains[]?.name // empty' 2>/dev/null || {
    echo "Failed to parse domains from DigitalOcean API response" >&2
    return 1
  }
}

# REQUIRED: Get the provider-specific zone identifier
provider_get_zone_id() {
  local zone_name="$1"

  if [[ -z "$zone_name" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  # For DigitalOcean, the zone ID is the same as the zone name
  # Verify the domain exists
  local response
  response=$(_do_api_call GET "/domains/$zone_name")

  if [[ -z "$response" ]]; then
    echo "Zone not found: $zone_name" >&2
    return 1
  fi

  # Check if domain exists in the response
  if echo "$response" | jq -e '.domain.name' >/dev/null 2>&1; then
    echo "$zone_name"
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

  # Get all records for the domain
  local response
  response=$(_do_api_call GET "/domains/$zone_id/records")

  if [[ -z "$response" ]]; then
    echo "Failed to get records for domain: $zone_id" >&2
    return 1
  fi

  # Find the specific record
  local record_value
  record_value=$(echo "$response" | jq -r ".domain_records[]? | select(.name == \"$record_name\" and .type == \"$record_type\") | .data" 2>/dev/null)

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
  local ttl="${5:-${PROVIDER_DEFAULT_TTL:-1800}}"

  if [[ -z "$zone_id" ]] || [[ -z "$record_name" ]] || [[ -z "$record_type" ]] || [[ -z "$record_value" ]]; then
    echo "Zone ID, record name, record type, and record value are required" >&2
    return 1
  fi

  # Check if record already exists
  local existing_record_id=""
  local response
  response=$(_do_api_call GET "/domains/$zone_id/records")

  if [[ -n "$response" ]]; then
    existing_record_id=$(echo "$response" | jq -r ".domain_records[]? | select(.name == \"$record_name\" and .type == \"$record_type\") | .id" 2>/dev/null)
  fi

  # Prepare the record data
  local record_data
  record_data=$(jq -n \
    --arg type "$record_type" \
    --arg name "$record_name" \
    --arg data "$record_value" \
    --argjson ttl "$ttl" \
    '{type: $type, name: $name, data: $data, ttl: $ttl}')

  local result
  if [[ -n "$existing_record_id" ]] && [[ "$existing_record_id" != "null" ]]; then
    # Update existing record
    result=$(_do_api_call PUT "/domains/$zone_id/records/$existing_record_id" "$record_data")
  else
    # Create new record
    result=$(_do_api_call POST "/domains/$zone_id/records" "$record_data")
  fi

  if [[ -z "$result" ]]; then
    echo "Failed to create/update record: $record_name" >&2
    return 1
  fi

  # Check if the operation was successful
  if echo "$result" | jq -e '.domain_record.id' >/dev/null 2>&1; then
    echo "Successfully created/updated record: $record_name -> $record_value (TTL: $ttl)"
    return 0
  else
    local error_message
    error_message=$(echo "$result" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
    echo "Failed to create/update record: $record_name - $error_message" >&2
    return 1
  fi
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

  # Find the record ID
  local response
  response=$(_do_api_call GET "/domains/$zone_id/records")

  if [[ -z "$response" ]]; then
    echo "Failed to get records for domain: $zone_id" >&2
    return 1
  fi

  local record_id
  record_id=$(echo "$response" | jq -r ".domain_records[]? | select(.name == \"$record_name\" and .type == \"$record_type\") | .id" 2>/dev/null)

  if [[ -z "$record_id" ]] || [[ "$record_id" == "null" ]]; then
    echo "Record not found for deletion: $record_name ($record_type)" >&2
    return 1
  fi

  # Delete the record
  local result
  result=$(_do_api_call DELETE "/domains/$zone_id/records/$record_id")

  # DigitalOcean returns empty response on successful deletion
  # Check for errors by looking for error messages in the response
  if [[ -n "$result" ]] && echo "$result" | jq -e '.message' >/dev/null 2>&1; then
    local error_message
    error_message=$(echo "$result" | jq -r '.message' 2>/dev/null || echo "Unknown error")
    echo "Failed to delete record: $record_name - $error_message" >&2
    return 1
  fi

  echo "Successfully deleted record: $record_name ($record_type)"
  return 0
}

# OPTIONAL: Provider-specific environment setup
provider_setup_env() {
  # Set default API URL if not provided
  export DIGITALOCEAN_API_URL="${DIGITALOCEAN_API_URL:-https://api.digitalocean.com/v2}"

  # Validate jq is available (required for JSON parsing)
  if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: jq is required for DigitalOcean provider but not found in PATH" >&2
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

  # DigitalOcean doesn't have a native batch API, so we'll use individual calls
  # This is still faster than the caller doing it themselves due to reduced overhead

  local success_count=0
  local fail_count=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    local record_name record_type record_value ttl
    read -r record_name record_type record_value ttl <<<"$line"

    if provider_create_record "$zone_id" "$record_name" "$record_type" "$record_value" "$ttl"; then
      success_count=$((success_count + 1))
    else
      fail_count=$((fail_count + 1))
      echo "Batch operation failed on record: $record_name" >&2
    fi
  done <"$records_file"

  if [[ $fail_count -gt 0 ]]; then
    echo "Batch operation completed with $fail_count failures out of $((success_count + fail_count)) records" >&2
    return 1
  fi

  echo "Batch operation completed successfully: $success_count records processed"
  return 0
}
