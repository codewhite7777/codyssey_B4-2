#!/bin/bash
# =====================================================================
#  monitor.sh - agent-leak-app 한 개만 지켜보며 상태를 시간순으로 기록한다
#
#  사용법 : ./monitor.sh [간격(초)]        예) ./monitor.sh 1
#  기록   : $AGENT_LOG_DIR/monitor.log  (화면에도 같이 출력)
#
#  순서
#   1. 앱이 뜰 때까지 기다린다
#   2. 실제로 일하는 "자식" 프로세스의 PID 를 찾는다
#   3. 간격마다 CPU / MEM / RSS / 스레드 수 / 상태 / 로그 멈춘 시간 을 한 줄로 기록
#   4. 앱이 사라지면 그 시각을 남기고 exit 1
# =====================================================================

# ---------- 설정값 ----------
APP_NAME="agent-leak-app"                          # 실행 파일 이름 (x86, arm64 둘 다 이 이름으로 시작)
INTERVAL="${1:-1}"                                 # 기록 간격(초), 기본 1초
LOG_DIR="${AGENT_LOG_DIR:-$HOME/agent-app/logs}"
LOG_FILE="$LOG_DIR/monitor.log"                    # monitor.sh 의 기록
APP_LOG="$LOG_DIR/agent_app.log"                   # 앱이 쓰는 로그 (멈췄는지 확인용)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ---------- 1. 앱이 뜰 때까지 기다리기 ----------
# pgrep -f '^[^ ]*agent-leak-app' = 명령줄의 첫 단어(실행된 프로그램)가 앱인 것만
#   -> 'vim agent-leak-app-x86' 같은 다른 프로세스는 걸리지 않는다
# pgrep -o = 가장 먼저 뜬 것 = 부모
echo "Waiting for '$APP_NAME'..."
until PARENT=$(pgrep -o -f "^[^ ]*${APP_NAME}"); do
    sleep 0.5
done

# ---------- 2. 자식 PID 찾기 ----------
# PyInstaller 실행 파일이라 프로세스가 2개 뜬다
#   부모 = 압축을 풀고 기다리기만 함 (메모리 약 1MB, 변화 없음)
#   자식 = 실제로 일함 (nice=10, 메모리가 늘어나는 쪽)  -> 이쪽을 잰다
# pgrep -P 부모PID = 그 부모의 자식
sleep 1
PID=$(pgrep -P "$PARENT" | head -n 1)
[ -z "$PID" ] && PID="$PARENT"
log "MONITOR START - PROCESS:$APP_NAME PARENT:$PARENT PID:$PID INTERVAL:${INTERVAL}s"

# ---------- 3. 살아 있는 동안 기록 ----------
# kill -0 = 신호를 보내지 않고 "살아 있나"만 확인
while kill -0 "$PID" 2>/dev/null; do
    # ps : %mem = 전체 RAM 대비 비율 / rss = 실제 물리 메모리(KB)
    #      nlwp = 스레드 수 / stat = 상태 (R 실행, S 대기, N 우선순위 낮음, l 멀티스레드)
    read -r MEM RSS_KB NLWP STAT <<< "$(ps -p "$PID" -o %mem=,rss=,nlwp=,stat=)"
    [ -z "$RSS_KB" ] && break

    # top : 지금 이 순간의 CPU 사용률
    #   ps 의 %cpu 는 "시작부터 지금까지의 평균"이라 순간 변화가 늦게 보인다
    #   -b 배치모드(파일로 저장 가능) / -n 2 두 번 측정 / -d 0.5 0.5초 간격 / -p 이 PID 만
    #   첫 번째 측정은 기준점이라 부정확 -> 두 번째 값을 쓴다 (END 에서 마지막 값)
    CPU=$(top -b -n 2 -d 0.5 -p "$PID" | awk -v pid="$PID" '$1 == pid { c = $9 } END { print c }')

    # 앱 로그가 마지막으로 바뀐 지 몇 초 지났나 (데드락이면 계속 커진다)
    #   stat -c %Y = 파일의 마지막 수정 시각(초)
    if [ -f "$APP_LOG" ]; then
        LOG_AGE="$(( $(date +%s) - $(stat -c %Y "$APP_LOG") ))s"
    else
        LOG_AGE="-"
    fi

    log "PROCESS:$APP_NAME PID:$PID CPU:${CPU}% MEM:${MEM}% RSS:$((RSS_KB / 1024))MB THREADS:$NLWP STAT:$STAT LOG_AGE:$LOG_AGE"
    sleep "$INTERVAL"
done

# ---------- 4. 사라진 시각 남기기 ----------
log "PROCESS NOT FOUND - PID:$PID terminated"
exit 1
