#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/scripts/cleanup-all-regions.sh"
LOG_DIR="$SCRIPT_DIR/logs"
CRON_LOG="$LOG_DIR/cron.log"

mkdir -p "$LOG_DIR"

chmod +x "$SCRIPT_DIR/scripts/cleanup.sh"
chmod +x "$SCRIPT_DIR/scripts/cleanup-all-regions.sh"

echo "Installing cron job to run cleanup every day at midnight..."

CRON_JOB="0 0 * * * AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY bash $CLEANUP_SCRIPT >> $CRON_LOG 2>&1"

(crontab -l 2>/dev/null | grep -v "cleanup-all-regions"; echo "$CRON_JOB") | crontab -

echo ""
echo "Cron job installed successfully."
echo ""
crontab -l | grep cleanup
echo ""
echo "Logs will be written to: $LOG_DIR"
echo "To remove the cron job run: crontab -e"
