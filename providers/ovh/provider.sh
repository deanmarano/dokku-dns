#!/bin/bash
# OVHcloud DNS Provider Implementation

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

_ovh_sha1() {
  if command -v sha1sum >/dev/null 2>&1; then
    sha1sum | awk '{print $1}'
  else
    shasum -a 1 | awk '{print $1}'
  fi
}

_ovh_api_call() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local url="${OVH_API_ENDPOINT}${endpoint}"
  local timestamp signature

  timestamp=$(curl -s "${OVH_API_ENDPOINT}/auth/time")
  if [[ ! "$timestamp" =~ ^[0-9]+$ ]]; then
    echo "Failed to get time from OVHcloud API" >&2
    return 1
  fi

  signature=$(printf '%s' "${OVH_APPLICATION_SECRET}+${OVH_CONSUMER_KEY}+${method}+${url}+${data}+${timestamp}" | _ovh_sha1)
  local curl_args=(
    -s
    -X "$method"
    -H "X-Ovh-Application: $OVH_APPLICATION_KEY"
    -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
    -H "X-Ovh-Timestamp: $timestamp"
    -H "X-Ovh-Signature: \$1\$$signature"
    -H "Content-Type: application/json"
  )
  [[ -n "$data" ]] && curl_args+=(-d "$data")
  curl "${curl_args[@]}" "$url"
}

_ovh_check_response() {
  local response="$1"
  local context="$2"
  local message

  if [[ -z "$response" ]]; then
    echo "OVHcloud API returned an empty response while $context" >&2
    return 1
  fi
  message=$(printf '%s' "$response" | jq -r '.message // .errorCode // empty' 2>/dev/null)
  if [[ -n "$message" ]]; then
    echo "OVHcloud API error while $context: $message" >&2
    return 1
  fi
}

_ovh_subdomain() {
  local zone="$1"
  local record_name="${2%.}"
  if [[ "$record_name" == "$zone" ]]; then
    printf '\n'
  elif [[ "$record_name" == *".$zone" ]]; then
    printf '%s\n' "${record_name%."$zone"}"
  else
    echo "Record $record_name does not belong to zone $zone" >&2
    return 1
  fi
}

_ovh_find_record_id() {
  local zone="$1"
  local subdomain="$2"
  local record_type="$3"
  local response record_id

  response=$(_ovh_api_call GET "/domain/zone/$zone/record?fieldType=$record_type&subDomain=$subdomain") || return 1
  _ovh_check_response "$response" "looking up record" || return 1
  record_id=$(printf '%s' "$response" | jq -r '.[0] // empty' 2>/dev/null)
  [[ -n "$record_id" ]] && printf '%s\n' "$record_id"
}

_ovh_refresh_zone() {
  local zone="$1"
  local response
  response=$(_ovh_api_call POST "/domain/zone/$zone/refresh" '{}') || return 1
  _ovh_check_response "$response" "refreshing zone $zone"
}

provider_validate_credentials() {
  local variable
  for variable in OVH_APPLICATION_KEY OVH_APPLICATION_SECRET OVH_CONSUMER_KEY; do
    if [[ -z "${!variable:-}" ]]; then
      echo "Missing required environment variable: $variable" >&2
      echo "Create API credentials at: https://api.ovh.com/createToken/" >&2
      return 1
    fi
  done

  local response
  response=$(_ovh_api_call GET /me) || return 1
  _ovh_check_response "$response" "validating credentials"
}

provider_list_zones() {
  local response
  response=$(_ovh_api_call GET /domain/zone) || return 1
  _ovh_check_response "$response" "listing zones" || return 1
  printf '%s' "$response" | jq -r '.[]?'
}

provider_get_zone_id() {
  local zone_name="${1%.}"
  local zones
  if [[ -z "$zone_name" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  zones=$(provider_list_zones) || return 1

  local zone
  while [[ "$zone_name" == *.* ]]; do
    while IFS= read -r zone; do
      if [[ "$zone" == "$zone_name" ]]; then
        printf '%s\n' "$zone"
        return 0
      fi
    done <<<"$zones"
    zone_name="${zone_name#*.}"
  done

  echo "Zone not found: $1" >&2
  return 1
}

provider_get_record() {
  local zone_id="$1"
  local record_name="$2"
  local record_type="$3"
  local subdomain record_id response value
  if [[ -z "$zone_id" || -z "$record_name" || -z "$record_type" ]]; then
    echo "Zone ID, record name, and record type are required" >&2
    return 1
  fi
  subdomain=$(_ovh_subdomain "$zone_id" "$record_name") || return 1
  record_id=$(_ovh_find_record_id "$zone_id" "$subdomain" "$record_type")
  if [[ -z "$record_id" ]]; then
    echo "Record not found: $record_name ($record_type)" >&2
    return 1
  fi
  response=$(_ovh_api_call GET "/domain/zone/$zone_id/record/$record_id") || return 1
  _ovh_check_response "$response" "getting record" || return 1
  value=$(printf '%s' "$response" | jq -r '.target // empty' 2>/dev/null)
  if [[ -z "$value" ]]; then
    echo "Record not found: $record_name ($record_type)" >&2
    return 1
  fi
  printf '%s\n' "$value"
}

provider_create_record() {
  local zone_id="$1"
  local record_name="$2"
  local record_type="$3"
  local record_value="$4"
  local ttl="${5:-${PROVIDER_DEFAULT_TTL:-300}}"
  local subdomain record_id data response action
  if [[ -z "$zone_id" || -z "$record_name" || -z "$record_type" || -z "$record_value" ]]; then
    echo "Zone ID, record name, record type, and record value are required" >&2
    return 1
  fi
  subdomain=$(_ovh_subdomain "$zone_id" "$record_name") || return 1
  record_id=$(_ovh_find_record_id "$zone_id" "$subdomain" "$record_type")

  if [[ -n "$record_id" ]]; then
    data=$(jq -n --arg target "$record_value" --argjson ttl "$ttl" '{target: $target, ttl: $ttl}')
    response=$(_ovh_api_call PUT "/domain/zone/$zone_id/record/$record_id" "$data") || return 1
    action="Updated"
  else
    data=$(jq -n --arg field_type "$record_type" --arg subdomain "$subdomain" --arg target "$record_value" --argjson ttl "$ttl" '{fieldType: $field_type, subDomain: $subdomain, target: $target, ttl: $ttl}')
    response=$(_ovh_api_call POST "/domain/zone/$zone_id/record" "$data") || return 1
    action="Created"
  fi
  _ovh_check_response "$response" "creating or updating record" || return 1
  _ovh_refresh_zone "$zone_id" || return 1
  echo "$action record: $record_name -> $record_value (TTL: $ttl)"
}

provider_delete_record() {
  local zone_id="$1"
  local record_name="$2"
  local record_type="$3"
  local subdomain record_id response
  if [[ -z "$zone_id" || -z "$record_name" || -z "$record_type" ]]; then
    echo "Zone ID, record name, and record type are required" >&2
    return 1
  fi
  subdomain=$(_ovh_subdomain "$zone_id" "$record_name") || return 1
  record_id=$(_ovh_find_record_id "$zone_id" "$subdomain" "$record_type")
  if [[ -z "$record_id" ]]; then
    echo "Record not found for deletion: $record_name ($record_type)" >&2
    return 1
  fi
  response=$(_ovh_api_call DELETE "/domain/zone/$zone_id/record/$record_id") || return 1
  _ovh_check_response "$response" "deleting record" || return 1
  _ovh_refresh_zone "$zone_id" || return 1
  echo "Deleted record: $record_name ($record_type)"
}

provider_setup_env() {
  command -v jq >/dev/null 2>&1 || {
    echo "jq is required for the OVHcloud provider" >&2
    return 1
  }
  command -v sha1sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || {
    echo "sha1sum or shasum is required for the OVHcloud provider" >&2
    return 1
  }
}
