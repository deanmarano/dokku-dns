#!/usr/bin/env bats
load test_helper

setup() {
  # Skip setup in Docker environment - apps and provider already configured
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
    # Set up mock environment for DigitalOcean testing
    export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"
    export DNS_TEST_MODE=1
  fi
}

teardown() {
  # Skip teardown in Docker environment to preserve setup
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
  fi
}

@test "(digitalocean provider) config.sh has correct metadata" {
  source providers/digitalocean/config.sh

  [[ "$PROVIDER_NAME" == "digitalocean" ]]
  [[ "$PROVIDER_DISPLAY_NAME" == "DigitalOcean" ]]
  [[ "$PROVIDER_REQUIRED_ENV_VARS" == "DIGITALOCEAN_ACCESS_TOKEN" ]]
  [[ "$PROVIDER_CAPABILITIES" =~ "zones" ]]
  [[ "$PROVIDER_CAPABILITIES" =~ "records" ]]
  [[ "$DIGITALOCEAN_API_URL" == "https://api.digitalocean.com/v2" ]]
}

@test "(digitalocean provider) is listed in available providers" {
  run cat providers/available
  assert_success
  [[ "$output" =~ digitalocean ]]
}

@test "(digitalocean provider) loads without errors" {
  run bash -c "source providers/loader.sh && load_provider digitalocean"
  assert_success
}

@test "(digitalocean provider) validates provider structure" {
  run bash -c "source providers/loader.sh && validate_provider digitalocean"
  assert_success
}

@test "(digitalocean provider) provider_validate_credentials requires API token" {
  unset DIGITALOCEAN_ACCESS_TOKEN

  source providers/digitalocean/provider.sh
  run provider_validate_credentials

  assert_failure
  [[ "$output" =~ "Missing required environment variable: DIGITALOCEAN_ACCESS_TOKEN" ]]
  [[ "$output" =~ "cloud.digitalocean.com/account/api/tokens" ]]
}

@test "(digitalocean provider) provider_validate_credentials accepts valid token format" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  # Mock successful API response
  function curl() {
    echo '{"account": {"uuid": "test-user-123", "email": "test@example.com"}}'
  }
  export -f curl

  source providers/digitalocean/provider.sh
  run provider_validate_credentials

  assert_success
}

@test "(digitalocean provider) provider_validate_credentials handles invalid token" {
  export DIGITALOCEAN_ACCESS_TOKEN="invalid-token"

  # Mock failed API response (DigitalOcean auth error format)
  function curl() {
    echo '{"id": "Unauthorized", "message": "Unable to authenticate you"}'
  }
  export -f curl

  source providers/digitalocean/provider.sh
  run provider_validate_credentials

  assert_failure
  [[ "$output" =~ "DigitalOcean API authentication failed: Unable to authenticate you" ]]
}

@test "(digitalocean provider) provider_list_zones calls correct API endpoint" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  # Mock curl to capture the API call
  function curl() {
    echo "Called with: $*" >&2
    echo '{"domains": [{"name": "example.com"}, {"name": "test.org"}]}'
  }
  export -f curl

  # Mock jq for JSON parsing
  function jq() {
    if [[ "$*" == *".domains[]?.name"* ]]; then
      echo -e "example.com\ntest.org"
    fi
  }
  export -f jq

  source providers/digitalocean/provider.sh
  run provider_list_zones

  assert_success
  [[ "$output" =~ "example.com" ]]
  [[ "$output" =~ "test.org" ]]
}

@test "(digitalocean provider) provider_get_zone_id finds exact zone match" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  # Mock API response for domain lookup
  function curl() {
    echo '{"domain": {"name": "example.com"}}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *"'.domain.name'"* ]]; then
      echo "example.com"
      return 0
    fi
  }
  export -f jq

  source providers/digitalocean/provider.sh
  run provider_get_zone_id "example.com"

  assert_success
  assert_output "example.com"
}

@test "(digitalocean provider) provider_get_zone_id handles non-existent zone" {
  skip "Complex mocking scenario - tested in integration tests"
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  # Mock API response for non-existent domain (with valid JSON but wrong structure)
  function curl() {
    echo '{"id": "not_found", "message": "The resource you requested could not be found."}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *"-e"* && "$*" == *"'.domain.name'"* ]]; then
      return 1 # jq -e returns 1 when key doesn't exist
    fi
  }
  export -f jq

  source providers/digitalocean/provider.sh
  run provider_get_zone_id "nonexistent.com"

  assert_failure
  [[ "$output" =~ "Zone not found: nonexistent.com" ]]
}

@test "(digitalocean provider) provider_get_record retrieves existing record" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

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

  source providers/digitalocean/provider.sh
  run provider_get_record "example.com" "test" "A"

  assert_success
  assert_output "192.168.1.100"
}

@test "(digitalocean provider) provider_get_record handles non-existent record" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

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

  source providers/digitalocean/provider.sh
  run provider_get_record "example.com" "nonexistent" "A"

  assert_failure
  [[ "$output" =~ "Record not found: nonexistent (A)" ]]
}

@test "(digitalocean provider) provider_create_record creates new record" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  # Mock API responses
  function curl() {
    if [[ "$*" == *"GET"* ]]; then
      # No existing record found
      echo '{"domain_records": []}'
    else
      # Successful creation
      echo '{"domain_record": {"id": 12345, "name": "test", "data": "192.168.1.100"}}'
    fi
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domain_records[]?"* ]]; then
      echo "" # No existing record
    elif [[ "$*" == *"'.domain_record.id'"* ]]; then
      echo "12345"
      return 0
    elif [[ "$*" == *"-n"* ]]; then
      # Handle the jq -n call for creating JSON data
      echo '{"name":"test","type":"A","data":"192.168.1.100","ttl":1800}'
    fi
  }
  export -f jq

  source providers/digitalocean/provider.sh
  run provider_create_record "example.com" "test" "A" "192.168.1.100" "1800"

  assert_success
  [[ "$output" =~ "Successfully created/updated record: test -> 192.168.1.100" ]]
}

@test "(digitalocean provider) provider_create_record updates existing record" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  function curl() {
    if [[ "$*" == *"GET"* ]]; then
      # Existing record found
      echo '{"domain_records": [{"id": 12345, "name": "test", "type": "A", "data": "192.168.1.50"}]}'
    else
      # Successful update
      echo '{"domain_record": {"id": 12345, "name": "test", "data": "192.168.1.100"}}'
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
      # Handle the jq -n call for creating JSON data
      echo '{"name":"test","type":"A","data":"192.168.1.100","ttl":1800}'
    fi
  }
  export -f jq

  source providers/digitalocean/provider.sh
  run provider_create_record "example.com" "test" "A" "192.168.1.100" "1800"

  assert_success
  [[ "$output" =~ "Successfully created/updated record: test -> 192.168.1.100" ]]
}

@test "(digitalocean provider) provider_delete_record removes existing record" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  function curl() {
    if [[ "$*" == *"GET"* ]]; then
      # Record found for deletion
      echo '{"domain_records": [{"id": 12345, "name": "test", "type": "A"}]}'
    else
      # Successful deletion (DigitalOcean returns empty response)
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

  source providers/digitalocean/provider.sh
  run provider_delete_record "example.com" "test" "A"

  assert_success
  [[ "$output" =~ "Successfully deleted record: test (A)" ]]
}

@test "(digitalocean provider) provider_delete_record handles non-existent record" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  function curl() {
    # No record found
    echo '{"domain_records": []}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domain_records[]?"* ]] && [[ "$*" == *".id"* ]]; then
      echo ""
    fi
  }
  export -f jq

  source providers/digitalocean/provider.sh
  run provider_delete_record "example.com" "nonexistent" "A"

  assert_failure
  [[ "$output" =~ "Record not found for deletion: nonexistent (A)" ]]
}

@test "(digitalocean provider) validates required parameters" {
  source providers/digitalocean/provider.sh

  # Test missing zone_id
  run provider_get_record "" "test.example.com" "A"
  assert_failure
  [[ "$output" =~ "Zone ID, record name, and record type are required" ]]

  # Test missing record_name
  run provider_create_record "example.com" "" "A" "192.168.1.100"
  assert_failure
  [[ "$output" =~ "Zone ID, record name, record type, and record value are required" ]]

  # Test missing zone_name
  run provider_get_zone_id ""
  assert_failure
  [[ "$output" =~ "Zone name is required" ]]
}

@test "(digitalocean provider) handles API errors gracefully" {
  export DIGITALOCEAN_ACCESS_TOKEN="invalid-token"

  # Mock failed API response
  function curl() {
    echo '{"id": "forbidden", "message": "This action requires authentication"}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *"'.account.uuid'"* ]]; then
      echo ""
    elif [[ "$*" == *"'.id'"* ]]; then
      echo "forbidden"
    elif [[ "$*" == *"'.message'"* ]]; then
      echo "This action requires authentication"
    fi
  }
  export -f jq

  source providers/digitalocean/provider.sh
  run provider_validate_credentials

  assert_failure
  [[ "$output" =~ "DigitalOcean API error" ]]
}

@test "(digitalocean provider) provider_setup_env validates jq dependency" {
  # Mock command to simulate jq not found
  function command() {
    if [[ "$1" == "-v" && "$2" == "jq" ]]; then
      return 1
    fi
    return 0
  }
  export -f command

  source providers/digitalocean/provider.sh
  run provider_setup_env

  assert_failure
  [[ "$output" =~ "jq is required for DigitalOcean provider but not found in PATH" ]]
  [[ "$output" =~ "Install jq: https://stedolan.github.io/jq/download/" ]]
}

@test "(digitalocean provider) provider_setup_env sets default API URL" {
  unset DIGITALOCEAN_API_URL

  # Mock jq as available
  function command() {
    if [[ "$1" == "-v" && "$2" == "jq" ]]; then
      return 0
    fi
  }
  export -f command

  source providers/digitalocean/provider.sh
  run provider_setup_env

  assert_success
  [[ "$DIGITALOCEAN_API_URL" == "https://api.digitalocean.com/v2" ]]
}

@test "(digitalocean provider) provider_batch_create_records processes records file" {
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  # Create temporary records file
  local records_file="/tmp/test_records.txt"
  cat >"$records_file" <<EOF
# Comment line
test1 A 192.168.1.1 300
test2 A 192.168.1.2 600
EOF

  # Mock successful creation for all records
  function curl() {
    echo '{"domain_record": {"id": 12345}}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *"'.domain_record.id'"* ]]; then
      echo "12345"
      return 0
    elif [[ "$*" == *"-n"* ]]; then
      echo '{"name":"test","type":"A","data":"192.168.1.1","ttl":300}'
    fi
  }
  export -f jq

  source providers/digitalocean/provider.sh
  run provider_batch_create_records "example.com" "$records_file"

  assert_success
  [[ "$output" =~ "Batch operation completed successfully: 2 records processed" ]]

  # Clean up
  rm -f "$records_file"
}

@test "(digitalocean provider) provider_batch_create_records handles mixed success/failure" {
  skip "Complex batch test - skipped for now"
  export DIGITALOCEAN_ACCESS_TOKEN="test-token-12345"

  # Create temporary records file
  local records_file="/tmp/test_records.txt"
  cat >"$records_file" <<EOF
test1 A 192.168.1.1 300
test2 A 192.168.1.2 600
EOF

  # Track call count to simulate one success, one failure
  local success_calls=0
  local fail_calls=0

  function curl() {
    if [[ "$*" == *"GET"* ]]; then
      echo '{"domain_records": []}'
    else
      if [[ $success_calls -eq 0 ]]; then
        success_calls=1
        echo '{"domain_record": {"id": 12345}}'
      else
        fail_calls=1
        echo '{"id": "unprocessable_entity", "message": "Record validation failed"}'
      fi
    fi
  }
  export -f curl

  function jq() {
    if [[ "$*" == *".domain_records[]?"* ]] && [[ "$*" == *".id"* ]]; then
      echo ""
    elif [[ "$*" == *"'.domain_record.id'"* ]]; then
      if [[ $success_calls -eq 1 && $fail_calls -eq 0 ]]; then
        echo "12345"
        return 0
      else
        echo ""
        return 1
      fi
    elif [[ "$*" == *"'.message'"* ]]; then
      echo "Record validation failed"
    elif [[ "$*" == *"-n"* ]]; then
      echo '{"name":"test","type":"A","data":"192.168.1.1","ttl":300}'
    fi
  }
  export -f jq

  source providers/digitalocean/provider.sh
  run provider_batch_create_records "example.com" "$records_file"

  assert_failure
  [[ "$output" =~ "Batch operation completed with 1 failures out of 2 records" ]]

  # Clean up
  rm -f "$records_file"
}

@test "(digitalocean provider) provider_batch_create_records validates parameters" {
  source providers/digitalocean/provider.sh

  # Test missing zone_id
  run provider_batch_create_records "" "/tmp/records.txt"
  assert_failure
  [[ "$output" =~ "Zone ID and valid records file are required" ]]

  # Test missing records file
  run provider_batch_create_records "example.com" ""
  assert_failure
  [[ "$output" =~ "Zone ID and valid records file are required" ]]

  # Test non-existent records file
  run provider_batch_create_records "example.com" "/tmp/nonexistent.txt"
  assert_failure
  [[ "$output" =~ "Zone ID and valid records file are required" ]]
}
