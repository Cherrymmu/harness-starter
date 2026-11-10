#!/bin/bash
# PreToolUse hook (matcher: Bash) — 프리티어를 벗어나는 AWS RDS 생성 명령을 강제 차단한다.
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if echo "$command" | grep -qE 'aws rds create-db-instance'; then
  if ! echo "$command" | grep -qE 'db\.(t3|t4g)\.micro'; then
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "프리티어 인스턴스 타입(db.t3.micro 또는 db.t4g.micro)이 아닙니다. 과금 위험이 있어 차단합니다."}}'
    exit 0
  fi
  if echo "$command" | grep -qE -- '--multi-az'; then
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "Multi-AZ는 프리티어 범위를 벗어납니다. 단일 AZ로만 생성하세요."}}'
    exit 0
  fi
fi

exit 0
