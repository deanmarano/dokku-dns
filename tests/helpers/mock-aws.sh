#!/usr/bin/env bash
# Mock AWS CLI that logs calls and returns canned responses
# Set MOCK_AWS_LOG to a file path to log all calls as JSONL
# Set MOCK_AWS_RESPONSES_DIR to a directory containing response files

LOG_FILE="${MOCK_AWS_LOG:-/tmp/mock-aws-calls.jsonl}"
RESPONSES_DIR="${MOCK_AWS_RESPONSES_DIR:-/tmp/mock-aws-responses}"

# Log the call
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
args_json=$(printf '%s\n' "$@" | jq -R . | jq -sc .)
echo "{\"timestamp\":\"$timestamp\",\"command\":\"aws\",\"args\":$args_json}" >>"$LOG_FILE"

# Route based on subcommand
case "$1" in
  sts)
    case "$2" in
      get-caller-identity)
        cat <<'EOF'
{"UserId":"MOCKUSERID123","Account":"123456789012","Arn":"arn:aws:iam::123456789012:user/mock-user"}
EOF
        ;;
    esac
    ;;
  route53)
    case "$2" in
      list-hosted-zones)
        if [[ -f "$RESPONSES_DIR/list-hosted-zones.json" ]]; then
          cat "$RESPONSES_DIR/list-hosted-zones.json"
        else
          cat <<'EOF'
{"HostedZones":[{"Id":"/hostedzone/Z1234MOCK","Name":"example.com.","CallerReference":"mock","Config":{"PrivateZone":false}}]}
EOF
        fi
        ;;
      list-resource-record-sets)
        # Extract zone ID from args
        zone_id=""
        for i in "$@"; do
          if [[ "$prev" == "--hosted-zone-id" ]]; then
            zone_id="$i"
          fi
          prev="$i"
        done
        response_file="$RESPONSES_DIR/list-records-${zone_id}.json"
        if [[ -f "$response_file" ]]; then
          cat "$response_file"
        else
          echo '{"ResourceRecordSets":[]}'
        fi
        ;;
      change-resource-record-sets)
        # Extract change batch from args
        change_batch=""
        for i in "$@"; do
          if [[ "$prev" == "--change-batch" ]]; then
            change_batch="$i"
          fi
          prev="$i"
        done
        # Log the change batch (compact JSON to single line for JSONL)
        change_batch_compact=$(echo "$change_batch" | jq -c . 2>/dev/null || echo '{}')
        echo "{\"timestamp\":\"$timestamp\",\"command\":\"aws\",\"subcommand\":\"change-resource-record-sets\",\"change_batch\":$change_batch_compact}" >>"$LOG_FILE"
        cat <<'EOF'
{"ChangeInfo":{"Id":"/change/CMOCK123","Status":"PENDING","SubmittedAt":"2026-01-01T00:00:00Z"}}
EOF
        ;;
    esac
    ;;
esac
