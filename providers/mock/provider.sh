#!/bin/bash
# Mock DNS Provider Implementation
# Used for testing the provider abstraction system

# Load provider configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Mock data storage - use fixed directory so all processes share same mock data
MOCK_DATA_DIR="/tmp/mock-dns-test"

# Initialize mock data
_init_mock_data() {
  mkdir -p "$MOCK_DATA_DIR/zones" "$MOCK_DATA_DIR/records"

  # Add some test zones
  echo "zone123456" >"$MOCK_DATA_DIR/zones/example.com"
  echo "zone789012" >"$MOCK_DATA_DIR/zones/test.org"
  echo "zone345678" >"$MOCK_DATA_DIR/zones/demo.net"
  echo "zonelocalhost" >"$MOCK_DATA_DIR/zones/localhost"

  # Add some test records
  echo "192.168.1.100:300" >"$MOCK_DATA_DIR/records/zone123456:www.example.com:A"
  echo "192.168.1.101:300" >"$MOCK_DATA_DIR/records/zone123456:api.example.com:A"
  echo "10.0.0.50:600" >"$MOCK_DATA_DIR/records/zone789012:test.org:A"
}

# Get zone ID from mock data
_get_mock_zone_id() {
  local zone_name="$1"
  local zone_file="$MOCK_DATA_DIR/zones/$zone_name"
  if [[ -f "$zone_file" ]]; then
    cat "$zone_file"
    return 0
  fi
  return 1
}

# Get record data from mock
_get_mock_record() {
  local record_key="$1"
  local record_file="$MOCK_DATA_DIR/records/$record_key"
  if [[ -f "$record_file" ]]; then
    cat "$record_file"
    return 0
  fi
  return 1
}

# Set record data in mock
_set_mock_record() {
  local record_key="$1"
  local record_data="$2"
  echo "$record_data" >"$MOCK_DATA_DIR/records/$record_key"
}

# Delete record from mock
_delete_mock_record() {
  local record_key="$1"
  rm -f "$MOCK_DATA_DIR/records/$record_key"
}

# Initialize on load
_init_mock_data

# REQUIRED: Validate that mock credentials are properly configured
provider_validate_credentials() {
  # Check if required environment variable is set
  if [[ -z "${MOCK_API_KEY:-}" ]]; then
    echo "Missing required environment variable: MOCK_API_KEY" >&2
    return 1
  fi

  # Mock validation (accept any non-empty key)
  if [[ "$MOCK_API_KEY" == "invalid" ]]; then
    echo "Invalid mock API key" >&2
    return 1
  fi

  return 0
}

# REQUIRED: List all hosted zones available to the mock account
provider_list_zones() {
  if ! provider_validate_credentials; then
    return 1
  fi

  # Return mock zone names
  if [[ -d "$MOCK_DATA_DIR/zones" ]]; then
    ls "$MOCK_DATA_DIR/zones" 2>/dev/null
  fi
}

# REQUIRED: Get the mock zone ID for a domain
provider_get_zone_id() {
  local zone_name="$1"

  if [[ -z "$zone_name" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  if ! provider_validate_credentials; then
    return 1
  fi

  # Check if zone exists in mock data
  local zone_id
  if zone_id=$(_get_mock_zone_id "$zone_name"); then
    echo "$zone_id"
    return 0
  fi

  # Try parent domains
  local current_domain="$zone_name"
  while [[ "$current_domain" == *.* ]]; do
    current_domain="${current_domain#*.}"
    if zone_id=$(_get_mock_zone_id "$current_domain"); then
      echo "$zone_id"
      return 0
    fi
  done

  echo "Mock zone not found: $zone_name" >&2
  return 1
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

  if ! provider_validate_credentials; then
    return 1
  fi

  # Check mock records
  local record_key="${zone_id}:${record_name}:${record_type}"
  local record_data
  if record_data=$(_get_mock_record "$record_key"); then
    local record_value="${record_data%:*}"
    echo "$record_value"
    return 0
  fi

  echo "Mock record not found: $record_name ($record_type)" >&2
  return 1
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

  if ! provider_validate_credentials; then
    return 1
  fi

  # Store in mock records
  local record_key="${zone_id}:${record_name}:${record_type}"
  _set_mock_record "$record_key" "${record_value}:${ttl}"

  echo "Mock created/updated record: $record_name -> $record_value (TTL: $ttl)"
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

  if ! provider_validate_credentials; then
    return 1
  fi

  # Remove from mock records
  local record_key="${zone_id}:${record_name}:${record_type}"
  if _get_mock_record "$record_key" >/dev/null 2>&1; then
    _delete_mock_record "$record_key"
    echo "Mock deleted record: $record_name ($record_type)"
    return 0
  else
    echo "Mock record not found for deletion: $record_name ($record_type)" >&2
    return 1
  fi
}

# OPTIONAL: Mock-specific environment setup
provider_setup_env() {
  # Set default mock API endpoint
  export MOCK_API_ENDPOINT="${MOCK_API_ENDPOINT:-https://api.mock-dns.com}"
  return 0
}

# OPTIONAL: Batch create multiple records
provider_batch_create_records() {
  local zone_id="$1"
  local records_file="$2"

  if [[ -z "$zone_id" ]] || [[ -z "$records_file" ]] || [[ ! -f "$records_file" ]]; then
    echo "Zone ID and valid records file are required" >&2
    return 1
  fi

  if ! provider_validate_credentials; then
    return 1
  fi

  local records_created=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    local record_name record_type record_value ttl
    read -r record_name record_type record_value ttl <<<"$line"
    ttl="${ttl:-${PROVIDER_DEFAULT_TTL:-300}}"

    if provider_create_record "$zone_id" "$record_name" "$record_type" "$record_value" "$ttl"; then
      records_created=$((records_created + 1))
    else
      echo "Mock batch operation failed on record: $record_name" >&2
      return 1
    fi
  done <"$records_file"

  echo "Mock batch created $records_created records"
  return 0
}

# Debug function to show mock state
provider_debug_state() {
  echo "Mock Zones:"
  if [[ -d "$MOCK_DATA_DIR/zones" ]]; then
    for zone_file in "$MOCK_DATA_DIR/zones"/*; do
      if [[ -f "$zone_file" ]]; then
        local zone_name zone_id
        zone_name=$(basename "$zone_file")
        zone_id=$(cat "$zone_file")
        echo "  $zone_name -> $zone_id"
      fi
    done
  fi

  echo "Mock Records:"
  if [[ -d "$MOCK_DATA_DIR/records" ]]; then
    for record_file in "$MOCK_DATA_DIR/records"/*; do
      if [[ -f "$record_file" ]]; then
        local record_key record_data
        record_key=$(basename "$record_file")
        record_data=$(cat "$record_file")
        echo "  $record_key -> $record_data"
      fi
    done
  fi
}
