#!/bin/bash
# Before/After 실습용 폴더 두 개를 이 저장소 밖에 만든다.
#   before/ — 완전히 빈 프로젝트 (수업안 0단계: 스타터 clone 전)
#   after/  — 스타터 코드 + 하네스(CLAUDE.md, .claude/rules·hooks·agents·settings.json)
# after/의 sql/schema.sql은 비워 둔다 — 실습 프롬프트가 그 파일을 새로 만들게 하기 위함.
# before/에 collector.py를 넣지 않는 이유: INSERT 문에 정답 컬럼명(fact_apt_trade, deal_amount_krw 등)이
# 그대로 들어 있어서, Claude가 그 파일을 읽으면 기준이 새어 들어간다.
# 사용법: scripts/make_lab.sh [대상 경로, 기본 ~/harness-lab]
#
# 저장소 밖에 만드는 이유: Claude Code는 상위 폴더의 CLAUDE.md까지 읽는다. 하네스가 있는 폴더 아래에서
# Before를 돌리면 기준이 새어 들어가 비교가 공정하지 않다.

set -euo pipefail
src="$(cd "$(dirname "$0")/.." && pwd)"
dest="${1:-$HOME/harness-lab}"

if [[ -e "$dest" ]]; then
  echo "[ERROR] $dest 가 이미 있습니다. 지우거나 다른 경로를 지정하세요." >&2
  exit 1
fi

starter=(collector.py requirements.txt docker-compose.yml)
mkdir -p "$dest/before/sql" "$dest/after/sql"
for f in "${starter[@]}"; do cp "$src/$f" "$dest/after/"; done
# 로컬 DB 접속 정보: 저장소에는 양식(.env.local.example)만 있다
if [[ -f "$src/.env.local" ]]; then cp "$src/.env.local" "$dest/after/"; else cp "$src/.env.local.example" "$dest/after/.env.local"; fi

cp "$src/CLAUDE.md" "$dest/after/"
mkdir -p "$dest/after/.claude"
cp -R "$src/.claude/rules" "$src/.claude/hooks" "$src/.claude/agents" "$src/.claude/settings.json" "$dest/after/.claude/"

echo "[OK] 생성 완료: $dest/before, $dest/after"
echo "다음 단계 (각 폴더에서 같은 프롬프트로 실행):"
echo "  cd $dest/before && claude"
echo "  cd $dest/after  && claude"
echo "  프롬프트: 아파트 매매 실거래가 데이터를 저장할 테이블 하나 설계해서 sql/schema.sql로 저장해줘"
echo "채점:"
echo "  $src/scripts/score_schema.sh $dest/before/sql/schema.sql Before"
echo "  $src/scripts/score_schema.sh $dest/after/sql/schema.sql After"
