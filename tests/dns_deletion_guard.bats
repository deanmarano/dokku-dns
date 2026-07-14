#!/usr/bin/env bats

load test_helper

# Regression tests for the stale-deletion-queue bug: deletions are queued when a domain is
# removed, but nothing invalidated the queue if the domain later came back. Re-adding a
# vhost left an entry that would delete a live record — and --force would do it silently.

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test1.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  create_test_app guard-app
  add_test_domains guard-app live.test1.com
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" guard-app >/dev/null 2>&1 || true
}

teardown() {
  cleanup_dns_data
}

queue_deletion() {
  local domain="$1"
  echo "$domain:ZONE123:$(date +%s)" >>"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
}

@test "(deletion guard) a live vhost is never deleted, even with --force" {
  queue_deletion live.test1.com

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" --force
  # Match the per-domain line, not the "Skipped: 0" summary counter.
  [[ "$output" == *"live.test1.com... ⏭️"* ]]
  [[ "$output" != *"✅ Deleted"* ]]
  [[ "$output" != *"Already deleted or not found"* ]]
  [[ "$output" == *"Deleted: 0"* ]]
}

@test "(deletion guard) a live vhost is dropped from the queue" {
  queue_deletion live.test1.com

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" --force

  run cat "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
  [[ "$output" != *"live.test1.com"* ]]
}

@test "(deletion guard) rescued domains are reported to the operator" {
  queue_deletion live.test1.com

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" --force
  [[ "$output" == *"live vhost"* ]]
  [[ "$output" == *"not deleted"* ]]
}

@test "(deletion guard) a genuinely dead domain is still processed" {
  queue_deletion dead.test1.com

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" --force
  # Must not be rescued — it is not a vhost any more.
  [[ "$output" != *"dead.test1.com... ⏭️"* ]]
}

@test "(deletion guard) rescuing one domain leaves other entries queued" {
  queue_deletion live.test1.com
  queue_deletion other-dead.test1.com

  # No stdin: EOF at the prompt must mean "no", not abort the run.
  run bash -c "dokku '$PLUGIN_COMMAND_PREFIX:sync:deletions' </dev/null"

  # The live one is dequeued; the dead one was only skipped at the prompt, so the queue
  # rewrite must preserve it.
  run cat "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
  [[ "$output" != *"live.test1.com"* ]]
  [[ "$output" == *"other-dead.test1.com"* ]]
}

@test "(deletion guard) non-interactive run completes instead of aborting at the prompt" {
  queue_deletion other-dead.test1.com

  run bash -c "dokku '$PLUGIN_COMMAND_PREFIX:sync:deletions' </dev/null"
  # Under set -e, read's EOF failure used to kill the run before the summary printed.
  [[ "$output" == *"Summary:"* ]]
  [[ "$output" != *"✅ Deleted"* ]]
}
