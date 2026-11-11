#!/bin/bash
# 디지털 트윈 40일 커리큘럼 — 매일 한 편 작성
#
# launchd(com.yongjun.blog.digital-twin)가 매일 07:00에 실행한다.
# 글만 쓰고 커밋·푸시는 하지 않는다. 10:00에 auto-deploy.sh가 함께 올린다.
#
# DRY=1 로 실행하면 파일을 쓰지 않고 진행 상태만 읽어 스모크 테스트한다.

REPO_DIR="/Users/yongjun.choi/WorkSpace/Personal/Blog"
CLAUDE_BIN="/Users/yongjun.choi/.local/bin/claude"
LOG_FILE="$REPO_DIR/scripts/digital-twin-daily.log"
PLAN_DIR="$REPO_DIR/hugo-site/.digital-twin-plan"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

cd "$REPO_DIR" || { log "ERROR: cd 실패"; exit 1; }

# 커리큘럼이 끝났으면 claude를 띄울 것도 없다.
NEXT_DAY=$(/usr/bin/python3 -c "import json;print(json.load(open('$PLAN_DIR/progress.json'))['next_day'])" 2>/dev/null)
TOTAL_DAYS=$(/usr/bin/python3 -c "import json;print(json.load(open('$PLAN_DIR/progress.json'))['total_days'])" 2>/dev/null)

if [ -z "$NEXT_DAY" ]; then
  log "ERROR: progress.json을 읽지 못했다"
  exit 1
fi

if [ "$NEXT_DAY" -gt "$TOTAL_DAYS" ]; then
  log "완주: ${TOTAL_DAYS}일 커리큘럼이 끝나 실행할 것이 없다"
  exit 0
fi

if [ "$DRY" = "1" ]; then
  log "DRY RUN 시작 (next_day=${NEXT_DAY})"
  "$CLAUDE_BIN" -p "hugo-site/.digital-twin-plan/progress.json 파일을 읽고 next_day 값만 한 줄로 답해라. 어떤 파일도 쓰거나 고치지 마라." \
    --permission-mode acceptEdits \
    --allowedTools "Read" >> "$LOG_FILE" 2>&1
  RC=$?
  log "DRY RUN 종료 (exit=${RC})"
  exit $RC
fi

log "Day ${NEXT_DAY}/${TOTAL_DAYS} 작성 시작"

"$CLAUDE_BIN" -p "/digital-twin-daily-blog" \
  --permission-mode acceptEdits \
  --allowedTools "Read" "Write" "Edit" "Glob" "Grep" "Skill" "Bash(curl:*)" \
  >> "$LOG_FILE" 2>&1
RC=$?

NEW_DAY=$(/usr/bin/python3 -c "import json;print(json.load(open('$PLAN_DIR/progress.json'))['next_day'])" 2>/dev/null)

if [ "$RC" -ne 0 ]; then
  log "ERROR: claude 종료 코드 ${RC} — Day ${NEXT_DAY} 미작성 가능성"
elif [ "$NEW_DAY" = "$NEXT_DAY" ]; then
  # 진행 상태가 그대로면 글을 안 썼거나 중간에 멈춘 것이다.
  log "WARN: next_day가 ${NEXT_DAY} 그대로다 — 글이 작성되지 않았을 수 있다"
else
  log "SUCCESS: Day ${NEXT_DAY} 작성 완료 (다음 회차 ${NEW_DAY}) — 10시 auto-deploy가 배포"
fi

exit $RC
