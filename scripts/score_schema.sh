#!/bin/bash
# Before/After 채점기 — AI가 만든 SQL이 이 프로젝트의 기준(rules/naming.md + CLAUDE.md Access Pattern)을
# 얼마나 지켰는지 항목별 PASS/FAIL과 점수로 출력한다.
# 사용법: scripts/score_schema.sh <schema.sql> [라벨]
#   예) scripts/score_schema.sh ~/harness-lab/before/sql/schema.sql Before
#
# 주의: "좋은 스키마인가"를 채점하는 게 아니라 "우리가 정한 기준을 따랐는가"를 채점한다.
# 기준을 모르는 Before가 낮은 점수를 받는 건 AI가 무능해서가 아니라 기준을 전달받지 못했기 때문이다.

file="$1"
label="${2:-$(basename "$file")}"
if [[ ! -f "$file" ]]; then
  echo "사용법: $0 <schema.sql> [라벨]" >&2
  exit 2
fi

# 주석(-- ...)과 문자열 리터럴('...')을 지우고 소문자로 통일한 본문만 검사한다.
sql=$(sed -e 's/--.*$//' -e "s/'[^']*'//g" "$file")
# 여러 줄에 걸친 문장(CREATE INDEX ... \n ON ...)도 잡히도록 한 줄로 이어 붙인다.
lower=$(echo "$sql" | tr '[:upper:]\n' '[:lower:] ')

pass=0
total=0
check() {
  local name="$1" ok="$2"
  total=$((total + 1))
  if [[ "$ok" == 1 ]]; then
    pass=$((pass + 1))
    printf '  [PASS] %s\n' "$name"
  else
    printf '  [FAIL] %s\n' "$name"
  fi
}
has() { echo "$lower" | grep -qE "$1" && echo 1 || echo 0; }
lacks() { echo "$lower" | grep -qE "$1" && echo 0 || echo 1; }

echo "== $label ($file)"

# 1. 테이블명 snake_case — 원문 대소문자 그대로 검사 (따옴표 감싼 "AptTrade" 같은 경우 포함)
tables=$(echo "$sql" | grep -oiE 'create[[:space:]]+table[[:space:]]+(if[[:space:]]+not[[:space:]]+exists[[:space:]]+)?"?[A-Za-z_][A-Za-z0-9_.]*' | awk '{print $NF}' | tr -d '"')
bad=0
for t in $tables; do [[ "${t##*.}" =~ ^[a-z][a-z0-9_]*$ ]] || bad=1; done
[[ -z "$tables" ]] && bad=1
check "테이블명 snake_case (${tables//$'\n'/, })" $((1 - bad))

# 2. 식별자에 한글 금지 (주석·문자열 제외 본문)
check "식별자에 한글 없음" "$(echo "$sql" | grep -q '[가-힣]' && echo 0 || echo 1)"

# 3. 메인 테이블명 fact_apt_trade
check "메인 테이블명 fact_apt_trade" "$(has 'create[[:space:]]+table[[:space:]]+(if[[:space:]]+not[[:space:]]+exists[[:space:]]+)?fact_apt_trade\b')"

# 4. PK = trade_id
check "PK가 trade_id" "$(echo "$lower" | grep -qE 'trade_id[^,]*primary[[:space:]]+key|primary[[:space:]]+key[[:space:]]*\([[:space:]]*trade_id[[:space:]]*\)' && echo 1 || echo 0)"

# 5. region_code는 문자열 타입 (앞자리 0 보존)
check "region_code가 문자열 타입(TEXT/VARCHAR/CHAR)" "$(has 'region_code[[:space:]]+(text|varchar|char|character)')"

# 6. 금액 컬럼 deal_amount_krw + 정수 타입
check "금액 컬럼 deal_amount_krw (BIGINT/INTEGER)" "$(has 'deal_amount_krw[[:space:]]+(bigint|integer|int8|int)\b')"

# 7. 면적 컬럼 exclusive_area_sqm
check "면적 컬럼 exclusive_area_sqm" "$(has 'exclusive_area_sqm[[:space:]]')"

# 8. 단위 없는 금액/면적 컬럼 금지 (amount, price, area로 끝나는 컬럼명)
check "단위 없는 금액/면적 컬럼 없음" "$(lacks '\b[a-z_]*(amount|price|area)[[:space:]]+(int|integer|bigint|numeric|decimal|float|real|double)')"

# 9. 계약일 deal_date DATE
check "계약일 deal_date DATE 타입" "$(has 'deal_date[[:space:]]+date\b')"

# 인덱스는 "정확한 컬럼 순서"가 아니라 "Access Pattern을 지원하는가"로 본다.
# (예: (region_code, legal_dong, deal_date)도 ①을 지원한다. 채점 기준이 너무 좁으면 더 나은 설계를 FAIL시킨다.)
indexes=$(echo "$lower" | grep -oE 'create[[:space:]]+(unique[[:space:]]+)?index[^;]*' || true)

# 10. Access Pattern ① 인덱스: region_code로 시작하고 deal_date를 포함
check "인덱스 ① region_code 선두 + deal_date 포함" "$(echo "$indexes" | grep -qE '\([[:space:]]*region_code[^)]*deal_date' && echo 1 || echo 0)"

# 11. Access Pattern ② 인덱스: 면적(exclusive_area_sqm 또는 면적대 컬럼)으로 시작
check "인덱스 ② 면적 컬럼 선두 (exclusive_area_sqm 또는 면적대)" "$(echo "$indexes" | grep -qE '\([[:space:]]*(exclusive_area_sqm|area_band|[a-z_]*area[a-z_]*band[a-z_]*)' && echo 1 || echo 0)"

echo "  -> 점수: $pass / $total"
