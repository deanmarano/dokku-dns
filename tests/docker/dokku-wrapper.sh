#!/usr/bin/env bash
# Dokku Docker Exec Wrapper for Docker Tests
# This script provides a 'dokku' command that uses docker exec to run commands in the dokku container

set -euo pipefail

# Configuration from environment
DOKKU_CONTAINER_NAME="${DOKKU_CONTAINER_NAME:-dokku-local}"

# Function to wait for dokku container to be ready
wait_for_dokku_container() {
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker exec "$DOKKU_CONTAINER_NAME" dokku version >/dev/null 2>&1; then
            return 0
        fi
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: Dokku container $DOKKU_CONTAINER_NAME not ready or not found" >&2
    return 1
}

# Function to execute dokku command via docker exec
execute_dokku_command() {
    local cmd="dokku $*"
    
    # Execute the dokku command in the container
    docker exec "$DOKKU_CONTAINER_NAME" sh -c "$cmd"
}

# Main execution
main() {
    # If no arguments provided, show this is a wrapper
    if [[ $# -eq 0 ]]; then
        echo "Dokku Docker Exec Wrapper for Docker Tests"
        echo "Target container: $DOKKU_CONTAINER_NAME"
        echo "Usage: $0 <dokku-command> [args...]"
        return 1
    fi
    
    # Wait for dokku container to be ready
    if ! wait_for_dokku_container; then
        echo "ERROR: Cannot connect to dokku container" >&2
        return 1
    fi
    
    # Execute the dokku command
    execute_dokku_command "$@"
}

# Run main function with all arguments
main "$@"