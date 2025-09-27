#!/bin/bash
# AWS Route53 Provider Implementation
# Implements the minimal DNS provider interface for AWS Route53

# Load provider configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Internal helper function to check AWS API responses for errors
_check_aws_response() {
  local response="$1"
  local context="$2"

  if [[ -z "$response" ]]; then
    echo "AWS API error in $context: empty response" >&2
    return 1
  fi

  # Check for common AWS error patterns
  if echo "$response" | jq -e '.Error' >/dev/null 2>&1; then
    local error_code error_message
    error_code=$(echo "$response" | jq -r '.Error.Code // "Unknown"' 2>/dev/null)
    error_message=$(echo "$response" | jq -r '.Error.Message // "Unknown error"' 2>/dev/null)
    echo "AWS API error in $context: $error_code - $error_message" >&2
    return 1
  fi

  return 0
}

# REQUIRED: Validate that AWS credentials are properly configured
provider_validate_credentials() {
  # Check if AWS CLI is available
  if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI not installed" >&2
    return 1
  fi

  # Validate that jq is available for JSON processing
  if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: jq is required for AWS provider but not found" >&2
    echo "Install jq: https://stedolan.github.io/jq/download/" >&2
    return 1
  fi

  # Test AWS credentials by calling get-caller-identity
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "AWS credentials not configured or invalid" >&2
    return 1
  fi

  return 0
}

# REQUIRED: List all hosted zones available to the AWS account
provider_list_zones() {
  if ! provider_validate_credentials; then
    return 1
  fi

  # List hosted zones and extract zone names using jq
  local response
  response=$(aws route53 list-hosted-zones --output json 2>/dev/null)

  if ! _check_aws_response "$response" "zone listing"; then
    return 1
  fi

  # Extract zone names using jq, removing trailing dots
  echo "$response" | jq -r '.HostedZones[]?.Name // empty' 2>/dev/null | sed 's/\.$//'
}

# REQUIRED: Get the AWS hosted zone ID for a domain
provider_get_zone_id() {
  local zone_name="$1"

  if [[ -z "$zone_name" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  if ! provider_validate_credentials; then
    return 1
  fi

  # Try to find hosted zone for domain or its parent domains
  local current_domain="$zone_name"

  while [[ "$current_domain" == *.* ]]; do
    # Check if there's a hosted zone for the current domain using jq
    local response zone_id
    response=$(aws route53 list-hosted-zones --output json 2>/dev/null)

    if _check_aws_response "$response" "zone ID lookup"; then
      zone_id=$(echo "$response" | jq -r ".HostedZones[]? | select(.Name==\"${current_domain}.\") | .Id" 2>/dev/null)

      if [[ -n "$zone_id" && "$zone_id" != "null" ]]; then
        # Found a hosted zone, return the zone ID without the /hostedzone/ prefix
        echo "${zone_id#/hostedzone/}"
        return 0
      fi
    fi

    # Remove the leftmost subdomain and try again
    current_domain="${current_domain#*.}"
  done

  # No hosted zone found
  echo "Hosted zone not found for: $zone_name" >&2
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

  # Query Route53 for the record using jq
  local response record_value
  response=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$zone_id" \
    --output json 2>/dev/null)

  if ! _check_aws_response "$response" "record lookup"; then
    return 1
  fi

  record_value=$(echo "$response" | jq -r ".ResourceRecordSets[]? | select(.Name==\"${record_name}.\" and .Type==\"${record_type}\") | .ResourceRecords[0]?.Value // empty" 2>/dev/null)

  if [[ -z "$record_value" ]]; then
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

  if ! provider_validate_credentials; then
    return 1
  fi

  # Create the change batch for Route53
  local change_batch="{
        \"Changes\": [{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"${record_name}\",
                \"Type\": \"${record_type}\",
                \"TTL\": ${ttl},
                \"ResourceRecords\": [{\"Value\": \"${record_value}\"}]
            }
        }]
    }"

  # Execute the change
  if aws route53 change-resource-record-sets \
    --hosted-zone-id "$zone_id" \
    --change-batch "$change_batch" >/dev/null 2>&1; then
    echo "Created/updated record: $record_name -> $record_value (TTL: $ttl)"
    return 0
  else
    echo "Failed to create/update record: $record_name" >&2
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

  if ! provider_validate_credentials; then
    return 1
  fi

  # First get the current record value (required for DELETE action) using jq
  local record_value ttl response
  response=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$zone_id" \
    --output json 2>/dev/null)

  if ! _check_aws_response "$response" "record deletion lookup"; then
    return 1
  fi

  local record_info
  record_info=$(echo "$response" | jq ".ResourceRecordSets[]? | select(.Name==\"${record_name}.\" and .Type==\"${record_type}\")" 2>/dev/null)

  if [[ -z "$record_info" ]] || [[ "$record_info" == "null" ]]; then
    echo "Record not found for deletion: $record_name ($record_type)" >&2
    return 1
  fi

  record_value=$(echo "$record_info" | jq -r '.ResourceRecords[0].Value')
  ttl=$(echo "$record_info" | jq -r '.TTL')

  # Create the delete change batch
  local change_batch="{
        \"Changes\": [{
            \"Action\": \"DELETE\",
            \"ResourceRecordSet\": {
                \"Name\": \"${record_name}\",
                \"Type\": \"${record_type}\",
                \"TTL\": ${ttl},
                \"ResourceRecords\": [{\"Value\": \"${record_value}\"}]
            }
        }]
    }"

  # Execute the delete
  if aws route53 change-resource-record-sets \
    --hosted-zone-id "$zone_id" \
    --change-batch "$change_batch" >/dev/null 2>&1; then
    echo "Deleted record: $record_name ($record_type)"
    return 0
  else
    echo "Failed to delete record: $record_name" >&2
    return 1
  fi
}

# OPTIONAL: AWS-specific environment setup
provider_setup_env() {
  # Set default region if not specified
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
  return 0
}

# OPTIONAL: Batch create multiple records (AWS optimization)
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

  # Build changes array for batch operation
  local changes='[]'
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    local record_name record_type record_value ttl
    read -r record_name record_type record_value ttl <<<"$line"
    ttl="${ttl:-${PROVIDER_DEFAULT_TTL:-300}}"

    # Add change to the batch
    local change="{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"${record_name}\",
                \"Type\": \"${record_type}\",
                \"TTL\": ${ttl},
                \"ResourceRecords\": [{\"Value\": \"${record_value}\"}]
            }
        }"

    changes=$(echo "$changes" | jq ". += [$change]")
  done <"$records_file"

  # Execute batch operation if we have changes
  if [[ "$(echo "$changes" | jq 'length')" -gt 0 ]]; then
    local change_batch
    change_batch=$(jq -n --argjson changes "$changes" '{Changes: $changes}')

    if aws route53 change-resource-record-sets \
      --hosted-zone-id "$zone_id" \
      --change-batch "$change_batch" >/dev/null 2>&1; then
      echo "Batch created $(echo "$changes" | jq 'length') records"
      return 0
    else
      echo "Batch operation failed" >&2
      return 1
    fi
  fi

  return 0
}
