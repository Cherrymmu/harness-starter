#!/bin/bash
# PreToolUse hook (matcher: Write|Edit) — SQL 파일 안에 rules/naming.md 위반 패턴이 있으면 강제 차단한다.
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [[ "$file_path" != *.sql ]]; then
  exit 0
fi

content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')

# camelCase 테이블명 탐지: CREATE TABLE 뒤 식별자만 뽑아 대소문자를 그대로(case-sensitive) 검사
table_name=$(echo "$content" | grep -oiE 'CREATE[[:space:]]+TABLE[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' | head -1 | awk '{print $NF}')
if [[ -n "$table_name" ]] && echo "$table_name" | grep -qE '[a-z][A-Z]'; then
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "테이블명('"$table_name"')에 camelCase가 감지됐습니다. rules/naming.md 규칙(snake_case)을 따르세요."}}'
  exit 0
fi

# 단위 없는 금액/면적 컬럼명 탐지 (컬럼명이 정확히 amount/area로만 끝나고 _krw, _sqm 등 단위 접미사가 없는 경우)
if echo "$content" | grep -qE '\b[a-zA-Z_]*(amount|area)[[:space:]]+(INT|NUMERIC|DECIMAL|FLOAT)' && ! echo "$content" | grep -qiE '(amount_krw|area_sqm)'; then
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "금액/면적 컬럼에 단위가 없습니다. _krw, _sqm 같은 단위 접미사를 붙이세요 (rules/naming.md)."}}'
  exit 0
fi

exit 0
