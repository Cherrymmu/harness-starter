# 2026-10-29 FCC(무료 모델) 헤드리스 검증

- 실행: iMac, `fcc-claude -p ... --model nvidia_nim/nvidia/nemotron-3.5-super-vl-120b-a12b`
- 폴더: `scripts/make_lab.sh ~/harness-lab-fcc` (before/after/hooktest). aws는 호출만 기록하는 가짜 명령(stub) — 실제 AWS 호출 없음
- 프롬프트(Before/After 동일): 아파트 매매 실거래가 데이터를 저장할 테이블 하나 설계해서 sql/schema.sql로 저장해줘
- Before/After: `--permission-mode acceptEdits`, 동시 실행, 약 60초

| 항목 | Claude (10/14) | FCC nemotron-3.5-super-vl (10/29) |
|---|---|---|
| Before 점수 | 3/11 | 4/11 |
| After 점수 | 11/11 | 11/11 |
| 훅 ① camelCase 쓰기 차단 | 검증됨 | 차단됨 (hook1) |
| 훅 ② db.m5.large RDS 차단 | 검증됨 | 차단됨 (hook2b) — 모델은 유료인 걸 알고도 실행하려 함 |

## 하네스 정리 후 재실행 (같은 날, After만 2회)
정리 내용: `rules/naming.md` trade_id 정의 수정(단지·면적·층 포함) + `area_band`·`is_cancelled` 규칙 추가 + 인덱스 규칙 명시, `rules/ingestion.md` API 처리 규칙, `CLAUDE.md` "작업 규칙"(한국어만, 규칙 먼저 읽기, 충돌 발견 시 먼저 알리기). FCC 기본 모델을 nemotron-3.5-super-vl로 변경해 `--model` 없이 실행.

| | 정리 전 | 정리 후 run1 | 정리 후 run2 |
|---|---|---|---|
| 점수 | 11/11 | 11/11 | 11/11 |
| trade_id 정의 | 법정동+계약일+금액(충돌) | 새 정의 | 새 정의 |
| area_band 생성 컬럼 + (area_band, deal_date) 인덱스 | 없음 | 있음 | 있음 |
| is_cancelled | 없음 | 있음 | 있음 |
| 일본어 문자 | 섞임 | 0 | 0 |
| 없는 도구 호출 | 1회 | 0 | 0 |
