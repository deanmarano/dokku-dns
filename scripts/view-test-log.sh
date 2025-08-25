#!/usr/bin/env bash
set -euo pipefail

# View the latest Docker test log
# Usage: scripts/view-test-log.sh [--tail] [--follow] [--parse]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../tmp/test-results"

if [[ ! -d "$LOG_DIR" ]]; then
    echo "❌ No test logs directory found: $LOG_DIR"
    echo "   Run tests first with: scripts/test-docker.sh"
    exit 1
fi

# Find the latest log file
LATEST_LOG=$(find "$LOG_DIR" -name "docker-tests-*.log" -type f -exec ls -t {} + 2>/dev/null | head -1)

if [[ -z "$LATEST_LOG" ]]; then
    echo "❌ No test log files found in: $LOG_DIR"
    echo "   Run tests first with: scripts/test-docker.sh"
    exit 1
fi

echo "📝 Viewing latest test log: $LATEST_LOG"

# Parse test results function
parse_test_results() {
    local log_file="$1"
    
    echo ""
    echo "=== 📊 Test Results Summary ==="
    echo ""
    
    # First try to extract results from the formal test summary if it exists
    local total_tests=0
    local total_passed=0
    local total_failed=0
    local summary_found=false
    
    # Look for the formal test results summary section
    if grep -q "📊 Test Results" "$log_file"; then
        summary_found=true
        # Strip ANSI color codes and extract numbers
        total_tests=$(grep -A5 "📊 Test Results" "$log_file" | sed 's/\x1b\[[0-9;]*m//g' | grep "Total tests:" | sed 's/.*Total tests: //' | sed 's/[^0-9].*//')
        total_passed=$(grep -A5 "📊 Test Results" "$log_file" | sed 's/\x1b\[[0-9;]*m//g' | grep "Passed:" | sed 's/.*Passed: //' | sed 's/[^0-9].*//')
        total_failed=$(grep -A5 "📊 Test Results" "$log_file" | sed 's/\x1b\[[0-9;]*m//g' | grep "Failed:" | sed 's/.*Failed: //' | sed 's/[^0-9].*//')
    fi
    
    # If we found the formal summary, use those values
    if [[ "$summary_found" = true ]] && [[ -n "$total_tests" ]] && [[ "$total_tests" -gt 0 ]]; then
        # Use the formal summary values (already extracted above)
        :  # No action needed, values already set
    else
        # Fallback to counting test markers if no formal summary
        # Count ✅ markers in test result lines
        total_passed=$(grep "✅" "$log_file" | grep -E "(test-runner.*✅|Testing.*✅)" | wc -l | tr -d ' ')
        
        # Count ❌ test failures (excluding AWS status messages)
        total_failed=$(grep "❌" "$log_file" | grep -v "no hosted zone" | grep -v "DNS record found" | grep -v "Points to different IP" | grep -v "AWS CLI not" | wc -l | tr -d ' ')
        
        total_tests=$((total_passed + total_failed))
    fi
    
    # Display results
    echo "📈 Test Execution Summary:"
    echo "   Total Tests: ${total_tests:-0}"
    echo "   ✅ Passed: ${total_passed:-0}"
    echo "   ❌ Failed: ${total_failed:-0}"
    
    # Calculate success rate if we have tests
    if [[ "${total_tests:-0}" -gt 0 ]]; then
        local success_rate=$(( (${total_passed:-0} * 100) / ${total_tests:-0} ))
        echo "   📊 Success Rate: ${success_rate}%"
    fi
    
    # Check final status
    if grep -q "All tests passed" "$log_file"; then
        echo "🎉 Overall Result: SUCCESS"
    elif grep -q "tests failed" "$log_file"; then
        echo "💥 Overall Result: FAILED"
    elif grep -q "✅.*completed successfully" "$log_file"; then
        echo "🎉 Overall Result: SUCCESS"
    elif grep -q "❌.*failed" "$log_file"; then
        echo "💥 Overall Result: FAILED"
    else
        echo "⚠️  Overall Result: INCOMPLETE"
    fi
    
    # Show test execution time
    local start_time
    local end_time
    start_time=$(grep "Started at:" "$log_file" | tail -1 | sed 's/.*Started at: //')
    end_time=$(grep "Completed at:" "$log_file" | tail -1 | sed 's/.*Completed at: //')
    
    if [[ -n "$start_time" && -n "$end_time" ]]; then
        echo "⏱️  Duration: $start_time → $end_time"
    fi
    
    # Show exit code if available
    local exit_code
    exit_code=$(grep "Exit code:" "$log_file" | tail -1 | sed 's/.*Exit code: //' | sed 's/[^0-9]//g')
    if [[ -n "$exit_code" ]]; then
        if [[ "$exit_code" -eq 0 ]]; then
            echo "🚀 Exit Code: $exit_code (Success)"
        else
            echo "⚠️  Exit Code: $exit_code (Failed)"
        fi
    fi
    
    # Show recent failures if any
    if [[ "${total_failed:-0}" -gt 0 ]]; then
        echo ""
        echo "=== 🔍 Recent Test Failures ==="
        grep "❌" "$log_file" | grep -v "no hosted zone" | grep -v "DNS record found" | grep -v "Points to different IP" | grep -v "AWS CLI not" | tail -10
    fi
    
    # Show test categories breakdown if available
    echo ""
    echo "=== 📋 Test Categories ==="
    
    # Count tests by category using simpler approach
    local help_tests
    local config_tests
    local app_tests
    local cron_tests
    local zone_tests
    local trigger_tests
    local error_tests
    
    help_tests=$(grep -A20 "Testing DNS help commands" "$log_file" 2>/dev/null | grep -B20 "Testing DNS configuration" 2>/dev/null | grep -c "✅" 2>/dev/null | tr -d '\n' | head -c 10)
    config_tests=$(grep -A20 "Testing DNS configuration" "$log_file" 2>/dev/null | grep -B20 "Testing DNS verification" 2>/dev/null | grep -c "✅" 2>/dev/null | tr -d '\n' | head -c 10)
    app_tests=$(grep -A20 "Testing DNS app management" "$log_file" 2>/dev/null | grep -B20 "Testing DNS cron" 2>/dev/null | grep -c "✅" 2>/dev/null | tr -d '\n' | head -c 10)
    cron_tests=$(grep -A30 "Testing DNS cron" "$log_file" 2>/dev/null | grep -B30 "Testing DNS zones" 2>/dev/null | grep -c "✅" 2>/dev/null | tr -d '\n' | head -c 10)
    zone_tests=$(grep -A20 "Testing DNS zones" "$log_file" 2>/dev/null | grep -B20 "Testing DNS triggers" 2>/dev/null | grep -c "✅" 2>/dev/null | tr -d '\n' | head -c 10)
    trigger_tests=$(grep -A20 "Testing DNS triggers" "$log_file" 2>/dev/null | grep -B20 "Testing error conditions" 2>/dev/null | grep -c "✅" 2>/dev/null | tr -d '\n' | head -c 10)
    error_tests=$(grep -A20 "Testing error conditions" "$log_file" 2>/dev/null | grep -c "✅" 2>/dev/null | tr -d '\n' | head -c 10)
    
    # Clean up any non-numeric values
    help_tests=${help_tests//[^0-9]/}
    config_tests=${config_tests//[^0-9]/}
    app_tests=${app_tests//[^0-9]/}
    cron_tests=${cron_tests//[^0-9]/}
    zone_tests=${zone_tests//[^0-9]/}
    trigger_tests=${trigger_tests//[^0-9]/}
    error_tests=${error_tests//[^0-9]/}
    
    # Default to 0 if empty
    help_tests=${help_tests:-0}
    config_tests=${config_tests:-0}
    app_tests=${app_tests:-0}
    cron_tests=${cron_tests:-0}
    zone_tests=${zone_tests:-0}
    trigger_tests=${trigger_tests:-0}
    error_tests=${error_tests:-0}
    
    # Only show categories that have tests
    [[ "$help_tests" -gt 0 ]] && echo "   🔍 Help Commands: $help_tests tests"
    [[ "$config_tests" -gt 0 ]] && echo "   ⚙️  Configuration: $config_tests tests"
    [[ "$app_tests" -gt 0 ]] && echo "   📱 App Management: $app_tests tests"
    [[ "$cron_tests" -gt 0 ]] && echo "   ⏰ Cron Functionality: $cron_tests tests"
    [[ "$zone_tests" -gt 0 ]] && echo "   🌐 Zone Management: $zone_tests tests"
    [[ "$trigger_tests" -gt 0 ]] && echo "   🔄 App Triggers: $trigger_tests tests"
    [[ "$error_tests" -gt 0 ]] && echo "   ❗ Error Conditions: $error_tests tests"
    
    echo ""
}

case "${1:-}" in
    --tail)
        echo ""
        tail -50 "$LATEST_LOG"
        ;;
    --follow)
        echo ""
        tail -f "$LATEST_LOG"
        ;;
    --parse)
        parse_test_results "$LATEST_LOG"
        ;;
    --help)
        echo "Usage: $0 [--tail|--follow|--parse]"
        echo ""
        echo "Options:"
        echo "  --tail     Show last 50 lines of test log"
        echo "  --follow   Follow test log in real-time"
        echo "  --parse    Parse and summarize test results"
        echo "  (no args)  Show full test log"
        ;;
    "")
        echo ""
        cat "$LATEST_LOG"
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac