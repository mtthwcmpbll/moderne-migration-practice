#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Suppress JVM warnings from Maven's libraries on Java 21+
export MAVEN_OPTS="--enable-native-access=ALL-UNNAMED -XX:+EnableDynamicAgentLoading"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default to mtthwcmpbll if GITHUB_ORG is not set
GITHUB_ORG=${GITHUB_ORG:-mtthwcmpbll}

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
        cat "$LOG_FILE"
        echo -e "${RED}${service_name} build failed${NC}"

        # Return failure status so the script can exit if desired
        return 1
    fi
}

get_repo_path() {
    local repo_name="$1"
    local flat_path="${WORKSPACE}/${GITHUB_ORG}/${repo_name}"

    if [ -d "$flat_path" ]; then
        echo "$flat_path"
        return 0
    fi

    # Check for nested wave structure (e.g. Workspace/Wave1/$GITHUB_ORG/$repo_name)
    # matching any immediate subdirectory of WORKSPACE
    local nested_paths=( "${WORKSPACE}"/*/"${GITHUB_ORG}/${repo_name}" )
    
    # Check if the glob expanded to an existing directory
    if [ -d "${nested_paths[0]}" ]; then
        echo "${nested_paths[0]}"
        return 0
    fi

    echo ""
    return 1
}

build_repo() {
    local repo_name="$1"
    local service_name="$2"
    
    local service_path=$(get_repo_path "$repo_name")
    
    if [ -z "$service_path" ]; then
        echo -e "${RED}Could not find repository ${GITHUB_ORG}/${repo_name} in ${WORKSPACE}${NC}"
        # We don't exit here to allow other builds to proceed if possible, 
        # but build_service would fail anyway if called with empty path.
        # Let's print error and return failure
        return 1
    fi

    build_service "$service_path" "$service_name"
}


# Wave definitions
run_wave_0() {
    echo "Running Wave 0..."
    build_repo "example-ecom-common" "ecom-common"
}

run_wave_1() {
    echo "Running Wave 1..."
    build_repo "example-ecom-security" "ecom-security"
    build_repo "example-ecom-inventory-service" "inventory-service"
    build_repo "example-ecom-kyc-service" "kyc-service"
    build_repo "example-ecom-notification-service" "notification-service"
    build_repo "example-ecom-risk-score-service" "risk-score-service"
}

run_wave_2() {
    echo "Running Wave 2..."
    build_repo "example-ecom-rest-client" "ecom-rest-client"
    build_repo "example-ecom-customer-service" "customer-service"
    build_repo "example-ecom-product-service" "product-service"
}

run_wave_3() {
    echo "Running Wave 3..."
    build_repo "example-ecom-fraud-detection-service" "fraud-detection-service"
    build_repo "example-ecom-order-service" "order-service"
}

echo "Starting build process..."

if [ -z "$1" ]; then
    # No argument, run all waves
    run_wave_0
    run_wave_1
    run_wave_2
    run_wave_3
else
    case "$1" in
        0)
            run_wave_0
            ;;
        1)
            run_wave_1
            ;;
        2)
            run_wave_2
            ;;
        3)
            run_wave_3
            ;;
        *)
            echo -e "${RED}Invalid wave argument: $1. Supported waves: 0, 1, 2, 3.${NC}"
            exit 1
            ;;
    esac
fi

echo "Build complete!"
