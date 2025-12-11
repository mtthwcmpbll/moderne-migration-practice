#!/bin/bash

# Exit immediately if a command exits with a non-zero status
# set -e

(
cd $WORKSPACE/mtthwcmpbll/example-ecom-common
git add .
git commit -m "$1"
)

(
echo "Building ecom-security..."
cd $WORKSPACE/mtthwcmpbll/example-ecom-security
git add .
git commit -m "$1"
)

(
echo "Building ecom-rest-client..."
cd $WORKSPACE/mtthwcmpbll/example-ecom-rest-client
git add .
git commit -m "$1"
)

(
echo "Building product-service..."
cd $WORKSPACE/mtthwcmpbll/example-ecom-product-service
git add .
git commit -m "$1"
)

(
echo "Building customer-service..."
cd $WORKSPACE/mtthwcmpbll/example-ecom-customer-service
git add .
git commit -m "$1"
)

(
echo "Building order-service..."
cd $WORKSPACEmtthwcmpbll/example-ecom-order-service
git add .
git commit -m "$1"
)

(
echo "Building inventory-service..."
cd $WORKSPACE/mtthwcmpbll/example-ecom-inventory-service
git add .
git commit -m "$1"
)

(
echo "Building notification-service..."
cd $WORKSPACE/mtthwcmpbll/example-ecom-notification-service
git add .
git commit -m "$1"
)

(
echo "Building kyc-service..."
cd $WORKSPACE/mtthwcmpbll/example-ecom-kyc-service
git add .
git commit -m "$1"
)

(
echo "Building risk-score-service..."
cd $WORKSPACE/mtthwcmpbll/example-ecom-risk-score-service
git add .
git commit -m "$1"
)

(
echo "Building fraud-detection-service..."
cd $WORKSPACE/mtthwcmpbll/example-ecom-fraud-detection-service
git add .
git commit -m "$1"
)