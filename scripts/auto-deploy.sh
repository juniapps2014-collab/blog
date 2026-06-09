#!/bin/bash

REPO_DIR="/Users/yongjun.choi/WorkSpace/Personal/Blog"
LOG_FILE="$REPO_DIR/scripts/auto-deploy.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

cd "$REPO_DIR" || { log "ERROR: Cannot cd to repo dir"; exit 1; }

# Stage all changes under hugo-site (content, static, assets, layouts, config)
git add hugo-site/

if git diff --cached --quiet; then
  log "No changes to deploy"
  exit 0
fi

CHANGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
DATE=$(date '+%Y-%m-%d')
git commit -m "Auto: deploy ${CHANGED} file(s) on ${DATE}"

if git push origin main; then
  log "SUCCESS: Pushed to GitHub — GitHub Actions will deploy"
else
  log "ERROR: git push failed"
  exit 1
fi
