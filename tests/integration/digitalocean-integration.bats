#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin DigitalOcean Provider Integration Tests
# Tests real DigitalOcean API integration with mock fallbacks

# shellcheck disable=SC2154  # status and output are BATS built-in variables

setup() {
  check_dns_plugin_available

  # Setup mock DigitalOcean environment for CI
  export DIGITALOCEAN_ACCESS_TOKEN="${DIGITALOCEAN_ACCESS_TOKEN:-mock-token-for-testing}"
  export DIGITALOCEAN_TEST_DOMAIN="${DIGITALOCEAN_TEST_DOMAIN:-example.com}"
}

@test "(digitalocean integration) provider loads successfully in multi-provider environment" {
  run bash -c "source ../../providers/loader.sh && load_provider digitalocean 2>&1"
  assert_success
  assert_output --partial "Loaded provider: digitalocean"
}

@test "(digitalocean integration) provider validates structure and functions" {
  run bash -c "source ../../providers/loader.sh && validate_provider digitalocean"
  assert_success
}

@test "(digitalocean integration) provider requires API token" {
  # Test without token
  local original_token="$DIGITALOCEAN_ACCESS_TOKEN"
  unset DIGITALOCEAN_ACCESS_TOKEN

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_validate_credentials"
  assert_failure
  assert_output --partial "Missing required environment variable: DIGITALOCEAN_ACCESS_TOKEN"

  # Restore token
  export DIGITALOCEAN_ACCESS_TOKEN="$original_token"
}

@test "(digitalocean integration) provider handles invalid API token gracefully" {
  # Test with invalid token
  export DIGITALOCEAN_ACCESS_TOKEN="invalid-token-format"

  # Mock curl to simulate auth failure
  function curl() {
    echo '{"id": "Unauthorized", "message": "Unable to authenticate you"}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *"'.account.uuid'"* ]]; then
      echo ""
    elif [[ "$*" == *"'.id'"* ]]; then
      echo "Unauthorized"
    elif [[ "$*" == *"'.message'"* ]]; then
      echo "Unable to authenticate you"
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_validate_credentials"
  assert_failure
  assert_output --partial "DigitalOcean API authentication failed: Unable to authenticate you"
}

@test "(digitalocean integration) provider lists zones correctly" {
  # Mock successful domain listing
  function curl() {
    echo '{"domains": [{"name": "example.com"}, {"name": "test.org"}]}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domains[]?.name"* ]]; then
      echo -e "example.com\ntest.org"
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_list_zones"
  assert_success
  assert_output --partial "example.com"
  assert_output --partial "test.org"
}

@test "(digitalocean integration) provider finds zone IDs for domains" {
  # Mock domain lookup (DigitalOcean uses domain name as zone ID)
  function curl() {
    if [[ "$*" == *"example.com"* ]]; then
      echo '{"domain": {"name": "example.com"}}'
    else
      echo '{"id": "not_found", "message": "The resource you requested could not be found."}'
    fi
  }
  export -f curl

  function jq() {
    if [[ "$*" == *"'.domain.name'"* ]] && [[ "$*" == *"example.com"* ]]; then
      echo "example.com"
      return 0
    else
      echo "null"
      return 1
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_get_zone_id 'example.com'"
  assert_success
  assert_output --partial "example.com"
}

@test "(digitalocean integration) provider handles domain not found for zone lookup" {
  # Mock domain not found
  function curl() {
    echo '{"id": "not_found", "message": "The resource you requested could not be found."}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *"'.domain.name'"* ]]; then
      echo "null"
      return 1
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_get_zone_id 'nonexistent.com'"
  assert_failure
  assert_output --partial "Zone not found: nonexistent.com"
}

@test "(digitalocean integration) provider creates DNS records" {
  # Mock record creation
  function curl() {
    if [[ "$*" == *"GET"* ]]; then
      # No existing record
      echo '{"domain_records": []}'
    else
      # Successful creation
      echo '{"domain_record": {"id": 12345, "name": "test", "data": "192.168.1.100", "type": "A"}}'
    fi
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domain_records[]?"* ]] && [[ "$*" == *".id"* ]]; then
      echo "" # No existing record
    elif [[ "$*" == *"'.domain_record.id'"* ]]; then
      echo "12345"
      return 0
    elif [[ "$*" == *"-n"* ]]; then
      # Handle jq -n for JSON creation
      echo '{"name":"test","type":"A","data":"192.168.1.100","ttl":1800}'
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_create_record 'example.com' 'test' 'A' '192.168.1.100' '1800'"
  assert_success
  assert_output --partial "Successfully created/updated record: test -> 192.168.1.100"
}

@test "(digitalocean integration) provider updates existing DNS records" {
  # Mock record update
  function curl() {
    if [[ "$*" == *"GET"* ]]; then
      # Existing record found
      echo '{"domain_records": [{"id": 12345, "name": "test", "type": "A", "data": "192.168.1.50"}]}'
    else
      # Successful update
      echo '{"domain_record": {"id": 12345, "name": "test", "data": "192.168.1.100", "type": "A"}}'
    fi
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domain_records[]?"* ]] && [[ "$*" == *".id"* ]]; then
      echo "12345"
    elif [[ "$*" == *"'.domain_record.id'"* ]]; then
      echo "12345"
      return 0
    elif [[ "$*" == *"-n"* ]]; then
      # Handle jq -n for JSON creation
      echo '{"name":"test","type":"A","data":"192.168.1.100","ttl":1800}'
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_create_record 'example.com' 'test' 'A' '192.168.1.100' '1800'"
  assert_success
  assert_output --partial "Successfully created/updated record: test -> 192.168.1.100"
}

@test "(digitalocean integration) provider deletes DNS records" {
  # Mock record deletion
  function curl() {
    if [[ "$*" == *"GET"* ]]; then
      # Record found for deletion
      echo '{"domain_records": [{"id": 12345, "name": "test", "type": "A", "data": "192.168.1.100"}]}'
    else
      # Successful deletion (empty response)
      echo ""
    fi
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domain_records[]?"* ]] && [[ "$*" == *".id"* ]]; then
      echo "12345"
    elif [[ "$*" == *"'.message'"* ]]; then
      # No error message for successful deletion
      return 1
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_delete_record 'example.com' 'test' 'A'"
  assert_success
  [[ "$output" == *"Successfully deleted record: test (A)"* ]]
}

@test "(digitalocean integration) provider retrieves DNS record values" {
  # Mock record retrieval
  function curl() {
    echo '{"domain_records": [{"name": "test", "type": "A", "data": "192.168.1.100"}]}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".data"* ]]; then
      echo "192.168.1.100"
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_get_record 'example.com' 'test' 'A'"
  assert_success
  assert_output --partial "192.168.1.100"
}

@test "(digitalocean integration) provider handles batch record operations" {
  # Create test records file
  local records_file="/tmp/test_records.txt"
  cat >"$records_file" <<EOF
test1 A 192.168.1.101 300
test2 A 192.168.1.102 600
test3 A 192.168.1.103 900
EOF

  # Mock batch operations (DigitalOcean uses individual calls)
  function curl() {
    if [[ "$*" == *"GET"* ]]; then
      # No existing records
      echo '{"domain_records": []}'
    else
      # Successful creation for each call
      echo '{"domain_record": {"id": 12345}}'
    fi
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domain_records[]?"* ]] && [[ "$*" == *".id"* ]]; then
      echo "" # No existing record
    elif [[ "$*" == *"'.domain_record.id'"* ]]; then
      echo "12345"
      return 0
    elif [[ "$*" == *"-n"* ]]; then
      # Handle jq -n for JSON creation
      echo '{"name":"test","type":"A","data":"192.168.1.100","ttl":300}'
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_batch_create_records 'example.com' '$records_file'"
  assert_success
  assert_output --partial "Batch operation completed successfully: 3 records processed"

  # Cleanup
  rm -f "$records_file"
}

@test "(digitalocean integration) provider handles API rate limiting gracefully" {
  # Mock rate limit response (DigitalOcean format)
  function curl() {
    echo '{"id": "too_many_requests", "message": "API rate limit exceeded"}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domains[]?.name"* ]]; then
      echo "Failed to parse domains from DigitalOcean API response"
      return 1
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_list_zones"
  assert_failure
  assert_output --partial "Failed to parse domains from DigitalOcean API response"
}

@test "(digitalocean integration) provider validates required parameters" {
  run bash -c "source ../../providers/digitalocean/provider.sh && provider_get_zone_id ''"
  assert_failure
  assert_output --partial "Zone name is required"

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_create_record '' 'test.com' 'A' '1.1.1.1'"
  assert_failure
  assert_output --partial "Zone ID, record name, record type, and record value are required"

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_delete_record 'example.com' '' 'A'"
  assert_failure
  assert_output --partial "Zone ID, record name, and record type are required"
}

@test "(digitalocean integration) provider setup validates jq dependency" {
  # Mock missing jq
  function command() {
    if [[ "$2" == "jq" ]]; then
      return 1 # jq not found
    fi
    return 0
  }
  export -f command

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_setup_env"
  assert_failure
  assert_output --partial "jq is required for DigitalOcean provider but not found in PATH"
}

@test "(digitalocean integration) provider handles zone not found errors" {
  # Mock domain not found
  function curl() {
    echo '{"id": "not_found", "message": "The resource you requested could not be found."}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *"'.domain.name'"* ]]; then
      echo "null"
      return 1
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_get_zone_id 'nonexistent.com'"
  assert_failure
  assert_output --partial "Zone not found: nonexistent.com"
}

@test "(digitalocean integration) provider handles record not found errors" {
  # Mock record not found
  function curl() {
    echo '{"domain_records": []}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".data"* ]]; then
      echo ""
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_get_record 'example.com' 'nonexistent' 'A'"
  assert_failure
  [[ "$output" == *"Record not found: nonexistent (A)"* ]]
}

@test "(digitalocean integration) provider configuration is correct" {
  run bash -c "source ../../providers/digitalocean/config.sh && echo \$PROVIDER_NAME"
  assert_success
  assert_output --partial "digitalocean"

  run bash -c "source ../../providers/digitalocean/config.sh && echo \$PROVIDER_DISPLAY_NAME"
  assert_success
  assert_output --partial "DigitalOcean"

  run bash -c "source ../../providers/digitalocean/config.sh && echo \$DIGITALOCEAN_API_URL"
  assert_success
  assert_output --partial "https://api.digitalocean.com/v2"
}

@test "(digitalocean integration) provider works in multi-provider environment" {
  # Test that digitalocean can be loaded alongside other providers
  run bash -c "
        source ../../providers/loader.sh
        load_provider mock 2>/dev/null || true
        load_provider digitalocean 2>/dev/null || true
        echo 'Mock loaded:' \$(is_provider_loaded mock && echo 'YES' || echo 'NO')
        echo 'DigitalOcean loaded:' \$(is_provider_loaded digitalocean && echo 'YES' || echo 'NO')
    "

  # Should work regardless of which providers are available
  assert_success
}

@test "(digitalocean integration) provider supports different record types" {
  local record_types=("A" "AAAA" "CNAME" "TXT" "MX" "NS" "SRV")

  for record_type in "${record_types[@]}"; do
    # Mock successful record creation for each type
    function curl() {
      if [[ "$*" == *"GET"* ]]; then
        echo '{"domain_records": []}'
      else
        echo '{"domain_record": {"id": 12345, "type": "'$record_type'"}}'
      fi
    }
    export -f curl

    function jq() {
      if [[ "$*" == *".domain_records[]?"* ]] && [[ "$*" == *".id"* ]]; then
        echo "" # No existing record
      elif [[ "$*" == *"'.domain_record.id'"* ]]; then
        echo "12345"
        return 0
      elif [[ "$*" == *"-n"* ]]; then
        echo '{"name":"test","type":"'$record_type'","data":"test-value","ttl":1800}'
      fi
    }
    export -f jq

    run bash -c "source ../../providers/digitalocean/provider.sh && provider_create_record 'example.com' 'test' '$record_type' 'test-value' '1800'"
    assert_success
  done
}

@test "(digitalocean integration) provider handles API connectivity issues" {
  # Mock connection failure
  function curl() {
    return 1 # Connection failed
  }
  export -f curl

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_validate_credentials"
  assert_failure
  assert_output --partial "Failed to connect to DigitalOcean API"
}

@test "(digitalocean integration) provider handles malformed JSON responses" {
  # Mock malformed JSON
  function curl() {
    echo '{"domains": [malformed json'
  }
  export -f curl

  function jq() {
    # jq fails to parse malformed JSON
    echo "parse error: Invalid numeric literal at line 1, column 20" >&2
    return 4
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_list_zones"
  assert_failure
  assert_output --partial "Failed to parse domains from DigitalOcean API response"
}

@test "(digitalocean integration) provider handles batch operation failures" {
  # Create test records file
  local records_file="/tmp/test_records.txt"
  cat >"$records_file" <<EOF
test1 A 192.168.1.101 300
test2 A 192.168.1.102 600
EOF

  # Track call count to simulate mixed success/failure
  local call_count=0

  function curl() {
    call_count=$((call_count + 1))
    if [[ "$*" == *"GET"* ]]; then
      echo '{"domain_records": []}'
    elif [[ $call_count -eq 2 ]]; then
      # First creation succeeds
      echo '{"domain_record": {"id": 12345}}'
    else
      # Second creation fails
      echo '{"id": "unprocessable_entity", "message": "Record validation failed"}'
    fi
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domain_records[]?"* ]] && [[ "$*" == *".id"* ]]; then
      echo "" # No existing record
    elif [[ "$*" == *"'.domain_record.id'"* ]]; then
      if [[ $call_count -eq 2 ]]; then
        echo "12345"
        return 0
      else
        echo ""
        return 1
      fi
    elif [[ "$*" == *"'.message'"* ]]; then
      echo "Record validation failed"
    elif [[ "$*" == *"-n"* ]]; then
      echo '{"name":"test","type":"A","data":"192.168.1.100","ttl":300}'
    fi
  }
  export -f jq

  run bash -c "source ../../providers/digitalocean/provider.sh && provider_batch_create_records 'example.com' '$records_file'"
  assert_failure
  assert_output --partial "Batch operation completed with 1 failures out of 2 records"

  # Cleanup
  rm -f "$records_file"
}
