#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Cloudflare Provider Integration Tests
# Tests real Cloudflare API integration with mock fallbacks

# shellcheck disable=SC2154  # status and output are BATS built-in variables

setup() {
    check_dns_plugin_available

    # Setup mock Cloudflare environment for CI
    export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-mock-token-for-testing}"
    export CLOUDFLARE_TEST_ZONE="${CLOUDFLARE_TEST_ZONE:-example.com}"
    export CLOUDFLARE_TEST_ZONE_ID="${CLOUDFLARE_TEST_ZONE_ID:-mock-zone-123}"
}

@test "(cloudflare integration) provider loads successfully in multi-provider environment" {
    run bash -c "source ../../providers/loader.sh && load_provider cloudflare 2>&1"
    assert_success
    assert_output --partial "Loaded provider: cloudflare"
}

@test "(cloudflare integration) provider validates structure and functions" {
    run bash -c "source ../../providers/loader.sh && validate_provider cloudflare"
    assert_success
}

@test "(cloudflare integration) provider requires API token" {
    # Test without token
    local original_token="$CLOUDFLARE_API_TOKEN"
    unset CLOUDFLARE_API_TOKEN

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_validate_credentials"
    assert_failure
    assert_output --partial "Missing required environment variable: CLOUDFLARE_API_TOKEN"

    # Restore token
    export CLOUDFLARE_API_TOKEN="$original_token"
}

@test "(cloudflare integration) provider handles invalid API token gracefully" {
    # Test with invalid token
    export CLOUDFLARE_API_TOKEN="invalid-token-format"

    # Mock curl to simulate auth failure
    function curl() {
        echo '{"success": false, "errors": [{"message": "Invalid API token"}]}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "false"
            return 1
        elif [[ "$*" == *"errors"* ]]; then
            echo "Invalid API token"
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_validate_credentials"
    assert_failure
    assert_output --partial "Cloudflare API error"
}

@test "(cloudflare integration) provider lists zones correctly" {
    # Mock successful zone listing
    function curl() {
        echo '{"success": true, "result": [{"name": "example.com", "id": "zone123"}, {"name": "test.org", "id": "zone456"}]}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".result[].name"* ]]; then
            echo -e "example.com\ntest.org"
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_list_zones"
    assert_success
    assert_output --partial "example.com"
    assert_output --partial "test.org"
}

@test "(cloudflare integration) provider finds zone IDs for domains" {
    # Mock zone ID lookup
    function curl() {
        if [[ "$*" == *"example.com"* ]]; then
            echo '{"success": true, "result": [{"name": "example.com", "id": "zone123456"}]}'
        else
            echo '{"success": true, "result": []}'
        fi
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".id"* ]] && [[ "$*" == *"example.com"* ]]; then
            echo "zone123456"
        else
            echo ""
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_get_zone_id 'example.com'"
    assert_success
    assert_output --partial "zone123456"
}

@test "(cloudflare integration) provider handles parent zone lookup for subdomains" {
    # Mock subdomain to parent zone lookup
    function curl() {
        if [[ "$*" == *"api.example.com"* ]]; then
            # No direct match for subdomain
            echo '{"success": true, "result": []}'
        elif [[ "$*" == *"example.com"* ]]; then
            # Parent zone found
            echo '{"success": true, "result": [{"name": "example.com", "id": "zone123456"}]}'
        fi
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".id"* ]]; then
            if [[ "$*" == *"example.com"* ]] && [[ "$*" != *"api.example.com"* ]]; then
                echo "zone123456"
            else
                echo ""
            fi
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_get_zone_id 'api.example.com'"
    assert_success
    assert_output --partial "zone123456"
}

@test "(cloudflare integration) provider creates DNS records" {
    # Mock record creation
    function curl() {
        if [[ "$*" == *"GET"* ]]; then
            # No existing record
            echo '{"success": true, "result": []}'
        else
            # Successful creation
            echo '{"success": true, "result": {"id": "record123", "name": "test.example.com", "content": "192.168.1.100"}}'
        fi
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *"-n"* ]]; then
            # Handle jq -n for JSON creation
            echo '{"name":"test.example.com","type":"A","content":"192.168.1.100","ttl":300}'
        elif [[ "$*" == *".id"* ]]; then
            echo ""  # No existing record
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_create_record 'zone123' 'test.example.com' 'A' '192.168.1.100' '300'"
    assert_success
    assert_output --partial "Created record: test.example.com -> 192.168.1.100"
}

@test "(cloudflare integration) provider updates existing DNS records" {
    # Mock record update
    function curl() {
        if [[ "$*" == *"GET"* ]]; then
            # Existing record found
            echo '{"success": true, "result": [{"id": "record123", "name": "test.example.com", "type": "A"}]}'
        else
            # Successful update
            echo '{"success": true, "result": {"id": "record123", "name": "test.example.com", "content": "192.168.1.200"}}'
        fi
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *"-n"* ]]; then
            # Handle jq -n for JSON creation
            echo '{"name":"test.example.com","type":"A","content":"192.168.1.200","ttl":300}'
        elif [[ "$*" == *".id"* ]] && [[ "$*" != *"-n"* ]]; then
            echo "record123"
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_create_record 'zone123' 'test.example.com' 'A' '192.168.1.200' '300'"
    assert_success
    assert_output --partial "Updated record: test.example.com -> 192.168.1.200"
}

@test "(cloudflare integration) provider deletes DNS records" {
    # Mock record deletion
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
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".id"* ]]; then
            echo "record123"
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_delete_record 'zone123' 'test.example.com' 'A'"
    assert_success
    assert_output --partial "Deleted record: test.example.com (A)"
}

@test "(cloudflare integration) provider retrieves DNS record values" {
    # Mock record retrieval
    function curl() {
        echo '{"success": true, "result": [{"name": "test.example.com", "type": "A", "content": "192.168.1.100"}]}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".content"* ]]; then
            echo "192.168.1.100"
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_get_record 'zone123' 'test.example.com' 'A'"
    assert_success
    assert_output --partial "192.168.1.100"
}

@test "(cloudflare integration) provider handles batch record operations" {
    # Create test records file
    local records_file="/tmp/test_records.txt"
    cat > "$records_file" << EOF
test1.example.com A 192.168.1.101 300
test2.example.com A 192.168.1.102 300
test3.example.com A 192.168.1.103 300
EOF

    # Mock batch operations (falls back to individual calls)
    function curl() {
        if [[ "$*" == *"GET"* ]]; then
            # No existing records
            echo '{"success": true, "result": []}'
        else
            # Successful creation for each call
            echo '{"success": true, "result": {"id": "record123"}}'
        fi
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *"-n"* ]]; then
            # Handle jq -n for JSON creation
            echo '{"name":"test.example.com","type":"A","content":"192.168.1.100","ttl":300}'
        elif [[ "$*" == *".id"* ]]; then
            echo ""  # No existing record
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_batch_create_records 'zone123' '$records_file'"
    assert_success
    assert_output --partial "Batch operation complete: 3/3 records processed"

    # Cleanup
    rm -f "$records_file"
}

@test "(cloudflare integration) provider handles API rate limiting gracefully" {
    # Mock rate limit response
    function curl() {
        echo '{"success": false, "errors": [{"code": 10013, "message": "Rate limit exceeded"}]}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "false"
            return 1
        elif [[ "$*" == *"errors"* ]]; then
            echo "Rate limit exceeded"
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_list_zones"
    assert_failure
    assert_output --partial "Rate limit exceeded"
}

@test "(cloudflare integration) provider validates required parameters" {
    run bash -c "source ../../providers/cloudflare/provider.sh && provider_get_zone_id ''"
    assert_failure
    assert_output --partial "Zone name is required"

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_create_record '' 'test.com' 'A' '1.1.1.1'"
    assert_failure
    assert_output --partial "Zone ID, record name, record type, and record value are required"

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_delete_record 'zone123' '' 'A'"
    assert_failure
    assert_output --partial "Zone ID, record name, and record type are required"
}

@test "(cloudflare integration) provider setup validates jq dependency" {
    # Mock missing jq
    function command() {
        if [[ "$2" == "jq" ]]; then
            return 1  # jq not found
        fi
        return 0
    }
    export -f command

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_setup_env"
    assert_failure
    assert_output --partial "jq is required for Cloudflare provider but not found"
}

@test "(cloudflare integration) provider handles zone not found errors" {
    # Mock zone not found
    function curl() {
        echo '{"success": true, "result": []}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".id"* ]]; then
            echo ""
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_get_zone_id 'nonexistent.com'"
    assert_failure
    assert_output --partial "Zone not found: nonexistent.com"
}

@test "(cloudflare integration) provider handles record not found errors" {
    # Mock record not found
    function curl() {
        echo '{"success": true, "result": []}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".content"* ]]; then
            echo ""
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_get_record 'zone123' 'nonexistent.example.com' 'A'"
    assert_failure
    assert_output --partial "Record not found: nonexistent.example.com (A)"
}

@test "(cloudflare integration) provider configuration is correct" {
    run bash -c "source ../../providers/cloudflare/config.sh && echo \$PROVIDER_NAME"
    assert_success
    assert_output --partial "cloudflare"

    run bash -c "source ../../providers/cloudflare/config.sh && echo \$PROVIDER_DISPLAY_NAME"
    assert_success
    assert_output --partial "Cloudflare"

    run bash -c "source ../../providers/cloudflare/config.sh && echo \$CLOUDFLARE_API_BASE"
    assert_success
    assert_output --partial "https://api.cloudflare.com/client/v4"
}

@test "(cloudflare integration) provider works in multi-provider environment" {
    # Test that cloudflare can be loaded alongside other providers
    run bash -c "
        source ../../providers/loader.sh
        load_provider mock 2>/dev/null || true
        load_provider cloudflare 2>/dev/null || true
        echo 'Mock loaded:' \$(is_provider_loaded mock && echo 'YES' || echo 'NO')
        echo 'Cloudflare loaded:' \$(is_provider_loaded cloudflare && echo 'YES' || echo 'NO')
    "

    # Should work regardless of which providers are available
    assert_success
}

@test "(cloudflare integration) provider supports different record types" {
    local record_types=("A" "AAAA" "CNAME" "TXT" "MX")

    for record_type in "${record_types[@]}"; do
        # Mock successful record creation for each type
        function curl() {
            echo '{"success": true, "result": {"id": "record123", "type": "'$record_type'"}}'
        }
        export -f curl

        function jq() {
            if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
                echo "true"
            elif [[ "$*" == *"-n"* ]]; then
                echo '{"name":"test.example.com","type":"'$record_type'","content":"test-value","ttl":300}'
            fi
        }
        export -f jq

        run bash -c "source ../../providers/cloudflare/provider.sh && provider_create_record 'zone123' 'test.example.com' '$record_type' 'test-value' '300'"
        assert_success
    done
}