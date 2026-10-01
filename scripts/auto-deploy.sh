#!/bin/bash

REPO_DIR="/Users/yongjun.choi/WorkSpace/Personal/Blog"
LOG_FILE="$REPO_DIR/scripts/auto-deploy.log"

# 22번 포트가 막히거나 네트워크가 늦게 올라올 때 쓰는 대체 원격 (~/.ssh/config 의 github-443 별칭)
FALLBACK_REMOTE="git@github-443:juniapps2014-collab/blog.git"

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

# launchd가 10시에 작업을 띄울 때 맥이 절전에서 막 깨어나 네트워크가 아직
# 준비되지 않은 경우가 있다. 그때 ssh가 "connect to host github.com port 22:
# Undefined error: 0" 으로 실패하는데, 기존 스크립트는 한 번 실패하면 그대로
# 끝나 커밋만 쌓이고 배포가 멈췄다(2026-09-27·29, 10-01).
# 1~3회는 기본 경로(22번)로, 4~5회는 443 포트 경로로 재시도한다.
push_with_retry() {
  local delays=(15 30 60 60)
  local i
  for i in 1 2 3 4 5; do
    if [ "$i" -le 3 ]; then
      git push origin main && { log "SUCCESS: Pushed to GitHub (attempt ${i}) — GitHub Actions will deploy"; return 0; }
    else
      git push "$FALLBACK_REMOTE" main && { log "SUCCESS: Pushed via 443 fallback (attempt ${i}) — GitHub Actions will deploy"; return 0; }
    fi
    if [ "$i" -lt 5 ]; then
      log "WARN: push attempt ${i}/5 failed; retrying in ${delays[$((i-1))]}s"
      sleep "${delays[$((i-1))]}"
    fi
  done
  return 1
}

if push_with_retry; then
  exit 0
else
  log "ERROR: git push failed after 5 attempts (22번·443 모두 실패)"
  exit 1
fi
