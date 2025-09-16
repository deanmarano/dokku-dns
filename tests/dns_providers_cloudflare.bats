#!/usr/bin/env bats
load test_helper

setup() {
    # Skip setup in Docker environment - apps and provider already configured
    if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
        cleanup_dns_data
        # Set up mock environment for Cloudflare testing
        export CLOUDFLARE_API_TOKEN="test-token-12345"
        export DNS_TEST_MODE=1
    fi
}

teardown() {
    # Skip teardown in Docker environment to preserve setup
    if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
        cleanup_dns_data
    fi
}

@test "(cloudflare provider) config.sh has correct metadata" {
    source providers/cloudflare/config.sh

    [[ "$PROVIDER_NAME" == "cloudflare" ]]
    [[ "$PROVIDER_DISPLAY_NAME" == "Cloudflare" ]]
    [[ "$PROVIDER_REQUIRED_ENV_VARS" == "CLOUDFLARE_API_TOKEN" ]]
    [[ "$PROVIDER_CAPABILITIES" =~ "zones" ]]
    [[ "$PROVIDER_CAPABILITIES" =~ "records" ]]
    [[ "$CLOUDFLARE_API_BASE" == "https://api.cloudflare.com/client/v4" ]]
}

@test "(cloudflare provider) is listed in available providers" {
    run cat providers/available
    assert_success
    [[ "$output" =~ cloudflare ]]
}

@test "(cloudflare provider) loads without errors" {
    run bash -c "source providers/loader.sh && load_provider cloudflare"
    assert_success
    [[ "$output" =~ "Loaded provider: cloudflare" ]]
}

@test "(cloudflare provider) validates provider structure" {
    run bash -c "source providers/loader.sh && validate_provider cloudflare"
    assert_success
}

@test "(cloudflare provider) provider_validate_credentials requires API token" {
    unset CLOUDFLARE_API_TOKEN

    source providers/cloudflare/provider.sh
    run provider_validate_credentials

    assert_failure
    [[ "$output" =~ "Missing required environment variable: CLOUDFLARE_API_TOKEN" ]]
    [[ "$output" =~ "dash.cloudflare.com/profile/api-tokens" ]]
}

@test "(cloudflare provider) provider_validate_credentials accepts valid token format" {
    export CLOUDFLARE_API_TOKEN="test-token-12345"

    # Mock successful API response
    function curl() {
        echo '{"success": true, "result": {"id": "test-user"}}'
    }
    export -f curl

    source providers/cloudflare/provider.sh
    run provider_validate_credentials

    assert_success
}

@test "(cloudflare provider) provider_list_zones calls correct API endpoint" {
    export CLOUDFLARE_API_TOKEN="test-token-12345"

    # Mock curl to capture the API call
    function curl() {
        echo "Called with: $*" >&2
        echo '{"success": true, "result": [{"name": "example.com"}, {"name": "test.org"}]}'
    }
    export -f curl

    # Mock jq for JSON parsing
    function jq() {
        if [[ "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".result[].name"* ]]; then
            echo -e "example.com\ntest.org"
        fi
    }
    export -f jq

    source providers/cloudflare/provider.sh
    run provider_list_zones

    assert_success
    [[ "$output" =~ "example.com" ]]
    [[ "$output" =~ "test.org" ]]
}

@test "(cloudflare provider) provider_get_zone_id finds exact zone match" {
    export CLOUDFLARE_API_TOKEN="test-token-12345"

    # Mock API response for zone lookup
    function curl() {
        echo '{"success": true, "result": [{"name": "example.com", "id": "zone123456"}]}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".id"* ]]; then
            echo "zone123456"
        fi
    }
    export -f jq

    source providers/cloudflare/provider.sh
    run provider_get_zone_id "example.com"

    assert_success
    assert_output "zone123456"
}

@test "(cloudflare provider) provider_get_zone_id finds parent zone for subdomains" {
    export CLOUDFLARE_API_TOKEN="test-token-12345"

    # Mock API responses: simulate finding parent zone after subdomain fails
    function curl() {
        if [[ "$*" =~ "api.example.com" ]]; then
            # First call for api.example.com - no results
            echo '{"success": true, "result": []}'
        else
            # Second call for example.com - found
            echo '{"success": true, "result": [{"name": "example.com", "id": "zone123456"}]}'
        fi
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".id"* ]]; then
            # Only return ID if we found the parent zone
            if [[ "$*" =~ "example.com" ]]; then
                echo "zone123456"
            else
                echo ""
            fi
        fi
    }
    export -f jq

    source providers/cloudflare/provider.sh
    run provider_get_zone_id "api.example.com"

    assert_success
    assert_output "zone123456"
}

@test "(cloudflare provider) provider_create_record creates new record" {
    export CLOUDFLARE_API_TOKEN="test-token-12345"

    # Mock API responses
    function curl() {
        if [[ "$*" == *"GET"* ]]; then
            # No existing record found
            echo '{"success": true, "result": []}'
        else
            # Successful creation
            echo '{"success": true, "result": {"id": "record123"}}'
        fi
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".id"* ]]; then
            echo ""  # No existing record
        else
            # Handle the jq -n call for creating JSON data
            echo '{"name":"test.example.com","type":"A","content":"192.168.1.100","ttl":300}'
        fi
    }
    export -f jq

    source providers/cloudflare/provider.sh
    run provider_create_record "zone123" "test.example.com" "A" "192.168.1.100" "300"

    assert_success
    [[ "$output" =~ "Created record: test.example.com -> 192.168.1.100" ]]
}

@test "(cloudflare provider) provider_create_record updates existing record" {
    export CLOUDFLARE_API_TOKEN="test-token-12345"

    function curl() {
        if [[ "$*" == *"GET"* ]]; then
            # Existing record found
            echo '{"success": true, "result": [{"id": "record123", "name": "test.example.com", "type": "A"}]}'
        else
            # Successful update
            echo '{"success": true, "result": {"id": "record123"}}'
        fi
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".id"* ]] && [[ "$*" != *"-n"* ]]; then
            echo "record123"
        else
            # Handle the jq -n call for creating JSON data
            echo '{"name":"test.example.com","type":"A","content":"192.168.1.200","ttl":300}'
        fi
    }
    export -f jq

    source providers/cloudflare/provider.sh
    run provider_create_record "zone123" "test.example.com" "A" "192.168.1.200" "300"

    assert_success
    [[ "$output" =~ "Updated record: test.example.com -> 192.168.1.200" ]]
}

@test "(cloudflare provider) provider_delete_record removes existing record" {
    export CLOUDFLARE_API_TOKEN="test-token-12345"

    function curl() {
        if [[ "$*" == *"GET"* ]]; then
            # Record found for deletion
            echo '{"success": true, "result": [{"id": "record123", "name": "test.example.com", "type": "A"}]}'
        else
            # Successful deletion
            echo '{"success": true, "result": {"id": "record123"}}'
        fi
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".id"* ]]; then
            echo "record123"
        fi
    }
    export -f jq

    source providers/cloudflare/provider.sh
    run provider_delete_record "zone123" "test.example.com" "A"

    assert_success
    [[ "$output" =~ "Deleted record: test.example.com (A)" ]]
}

@test "(cloudflare provider) provider_get_record retrieves existing record" {
    export CLOUDFLARE_API_TOKEN="test-token-12345"

    function curl() {
        echo '{"success": true, "result": [{"name": "test.example.com", "type": "A", "content": "192.168.1.100"}]}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".content"* ]]; then
            echo "192.168.1.100"
        fi
    }
    export -f jq

    source providers/cloudflare/provider.sh
    run provider_get_record "zone123" "test.example.com" "A"

    assert_success
    assert_output "192.168.1.100"
}

@test "(cloudflare provider) validates required parameters" {
    source providers/cloudflare/provider.sh

    # Test missing zone_id
    run provider_get_record "" "test.example.com" "A"
    assert_failure
    [[ "$output" =~ "Zone ID, record name, and record type are required" ]]

    # Test missing record_name
    run provider_create_record "zone123" "" "A" "192.168.1.100"
    assert_failure
    [[ "$output" =~ "Zone ID, record name, record type, and record value are required" ]]

    # Test missing zone_name
    run provider_get_zone_id ""
    assert_failure
    [[ "$output" =~ "Zone name is required" ]]
}

@test "(cloudflare provider) handles API errors gracefully" {
    export CLOUDFLARE_API_TOKEN="invalid-token"

    # Mock failed API response
    function curl() {
        echo '{"success": false, "errors": [{"message": "Invalid API token"}]}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            # jq -e should exit with failure when success is false
            echo "false"
            return 1
        elif [[ "$*" == *"errors"* ]]; then
            echo "Invalid API token"
        fi
    }
    export -f jq

    source providers/cloudflare/provider.sh
    run provider_validate_credentials

    assert_failure
}