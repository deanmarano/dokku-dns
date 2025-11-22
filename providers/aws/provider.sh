#!/bin/bash
# AWS Route53 Provider Implementation
# Implements the minimal DNS provider interface for AWS Route53

# Load provider configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Internal helper function to check AWS API responses for errors
#
# Validates AWS CLI JSON responses and extracts error information if present.
# AWS API errors are returned in a consistent JSON structure with .Error.Code and .Error.Message fields.
#
# Arguments:
#   $1 - response: JSON string from AWS CLI command
#   $2 - context: Descriptive context for error messages (e.g., "zone listing", "record creation")
#
# Returns:
#   0 - Response is valid (no errors detected)
#   1 - Response is invalid (empty or contains AWS error)
#
# Outputs:
#   Writes error messages to stderr if validation fails
#
# Example AWS error JSON:
#   {"Error": {"Code": "NoSuchHostedZone", "Message": "The hosted zone does not exist"}}
#
_check_aws_response() {
  local response="$1"
  local context="$2"

  # Validate response is not empty
  if [[ -z "$response" ]]; then
    echo "AWS API error in $context: empty response" >&2
    return 1
  fi

  # Check for AWS error structure using jq's -e flag (exit with error if expression is false/null)
  # The '.Error' expression tests if the Error field exists in the JSON
  if echo "$response" | jq -e '.Error' >/dev/null 2>&1; then
    local error_code error_message
    # Extract error code using jq:
    #   -r: raw output (no quotes)
    #   '.Error.Code // "Unknown"': Get .Error.Code, default to "Unknown" if null/missing
    error_code=$(echo "$response" | jq -r '.Error.Code // "Unknown"' 2>/dev/null)
    error_message=$(echo "$response" | jq -r '.Error.Message // "Unknown error"' 2>/dev/null)
    echo "AWS API error in $context: $error_code - $error_message" >&2
    return 1
  fi

  return 0
}

# REQUIRED: Validate that AWS credentials are properly configured
#
# Verifies that all prerequisites for AWS Route53 operations are met:
#   1. AWS CLI is installed and accessible
#   2. jq is installed for JSON processing
#   3. AWS credentials are configured and valid
#
# This function is called before every AWS API operation to ensure the environment is ready.
#
# AWS credential sources (in order of precedence):
#   - Environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
#   - AWS credentials file: ~/.aws/credentials
#   - IAM role (when running on EC2/ECS)
#
# Arguments:
#   None
#
# Returns:
#   0 - All prerequisites met, credentials valid
#   1 - Missing dependencies or invalid credentials
#
# Outputs:
#   Writes error messages to stderr explaining what's missing or invalid
#
provider_validate_credentials() {
  # Check if AWS CLI is available
  if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI not installed" >&2
    return 1
  fi

  # Validate that jq is available for JSON processing
  # jq is essential for parsing AWS CLI JSON responses throughout this provider
  if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: jq is required for AWS provider but not found" >&2
    echo "Install jq: https://stedolan.github.io/jq/download/" >&2
    return 1
  fi

  # Test AWS credentials by calling get-caller-identity
  # This is a lightweight STS API call that verifies credentials without requiring specific permissions
  # Returns account ID, user ARN, and user ID if credentials are valid
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "AWS credentials not configured or invalid" >&2
    return 1
  fi

  return 0
}

# REQUIRED: List all hosted zones available to the AWS account
#
# Retrieves all Route53 hosted zones and returns their domain names.
# Hosted zones in Route53 are DNS zone containers that hold DNS records.
#
# Arguments:
#   None
#
# Returns:
#   0 - Successfully retrieved zones
#   1 - Failed to retrieve zones (credentials invalid or API error)
#
# Outputs:
#   Writes one zone name per line to stdout (e.g., "example.com")
#   Zone names have trailing dots removed for consistency
#
# Example AWS Route53 response JSON:
#   {
#     "HostedZones": [
#       {"Id": "/hostedzone/Z123", "Name": "example.com.", "Config": {...}},
#       {"Id": "/hostedzone/Z456", "Name": "test.io.", "Config": {...}}
#     ]
#   }
#
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
  # jq expression breakdown:
  #   '.HostedZones[]?': Iterate over HostedZones array, ? suppresses errors if field doesn't exist
  #   '.Name // empty': Get the Name field, or return empty if null/missing
  #   -r: Output raw strings (no JSON quotes)
  # sed removes the trailing dot that Route53 adds to zone names (DNS FQDN format)
  echo "$response" | jq -r '.HostedZones[]?.Name // empty' 2>/dev/null | sed 's/\.$//'
}

# REQUIRED: Get the AWS hosted zone ID for a domain
#
# Finds the Route53 hosted zone ID for a given domain by searching the domain
# and all parent domains in the DNS hierarchy.
#
# This implements "zone climbing" - if no zone exists for "www.api.example.com",
# it tries "api.example.com", then "example.com", until a zone is found.
#
# Arguments:
#   $1 - zone_name: Domain name to find zone for (e.g., "www.example.com")
#
# Returns:
#   0 - Zone found, ID written to stdout
#   1 - No zone found for domain or any parent domain
#
# Outputs:
#   stdout: Zone ID without /hostedzone/ prefix (e.g., "Z1234567890ABC")
#   stderr: Error message if no zone found
#
# Example:
#   For input "www.api.example.com":
#   1. Tries "www.api.example.com" - not found
#   2. Tries "api.example.com" - not found
#   3. Tries "example.com" - FOUND! Returns zone ID
#
provider_get_zone_id() {
  local zone_name="$1"

  if [[ -z "$zone_name" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  if ! provider_validate_credentials; then
    return 1
  fi

  # Try to find hosted zone for domain or its parent domains (zone climbing)
  local current_domain="$zone_name"

  # Continue while domain has at least one dot (stops at TLD like "com")
  # Pattern match *.* ensures we have a domain with at least subdomain.tld format
  while [[ "$current_domain" == *.* ]]; do
    # Check if there's a hosted zone for the current domain using jq
    local response zone_id
    response=$(aws route53 list-hosted-zones --output json 2>/dev/null)

    if _check_aws_response "$response" "zone ID lookup"; then
      # jq expression breakdown:
      #   '.HostedZones[]?': Iterate over zones array
      #   'select(.Name=="example.com.")': Filter to zone matching current domain (note trailing dot)
      #   '.Id': Extract the zone ID field
      # Route53 stores zone names with trailing dots (FQDN format), so we add one for comparison
      zone_id=$(echo "$response" | jq -r ".HostedZones[]? | select(.Name==\"${current_domain}.\") | .Id" 2>/dev/null)

      if [[ -n "$zone_id" && "$zone_id" != "null" ]]; then
        # Found a hosted zone, return the zone ID without the /hostedzone/ prefix
        # AWS returns IDs in format "/hostedzone/Z123", we strip the prefix using parameter expansion
        echo "${zone_id#/hostedzone/}"
        return 0
      fi
    fi

    # Remove the leftmost subdomain and try the parent domain
    # Parameter expansion: ${var#*.} removes shortest match of "*." from the beginning
    # Example: "www.api.example.com" -> "api.example.com" -> "example.com"
    current_domain="${current_domain#*.}"
  done

  # No hosted zone found for this domain or any parent domains
  echo "Hosted zone not found for: $zone_name" >&2
  return 1
}

# REQUIRED: Get current DNS record value
#
# Retrieves the value of a specific DNS record from Route53.
# Searches for an exact match on both record name and type.
#
# Arguments:
#   $1 - zone_id: Route53 hosted zone ID (without /hostedzone/ prefix)
#   $2 - record_name: Fully qualified domain name (e.g., "www.example.com")
#   $3 - record_type: DNS record type (e.g., "A", "CNAME", "TXT")
#
# Returns:
#   0 - Record found, value written to stdout
#   1 - Record not found or API error
#
# Outputs:
#   stdout: Record value (e.g., "192.168.1.1" for A record)
#   stderr: Error message if record not found
#
# Example Route53 record structure:
#   {
#     "Name": "www.example.com.",
#     "Type": "A",
#     "TTL": 300,
#     "ResourceRecords": [{"Value": "192.168.1.1"}]
#   }
#
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

  # Complex jq expression to find and extract record value:
  #   '.ResourceRecordSets[]?': Iterate over all DNS records in the zone
  #   'select(.Name=="..." and .Type=="...")': Filter to exact name AND type match
  #     Note: Route53 stores names with trailing dots (FQDN format)
  #   '.ResourceRecords[0]?.Value': Get the first record's value
  #   '// empty': Return empty string if value is null/missing (for chaining with || in shell)
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
#
# Creates or updates multiple DNS records in a single Route53 API call.
# This is significantly more efficient than individual record operations.
#
# Route53 allows up to 1000 changes per batch request. Batching reduces:
#   - API calls from N to 1 (for N records)
#   - Network latency
#   - API rate limit consumption
#
# Arguments:
#   $1 - zone_id: Route53 hosted zone ID (without /hostedzone/ prefix)
#   $2 - records_file: Path to file containing records (one per line)
#
# Records file format (space-separated):
#   record_name record_type record_value [ttl]
#
# Example records file:
#   www.example.com A 192.168.1.1 300
#   api.example.com A 192.168.1.2 600
#   # Comments and empty lines are ignored
#
# Returns:
#   0 - Batch operation successful or no records to process
#   1 - Invalid arguments or API error
#
# Outputs:
#   stdout: Success message with count of records created
#   stderr: Error message if batch operation fails
#
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
  # Start with empty JSON array that we'll append to
  local changes='[]'
  local line

  # Read file line by line, preserving trailing lines without newlines
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    # Regex ^[[:space:]]*# matches lines starting with optional whitespace followed by #
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    local record_name record_type record_value ttl
    # Split line into variables using here-string (<<<)
    # read uses whitespace as delimiter by default
    read -r record_name record_type record_value ttl <<<"$line"
    # Default TTL if not specified: use PROVIDER_DEFAULT_TTL or 300 seconds
    ttl="${ttl:-${PROVIDER_DEFAULT_TTL:-300}}"

    # Build JSON change object for this record
    # UPSERT action creates record if it doesn't exist, updates if it does
    local change="{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"${record_name}\",
                \"Type\": \"${record_type}\",
                \"TTL\": ${ttl},
                \"ResourceRecords\": [{\"Value\": \"${record_value}\"}]
            }
        }"

    # Append change to changes array using jq
    # Expression '. += [$change]' means: append $change to current array
    changes=$(echo "$changes" | jq ". += [$change]")
  done <"$records_file"

  # Execute batch operation if we have changes
  # jq 'length' returns the number of elements in the array
  if [[ "$(echo "$changes" | jq 'length')" -gt 0 ]]; then
    local change_batch
    # Build final change batch structure using jq:
    #   -n: Don't read input, start with null
    #   --argjson changes "$changes": Pass $changes as a JSON variable
    #   '{Changes: $changes}': Create object with Changes field
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
