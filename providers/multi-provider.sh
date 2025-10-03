#!/bin/bash
# Multi-Provider Management System - Simple Version
# Auto-discovery based approach using files instead of associative arrays

# Load the provider loader
PROVIDERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROVIDERS_DIR/loader.sh"

# Get plugin data root
PLUGIN_DATA_ROOT="${DNS_ROOT:-${DOKKU_LIB_ROOT:-/var/lib/dokku}/services/dns}"

# Directory to store provider/zone mappings (persistent across invocations)
MULTI_PROVIDER_DATA="$PLUGIN_DATA_ROOT/.multi-provider"

# Initialize data directory
init_multi_data() {
  mkdir -p "$MULTI_PROVIDER_DATA/providers"
  mkdir -p "$MULTI_PROVIDER_DATA/zones"
}

# Clean up data directory (not currently used - data is persistent)
cleanup_multi_data() {
  rm -rf "$MULTI_PROVIDER_DATA"
}

# Load all available providers and discover their zones
discover_all_providers() {
  init_multi_data

  echo "Discovering zones from all providers..." >&2

  local available_providers=()
  while IFS= read -r provider; do
    available_providers+=("$provider")
  done < <(get_available_providers)

  local working_providers=0

  for provider in "${available_providers[@]}"; do
    echo "  Checking provider: $provider" >&2

    # Try to load the provider
    if load_provider "$provider" 2>/dev/null; then
      # Test if credentials are valid
      if provider_validate_credentials 2>/dev/null; then
        echo "    ✓ $provider credentials valid" >&2

        # Get zones from this provider
        local zones
        if zones=$(provider_list_zones 2>/dev/null); then
          local zone_count
          zone_count=$(echo "$zones" | wc -l)
          echo "    ✓ $provider manages $zone_count zone(s)" >&2

          # Store zones for this provider
          echo "$zones" >"$MULTI_PROVIDER_DATA/providers/$provider"

          # Create reverse mapping: zone -> provider
          echo "$zones" | while IFS= read -r zone; do
            [[ -n "$zone" ]] && echo "$provider" >"$MULTI_PROVIDER_DATA/zones/$zone"
          done

          working_providers=$((working_providers + 1))
        else
          echo "    ✗ $provider: failed to list zones" >&2
        fi
      else
        echo "    ✗ $provider: invalid credentials" >&2
      fi
    else
      echo "    ✗ $provider: failed to load" >&2
    fi
  done

  echo "Zone discovery complete: $working_providers working provider(s)" >&2
  if [[ $working_providers -gt 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Find which provider manages a specific zone
find_provider_for_zone() {
  local target_zone="$1"

  if [[ -z "$target_zone" ]]; then
    echo "Zone name is required" >&2
    return 1
  fi

  # Check for exact match first
  if [[ -f "$MULTI_PROVIDER_DATA/zones/$target_zone" ]]; then
    cat "$MULTI_PROVIDER_DATA/zones/$target_zone"
    return 0
  fi

  # Check for parent zone match
  local current_domain="$target_zone"
  while [[ "$current_domain" == *.* ]]; do
    current_domain="${current_domain#*.}"
    if [[ -f "$MULTI_PROVIDER_DATA/zones/$current_domain" ]]; then
      cat "$MULTI_PROVIDER_DATA/zones/$current_domain"
      return 0
    fi
  done

  # No provider found
  return 1
}

# Multi-provider wrapper for zone operations
multi_get_zone_id() {
  local zone_name="$1"

  # Find the provider for this zone
  local provider
  if ! provider=$(find_provider_for_zone "$zone_name"); then
    echo "No provider found for zone: $zone_name" >&2
    return 1
  fi

  # Load the provider to ensure its functions are active
  if ! load_provider "$provider" 2>/dev/null; then
    echo "Failed to load provider: $provider" >&2
    return 1
  fi

  # Get zone ID from the provider
  provider_get_zone_id "$zone_name"
}

# Multi-provider wrapper for record operations
multi_get_record() {
  local zone_id="$1"
  local record_name="$2"
  local record_type="$3"

  # Determine zone from record name (remove first subdomain)
  local zone_name
  if [[ "$record_name" == *.* ]]; then
    zone_name="${record_name#*.}"
  else
    zone_name="$record_name"
  fi

  # Find provider for this zone
  local provider
  if ! provider=$(find_provider_for_zone "$zone_name"); then
    echo "No provider found for zone: $zone_name" >&2
    return 1
  fi

  # Load provider to ensure its functions are active
  if ! load_provider "$provider" 2>/dev/null; then
    echo "Failed to load provider: $provider" >&2
    return 1
  fi

  provider_get_record "$zone_id" "$record_name" "$record_type"
}

# Multi-provider wrapper for record creation
multi_create_record() {
  local zone_id="$1"
  local record_name="$2"
  local record_type="$3"
  local record_value="$4"
  local ttl="$5"

  # Determine zone from record name
  local zone_name
  if [[ "$record_name" == *.* ]]; then
    zone_name="${record_name#*.}"
  else
    zone_name="$record_name"
  fi

  # Find provider for this zone
  local provider
  if ! provider=$(find_provider_for_zone "$zone_name"); then
    echo "No provider found for zone: $zone_name" >&2
    return 1
  fi

  # Load provider to ensure its functions are active
  if ! load_provider "$provider" 2>/dev/null; then
    echo "Failed to load provider: $provider" >&2
    return 1
  fi

  provider_create_record "$zone_id" "$record_name" "$record_type" "$record_value" "$ttl"
}

# Multi-provider wrapper for record deletion
multi_delete_record() {
  local zone_id="$1"
  local record_name="$2"
  local record_type="$3"

  # Determine zone from record name
  local zone_name
  if [[ "$record_name" == *.* ]]; then
    zone_name="${record_name#*.}"
  else
    zone_name="$record_name"
  fi

  # Find provider for this zone
  local provider
  if ! provider=$(find_provider_for_zone "$zone_name"); then
    echo "No provider found for zone: $zone_name" >&2
    return 1
  fi

  # Load provider to ensure its functions are active
  if ! load_provider "$provider" 2>/dev/null; then
    echo "Failed to load provider: $provider" >&2
    return 1
  fi

  provider_delete_record "$zone_id" "$record_name" "$record_type"
}

# Show discovered provider/zone mappings
show_discovered_zones() {
  echo "Discovered Provider → Zone Mappings:"
  echo "===================================="

  if [[ ! -d "$MULTI_PROVIDER_DATA/providers" ]]; then
    echo "No providers discovered"
    return 1
  fi

  local found_providers=false
  for provider_file in "$MULTI_PROVIDER_DATA/providers"/*; do
    if [[ -f "$provider_file" ]]; then
      found_providers=true
      local provider
      provider=$(basename "$provider_file")
      echo
      echo "Provider: $provider"

      local zones
      zones=$(cat "$provider_file")
      if [[ -n "$zones" ]]; then
        while IFS= read -r zone; do
          echo "  $zone"
        done <<<"$zones"
      else
        echo "  (no zones)"
      fi
    fi
  done

  if [[ "$found_providers" != "true" ]]; then
    echo "No providers with zones discovered"
    return 1
  fi
}

# Initialize multi-provider system
init_multi_provider_system() {
  echo "Initializing multi-provider DNS system..." >&2

  if ! discover_all_providers; then
    echo "No providers with valid credentials found" >&2
    return 1
  fi

  local provider_count
  provider_count=$(find "$MULTI_PROVIDER_DATA/providers" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)

  if [[ $provider_count -eq 0 ]]; then
    echo "No working providers found" >&2
    return 1
  fi

  echo "Multi-provider system ready: $provider_count provider(s) active" >&2
  return 0
}
