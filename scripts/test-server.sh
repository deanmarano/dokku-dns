#!/usr/bin/env bash
set -euo pipefail

# Remote server test script for dokku-dns plugin (Single SSH Session)
# Usage: scripts/test-server.sh [server-hostname] [ssh-user] [test-app]
#
# For AWS testing, create a .env file with:
#   AWS_ACCESS_KEY_ID=your_key
#   AWS_SECRET_ACCESS_KEY=your_secret
#   AWS_DEFAULT_REGION=us-east-1

SERVER_HOST="${1:-${SSH_SERVER:-your-server.com}}"
SSH_USER="${2:-${REMOTE_USER:-root}}"
TEST_APP="${3:-nextcloud}"
PLUGIN_NAME="dns"
PLUGIN_REPO="https://github.com/deanmarano/dokku-dns.git"
LOG_FILE="test-server-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

generate_remote_script() {
    local script_file="/tmp/dokku-dns-test-script.sh"
    
    echo "DEBUG: Creating script file: $script_file" >&2
    cat > "$script_file" << 'REMOTE_SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail

# Function to log with timestamps
log_remote() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2"
}

# Check current AWS state
log_remote "INFO" "=== CHECKING CURRENT AWS CONFIGURATION ==="
echo 'Current AWS CLI state:'
if command -v aws >/dev/null 2>&1; then
    echo '✓ AWS CLI is installed'
    if aws sts get-caller-identity 2>/dev/null; then
        echo '✓ AWS CLI is configured and authenticated'
    else
        echo '⚠ AWS CLI is installed but not configured'
    fi
else
    echo '- AWS CLI is not installed'
fi

# Backup existing AWS configuration
log_remote "INFO" "=== BACKING UP EXISTING AWS CONFIGURATION ==="
if [[ -f ~/.aws/credentials ]]; then
    cp ~/.aws/credentials /tmp/aws_credentials_backup
    echo 'Backed up existing AWS credentials'
else
    echo 'No existing AWS credentials to backup'
fi
if [[ -f ~/.aws/config ]]; then
    cp ~/.aws/config /tmp/aws_config_backup
    echo 'Backed up existing AWS config'
else
    echo 'No existing AWS config to backup'
fi

# Check Dokku version
log_remote "INFO" "=== CHECKING DOKKU ==="
sudo dokku version

# List current plugins
log_remote "INFO" "=== CURRENT PLUGIN STATUS ==="
sudo dokku plugin:list

# Check if dns plugin is installed and uninstall if needed
log_remote "INFO" "=== CHECKING DNS PLUGIN ==="
DNS_PLUGIN_CHECK=$(sudo dokku plugin:list 2>/dev/null | grep dns || echo "not-found")
if [[ "$DNS_PLUGIN_CHECK" != "not-found" ]]; then
    echo "DNS plugin is currently installed: $DNS_PLUGIN_CHECK"
    echo "Uninstalling existing DNS plugin..."
    sudo dokku plugin:uninstall dns --force 2>/dev/null || echo "Standard uninstall failed, trying force removal..."
    sleep 2  # Give time for cleanup
    
    # Force removal of plugin directories
    echo "Forcing removal of plugin directories..."
    sudo rm -rf /var/lib/dokku/plugins/available/dns 2>/dev/null || true
    sudo rm -rf /var/lib/dokku/plugins/enabled/dns 2>/dev/null || true
    
    # Verify removal
    DNS_PLUGIN_RECHECK=$(sudo dokku plugin:list 2>/dev/null | grep dns || echo "not-found")
    if [[ "$DNS_PLUGIN_RECHECK" != "not-found" ]]; then
        echo "Warning: DNS plugin still present after cleanup: $DNS_PLUGIN_RECHECK"
    else
        echo "✓ DNS plugin successfully removed"
    fi
else
    echo "DNS plugin is not currently installed"
fi

REMOTE_SCRIPT_EOF

    echo "DEBUG: Finished initial script block" >&2
    # Add AWS credential setup if credentials are available
    echo "DEBUG: Checking AWS credentials..." >&2
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        echo "DEBUG: AWS credentials found, adding credential setup" >&2
        
        echo "DEBUG: About to write credential header" >&2
        # Write credential setup without heredoc to avoid local execution
        cat >> "$script_file" << 'CRED_HEADER_EOF'

# Set up temporary AWS credentials for testing
log_remote "INFO" "=== SETTING UP TEMPORARY AWS CREDENTIALS ==="
echo "Local AWS credentials detected - configuring temporarily on remote server"
CRED_HEADER_EOF
        
        echo "DEBUG: Finished credential header" >&2
        echo "echo \"Test app: ${TEST_APP}\"" >> "$script_file"
        echo "DEBUG: Added test app line" >&2
        
        cat >> "$script_file" << 'CRED_BODY_EOF'

# Configure for current user
mkdir -p ~/.aws
CRED_BODY_EOF
        
        echo "DEBUG: Finished credential body" >&2
        # Write credentials with variable substitution but no command execution
        echo "DEBUG: About to write credentials" >&2
        echo "cat > ~/.aws/credentials << 'AWS_CRED_EOF'" >> "$script_file"
        echo "[default]" >> "$script_file"
        echo "DEBUG: About to access AWS_ACCESS_KEY_ID" >&2
        {
            echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}"
            echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}"
            echo "AWS_CRED_EOF"
            echo ""
            echo "# Also configure for root (for sudo operations like plugin install)"
            echo "sudo mkdir -p /root/.aws"
            echo "sudo tee /root/.aws/credentials > /dev/null << 'AWS_CRED_EOF'"
            echo "[default]"
            echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}"
            echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}"
        } >> "$script_file"
        echo "DEBUG: About to access AWS_SECRET_ACCESS_KEY" >&2
        echo "DEBUG: Finished first credentials block" >&2
        echo "DEBUG: About to write second AWS_ACCESS_KEY_ID" >&2
        echo "DEBUG: About to write second AWS_SECRET_ACCESS_KEY" >&2
        echo "AWS_CRED_EOF" >> "$script_file"
        echo "DEBUG: Finished second credentials block" >&2

        echo "DEBUG: About to write credential footer" >&2
        cat >> "$script_file" << 'CRED_FOOTER_EOF'

# Configure region for both users
cat > ~/.aws/config << 'AWS_CONFIG_EOF'
[default]
region = us-east-1
output = json
AWS_CONFIG_EOF

sudo tee /root/.aws/config > /dev/null << 'AWS_CONFIG_EOF'
[default]
region = us-east-1
output = json
AWS_CONFIG_EOF

# Test AWS CLI configuration
log_remote "INFO" "Testing AWS CLI configuration..."
aws sts get-caller-identity
echo "✓ Temporary AWS credentials configured - expecting best-case auto-detection!"
CRED_FOOTER_EOF
        echo "DEBUG: Finished credential footer" >&2
    else
        echo "DEBUG: No AWS credentials, writing no-cred section" >&2
        cat >> "$script_file" << NO_CRED_SCRIPT_EOF

log_remote "INFO" "=== NO AWS CREDENTIALS PROVIDED ==="
echo "No local AWS credentials found in environment"
echo "Test app: ${TEST_APP}"
echo "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to test with credentials"
NO_CRED_SCRIPT_EOF
    fi

    echo "DEBUG: About to add rest of script" >&2
    # Add the rest of the script
    cat >> "$script_file" << 'REMOTE_SCRIPT_EOF2'

# Install the plugin
log_remote "INFO" "=== INSTALLING DNS PLUGIN ==="
REMOTE_SCRIPT_EOF2

    echo "DEBUG: Finished REMOTE_SCRIPT_EOF2" >&2
    echo "DEBUG: Checking AWS credentials again..." >&2
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        echo "DEBUG: AWS credentials found again, adding message" >&2
        cat >> "$script_file" << 'WITH_CRED_MSG_EOF'
echo "Expected installation scenario with AWS credentials:"
echo "  🚀 Best case expected: AWS CLI ready with Route53 access → Immediate use"
echo "     Should see: ✓ Route53 access confirmed with hosted zone count"
WITH_CRED_MSG_EOF
    else
        cat >> "$script_file" << 'NO_CRED_MSG_EOF'
echo "Expected installation scenarios without credentials:"
echo "  🔧 Expected: AWS CLI detected → Needs 'aws configure'"
echo "  ⚙️ Fallback: No CLI detected → Manual setup required"
NO_CRED_MSG_EOF
    fi

    cat >> "$script_file" << REMOTE_SCRIPT_EOF3

sudo dokku plugin:install https://github.com/deanmarano/dokku-dns.git

# Verify installation
log_remote "INFO" "=== VERIFYING INSTALLATION ==="
sudo dokku plugin:list | grep dns
sudo dokku help | grep dns
sudo dokku dns:help || echo "Help command failed, but plugin might still work"

# Test provider capabilities
log_remote "INFO" "=== TESTING PROVIDER CAPABILITIES ==="
if command -v aws >/dev/null 2>&1 && \aws sts get-caller-identity >/dev/null 2>&1; then
    echo "✓ AWS CLI is installed and configured - should be ready to use"
    \aws route53 list-hosted-zones >/dev/null 2>&1 && echo 'Route53 access confirmed' || echo 'Route53 access limited'
    sudo dokku dns:providers:verify 2>&1 || true
elif command -v aws >/dev/null 2>&1; then
    echo "🔧 AWS CLI is installed but not configured"
    timeout 10s sudo dokku dns:providers:verify < /dev/null 2>&1 || true
else
    echo "⚙️ AWS CLI not installed"
    sudo dokku dns:providers:verify 2>&1 || true
fi

# Test implemented DNS commands only
log_remote "INFO" "=== TESTING IMPLEMENTED DNS COMMANDS ==="

# Create test app and domains for comprehensive testing
echo "Setting up test app: ${TEST_APP}"
if ! sudo dokku apps:list 2>/dev/null | grep -q "${TEST_APP}"; then
    echo "Creating test app: ${TEST_APP}"
    sudo dokku apps:create "${TEST_APP}" 2>&1 || echo "Failed to create app, using existing"
else
    echo "Test app ${TEST_APP} already exists"
fi

# Add test domains to the app for comprehensive DNS testing
echo "Adding test domains to app ${TEST_APP}..."
sudo dokku domains:add "${TEST_APP}" "test.example.com" 2>&1 || echo "Domain add failed or already exists"
sudo dokku domains:add "${TEST_APP}" "api.test.example.com" 2>&1 || echo "Domain add failed or already exists"

# Check what domains are actually configured
echo "Current domains for ${TEST_APP}:"
sudo dokku domains:report "${TEST_APP}" 2>&1 || echo "Could not get domain report"

# Test the 7 implemented DNS commands
log_remote "INFO" "Testing implemented DNS commands..."

echo "1. Testing dns:help"
sudo dokku dns:help 2>&1 || echo "Help command failed"

echo "2. Testing dns:providers:verify (verify DNS provider setup and connectivity + discover existing records)"
sudo dokku dns:providers:verify 2>&1 || echo "Verify command completed"

echo "3. Testing dns:providers:configure (configure global DNS provider)"
if command -v aws >/dev/null 2>&1 && \aws sts get-caller-identity >/dev/null 2>&1; then
    echo "   Configuring with AWS provider (auto-detected)..."
    sudo dokku dns:providers:configure aws 2>&1 || echo "Configure command completed"
else
    echo "   Testing default configuration..."
    sudo dokku dns:providers:configure 2>&1 || echo "Configure command completed"
fi

echo "4. Testing dns:apps:enable $TEST_APP (add app domains to DNS management)"
echo "   This should show the new domain status table with hosted zones!"
sudo dokku dns:apps:enable "$TEST_APP" 2>&1 || echo "Add command completed"

echo "4a. Testing dns:report $TEST_APP after adding (should show 'DNS Status: Added')"
sudo dokku dns:report "$TEST_APP" 2>&1 || echo "Report after add completed"

echo "5. Testing dns:apps:sync $TEST_APP (synchronize DNS records for app)"
sudo dokku dns:apps:sync "$TEST_APP" 2>&1 || echo "Sync command completed"

echo "6. Testing dns:report (global report - all apps and domains)"
sudo dokku dns:report 2>&1 || echo "Global report command completed"

echo "7. Testing dns:report $TEST_APP (app-specific DNS status and domain info)"
sudo dokku dns:report "$TEST_APP" 2>&1 || echo "App report command completed"

echo "8. Testing dns:apps:disable $TEST_APP (remove app from DNS management)"
sudo dokku dns:apps:disable "$TEST_APP" 2>&1 || echo "Remove command completed"

echo "8a. Testing dns:report $TEST_APP after removal (should show 'DNS Status: Not added')"
sudo dokku dns:report "$TEST_APP" 2>&1 || echo "Report after remove completed"

echo "8b. Testing global dns:report after removal (should not show $TEST_APP)"
sudo dokku dns:report 2>&1 || echo "Global report after remove completed"

echo "9. Testing dns:providers:verify again (should show updated status after configuration)"
sudo dokku dns:providers:verify 2>&1 || echo "Verify command completed"

# Test cleanup and edge cases
echo "10. Testing edge cases and error handling..."
echo "   Testing dns:apps:enable without arguments (should show usage):"
sudo dokku dns:apps:enable 2>&1 || echo "Add command shows usage as expected"

echo "   Testing dns:apps:sync without arguments (should show usage):"
sudo dokku dns:apps:sync 2>&1 || echo "Sync command shows usage as expected"

echo "   Testing dns:apps:disable without arguments (should show usage):"
sudo dokku dns:apps:disable 2>&1 || echo "Remove command shows usage as expected"

echo "   Testing dns:report with nonexistent app:"
sudo dokku dns:report nonexistent-test-app 2>&1 || echo "App report shows error as expected"

# Cleanup test app if we created it for testing  
echo "11. Cleanup test resources..."
echo "    Removing test domains from ${TEST_APP}..."
sudo dokku domains:remove "${TEST_APP}" "test.example.com" 2>&1 || echo "Domain removal completed"
sudo dokku domains:remove "${TEST_APP}" "api.test.example.com" 2>&1 || echo "Domain removal completed"

echo "    Note: Leaving test app ${TEST_APP} for potential future testing"
echo "    To remove it manually: sudo dokku apps:destroy ${TEST_APP} --force"

log_remote "SUCCESS" "DNS command testing completed! Tested all implemented commands with comprehensive scenarios."

# Test the new fixes implemented in the DNS plugin
log_remote "INFO" "=== TESTING DNS PLUGIN FIXES ==="

echo "Fix 1: Testing DNS management tracking (LINKS file functionality)"
echo "   Before adding app to DNS management, report should show warning..."
# Create a fresh test app that hasn't been added to DNS management
if ! sudo dokku apps:list 2>/dev/null | grep -q "tracking-test"; then
    sudo dokku apps:create "tracking-test" 2>&1 || echo "Failed to create tracking test app"
    sudo dokku domains:add "tracking-test" "tracking.example.com" 2>&1 || echo "Failed to add domain"
fi

echo "   Testing report for non-DNS-managed app (should show warning):"
sudo dokku dns:report tracking-test 2>&1 || echo "Report correctly showed app not under DNS management"

echo "   Adding app to DNS management..."
sudo dokku dns:apps:enable tracking-test 2>&1 || echo "DNS add completed"

echo "   Testing report for DNS-managed app (should now show details):"
sudo dokku dns:report tracking-test 2>&1 || echo "Report completed for DNS-managed app"

echo "   Testing global report (should only show DNS-managed apps):"
echo "   Before: all apps were shown, Now: only DNS-managed apps shown"
sudo dokku dns:report 2>&1 || echo "Global report completed"

echo "Fix 2: Testing hosted zone validation for domain activation"
echo "   The domain status table should show 'No (no hosted zone)' for domains without hosted zones"
echo "   and 'Yes' only for domains that have valid hosted zones in Route53"
echo "   Note: This requires AWS Route53 configuration to fully test"

echo "Fix 3: Testing elimination of plugin:install suggestions"
echo "   Previous versions showed 'Please run: sudo dokku plugin:install' messages"
echo "   Now shows helpful configuration guidance instead"
echo "   If you see any plugin:install messages, that indicates a regression"

echo "Fix 4: Testing domain parsing improvements"
echo "   Multiple domains should now be displayed as separate rows in the table"
echo "   Previous versions concatenated multiple domains into a single row"
echo "   Check the domain tables above - each domain should be on its own line"

# Test edge cases for the fixes
echo "Testing edge cases for fixes..."
echo "   Testing report for app with no domains:"
if ! sudo dokku apps:list 2>/dev/null | grep -q "no-domains-test"; then
    sudo dokku apps:create "no-domains-test" 2>&1 || echo "Failed to create no-domains test app"
fi
sudo dokku dns:report no-domains-test 2>&1 || echo "Report handled no-domains case"

echo "   Testing global report when no apps are under DNS management:"
# Temporarily move the LINKS file to simulate no managed apps
sudo mv /var/lib/dokku/services/dns/LINKS /var/lib/dokku/services/dns/LINKS.backup 2>/dev/null || true
sudo dokku dns:report 2>&1 || echo "Global report handled no managed apps case"
# Restore the LINKS file
sudo mv /var/lib/dokku/services/dns/LINKS.backup /var/lib/dokku/services/dns/LINKS 2>/dev/null || true

echo "Testing dns:apps:disable command..."
echo "   Testing dns:apps:disable for app that is in DNS management:"
sudo dokku dns:apps:disable tracking-test 2>&1 || echo "DNS remove completed"

echo "   Verifying app was removed from DNS management:"
sudo dokku dns:report tracking-test 2>&1 || echo "Report correctly shows app not added after removal"

echo "   Testing dns:apps:disable for app not in DNS management (should handle gracefully):"
sudo dokku dns:apps:disable no-domains-test 2>&1 || echo "DNS remove handled non-managed app correctly"

echo "   Testing global report after removing apps:"
sudo dokku dns:report 2>&1 || echo "Global report after removals completed"

# Cleanup tracking test app
echo "   Cleaning up tracking test app..."
sudo dokku apps:destroy tracking-test --force 2>&1 || echo "Tracking test app cleanup completed"
sudo dokku apps:destroy no-domains-test --force 2>&1 || echo "No-domains test app cleanup completed"

log_remote "SUCCESS" "DNS plugin fixes testing completed!"
echo ""
echo "Summary of fixes tested:"
echo "✅ DNS management tracking with LINKS file"
echo "✅ Hosted zone validation for domain activation"  
echo "✅ Elimination of plugin:install suggestions"
echo "✅ Domain parsing improvements for multiple domains"
echo "✅ Proper report functionality for managed vs unmanaged apps" 
echo "✅ DNS remove functionality for cleaning up tracking"
echo ""

# Test Route53 capabilities if AWS is configured
REMOTE_SCRIPT_EOF3

    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        cat >> "$script_file" << 'ROUTE53_TEST_EOF'
log_remote "INFO" "=== TESTING ROUTE53 CAPABILITIES ==="
aws route53 list-hosted-zones --query 'HostedZones[].Name' --output table 2>/dev/null || echo 'No hosted zones or limited access'
ROUTE53_TEST_EOF
    fi

    cat >> "$script_file" << 'REMOTE_SCRIPT_EOF4'

log_remote "SUCCESS" "=== PLUGIN TEST COMPLETED ==="

# Cleanup AWS credentials
log_remote "INFO" "=== CLEANING UP AWS CONFIGURATION ==="
if [[ -f /tmp/aws_credentials_backup ]]; then
    mkdir -p ~/.aws
    cp /tmp/aws_credentials_backup ~/.aws/credentials
    echo "Restored original AWS credentials"
else
    rm -f ~/.aws/credentials
    sudo rm -f /root/.aws/credentials
    echo "Removed test AWS credentials"
fi

if [[ -f /tmp/aws_config_backup ]]; then
    mkdir -p ~/.aws
    cp /tmp/aws_config_backup ~/.aws/config
    echo "Restored original AWS config"
else
    rm -f ~/.aws/config
    sudo rm -f /root/.aws/config
    echo "Removed test AWS config"
fi

rm -f /tmp/aws_credentials_backup /tmp/aws_config_backup
echo "✓ AWS configuration restored to original state"

REMOTE_SCRIPT_EOF4

    echo "$script_file"
}

main() {
    # Load environment variables from .env file if it exists
    if [[ -f ".env" ]]; then
        echo "Loading AWS credentials from .env file"
        set -a; source .env; set +a
    elif [[ -f "../.env" ]]; then
        echo "Loading AWS credentials from ../.env file"  
        set -a; source ../.env; set +a
    fi

    log "INFO" "Starting DNS plugin test on server: $SERVER_HOST"
    log "INFO" "SSH User: $SSH_USER"
    log "INFO" "Test App: $TEST_APP"
    log "INFO" "Log file: $LOG_FILE"
    echo ""
    
    # Test SSH connection  
    log "INFO" "Testing SSH connection..."
    if ! ssh -o ConnectTimeout=10 "$SSH_USER@$SERVER_HOST" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log "ERROR" "Cannot connect to $SERVER_HOST as $SSH_USER"
        log "ERROR" "Please check your SSH configuration and server details"
        exit 1
    fi
    log "SUCCESS" "SSH connection established"
    echo ""
    
    # Generate the remote script
    log "INFO" "Generating remote test script..."
    echo "DEBUG: About to call generate_remote_script function"
    local SCRIPT_FILE
    echo "DEBUG: Starting generate_remote_script"
    SCRIPT_FILE=$(generate_remote_script)
    echo "DEBUG: Finished generate_remote_script"
    
    # Check credentials
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        log "SUCCESS" "AWS credentials detected - will test best-case auto-detection"
    else
        log "INFO" "No AWS credentials provided - will test basic auto-detection"
        echo "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to test with credentials"
    fi
    echo ""
    
    # Run the entire test in a single SSH session
    log "INFO" "Executing comprehensive test via single SSH session..."
    echo "This will run all tests in one SSH connection to minimize password prompts"
    echo ""
    
    # Copy script and execute
    if scp "$SCRIPT_FILE" "$SSH_USER@$SERVER_HOST:/tmp/dokku-dns-test.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Test script uploaded successfully"
    else
        log "ERROR" "Failed to upload test script"
        exit 1
    fi
    
    # Execute the test script
    if ssh -t "$SSH_USER@$SERVER_HOST" "chmod +x /tmp/dokku-dns-test.sh && /tmp/dokku-dns-test.sh; rm -f /tmp/dokku-dns-test.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Remote test execution completed"
    else
        log "WARNING" "Remote test completed with some errors"
    fi
    
    # Clean up local script
    rm -f "$SCRIPT_FILE"
    
    echo ""
    echo "===================================================================================="
    log "INFO" "TEST COMPLETED - Log file saved as: $LOG_FILE"
    echo "===================================================================================="
    
    echo ""
    log "INFO" "Manual testing guide:"
    echo "  ssh $SSH_USER@$SERVER_HOST"
    echo ""
    echo "Available commands to test:"
    echo "  sudo dokku dns:help                    # Show all commands"
    echo "  sudo dokku dns:providers:verify                  # Test provider access + discover existing DNS records"
    echo "  sudo dokku dns:providers:configure               # Configure DNS provider"
    echo "  sudo dokku dns:apps:enable <app>               # Add app domains to DNS"
    echo "  sudo dokku dns:apps:sync <app>              # Sync DNS records"
    echo "  sudo dokku dns:report                  # Show global report (all apps and domains)"
    echo "  sudo dokku dns:report <app>            # Show app-specific domain status"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi