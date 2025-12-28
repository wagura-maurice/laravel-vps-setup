#!/bin/bash
set -x  # Enable debug mode

# Set up logging
exec 2> >(tee -a "/tmp/laravel-setup-debug-$(date +%s).log" >&2)
echo "Debug mode enabled. Logging to /tmp/laravel-setup-debug-*.log"

# Source the main script with error handling
if ! source "$(dirname "$0")/laravel-setup-system.sh"; then
    echo "Failed to source laravel-setup-system.sh" >&2
    exit 1
fi

# Run the main function
main "$@"
