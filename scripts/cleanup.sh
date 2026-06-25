#!/bin/bash

# Exit immediately if any command fails
set -e

echo "========================================="
echo "   STARTING AWS RESOURCE CLEANUP"
echo "========================================="

# 1. Fetch the latest release asset download URL dynamically from GitHub API
echo "Locating the latest release package..."
LATEST_URL=$(curl -s https://github.com | grep "browser_download_url.*linux-amd64.tar.gz" | cut -d '"' -f 4)

echo "Downloading latest aws-nuke from: $LATEST_URL"
wget -q "$LATEST_URL" -O aws-nuke-latest.tar.gz

# 2. Extract the binary file and assign standard execution permissions
echo "Extracting binary components..."
tar -xzf aws-nuke-latest.tar.gz

# Find the extracted file dynamically and rename it cleanly to 'aws-nuke'
mv aws-nuke-v*linux-amd64 aws-nuke 2>/dev/null || mv aws-nuke 2>/dev/null || true
chmod +x aws-nuke

# 3. Verify AWS authentication credentials are active
echo "Verifying AWS Caller Identity..."
aws sts get-caller-identity

# 4. Run aws-nuke using the local configuration file.
# Note: Version 3 requires the 'run' subcommand to execute the cleanup.
echo "Executing destructive resource wipe..."
./aws-nuke run -c nuke-config.yaml --no-alias-check --no-dry-run

echo "========================================="
echo "   AWS ACCOUNT CLEANUP COMPLETED"
echo "========================================="
