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
    cat <<'EOF'
{"success":true,"result":{"id":"mock-user-id","email":"mock@example.com"}}
EOF
    ;;
  *api.cloudflare.com/client/v4/zones/*/dns_records/*)
    # Individual record operations (PUT/DELETE)
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
    ;;
  *api.cloudflare.com/client/v4/zones/*/dns_records*)
    # Record listing/creation
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
    ;;
  *api.cloudflare.com/client/v4/zones*)
    if [[ -f "$RESPONSES_DIR/cf-zones.json" ]]; then
      cat "$RESPONSES_DIR/cf-zones.json"
    else
      cat <<'EOF'
{"success":true,"result":[{"id":"mock-zone-id","name":"example.com"}]}
EOF
    fi
    ;;
  # DigitalOcean API
  *api.digitalocean.com/v2/domains/*/records*)
    case "$method" in
      GET)
        echo '{"domain_records":[]}'
        ;;
      POST)
        echo '{"domain_record":{"id":12345,"type":"A","name":"test","data":"1.2.3.4","ttl":300}}'
        ;;
      DELETE)
        echo '{}'
        ;;
    esac
    ;;
  *api.digitalocean.com/v2/domains*)
    echo '{"domains":[{"name":"example.com"}]}'
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
