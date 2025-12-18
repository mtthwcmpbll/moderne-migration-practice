#!/bin/bash

# Exit immediately if a command exits with a non-zero status
# set -e

# Define the list of repositories
repositories=(
  "mtthwcmpbll/example-ecom-common"
  "mtthwcmpbll/example-ecom-security"
  "mtthwcmpbll/example-ecom-rest-client"
  "mtthwcmpbll/example-ecom-product-service"
  "mtthwcmpbll/example-ecom-customer-service"
  "mtthwcmpbll/example-ecom-order-service"
  "mtthwcmpbll/example-ecom-inventory-service"
  "mtthwcmpbll/example-ecom-notification-service"
  "mtthwcmpbll/example-ecom-kyc-service"
  "mtthwcmpbll/example-ecom-risk-score-service"
  "mtthwcmpbll/example-ecom-fraud-detection-service"
)

# Check if arguments are provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <git_command_arguments>"
  exit 1
fi

# Loop through each repository and run the git command
for repo in "${repositories[@]}"; do
  echo "Running 'git $*' in $repo..."
  (
    cd "$WORKSPACE/$repo"
    git "$@"
  )
done