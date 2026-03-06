#!/usr/bin/env bash
# Mock curl that logs calls and returns canned responses for DNS provider APIs
# Set MOCK_CURL_LOG to a file path to log all calls as JSONL
# Set MOCK_CURL_RESPONSES_DIR to a directory containing response files

LOG_FILE="${MOCK_CURL_LOG:-/tmp/mock-curl-calls.jsonl}"
RESPONSES_DIR="${MOCK_CURL_RESPONSES_DIR:-/tmp/mock-curl-responses}"

# Parse curl arguments
method="GET"
url=""
data=""
headers=()
prev=""

for arg in "$@"; do
  case "$prev" in
    -X) method="$arg" ;;
    -d) data="$arg" ;;
    -H) headers+=("$arg") ;;
  esac
  prev="$arg"
done

# Last non-flag argument is the URL
for arg in "$@"; do
  if [[ "$arg" != -* && "$prev" != "-X" && "$prev" != "-d" && "$prev" != "-H" && "$prev" != "-o" ]]; then
    url="$arg"
  fi
  prev="$arg"
done

# Log the call
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
headers_json=$(printf '%s\n' "${headers[@]}" | jq -R . 2>/dev/null | jq -sc . 2>/dev/null || echo '[]')
if [[ -n "$data" ]]; then
  data_compact=$(echo "$data" | jq -c . 2>/dev/null || echo "{}")
  echo "{\"timestamp\":\"$timestamp\",\"command\":\"curl\",\"method\":\"$method\",\"url\":\"$url\",\"data\":$data_compact,\"headers\":$headers_json}" >>"$LOG_FILE"
else
  echo "{\"timestamp\":\"$timestamp\",\"command\":\"curl\",\"method\":\"$method\",\"url\":\"$url\",\"headers\":$headers_json}" >>"$LOG_FILE"
fi

# Route based on URL pattern
case "$url" in
  # Cloudflare API
  *api.cloudflare.com/client/v4/user*)
    if [[ -f "$RESPONSES_DIR/cf-error" ]]; then
      echo '{"success":false,"errors":[{"code":9103,"message":"Unknown X-Auth-Key or X-Auth-Email"}]}'
    else
      cat <<'EOF'
{"success":true,"result":{"id":"mock-user-id","email":"mock@example.com"}}
EOF
    fi
    ;;
  *api.cloudflare.com/client/v4/zones/*/dns_records/*)
    # Individual record operations (PUT/DELETE)
    if [[ -f "$RESPONSES_DIR/cf-error" ]]; then
      echo '{"success":false,"errors":[{"code":7003,"message":"Could not route to /zones/dns_records"}]}'
    else
      case "$method" in
        PUT)
          cat <<'EOF'
{"success":true,"result":{"id":"mock-record-id","type":"A","name":"test.example.com","content":"1.2.3.4","ttl":300}}
EOF
          ;;
        DELETE)
          cat <<'EOF'
{"success":true,"result":{"id":"mock-record-id"}}
EOF
          ;;
      esac
    fi
    ;;
  *api.cloudflare.com/client/v4/zones/*/dns_records*)
    # Record listing/creation
    if [[ -f "$RESPONSES_DIR/cf-error" ]]; then
      echo '{"success":false,"errors":[{"code":7003,"message":"Could not route to /zones/dns_records"}]}'
    else
      case "$method" in
        GET)
          # Check for canned response
          if [[ -f "$RESPONSES_DIR/cf-dns-records.json" ]]; then
            cat "$RESPONSES_DIR/cf-dns-records.json"
          else
            echo '{"success":true,"result":[]}'
          fi
          ;;
        POST)
          cat <<'EOF'
{"success":true,"result":{"id":"mock-new-record-id","type":"A","name":"test.example.com","content":"1.2.3.4","ttl":300}}
EOF
          ;;
      esac
    fi
    ;;
  *api.cloudflare.com/client/v4/zones*)
    if [[ -f "$RESPONSES_DIR/cf-error" ]]; then
      echo '{"success":false,"errors":[{"code":9103,"message":"Unknown X-Auth-Key or X-Auth-Email"}]}'
    elif [[ -f "$RESPONSES_DIR/cf-zones.json" ]]; then
      cat "$RESPONSES_DIR/cf-zones.json"
    else
      cat <<'EOF'
{"success":true,"result":[{"id":"mock-zone-id","name":"example.com"}]}
EOF
    fi
    ;;
  # DigitalOcean API
  *api.digitalocean.com/v2/account*)
    if [[ -f "$RESPONSES_DIR/do-error" ]]; then
      echo '{"id":"Unauthorized","message":"Unable to authenticate you"}'
    else
      echo '{"account":{"uuid":"mock-account-uuid","email":"mock@example.com","status":"active"}}'
    fi
    ;;
  *api.digitalocean.com/v2/domains/*/records/*)
    # Individual record operations (PUT/DELETE)
    if [[ -f "$RESPONSES_DIR/do-error" ]]; then
      echo '{"id":"not_found","message":"The resource you requested could not be found."}'
    else
      case "$method" in
        PUT)
          echo '{"domain_record":{"id":12345,"type":"A","name":"test","data":"1.2.3.4","ttl":1800}}'
          ;;
        DELETE)
          # DigitalOcean returns empty on successful delete
          echo ''
          ;;
      esac
    fi
    ;;
  *api.digitalocean.com/v2/domains/*/records*)
    if [[ -f "$RESPONSES_DIR/do-error" ]]; then
      echo '{"id":"not_found","message":"The resource you requested could not be found."}'
    else
      # Extract domain from URL: /v2/domains/<domain>/records
      domain_name=$(echo "$url" | sed -n 's|.*/v2/domains/\([^/]*\)/records.*|\1|p')
      case "$method" in
        GET)
          if [[ -f "$RESPONSES_DIR/do-records-${domain_name}.json" ]]; then
            cat "$RESPONSES_DIR/do-records-${domain_name}.json"
          else
            echo '{"domain_records":[]}'
          fi
          ;;
        POST)
          echo '{"domain_record":{"id":12345,"type":"A","name":"test","data":"1.2.3.4","ttl":1800}}'
          ;;
      esac
    fi
    ;;
  *api.digitalocean.com/v2/domains/*)
    # Single domain lookup: /v2/domains/<domain>
    if [[ -f "$RESPONSES_DIR/do-error" ]]; then
      echo '{"id":"not_found","message":"The resource you requested could not be found."}'
    else
      domain_name=$(echo "$url" | sed -n 's|.*/v2/domains/\([^/?]*\).*|\1|p')
      echo "{\"domain\":{\"name\":\"$domain_name\"}}"
    fi
    ;;
  *api.digitalocean.com/v2/domains*)
    if [[ -f "$RESPONSES_DIR/do-error" ]]; then
      echo '{"id":"Unauthorized","message":"Unable to authenticate you"}'
    elif [[ -f "$RESPONSES_DIR/do-domains.json" ]]; then
      cat "$RESPONSES_DIR/do-domains.json"
    else
      echo '{"domains":[{"name":"example.com"}]}'
    fi
    ;;
  # IP detection services (used by get_server_ip)
  *ifconfig.me* | *icanhazip.com* | *checkip.amazonaws.com* | *ipecho.net*)
    echo "192.0.2.1"
    ;;
  *)
    # Unknown URL - return empty
    echo ""
    ;;
esac
