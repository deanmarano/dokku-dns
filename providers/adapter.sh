#!/bin/bash
# Generic Provider Adapter
# This layer converts minimal provider functions into plugin-specific functionality

# Load the provider loader system
PROVIDERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROVIDERS_DIR/loader.sh"

# Load DNS plugin functions for TTL support
PLUGIN_DIR="$(dirname "$PROVIDERS_DIR")"
if [[ -f "$PLUGIN_DIR/functions" ]]; then
  source "$PLUGIN_DIR/functions"
fi

# Plugin configuration
PLUGIN_DATA_ROOT="${DNS_ROOT:-${DOKKU_LIB_ROOT:-/var/lib/dokku}/services/dns}"

# Initialize provider system
# shellcheck disable=SC2120
init_provider_system() {
  local provider_name="$1"

  if [[ -n "$provider_name" ]]; then
    # Load specific provider (single-provider mode)
    if ! load_specific_provider "$provider_name"; then
      echo "Failed to load provider: $provider_name" >&2
      return 1
    fi
  else
    # Check if multi-provider mode should be enabled
    local PROVIDERS_DIR
    PROVIDERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local available_providers
    available_providers=$(get_available_providers | wc -l)

    if [[ $available_providers -gt 1 ]]; then
      # Multi-provider mode: auto-discover zones from all providers
      source "$PROVIDERS_DIR/multi-provider.sh"
      if init_multi_provider_system; then
        export MULTI_PROVIDER_MODE=true
        echo "Multi-provider mode activated" >&2
      else
        echo "Multi-provider discovery failed, falling back to single provider" >&2
        if ! auto_load_provider; then
          echo "No working DNS provider found" >&2
          return 1
        fi
        export MULTI_PROVIDER_MODE=false
      fi
    else
      # Single-provider mode: auto-detect best provider
      if ! auto_load_provider; then
        echo "No working DNS provider found" >&2
        return 1
      fi
      export MULTI_PROVIDER_MODE=false
    fi
  fi

  return 0
}

# Get server IP (plugin-specific logic)
get_server_ip() {
  # Try various methods to detect server IP
  local server_ip

  # Method 1: In test/mock mode, use a test IP (192.0.2.0/24 is TEST-NET-1)
  if [[ -n "${MOCK_API_KEY:-}" ]]; then
    echo "DEBUG: MOCK_API_KEY is set, returning test IP 192.0.2.1" >&2
    echo "192.0.2.1"
    return 0
  fi

  echo "DEBUG: MOCK_API_KEY not set (value: '${MOCK_API_KEY:-}'), trying other methods" >&2

  # Method 2: Check if IP is set in environment
  if [[ -n "${DOKKU_DNS_SERVER_IP:-}" ]]; then
    echo "$DOKKU_DNS_SERVER_IP"
    return 0
  fi

  # Method 3: Try to get public IP from metadata service (AWS/GCP/etc)
  if server_ip=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null) && [[ -n "$server_ip" ]]; then
    echo "$server_ip"
    return 0
  fi

  # Method 4: Try external IP detection services
  local ip_services=(
    "http://ipv4.icanhazip.com"
    "http://checkip.amazonaws.com"
    "https://ipecho.net/plain"
  )

  for service in "${ip_services[@]}"; do
    if server_ip=$(curl -s --max-time 5 "$service" 2>/dev/null | tr -d '[:space:]') && [[ -n "$server_ip" ]]; then
      echo "$server_ip"
      return 0
    fi
  done

  # Method 5: Get IP from default route interface
  if server_ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}') && [[ -n "$server_ip" ]]; then
    echo "$server_ip"
    return 0
  fi

  echo "Unknown"
  return 1
}

# Sync DNS records for an app (high-level plugin operation)
dns_sync_app() {
  local app_name="$1"
  local domains_file="$PLUGIN_DATA_ROOT/$app_name/DOMAINS"

  if [[ ! -f "$domains_file" ]]; then
    echo "No DNS-managed domains found for app: $app_name"
    return 0
  fi

  # Get server IP
  local server_ip
  server_ip=$(get_server_ip)
  if [[ -z "$server_ip" ]] || [[ "$server_ip" == "Unknown" ]]; then
    echo "Error: Unable to determine server IP address" >&2
    return 1
  fi

  echo "Syncing domains for app '$app_name' to server IP: $server_ip"
  echo

  # Phase 1: Analyze current state
  echo "Analyzing current DNS records..."
  local -a planned_changes=()
  local -a domains_to_sync=()
  local changes_needed=false
  local domain

  while IFS= read -r domain || [[ -n "$domain" ]]; do
    [[ -z "$domain" ]] && continue

    printf "  Checking %s... " "$domain"

    # Get zone ID for this domain
    local zone_id
    if [[ "${MULTI_PROVIDER_MODE:-false}" == "true" ]]; then
      if ! zone_id=$(multi_get_zone_id "$domain"); then
        echo "❌ No hosted zone found"
        continue
      fi

      # Check current record
      current_ip=$(multi_get_record "$zone_id" "$domain" "A" 2>/dev/null || echo "")
    else
      if ! zone_id=$(provider_get_zone_id "$domain"); then
        echo "❌ No hosted zone found"
        continue
      fi

      # Check current record
      current_ip=$(provider_get_record "$zone_id" "$domain" "A" 2>/dev/null || echo "")
    fi

    if [[ -z "$current_ip" ]]; then
      echo "➕ Will create A record"
      planned_changes+=("+ $domain → $server_ip (A record)")
      domains_to_sync+=("$domain")
      changes_needed=true
    elif [[ "$current_ip" != "$server_ip" ]]; then
      echo "🔄 Will update A record"
      planned_changes+=("~ $domain → $server_ip [was: $current_ip] (A record)")
      domains_to_sync+=("$domain")
      changes_needed=true
    else
      echo "✅ Already correct"
    fi
  done <"$domains_file"

  echo

  # Show planned changes
  if [[ "$changes_needed" == "true" ]]; then
    echo "Planned Changes:"
    for change in "${planned_changes[@]}"; do
      echo "  $change"
    done
    echo
    echo "Plan: 0 to add, 0 to change, ${#planned_changes[@]} to apply"
    echo

    # Phase 2: Apply changes
    echo "Applying changes..."
    local domains_synced=0
    local domains_failed=0

    for domain in "${domains_to_sync[@]}"; do
      printf "  %s... " "$domain"

      # Get zone ID again for this domain
      local zone_id
      if [[ "${MULTI_PROVIDER_MODE:-false}" == "true" ]]; then
        zone_id=$(multi_get_zone_id "$domain" 2>/dev/null)

        # Apply the change using domain-specific TTL
        local ttl
        if declare -f get_domain_ttl >/dev/null 2>&1; then
          ttl=$(get_domain_ttl "$app_name" "$domain")
        else
          ttl="300"
        fi
        if multi_create_record "$zone_id" "$domain" "A" "$server_ip" "$ttl" >/dev/null 2>&1; then
          echo "✅ Applied"
          domains_synced=$((domains_synced + 1))
        else
          echo "❌ Failed"
          domains_failed=$((domains_failed + 1))
        fi
      else
        zone_id=$(provider_get_zone_id "$domain" 2>/dev/null)

        # Apply the change using domain-specific TTL
        local ttl
        if declare -f get_domain_ttl >/dev/null 2>&1; then
          ttl=$(get_domain_ttl "$app_name" "$domain")
        else
          ttl="300"
        fi
        if provider_create_record "$zone_id" "$domain" "A" "$server_ip" "$ttl" >/dev/null 2>&1; then
          echo "✅ Applied"
          domains_synced=$((domains_synced + 1))
        else
          echo "❌ Failed"
          domains_failed=$((domains_failed + 1))
        fi
      fi
    done

    echo
    echo "Apply complete! Successfully applied $domains_synced of ${#domains_to_sync[@]} planned changes."

    if [[ $domains_failed -gt 0 ]]; then
      return 1
    else
      return 0
    fi
  else
    echo "No changes needed! All DNS records are already correct."
    return 0
  fi
}

# Get DNS status for a domain (high-level plugin operation)
dns_get_domain_status() {
  local domain="$1"
  local server_ip="$2"

  # Get current DNS record IP from provider
  local zone_id current_ip

  # Use multi-provider functions if in multi-provider mode
  if [[ "${MULTI_PROVIDER_MODE:-false}" == "true" ]]; then
    if ! zone_id=$(multi_get_zone_id "$domain" 2>/dev/null); then
      echo "❌" # No zone
      return 1
    fi

    if ! current_ip=$(multi_get_record "$zone_id" "$domain" "A" 2>/dev/null); then
      echo "❌" # No record
      return 1
    fi
  else
    # Single provider mode
    if ! zone_id=$(provider_get_zone_id "$domain" 2>/dev/null); then
      echo "❌" # No zone
      return 1
    fi

    if ! current_ip=$(provider_get_record "$zone_id" "$domain" "A" 2>/dev/null); then
      echo "❌" # No record
      return 1
    fi
  fi

  if [[ "$current_ip" == "$server_ip" ]]; then
    echo "✅" # Correct IP
    return 0
  else
    echo "⚠️" # Wrong IP
    return 1
  fi
}

# Add domains to DNS management (high-level plugin operation)
dns_add_domains() {
  local app_name="$1"
  shift
  local domains=("$@")

  if [[ ${#domains[@]} -eq 0 ]]; then
    echo "No domains specified" >&2
    return 1
  fi

  # Validate each domain has a hosted zone
  local valid_domains=()
  for domain in "${domains[@]}"; do
    echo "Validating domain: $domain"

    if provider_get_zone_id "$domain" >/dev/null 2>&1; then
      echo "  ✓ Hosted zone found for $domain"
      valid_domains+=("$domain")
    else
      echo "  ✗ No hosted zone found for $domain"
    fi
  done

  if [[ ${#valid_domains[@]} -eq 0 ]]; then
    echo "No domains have hosted zones" >&2
    return 1
  fi

  # Create app DNS directory
  local app_dir="$PLUGIN_DATA_ROOT/$app_name"
  mkdir -p "$app_dir"

  # Save domains to file
  local domains_file="$app_dir/DOMAINS"
  printf '%s\n' "${valid_domains[@]}" >"$domains_file"

  echo "Added ${#valid_domains[@]} domain(s) to DNS management for app: $app_name"
  return 0
}

# Remove app from DNS management
dns_remove_app() {
  local app_name="$1"
  local app_dir="$PLUGIN_DATA_ROOT/$app_name"

  if [[ -d "$app_dir" ]]; then
    rm -rf "$app_dir"
    echo "Removed app '$app_name' from DNS management"
  else
    echo "App '$app_name' not found in DNS management"
  fi

  return 0
}

# List all apps under DNS management
dns_list_apps() {
  if [[ ! -d "$PLUGIN_DATA_ROOT" ]]; then
    return 0
  fi

  local app_dir
  for app_dir in "$PLUGIN_DATA_ROOT"/*; do
    if [[ -d "$app_dir" && -f "$app_dir/DOMAINS" ]]; then
      basename "$app_dir"
    fi
  done
}

# Get domains for an app
dns_get_app_domains() {
  local app_name="$1"
  local domains_file="$PLUGIN_DATA_ROOT/$app_name/DOMAINS"

  if [[ -f "$domains_file" ]]; then
    cat "$domains_file"
  fi
}

# Validate provider and show status
dns_validate_provider() {
  if ! validate_current_provider; then
    return 1
  fi

  local current_provider
  current_provider=$(get_current_provider)

  echo "Current provider: $current_provider"
  echo "Provider status: ✅ Valid"

  # Show available zones
  echo "Available zones:"
  if ! provider_list_zones | sed 's/^/  /'; then
    echo "  (Failed to list zones)"
    return 1
  fi

  return 0
}

# Cleanup DNS records that no longer correspond to active apps
dns_cleanup_orphaned_records() {
  local zone_name="$1"

  if [[ -z "$zone_name" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  # Get zone ID
  local zone_id
  if ! zone_id=$(provider_get_zone_id "$zone_name"); then
    echo "Zone not found: $zone_name" >&2
    return 1
  fi

  echo "Scanning zone '$zone_name' for orphaned records..."

  # This would need provider-specific logic to list all records
  # and compare against current app domains
  # For now, just show a message
  echo "Orphaned record cleanup not yet implemented"
  return 0
}

# Validate that a domain can be managed by any provider
dns_validate_domain() {
  local domain="$1"

  if [[ -z "$domain" ]]; then
    echo "Domain is required" >&2
    return 1
  fi

  # Check if any provider can handle this domain
  if [[ "$MULTI_PROVIDER_MODE" == "true" ]]; then
    # Multi-provider mode: check which provider can handle this zone
    source "$PROVIDERS_DIR/multi-provider.sh"
    find_provider_for_zone "$domain" >/dev/null 2>&1
  else
    # Single provider mode: check if the current provider can handle it
    provider_get_zone_id "$domain" >/dev/null 2>&1
  fi
}

# Create or update a DNS record
dns_create_record() {
  local domain="$1"
  local record_type="$2"
  local record_value="$3"
  local ttl="$4"

  # If no TTL specified, use global TTL configuration
  if [[ -z "$ttl" ]]; then
    if declare -f get_global_ttl >/dev/null 2>&1; then
      ttl=$(get_global_ttl)
    else
      ttl="300" # Fallback default
    fi
  fi

  if [[ -z "$domain" ]] || [[ -z "$record_type" ]] || [[ -z "$record_value" ]]; then
    echo "Domain, record type, and record value are required" >&2
    return 1
  fi

  # Get zone ID for the domain
  local zone_id
  if [[ "$MULTI_PROVIDER_MODE" == "true" ]]; then
    # Multi-provider mode: find the right provider and get zone ID
    source "$PROVIDERS_DIR/multi-provider.sh"
    zone_id=$(multi_get_zone_id "$domain")
  else
    # Single provider mode
    zone_id=$(provider_get_zone_id "$domain")
  fi

  if [[ -z "$zone_id" ]]; then
    echo "No zone found for domain: $domain" >&2
    return 1
  fi

  # Create the record using the appropriate provider
  if [[ "$MULTI_PROVIDER_MODE" == "true" ]]; then
    multi_create_record "$zone_id" "$domain" "$record_type" "$record_value" "$ttl"
  else
    provider_create_record "$zone_id" "$domain" "$record_type" "$record_value" "$ttl"
  fi
}

# Get current value of a DNS record
dns_get_record() {
  local domain="$1"
  local record_type="$2"

  if [[ -z "$domain" ]] || [[ -z "$record_type" ]]; then
    echo "Domain and record type are required" >&2
    return 1
  fi

  # Get zone ID for the domain
  local zone_id
  if [[ "$MULTI_PROVIDER_MODE" == "true" ]]; then
    # Multi-provider mode: find the right provider and get zone ID
    source "$PROVIDERS_DIR/multi-provider.sh"
    zone_id=$(multi_get_zone_id "$domain")
  else
    # Single provider mode
    zone_id=$(provider_get_zone_id "$domain")
  fi

  if [[ -z "$zone_id" ]]; then
    echo "No zone found for domain: $domain" >&2
    return 1
  fi

  # Get the record using the appropriate provider
  if [[ "$MULTI_PROVIDER_MODE" == "true" ]]; then
    multi_get_record "$zone_id" "$domain" "$record_type"
  else
    provider_get_record "$zone_id" "$domain" "$record_type"
  fi
}

# Delete a DNS record
dns_delete_record() {
  local domain="$1"
  local record_type="$2"

  if [[ -z "$domain" ]] || [[ -z "$record_type" ]]; then
    echo "Domain and record type are required" >&2
    return 1
  fi

  # Get zone ID for the domain
  local zone_id
  if [[ "$MULTI_PROVIDER_MODE" == "true" ]]; then
    # Multi-provider mode: find the right provider and get zone ID
    source "$PROVIDERS_DIR/multi-provider.sh"
    zone_id=$(multi_get_zone_id "$domain")
  else
    # Single provider mode
    zone_id=$(provider_get_zone_id "$domain")
  fi

  if [[ -z "$zone_id" ]]; then
    echo "No zone found for domain: $domain" >&2
    return 1
  fi

  # Delete the record using the appropriate provider
  if [[ "$MULTI_PROVIDER_MODE" == "true" ]]; then
    multi_delete_record "$zone_id" "$domain" "$record_type"
  else
    provider_delete_record "$zone_id" "$domain" "$record_type"
  fi
}
