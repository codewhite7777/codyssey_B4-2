#!/bin/bash
# monitor.sh - agent-leak-app 하나만 지켜보는 간단한 관제 스크립트
#
# 사용법: ./monitor.sh [간격(초)] [로그파일]
#   예)   ./monitor.sh 5 logs/oom_before/monitor.log
#
# 한 줄 출력 예:
# [2026-10-19 01:30:00] PROCESS:agent-leak-app PID:1234 CPU:1.2% MEM:5.1% RSS:120MB THREADS:3 STAT:S

TARGET="agent-app-leak"          # 프로세스 이름(명령줄)에 들어가는 문자열
INTERVAL="${1:-5}"
LOG_FILE="${2:-monitor.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 1) 대상 프로세스가 뜰 때까지 기다린다
while ! PID=$(pgrep -f "$TARGET" | head -n 1); do
    sleep 1
done
log "MONITOR START - PROCESS:agent-leak-app PID:$PID INTERVAL:${INTERVAL}s"

# 2) 프로세스가 살아있는 동안 주기적으로 기록한다
while kill -0 "$PID" 2>/dev/null; do
    # ps : 메모리 정보 (%mem = 전체 RAM 대비 비율, rss = 실제 물리 메모리 KB)
    #      nlwp = 스레드 개수, stat = 프로세스 상태(R 실행 / S 대기 ...)
    read -r MEM RSS_KB NLWP STAT <<< "$(ps -p "$PID" -o %mem=,rss=,nlwp=,stat=)"

    # top : 지금 이 순간의 CPU 사용률
    #       (ps의 %cpu는 '시작부터 지금까지 평균'이라 급상승을 늦게 보여준다)
    #       -b 배치모드(파일로 저장 가능) / -n 2 두 번 측정 / -d 1 1초 간격 / -p 이 PID만
    CPU=$(top -b -n 2 -d 1 -p "$PID" | awk -v pid="$PID" '$1==pid {c=$9} END {print c}')

    [ -z "$RSS_KB" ] && break
    log "PROCESS:agent-leak-app PID:$PID CPU:${CPU}% MEM:${MEM}% RSS:$((RSS_KB / 1024))MB THREADS:$NLWP STAT:$STAT"
    sleep "$INTERVAL"
done

# 3) 프로세스가 사라지면 그 시각을 남긴다
log "PROCESS NOT FOUND - PID:$PID terminated"
