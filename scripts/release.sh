#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Temporary log file to capture output
LOG_FILE=$(mktemp)

# Clean up log file on exit
cleanup() {
    rm -f "$LOG_FILE"
}
trap cleanup EXIT

# Function to increment version
increment_version() {
    local version=$1
    local delimiter=.
    local array=($(echo "$version" | tr $delimiter '\n'))
    local index=${#array[@]}-1
    
    # Check if the last part is numeric (it should be for a release version like 1.2.0)
    # If it's not (strange case), just append .1? No, let's assume standard semantic versioning as per request.
    
    array[$index]=$((array[$index] + 1))
    echo $(local IFS=$delimiter ; echo "${array[*]}")
}

process_release() {
    local service_path="$1"
    local service_name="$2"

    echo -e "${BLUE}Starting release process for ${service_name}...${NC}"

    if [ ! -d "$service_path" ]; then
        echo -e "${RED}Directory not found: $service_path${NC}"
        return 1
    fi

    # Go to service directory
    cd "$service_path" || return 1

    # 1. Get current version
    # usage: mvn help:evaluate -Dexpression=project.version -q -DforceStdout
    CURRENT_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
    if [ $? -ne 0 ] || [ -z "$CURRENT_VERSION" ]; then
        echo -e "${RED}Failed to get version for ${service_name}${NC}"
        return 1
    fi

    # Check if snapshot
    if [[ "$CURRENT_VERSION" != *"-SNAPSHOT" ]]; then
        echo -e "${RED}Version $CURRENT_VERSION check failed: Not a SNAPSHOT version. Skipping.${NC}"
        return 1
    fi

    RELEASE_VERSION=${CURRENT_VERSION%-SNAPSHOT}
    
    # Increment minor version. 
    # Logic: 1.2.0 -> 1.3.0. 
    # Wait, user said: "if a repo's currently set to version "1.2.0-SNAPSHOT", it should install version "1.2.0" and then set the pom to be version "1.3.0-SNAPSHOT""
    # This implies incrementing the MIDDLE number (MINOR version), not the PATCH version.
    # Semantic versioning: MAJOR.MINOR.PATCH
    # 1.2.0 -> Minor bump is 1.3.0.
    # 1.2.1 -> Minor bump is 1.3.0? Or just 1.3.0? Usually simple minor bump resets patch to 0. 
    # Let's write a robust minor bumper.
    
    IFS='.' read -r -a VERSION_PARTS <<< "$RELEASE_VERSION"
    if [ "${#VERSION_PARTS[@]}" -lt 2 ]; then
         echo -e "${RED}Version format unexpected: $RELEASE_VERSION (expected X.Y.Z)${NC}"
         return 1
    fi
    
    MAJOR=${VERSION_PARTS[0]}
    MINOR=${VERSION_PARTS[1]}
    # PATCH=${VERSION_PARTS[2]} # We don't strictly need this if we reset it, but let's keep it if we just increment minor.
    # User example: 1.2.0-SNAPSHOT -> 1.2.0 -> 1.3.0-SNAPSHOT.
    # What if it was 1.2.5-SNAPSHOT? 1.2.5 -> ? Probably 1.3.0-SNAPSHOT.
    # I will implement: Increment MINOR, set PATCH to 0.
    
    NEW_MINOR=$((MINOR + 1))
    NEXT_SNAPSHOT_VERSION="${MAJOR}.${NEW_MINOR}.0-SNAPSHOT"

    echo -e "  Current: ${CURRENT_VERSION}"
    echo -e "  Release: ${RELEASE_VERSION}"
    echo -e "  Next:    ${NEXT_SNAPSHOT_VERSION}"

    # 2. Set to Release Version
    echo -e "  Setting version to ${RELEASE_VERSION}..."
    if ! mvn org.codehaus.mojo:versions-maven-plugin:2.16.2:set -DnewVersion="${RELEASE_VERSION}" -DgenerateBackupPoms=false > "$LOG_FILE" 2>&1; then
         echo -e "${RED}Failed to set release version for ${service_name}${NC}"
         cat "$LOG_FILE"
         return 1
    fi

    # 3. Maven Clean Install (Simulate Release)
    echo -e "  Running release build..."
    if ! mvn clean install > "$LOG_FILE" 2>&1; then
         echo -e "${RED}Build failed for ${service_name} at version ${RELEASE_VERSION}${NC}"
         cat "$LOG_FILE"
         # Revert? User didn't ask for revert, but it's polite. 
         # I'll leave it in broken state for now or maybe just stop.
         return 1
    fi
    echo -e "${GREEN}  Build successful.${NC}"

    # 4. Set to Next Snapshot Version
    echo -e "  Setting version to ${NEXT_SNAPSHOT_VERSION}..."
    if ! mvn org.codehaus.mojo:versions-maven-plugin:2.16.2:set -DnewVersion="${NEXT_SNAPSHOT_VERSION}" -DgenerateBackupPoms=false > "$LOG_FILE" 2>&1; then
         echo -e "${RED}Failed to set next snapshot version for ${service_name}${NC}"
         cat "$LOG_FILE"
         return 1
    fi

    echo -e "${GREEN}  Release process complete for ${service_name}. New version: ${NEXT_SNAPSHOT_VERSION}${NC}"
    
    # Return to script dir (not strictly needed as we run in subshell or process one by one, but good practice)
    # Actually, I am doing `cd "$service_path"`. I should `cd` back or run in subshell. 
    # I'll run this function body in a subshell or just cd back.
    # Using `( ... )` syntax for the function body is cleaner for directory changes.
}

# Wrapper to run process_release in a subshell to avoid directory issues
run_release() {
    ( process_release "$1" "$2" )
}

echo "Starting Mass Release..."

# Wave definitions
run_wave_0() {
    echo "Running Wave 0..."
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-common" "ecom-common"
}

run_wave_1() {
    echo "Running Wave 1..."
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-security" "ecom-security"
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-inventory-service" "inventory-service"
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-kyc-service" "kyc-service"
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-notification-service" "notification-service"
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-risk-score-service" "risk-score-service"
}

run_wave_2() {
    echo "Running Wave 2..."
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-rest-client" "ecom-rest-client"
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-customer-service" "customer-service"
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-product-service" "product-service"
}

run_wave_3() {
    echo "Running Wave 3..."
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-fraud-detection-service" "fraud-detection-service"
    run_release "${WORKSPACE}/mtthwcmpbll/example-ecom-order-service" "order-service"
}

echo "Starting Mass Release..."

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

echo "Mass Release Complete!"
