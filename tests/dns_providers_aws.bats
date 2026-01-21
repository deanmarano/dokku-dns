#!/usr/bin/env bats
load test_helper

setup() {
  # Skip setup in Docker environment - apps and provider already configured
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
    # Set up mock environment for AWS testing
    export AWS_ACCESS_KEY_ID="test-key-12345"
    export AWS_SECRET_ACCESS_KEY="test-secret-12345"
    export DNS_TEST_MODE=1
  fi
}

teardown() {
  # Skip teardown in Docker environment to preserve setup
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
  fi
}

@test "(aws provider) config.sh has correct metadata" {
  source providers/aws/config.sh

  [[ "$PROVIDER_NAME" == "aws" ]]
  [[ "$PROVIDER_DISPLAY_NAME" == "AWS Route53" ]]
  [[ "$PROVIDER_REQUIRED_ENV_VARS" == "AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY" ]]
  [[ "$PROVIDER_CAPABILITIES" =~ "zones" ]]
  [[ "$PROVIDER_CAPABILITIES" =~ "records" ]]
  [[ "$PROVIDER_CAPABILITIES" =~ "batch" ]]
  [[ "$PROVIDER_DEFAULT_TTL" == "300" ]]
}

@test "(aws provider) is listed in available providers" {
  run cat providers/available
  assert_success
  [[ "$output" =~ aws ]]
}

@test "(aws provider) loads without errors" {
  run bash -c "source providers/loader.sh && load_provider aws"
  assert_success
  [[ "$output" =~ "Loaded provider: aws" ]]
}

@test "(aws provider) validates provider structure" {
  run bash -c "source providers/loader.sh && validate_provider aws"
  assert_success
}

@test "(aws provider) provider_validate_credentials requires AWS CLI" {
  # Mock command to simulate aws not found
  function command() {
    if [[ "$1" == "-v" && "$2" == "aws" ]]; then
      return 1
    fi
    builtin command "$@"
  }
  export -f command

  source providers/aws/provider.sh
  run provider_validate_credentials

  assert_failure
  [[ "$output" =~ "AWS CLI not installed" ]]
}

@test "(aws provider) provider_validate_credentials requires jq" {
  # Mock command to simulate jq not found but aws found
  function command() {
    if [[ "$1" == "-v" && "$2" == "jq" ]]; then
      return 1
    elif [[ "$1" == "-v" && "$2" == "aws" ]]; then
      return 0
    fi
    builtin command "$@"
  }
  export -f command

  source providers/aws/provider.sh
  run provider_validate_credentials

  assert_failure
  [[ "$output" =~ "jq is required for AWS provider" ]]
}

@test "(aws provider) provider_validate_credentials accepts valid credentials" {
  # Mock aws command for successful STS call
  function aws() {
    if [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo '{"Account": "123456789012", "Arn": "arn:aws:iam::123456789012:user/test"}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_validate_credentials

  assert_success
}

@test "(aws provider) provider_validate_credentials handles invalid credentials" {
  # Mock aws command for failed STS call
  function aws() {
    if [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
      echo "An error occurred (InvalidClientTokenId) when calling GetCallerIdentity" >&2
      return 1
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_validate_credentials

  assert_failure
  [[ "$output" =~ "AWS credentials not configured or invalid" ]]
}

@test "(aws provider) provider_list_zones returns zone names" {
  # Mock aws and jq for zone listing
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-hosted-zones" ]]; then
      echo '{"HostedZones": [{"Id": "/hostedzone/Z123", "Name": "example.com."}, {"Id": "/hostedzone/Z456", "Name": "test.org."}]}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_list_zones

  assert_success
  [[ "$output" =~ "example.com" ]]
  [[ "$output" =~ "test.org" ]]
}

@test "(aws provider) provider_get_zone_id finds exact zone match" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-hosted-zones" ]]; then
      echo '{"HostedZones": [{"Id": "/hostedzone/Z123ABC", "Name": "example.com."}]}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_get_zone_id "example.com"

  assert_success
  assert_output "Z123ABC"
}

@test "(aws provider) provider_get_zone_id finds parent zone for subdomains" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-hosted-zones" ]]; then
      # Only example.com exists, not api.example.com
      echo '{"HostedZones": [{"Id": "/hostedzone/Z123ABC", "Name": "example.com."}]}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_get_zone_id "api.example.com"

  assert_success
  assert_output "Z123ABC"
}

@test "(aws provider) provider_get_zone_id handles deep subdomains" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-hosted-zones" ]]; then
      echo '{"HostedZones": [{"Id": "/hostedzone/Z123ABC", "Name": "example.com."}]}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_get_zone_id "deep.nested.sub.example.com"

  assert_success
  assert_output "Z123ABC"
}

@test "(aws provider) provider_get_zone_id handles non-existent zone" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-hosted-zones" ]]; then
      echo '{"HostedZones": []}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_get_zone_id "nonexistent.com"

  assert_failure
  [[ "$output" =~ "Hosted zone not found" ]]
}

@test "(aws provider) provider_get_record retrieves existing record" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-resource-record-sets" ]]; then
      echo '{"ResourceRecordSets": [{"Name": "www.example.com.", "Type": "A", "TTL": 300, "ResourceRecords": [{"Value": "192.168.1.100"}]}]}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_get_record "Z123ABC" "www.example.com" "A"

  assert_success
  assert_output "192.168.1.100"
}

@test "(aws provider) provider_get_record handles non-existent record" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-resource-record-sets" ]]; then
      echo '{"ResourceRecordSets": []}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_get_record "Z123ABC" "nonexistent.example.com" "A"

  assert_failure
  [[ "$output" =~ "Record not found" ]]
}

@test "(aws provider) provider_create_record creates new record" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "change-resource-record-sets" ]]; then
      echo '{"ChangeInfo": {"Id": "/change/C123", "Status": "PENDING"}}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_create_record "Z123ABC" "test.example.com" "A" "192.168.1.100" "300"

  assert_success
  [[ "$output" =~ "Created/updated record: test.example.com -> 192.168.1.100" ]]
}

@test "(aws provider) provider_create_record uses jq for JSON escaping" {
  # This test verifies that special characters are properly escaped
  local captured_batch=""

  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "change-resource-record-sets" ]]; then
      # Capture the change batch for verification
      for arg in "$@"; do
        if [[ "$arg" == --change-batch ]]; then
          continue
        fi
        if [[ -n "$captured_batch" ]] || [[ "$arg" == "{"* ]]; then
          captured_batch="$arg"
          break
        fi
      done
      echo '{"ChangeInfo": {"Id": "/change/C123", "Status": "PENDING"}}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_create_record "Z123ABC" "test.example.com" "TXT" "v=spf1 include:example.com ~all" "300"

  assert_success
}

@test "(aws provider) provider_create_record handles TXT records with quotes" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "change-resource-record-sets" ]]; then
      echo '{"ChangeInfo": {"Id": "/change/C123", "Status": "PENDING"}}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  # TXT record with quotes - this was the bug we fixed
  run provider_create_record "Z123ABC" "_dkim.example.com" "TXT" "\"p=MIGfMA0GCSqGSIb...\"" "300"

  assert_success
  [[ "$output" =~ "Created/updated record" ]]
}

@test "(aws provider) provider_create_record handles DMARC records" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "change-resource-record-sets" ]]; then
      echo '{"ChangeInfo": {"Id": "/change/C123", "Status": "PENDING"}}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_create_record "Z123ABC" "_dmarc.example.com" "TXT" "v=DMARC1; p=none;" "300"

  assert_success
  [[ "$output" =~ "Created/updated record" ]]
}

@test "(aws provider) provider_delete_record removes existing record" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-resource-record-sets" ]]; then
      echo '{"ResourceRecordSets": [{"Name": "test.example.com.", "Type": "A", "TTL": 300, "ResourceRecords": [{"Value": "192.168.1.100"}]}]}'
      return 0
    elif [[ "$1" == "route53" && "$2" == "change-resource-record-sets" ]]; then
      echo '{"ChangeInfo": {"Id": "/change/C123", "Status": "PENDING"}}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_delete_record "Z123ABC" "test.example.com" "A"

  assert_success
  [[ "$output" =~ "Deleted record: test.example.com (A)" ]]
}

@test "(aws provider) provider_delete_record handles non-existent record" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-resource-record-sets" ]]; then
      echo '{"ResourceRecordSets": []}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_delete_record "Z123ABC" "nonexistent.example.com" "A"

  assert_failure
  [[ "$output" =~ "Record not found for deletion" ]]
}

@test "(aws provider) provider_delete_record uses jq for JSON escaping" {
  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "list-resource-record-sets" ]]; then
      # TXT record with quotes in the value
      echo '{"ResourceRecordSets": [{"Name": "_dkim.example.com.", "Type": "TXT", "TTL": 300, "ResourceRecords": [{"Value": "\"p=MIGfMA0GCSqGSIb...\""}]}]}'
      return 0
    elif [[ "$1" == "route53" && "$2" == "change-resource-record-sets" ]]; then
      echo '{"ChangeInfo": {"Id": "/change/C123", "Status": "PENDING"}}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_delete_record "Z123ABC" "_dkim.example.com" "TXT"

  assert_success
  [[ "$output" =~ "Deleted record" ]]
}

@test "(aws provider) validates required parameters for provider_get_record" {
  source providers/aws/provider.sh

  # Test missing zone_id
  run provider_get_record "" "test.example.com" "A"
  assert_failure
  [[ "$output" =~ "Zone ID, record name, and record type are required" ]]

  # Test missing record_name
  run provider_get_record "Z123ABC" "" "A"
  assert_failure
  [[ "$output" =~ "Zone ID, record name, and record type are required" ]]

  # Test missing record_type
  run provider_get_record "Z123ABC" "test.example.com" ""
  assert_failure
  [[ "$output" =~ "Zone ID, record name, and record type are required" ]]
}

@test "(aws provider) validates required parameters for provider_create_record" {
  source providers/aws/provider.sh

  # Test missing zone_id
  run provider_create_record "" "test.example.com" "A" "192.168.1.100"
  assert_failure
  [[ "$output" =~ "Zone ID, record name, record type, and record value are required" ]]

  # Test missing record_value
  run provider_create_record "Z123ABC" "test.example.com" "A" ""
  assert_failure
  [[ "$output" =~ "Zone ID, record name, record type, and record value are required" ]]
}

@test "(aws provider) validates required parameters for provider_delete_record" {
  source providers/aws/provider.sh

  run provider_delete_record "" "test.example.com" "A"
  assert_failure
  [[ "$output" =~ "Zone ID, record name, and record type are required" ]]
}

@test "(aws provider) validates required parameters for provider_get_zone_id" {
  source providers/aws/provider.sh

  run provider_get_zone_id ""
  assert_failure
  [[ "$output" =~ "Zone name is required" ]]
}

@test "(aws provider) _check_aws_response handles empty response" {
  source providers/aws/provider.sh
  run _check_aws_response "" "test context"

  assert_failure
  [[ "$output" =~ "AWS API error in test context: empty response" ]]
}

@test "(aws provider) _check_aws_response handles AWS error structure" {
  source providers/aws/provider.sh
  local error_response='{"Error": {"Code": "NoSuchHostedZone", "Message": "The hosted zone does not exist"}}'
  run _check_aws_response "$error_response" "zone lookup"

  assert_failure
  [[ "$output" =~ "AWS API error in zone lookup: NoSuchHostedZone" ]]
}

@test "(aws provider) _check_aws_response accepts valid response" {
  source providers/aws/provider.sh
  local valid_response='{"HostedZones": [{"Id": "/hostedzone/Z123", "Name": "example.com."}]}'
  run _check_aws_response "$valid_response" "zone listing"

  assert_success
}

@test "(aws provider) provider_setup_env sets default region" {
  unset AWS_DEFAULT_REGION

  source providers/aws/provider.sh
  provider_setup_env

  [[ "$AWS_DEFAULT_REGION" == "us-east-1" ]]
}

@test "(aws provider) provider_batch_create_records validates parameters" {
  source providers/aws/provider.sh

  # Test missing zone_id
  run provider_batch_create_records "" "/tmp/records.txt"
  assert_failure
  [[ "$output" =~ "Zone ID and valid records file are required" ]]

  # Test missing records file
  run provider_batch_create_records "Z123ABC" ""
  assert_failure
  [[ "$output" =~ "Zone ID and valid records file are required" ]]

  # Test non-existent records file
  run provider_batch_create_records "Z123ABC" "/tmp/nonexistent.txt"
  assert_failure
  [[ "$output" =~ "Zone ID and valid records file are required" ]]
}

@test "(aws provider) provider_batch_create_records processes records file" {
  # Create temporary records file
  local records_file="/tmp/test_aws_records.txt"
  cat >"$records_file" <<EOF
# Comment line
test1.example.com A 192.168.1.1 300
test2.example.com A 192.168.1.2 600
EOF

  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "change-resource-record-sets" ]]; then
      echo '{"ChangeInfo": {"Id": "/change/C123", "Status": "PENDING"}}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_batch_create_records "Z123ABC" "$records_file"

  assert_success
  [[ "$output" =~ "Batch created 2 records" ]]

  # Clean up
  rm -f "$records_file"
}

@test "(aws provider) provider_batch_create_records skips comments and empty lines" {
  local records_file="/tmp/test_aws_records_comments.txt"
  cat >"$records_file" <<EOF
# This is a comment
   # Another comment with leading whitespace

test1.example.com A 192.168.1.1 300

# Middle comment
test2.example.com CNAME target.example.com

EOF

  function aws() {
    if [[ "$1" == "sts" ]]; then
      return 0
    elif [[ "$1" == "route53" && "$2" == "change-resource-record-sets" ]]; then
      echo '{"ChangeInfo": {"Id": "/change/C123", "Status": "PENDING"}}'
      return 0
    fi
    return 1
  }
  export -f aws

  source providers/aws/provider.sh
  run provider_batch_create_records "Z123ABC" "$records_file"

  assert_success
  [[ "$output" =~ "Batch created 2 records" ]]

  rm -f "$records_file"
}
