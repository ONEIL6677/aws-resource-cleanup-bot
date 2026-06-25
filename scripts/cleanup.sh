#!/bin/bash
set -e

echo "========================================="
echo "   STARTING AWS RESOURCE CLEANUP"
echo "========================================="

echo "Locating the latest release package..."
LATEST_URL=$(curl -s https://github.com | grep "browser_download_url.*linux-amd64.tar.gz" | cut -d '"' -f 4)

echo "Downloading latest aws-nuke..."
wget -q "$LATEST_URL" -O aws-nuke-latest.tar.gz

echo "Extracting binary components..."
tar -xzf aws-nuke-latest.tar.gz
mv aws-nuke-v*linux-amd64 aws-nuke 2>/dev/null || mv aws-nuke 2>/dev/null || true
chmod +x aws-nuke

echo "Verifying AWS Caller Identity..."
aws sts get-caller-identity

echo "Executing destructive resource wipe..."
./aws-nuke run -c nuke-config.yaml --no-alias-check --no-dry-run

echo "========================================="
echo "   AWS ACCOUNT CLEANUP COMPLETED"
echo "========================================="
