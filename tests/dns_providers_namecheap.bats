#!/usr/bin/env bats
load test_helper

# Namecheap's setHosts replaces every record in a domain, so these tests focus
# on the read-modify-write round trip never losing or mangling records.

setup() {
  export NAMECHEAP_API_USER="test-user"
  export NAMECHEAP_API_KEY="test-key"
  export NAMECHEAP_CLIENT_IP="192.0.2.1"
  CALLS_FILE="$BATS_TEST_TMPDIR/namecheap-calls"
  : >"$CALLS_FILE"
  export CALLS_FILE

  # Zone with records that a naive parser would mangle: a DKIM key with '/',
  # '+' and '=', an SPF record with spaces and XML-escaped quotes, a URL
  # redirect, and an MX record with a preference.
  GET_HOSTS_RESPONSE='<?xml version="1.0" encoding="utf-8"?>
<ApiResponse Status="OK" xmlns="http://api.namecheap.com/xml.response">
  <CommandResponse Type="namecheap.domains.dns.getHosts">
    <DomainDNSGetHostsResult Domain="example.com" EmailType="MX" IsUsingOurDNS="true">
      <host HostId="1" Name="@" Type="A" Address="192.0.2.10" MXPref="10" TTL="1800" AssociatedAppTitle="" FriendlyName="" IsActive="true" IsDDNSEnabled="false" />
      <host HostId="2" Name="api" Type="A" Address="192.0.2.11" MXPref="10" TTL="300" AssociatedAppTitle="" FriendlyName="" IsActive="true" IsDDNSEnabled="false" />
      <host HostId="3" Name="mail._domainkey" Type="TXT" Address="v=DKIM1; k=rsa; p=MIGfMA0G/SIb3+DQEBAQ==" MXPref="10" TTL="1800" AssociatedAppTitle="" FriendlyName="" IsActive="true" IsDDNSEnabled="false" />
      <host HostId="4" Name="@" Type="TXT" Address="v=spf1 include:_spf.example.net &quot;quoted&quot; &amp; ~all" MXPref="10" TTL="1800" AssociatedAppTitle="" FriendlyName="" IsActive="true" IsDDNSEnabled="false" />
      <host HostId="5" Name="go" Type="URL" Address="http://example.org/landing/" MXPref="10" TTL="1800" AssociatedAppTitle="" FriendlyName="" IsActive="true" IsDDNSEnabled="false" />
      <host HostId="6" Name="@" Type="MX" Address="mx1.example.net." MXPref="5" TTL="1800" AssociatedAppTitle="" FriendlyName="" IsActive="true" IsDDNSEnabled="false" />
    </DomainDNSGetHostsResult>
  </CommandResponse>
</ApiResponse>'
  export GET_HOSTS_RESPONSE

  source providers/namecheap/provider.sh

  # Record every call's arguments (one per line) in a file, since the
  # provider calls the API inside $(...) subshells.
  _namecheap_api_call() {
    local command="$1"
    shift
    {
      echo "=== $command"
      printf '%s\n' "$@"
    } >>"$CALLS_FILE"
    case "$command" in
      namecheap.domains.dns.getHosts) printf '%s' "$GET_HOSTS_RESPONSE" ;;
      namecheap.domains.dns.setHosts) printf '%s' '<ApiResponse Status="OK"><CommandResponse><DomainDNSSetHostsResult Domain="example.com" IsSuccess="true" /></CommandResponse></ApiResponse>' ;;
    esac
  }
}

# Arguments of the setHosts call, one per line
set_hosts_args() {
  sed -n '/^=== namecheap.domains.dns.setHosts$/,/^=== /p' "$CALLS_FILE" | grep -v '^=== '
}

@test "(namecheap provider) loads and validates its interface" {
  run bash -c "source providers/loader.sh && validate_provider namecheap"
  assert_success
}

@test "(namecheap provider) requires API user and key" {
  unset NAMECHEAP_API_KEY
  run provider_validate_credentials
  assert_failure
  assert_output_contains "Missing required environment variable: NAMECHEAP_API_KEY"
}

@test "(namecheap provider) reads a record value and decodes XML entities" {
  run provider_get_record example.com example.com TXT
  assert_success
  assert_output 'v=spf1 include:_spf.example.net "quoted" & ~all'
}

@test "(namecheap provider) creating a record keeps every existing record intact" {
  run provider_create_record example.com new.example.com A 192.0.2.20 600
  assert_success
  assert_output_contains "Created record: new.example.com -> 192.0.2.20"

  run set_hosts_args
  # all six existing records are written back, plus the new one
  [ "$(echo "$output" | grep -c '^HostName')" -eq 7 ]
  # values containing '/', '+', '=', spaces and decoded entities survive verbatim
  assert_output_contains "Address3=v=DKIM1; k=rsa; p=MIGfMA0G/SIb3+DQEBAQ=="
  assert_output_contains 'Address4=v=spf1 include:_spf.example.net "quoted" & ~all'
  assert_output_contains "Address5=http://example.org/landing/"
  # MX preference and the domain's mail setting are carried through
  assert_output_contains "MXPref6=5"
  assert_output_contains "EmailType=MX"
  # the new record
  assert_output_contains "HostName7=new"
  assert_output_contains "Address7=192.0.2.20"
  assert_output_contains "TTL7=600"
}

@test "(namecheap provider) updating a record changes only that record" {
  run provider_create_record example.com api.example.com A 192.0.2.99 300
  assert_success
  assert_output_contains "Updated record: api.example.com"

  run set_hosts_args
  [ "$(echo "$output" | grep -c '^HostName')" -eq 6 ]
  assert_output_contains "Address2=192.0.2.99"
  assert_output_contains "Address1=192.0.2.10"
}

@test "(namecheap provider) deleting a record removes only that record" {
  run provider_delete_record example.com api.example.com A
  assert_success

  run set_hosts_args
  [ "$(echo "$output" | grep -c '^HostName')" -eq 5 ]
  [[ "$output" != *"192.0.2.11"* ]]
  assert_output_contains "Address2=v=DKIM1; k=rsa; p=MIGfMA0G/SIb3+DQEBAQ=="
  assert_output_contains "EmailType=MX"
}

@test "(namecheap provider) refuses to write when a record cannot be parsed" {
  # a <host> element split across lines can't be parsed reliably
  GET_HOSTS_RESPONSE="${GET_HOSTS_RESPONSE/<host HostId=\"2\" Name=\"api\"/<host HostId=\"2\"
 Name=\"api\"}"
  run provider_create_record example.com new.example.com A 192.0.2.20
  assert_failure
  assert_output_contains "refusing to modify it"
  [ -z "$(set_hosts_args)" ]
}

@test "(namecheap provider) refuses to manage a domain not using Namecheap DNS" {
  GET_HOSTS_RESPONSE="${GET_HOSTS_RESPONSE/IsUsingOurDNS=\"true\"/IsUsingOurDNS=\"false\"}"
  run provider_create_record example.com new.example.com A 192.0.2.20
  assert_failure
  assert_output_contains "not using Namecheap DNS"
  [ -z "$(set_hosts_args)" ]
}

@test "(namecheap provider) sends every value URL-encoded in a POST body" {
  unset -f _namecheap_api_call
  source providers/namecheap/provider.sh
  curl() { printf '%s\n' "$@" >"$CALLS_FILE"; }
  _namecheap_api_call namecheap.domains.dns.setHosts "Address1=v=spf1 a+b&c=d"
  run cat "$CALLS_FILE"
  assert_output_contains "POST"
  [ "$(grep -c -- "--data-urlencode" "$CALLS_FILE")" -eq 6 ]
  assert_output_contains "Address1=v=spf1 a+b&c=d"
  # the API key is never placed in the URL
  [ "$(tail -1 "$CALLS_FILE")" = "$NAMECHEAP_API_BASE" ]
}
