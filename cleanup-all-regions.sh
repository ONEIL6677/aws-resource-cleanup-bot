#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
LOG_DIR="$SCRIPT_DIR/../logs"
MASTER_LOG="$LOG_DIR/master-cleanup-$(date +%Y-%m-%d).log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MASTER_LOG"
}

REGIONS=(
  "us-east-1"
  "us-east-2"
  "us-west-1"
  "us-west-2"
  "eu-west-1"
  "eu-central-1"
  "ap-southeast-1"
  "ap-northeast-1"
)

log "================================================="
log "Multi-Region AWS Cost Optimisation Cleanup"
log "================================================="
log "Regions to clean: ${REGIONS[*]}"

for REGION in "${REGIONS[@]}"; do
  log ""
  log ">>> Processing region: $REGION"
  export AWS_DEFAULT_REGION="$REGION"
  bash "$SCRIPT_DIR/cleanup.sh" || log "WARNING: Errors in region $REGION — check logs"
  log "<<< Done with region: $REGION"
done

log ""
log "================================================="
log "All regions processed. Master log: $MASTER_LOG"
log "================================================="
