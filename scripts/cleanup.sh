#!/bin/bash

# Exit immediately if any command fails
set -e

echo "========================================="
echo "   STARTING AWS RESOURCE CLEANUP"
echo "========================================="

# 1. Fetch the stable release of aws-nuke binary
echo "Downloading aws-nuke..."
wget -q https://github.com

# 2. Extract the binary file and dynamically handle naming
echo "Extracting binary components..."
tar -xzf aws-nuke-v2.24.2-linux-amd64.tar.gz
mv aws-nuke-v2.24.2-linux-amd64 aws-nuke 2>/dev/null || true
chmod +x aws-nuke


# 2. Extract the binary file
tar -xzf aws-nuke-v2.25.0-linux-amd64.tar.gz
mv aws-nuke-v2.25.0-linux-amd64 aws-nuke
chmod +x aws-nuke

# 3. Verify AWS authentication credentials are active
echo "Verifying AWS Caller Identity..."
aws sts get-caller-identity

# 4. Run aws-nuke using the local configuration file.
# --no-alias-check bypasses the safety prompt requiring an account alias.
# --no-dry-run executes actual destructive deletion instead of a preview.
echo "Executing destructive resource wipe..."
./aws-nuke -c nuke-config.yaml --no-alias-check --no-dry-run

echo "========================================="
echo "   AWS ACCOUNT CLEANUP COMPLETED"
echo "========================================="
