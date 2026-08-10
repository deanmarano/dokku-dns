#!/usr/bin/env bats
load test_helper

setup() {
  export OVH_APPLICATION_KEY="test-application-key"
  export OVH_APPLICATION_SECRET="test-application-secret"
  export OVH_CONSUMER_KEY="test-consumer-key"
}

@test "(ovh provider) loads and validates its interface" {
  run bash -c "source providers/loader.sh && validate_provider ovh"
  assert_success
}

@test "(ovh provider) requires all three credentials" {
  unset OVH_APPLICATION_KEY
  source providers/ovh/provider.sh
  run provider_validate_credentials
  assert_failure
  [[ "$output" == *"Missing required environment variable: OVH_APPLICATION_KEY"* ]]
}

@test "(ovh provider) finds a parent zone" {
  source providers/ovh/provider.sh
  provider_list_zones() { printf '%s\n' example.com test.org; }
  run provider_get_zone_id api.example.com
  assert_success
  assert_output "example.com"
}

@test "(ovh provider) creates a subdomain record and refreshes its zone" {
  source providers/ovh/provider.sh
  calls=()
  _ovh_api_call() {
    calls+=("$1 $2 $3")
    case "$1 $2" in
      "GET /domain/zone/example.com/record?fieldType=A&subDomain=api") printf '[]' ;;
      "POST /domain/zone/example.com/record") printf '42' ;;
      "POST /domain/zone/example.com/refresh") printf '{}' ;;
    esac
  }
  _ovh_refresh_zone() { _ovh_api_call POST "/domain/zone/$1/refresh" '{}'; }
  provider_create_record example.com api.example.com A 192.0.2.10 600
  [[ "${calls[*]}" == *"POST /domain/zone/example.com/record"* ]]
  [[ "${calls[*]}" == *"POST /domain/zone/example.com/refresh"* ]]
}

@test "(ovh provider) reads the apex record using an empty subdomain" {
  source providers/ovh/provider.sh
  _ovh_api_call() {
    case "$1 $2" in
      "GET /domain/zone/example.com/record?fieldType=A&subDomain=") printf '[42]' ;;
      "GET /domain/zone/example.com/record/42") printf '{"target":"192.0.2.10"}' ;;
    esac
  }
  run provider_get_record example.com example.com A
  assert_success
  assert_output "192.0.2.10"
}
