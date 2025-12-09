#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Temporary log file to capture output
LOG_FILE=$(mktemp)

# Clean up log file on exit
cleanup() {
    rm -f "$LOG_FILE"
}
trap cleanup EXIT

build_service() {
    local service_path="$1"
    local service_name="$2"

    # Use a subshell to change directory safely without affecting the main script
    if (cd "$service_path" && mvn clean install > "$LOG_FILE" 2>&1); then
        echo -e "${GREEN}${service_name} built successfully${NC}"
    else
        echo -e "${RED}${service_name} build failed${NC}"
        # Return failure status so the script can exit if desired
        return 1
    fi
}

echo "Starting build process..."

# Build services
# We use || exit 1 to stop the script immediately if a build fails, similar to set -e
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-common" "ecom-common"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-security" "ecom-security"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-rest-client" "ecom-rest-client"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-product-service" "product-service"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-customer-service" "customer-service"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-order-service" "order-service"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-inventory-service" "inventory-service"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-notification-service" "notification-service"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-kyc-service" "kyc-service"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-risk-score-service" "risk-score-service"
build_service "${WORKSPACE}/mtthwcmpbll/example-ecom-fraud-detection-service" "fraud-detection-service"

echo "Build complete!"
