#!/bin/bash
# Namecheap DNS Provider Implementation
# Uses Namecheap API for DNS zone and record management
#
# NOTE: Namecheap's DNS API works differently from other providers.
# Records are managed per-domain as a complete set — you must GET all
# records, modify the list, then SET the entire list back. There is no
# individual record create/update/delete endpoint.
#
# Because setHosts replaces every record in the domain, anything we fail to
# read back would be deleted. The read path therefore refuses to continue
# unless every <host> in the response parsed cleanly, values are XML-decoded
# and re-sent URL-encoded in a POST body, and MX preferences and the domain's
# EmailType are carried through unchanged.

# Load provider configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Records read by _namecheap_read_hosts, as parallel arrays
NC_HOST_NAMES=()
NC_HOST_TYPES=()
NC_HOST_ADDRS=()
NC_HOST_TTLS=()
NC_HOST_MXPREFS=()
NC_EMAIL_TYPE=""

# Resolve the client IP Namecheap requires (must be whitelisted in the account)
_namecheap_client_ip() {
  if [[ -n "${NAMECHEAP_CLIENT_IP:-}" ]]; then
    printf '%s\n' "$NAMECHEAP_CLIENT_IP"
    return 0
  fi
  if [[ -z "${_NC_DETECTED_CLIENT_IP:-}" ]]; then
    _NC_DETECTED_CLIENT_IP=$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null || true)
  fi
  if [[ ! "$_NC_DETECTED_CLIENT_IP" =~ ^[0-9a-fA-F.:]+$ ]]; then
    echo "Could not detect this server's public IP; set NAMECHEAP_CLIENT_IP" >&2
    return 1
  fi
  printf '%s\n' "$_NC_DETECTED_CLIENT_IP"
}

# Call the Namecheap API. Extra arguments are "Key=Value" pairs; every value
# is URL-encoded and sent in a POST body (keeps the API key out of URLs and
# handles SPF/DKIM values containing spaces, '+', '=', '&' or '/').
_namecheap_api_call() {
  local command="$1"
  shift

  local client_ip
  client_ip=$(_namecheap_client_ip) || return 1

  local curl_args=(
    -s -X POST
    --data-urlencode "ApiUser=${NAMECHEAP_API_USER}"
    --data-urlencode "ApiKey=${NAMECHEAP_API_KEY}"
    --data-urlencode "UserName=${NAMECHEAP_API_USER}"
    --data-urlencode "ClientIp=${client_ip}"
    --data-urlencode "Command=${command}"
  )
  local param
  for param in "$@"; do
    curl_args+=(--data-urlencode "$param")
  done

  curl "${curl_args[@]}" "$NAMECHEAP_API_BASE"
}

# Decode the XML entities that can appear in attribute values
_xml_unescape() {
  sed -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' \
    -e "s/&apos;/'/g" -e "s/&#39;/'/g" -e 's/&amp;/\&/g'
}

# Extract one attribute from a single XML tag. The leading whitespace in the
# pattern keeps e.g. Name= from matching inside FriendlyName=.
_xml_attr() {
  local tag="$1"
  local attr="$2"
  printf '%s' "$tag" | grep -oP "(?<=\\s${attr}=\")[^\"]*" | head -1 | _xml_unescape || true
}

# Helper to check API response for errors
_check_namecheap_response() {
  local response="$1"
  local context="$2"

  if [[ -z "$response" ]]; then
    echo "Namecheap API returned an empty response in $context" >&2
    return 1
  fi

  if echo "$response" | grep -q 'Status="ERROR"'; then
    local error
    error=$(echo "$response" | grep -oP '(?<=<Error Number="[0-9]{1,10}">)[^<]+|(?<=<Message>)[^<]+' | head -1)
    echo "Namecheap API error in $context: ${error:-Unknown error}" >&2
    return 1
  fi

  return 0
}

# Split a domain into SLD and TLD parts
# e.g., "example.com" -> SLD=example TLD=com
#        "example.co.uk" -> SLD=example TLD=co.uk
_namecheap_split_domain() {
  local domain="$1"

  # Known two-part TLDs
  local two_part_tlds="co.uk co.nz com.au com.br net.au org.uk org.au"

  local sld tpt
  for tpt in $two_part_tlds; do
    if [[ "$domain" == *".$tpt" ]]; then
      sld="${domain%."$tpt"}"
      # Remove any subdomains - get just the SLD
      sld="${sld##*.}"
      echo "$sld" "$tpt"
      return 0
    fi
  done

  # Standard single-part TLD
  local tld="${domain##*.}"
  local without_tld="${domain%.*}"
  sld="${without_tld##*.}"
  echo "$sld" "$tld"
  return 0
}

# Get the subdomain part (host) for a record within its zone
# e.g., domain="app.example.com" zone="example.com" -> "app"
#        domain="example.com" zone="example.com" -> "@"
_namecheap_get_host() {
  local record_name="${1%.}"
  local zone="$2"

  if [[ "$record_name" == "$zone" ]]; then
    echo "@"
  else
    echo "${record_name%."$zone"}"
  fi
}

# Read every DNS record for a domain into the NC_HOST_* arrays.
# Fails (and leaves nothing safe to write) unless every <host> element parsed.
_namecheap_read_hosts() {
  local zone="$1"

  NC_HOST_NAMES=()
  NC_HOST_TYPES=()
  NC_HOST_ADDRS=()
  NC_HOST_TTLS=()
  NC_HOST_MXPREFS=()
  NC_EMAIL_TYPE=""

  local sld tld
  read -r sld tld < <(_namecheap_split_domain "$zone")

  local response
  response=$(_namecheap_api_call "namecheap.domains.dns.getHosts" "SLD=$sld" "TLD=$tld") || return 1
  _check_namecheap_response "$response" "get hosts" || return 1

  local result_tag
  result_tag=$(printf '%s' "$response" | grep -oP '<DomainDNSGetHostsResult\b[^>]*>' | head -1 || true)
  if [[ -z "$result_tag" ]]; then
    echo "Unexpected Namecheap getHosts response for $zone" >&2
    return 1
  fi
  if [[ "$(_xml_attr "$result_tag" IsUsingOurDNS)" != "true" ]]; then
    echo "$zone is not using Namecheap DNS; refusing to manage its records" >&2
    return 1
  fi
  NC_EMAIL_TYPE=$(_xml_attr "$result_tag" EmailType)

  local expected
  expected=$(printf '%s' "$response" | grep -oP '<host\b' | wc -l)

  local tags=() tag
  while IFS= read -r tag; do
    [[ -n "$tag" ]] && tags+=("$tag")
  done < <(printf '%s' "$response" | grep -oP '<host\b(?:\s+[\w:.-]+="[^"]*")*\s*/?>' || true)

  if [[ "${#tags[@]}" -ne "$expected" ]]; then
    echo "Could only parse ${#tags[@]} of $expected Namecheap records for $zone; refusing to modify it" >&2
    return 1
  fi

  local name type address
  for tag in "${tags[@]}"; do
    name=$(_xml_attr "$tag" Name)
    type=$(_xml_attr "$tag" Type)
    address=$(_xml_attr "$tag" Address)
    if [[ -z "$name" || -z "$type" || -z "$address" ]]; then
      echo "Namecheap record missing Name/Type/Address for $zone; refusing to modify it: $tag" >&2
      return 1
    fi
    [[ "$type" == "SOA" ]] && continue
    NC_HOST_NAMES+=("$name")
    NC_HOST_TYPES+=("$type")
    NC_HOST_ADDRS+=("$address")
    NC_HOST_TTLS+=("$(_xml_attr "$tag" TTL)")
    NC_HOST_MXPREFS+=("$(_xml_attr "$tag" MXPref)")
  done

  return 0
}

# Write the NC_HOST_* arrays back as the domain's complete record set
_namecheap_write_hosts() {
  local zone="$1"

  local sld tld
  read -r sld tld < <(_namecheap_split_domain "$zone")

  local params=("SLD=$sld" "TLD=$tld")
  local i n has_mx=false
  for i in "${!NC_HOST_NAMES[@]}"; do
    n=$((i + 1))
    params+=(
      "HostName${n}=${NC_HOST_NAMES[$i]}"
      "RecordType${n}=${NC_HOST_TYPES[$i]}"
      "Address${n}=${NC_HOST_ADDRS[$i]}"
      "TTL${n}=${NC_HOST_TTLS[$i]:-${PROVIDER_DEFAULT_TTL:-300}}"
    )
    if [[ "${NC_HOST_TYPES[$i]}" == "MX" ]]; then
      has_mx=true
      params+=("MXPref${n}=${NC_HOST_MXPREFS[$i]:-10}")
    fi
  done

  # setHosts resets mail settings unless EmailType is sent; MX records only
  # take effect with EmailType=MX
  local email_type="$NC_EMAIL_TYPE"
  if [[ "$has_mx" == "true" && -z "$email_type" ]]; then
    email_type="MX"
  fi
  if [[ -n "$email_type" ]]; then
    params+=("EmailType=${email_type}")
  fi

  local response
  response=$(_namecheap_api_call "namecheap.domains.dns.setHosts" "${params[@]}") || return 1
  _check_namecheap_response "$response" "set hosts" || return 1

  if ! printf '%s' "$response" | grep -qP '<DomainDNSSetHostsResult\b[^>]*\sIsSuccess="true"'; then
    echo "Namecheap did not confirm the record update for $zone" >&2
    return 1
  fi

  return 0
}

# Index of the record matching host and type in the NC_HOST_* arrays, or empty
_namecheap_find_host() {
  local host="${1,,}"
  local record_type="$2"
  local i
  for i in "${!NC_HOST_NAMES[@]}"; do
    if [[ "${NC_HOST_NAMES[$i],,}" == "$host" && "${NC_HOST_TYPES[$i]}" == "$record_type" ]]; then
      printf '%s\n' "$i"
      return 0
    fi
  done
  return 0
}

# REQUIRED: Validate that provider credentials are properly configured
provider_validate_credentials() {
  if [[ -z "${NAMECHEAP_API_USER:-}" ]]; then
    echo "Missing required environment variable: NAMECHEAP_API_USER" >&2
    echo "Set this to your Namecheap username." >&2
    return 1
  fi

  if [[ -z "${NAMECHEAP_API_KEY:-}" ]]; then
    echo "Missing required environment variable: NAMECHEAP_API_KEY" >&2
    echo "Get your API key from: https://ap.www.namecheap.com/settings/tools/apiaccess/" >&2
    return 1
  fi

  # Test API connectivity by listing domains (page size 1)
  local response
  response=$(_namecheap_api_call "namecheap.domains.getList" "PageSize=1") || return 1

  if ! _check_namecheap_response "$response" "credential validation"; then
    echo "Namecheap API authentication failed. Check your NAMECHEAP_API_USER and NAMECHEAP_API_KEY." >&2
    echo "Also ensure your IP is whitelisted at: https://ap.www.namecheap.com/settings/tools/apiaccess/" >&2
    return 1
  fi

  return 0
}

# REQUIRED: List all DNS zones available to the configured account
provider_list_zones() {
  local page=1
  local page_size=100

  while true; do
    local response
    response=$(_namecheap_api_call "namecheap.domains.getList" "PageSize=$page_size" "Page=$page") || return 1
    _check_namecheap_response "$response" "zone listing" || return 1

    local domains=() tag
    while IFS= read -r tag; do
      [[ -n "$tag" ]] && domains+=("$(_xml_attr "$tag" Name)")
    done < <(printf '%s' "$response" | grep -oP '<Domain\b[^>]*>' || true)

    if [[ "${#domains[@]}" -eq 0 ]]; then
      break
    fi

    printf '%s\n' "${domains[@]}"

    # Check if there are more pages
    local total
    total=$(printf '%s' "$response" | grep -oP '(?<=<TotalItems>)[0-9]+' | head -1 || true)
    if [[ -z "$total" || $((page * page_size)) -ge "$total" ]]; then
      break
    fi

    page=$((page + 1))
  done

  return 0
}

# REQUIRED: Get the provider-specific zone identifier
# For Namecheap, the zone ID is the domain name itself (SLD.TLD format)
provider_get_zone_id() {
  local zone_name="${1%.}"

  if [[ -z "$zone_name" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  local zones
  zones=$(provider_list_zones) || return 1

  # Walk up from the full name to find the most specific zone in the account
  local candidate="$zone_name" zone
  while [[ "$candidate" == *.* ]]; do
    while IFS= read -r zone; do
      if [[ "${zone,,}" == "${candidate,,}" ]]; then
        printf '%s\n' "$zone"
        return 0
      fi
    done <<<"$zones"
    candidate="${candidate#*.}"
  done

  echo "Zone not found: $1" >&2
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

  local host index
  host=$(_namecheap_get_host "$record_name" "$zone_id")
  _namecheap_read_hosts "$zone_id" || return 1
  index=$(_namecheap_find_host "$host" "$record_type")

  if [[ -z "$index" ]]; then
    echo "Record not found: $record_name ($record_type)" >&2
    return 1
  fi

  printf '%s\n' "${NC_HOST_ADDRS[$index]}"
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

  local host index action
  host=$(_namecheap_get_host "$record_name" "$zone_id")
  _namecheap_read_hosts "$zone_id" || return 1
  index=$(_namecheap_find_host "$host" "$record_type")

  if [[ -n "$index" ]]; then
    NC_HOST_ADDRS[index]="$record_value"
    NC_HOST_TTLS[index]="$ttl"
    action="Updated"
  else
    NC_HOST_NAMES+=("$host")
    NC_HOST_TYPES+=("$record_type")
    NC_HOST_ADDRS+=("$record_value")
    NC_HOST_TTLS+=("$ttl")
    NC_HOST_MXPREFS+=("")
    action="Created"
  fi

  if ! _namecheap_write_hosts "$zone_id"; then
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

  local host index
  host=$(_namecheap_get_host "$record_name" "$zone_id")
  _namecheap_read_hosts "$zone_id" || return 1
  index=$(_namecheap_find_host "$host" "$record_type")

  if [[ -z "$index" ]]; then
    echo "Record not found for deletion: $record_name ($record_type)" >&2
    return 1
  fi

  unset 'NC_HOST_NAMES[index]' 'NC_HOST_TYPES[index]' 'NC_HOST_ADDRS[index]' \
    'NC_HOST_TTLS[index]' 'NC_HOST_MXPREFS[index]'
  NC_HOST_NAMES=("${NC_HOST_NAMES[@]}")
  NC_HOST_TYPES=("${NC_HOST_TYPES[@]}")
  NC_HOST_ADDRS=("${NC_HOST_ADDRS[@]}")
  NC_HOST_TTLS=("${NC_HOST_TTLS[@]}")
  NC_HOST_MXPREFS=("${NC_HOST_MXPREFS[@]}")

  if ! _namecheap_write_hosts "$zone_id"; then
    echo "Failed to delete record: $record_name ($record_type)" >&2
    return 1
  fi

  echo "Deleted record: $record_name ($record_type)"
  return 0
}

# OPTIONAL: Provider-specific environment setup
provider_setup_env() {
  # Set default API base if not already set
  export NAMECHEAP_API_BASE="${NAMECHEAP_API_BASE:-https://api.namecheap.com/xml.response}"

  return 0
}
