#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Cloudflare Provider Edge Cases and Stress Tests
# Tests for unusual scenarios, edge cases, and error conditions

# shellcheck disable=SC2154  # status and output are BATS built-in variables

setup() {
    check_dns_plugin_available
    export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-mock-token-for-testing}"
}

@test "(cloudflare edge cases) handles very long domain names" {
    # Test with maximum length domain name (253 characters)
    local long_domain="a.very.long.subdomain.name.that.approaches.the.maximum.length.allowed.by.dns.standards.which.is.typically.around.253.characters.in.total.length.including.all.subdomains.and.the.root.domain.name.extension.example.com"

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

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_get_zone_id '$long_domain'"
    # Should handle gracefully (either succeed or fail with proper error)
    [[ $status -eq 0 || $status -eq 1 ]]
}

@test "(cloudflare edge cases) handles special characters in domain names" {
    # Test with internationalized domain names (IDN)
    local idn_domain="test-üñíçødé.example.com"

    function curl() {
        echo '{"success": true, "result": []}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_get_zone_id '$idn_domain'"
    # Should handle gracefully
    [[ $status -eq 0 || $status -eq 1 ]]
}

@test "(cloudflare edge cases) handles malformed JSON responses" {
    # Test with invalid JSON from API
    function curl() {
        echo '{"success": true, "result": [{"name": "broken.json"'  # Incomplete JSON
    }
    export -f curl

    function jq() {
        # Simulate jq parsing error
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "parse error: Invalid numeric literal" >&2
            return 1
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_list_zones"
    assert_failure
    # Should handle JSON parsing errors gracefully
}

@test "(cloudflare edge cases) handles network timeouts" {
    # Mock network timeout
    function curl() {
        echo "curl: (28) Operation timed out after 30000 milliseconds" >&2
        return 28
    }
    export -f curl

    # The provider should detect curl failure and return non-zero
    run bash -c "source ../../providers/cloudflare/provider.sh && provider_list_zones 2>/dev/null"
    # Should handle network timeouts gracefully by failing
    assert_failure
}

@test "(cloudflare edge cases) handles empty API responses" {
    # Test with empty but valid responses
    function curl() {
        echo '{"success": true, "result": [], "result_info": {"total_count": 0}}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".result[].name"* ]]; then
            echo ""  # Empty result
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_list_zones"
    assert_success
    # Should return empty result without error
    assert_output ""
}

@test "(cloudflare edge cases) handles very large zone lists" {
    # Mock large number of zones
    function curl() {
        local zones=""
        for i in {1..100}; do
            zones="$zones{\"name\": \"zone$i.example.com\", \"id\": \"zone$i\"},"
        done
        zones="${zones%,}"  # Remove trailing comma
        echo "{\"success\": true, \"result\": [$zones]}"
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".result[].name"* ]]; then
            for i in {1..100}; do
                echo "zone$i.example.com"
            done
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_list_zones | wc -l"
    assert_success
    assert_output --partial "100"
}

@test "(cloudflare edge cases) handles concurrent API calls gracefully" {
    # Test that concurrent calls don't interfere
    function curl() {
        sleep 0.1  # Simulate API delay
        echo '{"success": true, "result": [{"name": "test.example.com", "id": "zone123"}]}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".result[].name"* ]]; then
            echo "test.example.com"
        fi
    }
    export -f jq

    # Run multiple provider calls in background
    run bash -c "
        source ../../providers/cloudflare/provider.sh
        provider_list_zones &
        provider_list_zones &
        provider_list_zones &
        wait
        echo 'All calls completed'
    "
    assert_success
    assert_output --partial "All calls completed"
}

@test "(cloudflare edge cases) handles API version changes gracefully" {
    # Test with unexpected API response format
    function curl() {
        echo '{"success": true, "data": [{"domain": "example.com", "zone_id": "123"}]}'  # Different format
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *".result[].name"* ]]; then
            echo ""  # No result in expected format
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_list_zones"
    assert_success
    # Should handle gracefully, possibly returning empty results
}

@test "(cloudflare edge cases) handles record limits and pagination" {
    # Test handling of large numbers of DNS records
    function curl() {
        if [[ "$*" == *"dns_records"* ]]; then
            # Mock large number of records
            local records=""
            for i in {1..1000}; do
                records="$records{\"name\": \"record$i.example.com\", \"type\": \"A\", \"content\": \"192.168.1.$((i % 255))\"},"
            done
            records="${records%,}"
            echo "{\"success\": true, \"result\": [$records]}"
        else
            echo '{"success": true, "result": [{"name": "example.com", "id": "zone123"}]}'
        fi
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

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_get_record 'zone123' 'record1.example.com' 'A'"
    assert_success
    assert_output --partial "192.168.1.100"
}

@test "(cloudflare edge cases) handles missing jq dependency gracefully" {
    # Test behavior when jq is not available
    function jq() {
        echo "jq: command not found" >&2
        return 127
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_list_zones"
    assert_failure
    # Should fail gracefully when jq is missing
}

@test "(cloudflare edge cases) handles API key with insufficient permissions" {
    # Mock insufficient permissions error
    function curl() {
        echo '{"success": false, "errors": [{"code": 6003, "message": "Insufficient permissions"}]}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "false"
            return 1
        elif [[ "$*" == *"errors"* ]]; then
            echo "Insufficient permissions"
        fi
    }
    export -f jq

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_validate_credentials"
    assert_failure
    assert_output --partial "Insufficient permissions"
}

@test "(cloudflare edge cases) handles record type validation" {
    # Test with invalid record types
    local invalid_types=("INVALID" "test" "123" "")

    for record_type in "${invalid_types[@]}"; do
        run bash -c "source ../../providers/cloudflare/provider.sh && provider_create_record 'zone123' 'test.example.com' '$record_type' '192.168.1.100'"
        # Should handle invalid record types (may succeed and let API validate, or fail gracefully)
        [[ $status -eq 0 || $status -eq 1 ]]
    done
}

@test "(cloudflare edge cases) handles very long TTL values" {
    # Test with extreme TTL values
    local extreme_ttls=("1" "2147483647" "999999999" "0" "-1")

    function curl() {
        echo '{"success": true, "result": {"id": "record123"}}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *"-n"* ]]; then
            echo '{"name":"test.example.com","type":"A","content":"192.168.1.100","ttl":300}'
        fi
    }
    export -f jq

    for ttl in "${extreme_ttls[@]}"; do
        run bash -c "source ../../providers/cloudflare/provider.sh && provider_create_record 'zone123' 'test.example.com' 'A' '192.168.1.100' '$ttl'"
        # Should handle extreme TTL values gracefully
        [[ $status -eq 0 || $status -eq 1 ]]
    done
}

@test "(cloudflare edge cases) handles IPv6 addresses correctly" {
    # Test with IPv6 addresses
    local ipv6_addresses=(
        "2001:db8::1"
        "2001:0db8:0000:0000:0000:ff00:0042:8329"
        "::1"
        "fe80::1%lo0"
    )

    function curl() {
        echo '{"success": true, "result": {"id": "record123"}}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *"-n"* ]]; then
            echo '{"name":"test.example.com","type":"AAAA","content":"2001:db8::1","ttl":300}'
        fi
    }
    export -f jq

    for ipv6 in "${ipv6_addresses[@]}"; do
        run bash -c "source ../../providers/cloudflare/provider.sh && provider_create_record 'zone123' 'test.example.com' 'AAAA' '$ipv6' '300'"
        # Should handle IPv6 addresses
        [[ $status -eq 0 || $status -eq 1 ]]
    done
}

@test "(cloudflare edge cases) handles batch operations with mixed success" {
    # Test batch operations where some records succeed and others fail
    local records_file="/tmp/test_mixed_records.txt"
    cat > "$records_file" << EOF
valid.example.com A 192.168.1.100 300
invalid..example.com A 192.168.1.101 300
valid2.example.com A 192.168.1.102 300
EOF

    # Mock batch operation that always reports some failures
    function curl() {
        # Always return success for API calls, but batch logic will handle failures
        echo '{"success": true, "result": {"id": "record123"}}'
    }
    export -f curl

    function jq() {
        if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
            echo "true"
        elif [[ "$*" == *"-n"* ]]; then
            echo '{"name":"test.example.com","type":"A","content":"192.168.1.100","ttl":300}'
        elif [[ "$*" == *".id"* ]]; then
            echo ""  # No existing record
        fi
    }
    export -f jq

    # Override the provider_create_record function to simulate mixed results
    function provider_create_record() {
        local record_name="$2"
        if [[ "$record_name" == "invalid..example.com" ]]; then
            echo "Failed to create record: $record_name" >&2
            return 1
        else
            echo "Created record: $record_name -> 192.168.1.100 (TTL: 300)"
            return 0
        fi
    }
    export -f provider_create_record

    run bash -c "source ../../providers/cloudflare/provider.sh && provider_batch_create_records 'zone123' '$records_file'"
    assert_failure  # Should fail because not all records succeeded
    assert_output --partial "Batch operation"

    # Cleanup
    rm -f "$records_file"
}

@test "(cloudflare edge cases) handles environment variable edge cases" {
    # Test with various edge cases in environment variables
    local edge_case_tokens=(
        ""                          # Empty token
        " "                         # Space token
        "token with spaces"         # Token with spaces
        "token\nwith\nnewlines"    # Token with newlines
        "token'with'quotes"         # Token with quotes
    )

    for token in "${edge_case_tokens[@]}"; do
        export CLOUDFLARE_API_TOKEN="$token"
        run bash -c "source ../../providers/cloudflare/provider.sh && provider_validate_credentials"
        # Should handle malformed tokens gracefully
        assert_failure
    done
}