#!/bin/bash
# setup.sh - agent-leak-app 실행 조건 준비 (일반 사용자 계정에서 실행)
# 사용법: source scripts/agent.env && bash scripts/setup.sh
set -e

if [ "$(id -u)" -eq 0 ]; then
    echo "[ERROR] root 계정으로는 실행할 수 없습니다. 일반 사용자로 실행하세요."
    exit 1
fi

# 1) 필요한 디렉터리 만들기
mkdir -p "$AGENT_UPLOAD_DIR" "$AGENT_KEY_PATH" "$AGENT_LOG_DIR"

# 2) API 키 파일 만들기
echo "agent_api_key_test" > "$AGENT_KEY_PATH/secret.key"

# 3) 결과 확인
echo "--- 실행 조건 확인 ---"
echo "USER              : $(whoami)"
echo "AGENT_HOME        : $AGENT_HOME"
echo "AGENT_PORT        : $AGENT_PORT"
echo "AGENT_UPLOAD_DIR  : $AGENT_UPLOAD_DIR"
echo "AGENT_KEY_PATH    : $AGENT_KEY_PATH"
echo "AGENT_LOG_DIR     : $AGENT_LOG_DIR (쓰기 권한: $([ -w "$AGENT_LOG_DIR" ] && echo OK || echo NO))"
echo "secret.key        : $(cat "$AGENT_KEY_PATH/secret.key")"
echo "MEMORY_LIMIT      : $MEMORY_LIMIT MB"
echo "CPU_MAX_OCCUPY    : $CPU_MAX_OCCUPY %"
echo "MULTI_THREAD      : $MULTI_THREAD_ENABLE"
