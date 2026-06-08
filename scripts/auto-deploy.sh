#!/bin/bash

REPO_DIR="/Users/yongjun.choi/WorkSpace/Personal/Blog"
LOG_FILE="$REPO_DIR/scripts/auto-deploy.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

cd "$REPO_DIR" || { log "ERROR: Cannot cd to repo dir"; exit 1; }

# Check for new or changed content files
git add hugo-site/content/

if git diff --cached --quiet; then
  log "No new content to deploy"
  exit 0
fi

DATE=$(date '+%Y-%m-%d')
git commit -m "Auto: daily content ${DATE}"

if git push origin main; then
  log "SUCCESS: Pushed to GitHub — GitHub Actions will deploy"
else
  log "ERROR: git push failed"
  exit 1
fi
