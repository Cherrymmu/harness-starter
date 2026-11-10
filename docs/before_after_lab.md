# Before/After 실습 — 같은 프롬프트, 다른 결과

> 이 문서는 수업 3부 실습(0번 Before → 6번 After)의 실제 실행 결과입니다. 2026-10-14에 Claude Code(`claude -p`, 헤드리스 모드)로 직접 돌려본 결과이며, 원본 파일은 `docs/lab_results/2026-10-14_headless/`에 있습니다.

## 1. 실험 조건

두 폴더에 **완전히 같은 프롬프트**를 한 번씩 입력했습니다.

```text
아파트 매매 실거래가 데이터를 저장할 테이블 하나 설계해서 sql/schema.sql로 저장해줘
```

| | Before | After |
|---|---|---|
| 폴더 | `~/harness-lab/before` | `~/harness-lab/after` |
| 들어 있는 것 | 아무것도 없음 (빈 프로젝트) | 스타터 코드 + `CLAUDE.md` + `.claude/rules` · `hooks` · `agents` |
| 바뀐 것 | — | **프롬프트는 그대로, 프로젝트 안의 기준만 추가** |

Before 폴더를 완전히 비워 둔 이유가 있습니다. 스타터 코드인 `collector.py`의 INSERT 문에는 정답 컬럼명(`fact_apt_trade`, `deal_amount_krw` 등)이 그대로 들어 있습니다. 이 파일이 있으면 Claude가 그걸 읽고 따라 하기 때문에, 기준이 새어 들어가 비교가 공정하지 않게 됩니다.

## 2. 결과

| 항목 | Before (기준 없음) | After (하네스 있음) |
|---|---|---|
| 테이블명 | `apt_trade` | `fact_apt_trade` |
| 기본키(PK) | `id BIGSERIAL` (자동 증가 번호) | `trade_id TEXT` (중복 적재 방지용 ID) |
| 지역코드 | `sgg_cd CHAR(5)` | `region_code VARCHAR(5)` + 5자리 숫자 검사 |
| 거래금액 | `deal_amount INTEGER` — **만원 단위인데 이름에 단위가 없음** | `deal_amount_krw BIGINT` — 원 단위, 이름에 단위 표시 |
| 전용면적 | `exclu_use_ar` (API 필드명 그대로) | `exclusive_area_sqm` |
| 인덱스 | 지역+기간, 단지+기간, 기간 — 3개를 AI가 임의로 선택 | Access Pattern ①, ②에 1개씩, 정확히 2개 |
| **채점 점수** | **3 / 11** | **11 / 11** |

After가 금액 컬럼을 `BIGINT`로 고른 이유도 스스로 설명했습니다: "강남구는 21억 원을 넘는 거래가 흔해서 INTEGER(최대 약 21억)로는 부족하다." 이런 판단은 `CLAUDE.md`에 "실습 범위: 강남구"와 "금액은 원 단위"라는 기준이 적혀 있었기 때문에 나올 수 있었습니다.

## 3. 채점 기준 (`scripts/score_schema.sh`)

채점기는 **"좋은 스키마인가"가 아니라 "우리가 정한 기준을 따랐는가"**를 봅니다. 기준은 `rules/naming.md`와 `CLAUDE.md`의 Access Pattern에서 나왔습니다.

| # | 항목 | 근거 |
|---|---|---|
| 1 | 테이블명이 snake_case | `naming.md` |
| 2 | 식별자에 한글 없음 | `naming.md` |
| 3 | 메인 테이블명 `fact_apt_trade` | `naming.md` |
| 4 | PK가 `trade_id` | `naming.md` |
| 5 | `region_code`가 문자열 타입(앞자리 0 보존) | `naming.md` |
| 6 | 금액 컬럼 `deal_amount_krw`(정수) | `naming.md` |
| 7 | 면적 컬럼 `exclusive_area_sqm` | `naming.md` |
| 8 | 단위 없는 금액/면적 컬럼 없음 | `naming.md` |
| 9 | 계약일 `deal_date`가 DATE 타입 | `naming.md` |
| 10 | Access Pattern ① 인덱스 (`region_code`로 시작, `deal_date` 포함) | `CLAUDE.md` |
| 11 | Access Pattern ② 인덱스 (면적 컬럼으로 시작) | `CLAUDE.md` |

## 4. 수업에서 짚을 장면 두 가지

### 장면 1. AI가 우리 기준의 허점을 먼저 지적했습니다
After는 스키마를 만들면서 이렇게 말했습니다.

> `naming.md`는 `trade_id`를 "법정동코드 + 계약일 + 거래금액"으로 정의합니다. 같은 동에서 같은 날, 같은 금액으로 팔린 서로 다른 아파트 두 채는 같은 ID를 받게 됩니다. `ON CONFLICT DO NOTHING` 때문에 두 번째 거래는 에러 없이 조용히 사라집니다.

우리가 직접 쓴 기준이 틀려 있었다는 뜻입니다. 기준이 있다고 끝이 아니라, **그 기준이 실제 데이터에 맞는지 판단하고 고치는 일은 여전히 사람의 몫**입니다.

### 장면 2. 채점기도 처음엔 틀렸습니다
채점기 첫 버전은 인덱스를 "정확히 `(region_code, deal_date)`인가"로만 검사했습니다. 그런데 After가 만든 인덱스는 `(region_code, legal_dong, deal_date)`로, 법정동별 집계까지 지원하는 **더 나은 설계**였습니다. 첫 채점기는 이걸 FAIL로 처리해 After에 9점을 줬습니다.

그래서 기준을 "정확한 컬럼 순서"에서 **"Access Pattern을 지원하는가"**로 바꿨습니다. 자동 채점(클로즈드 루프)도 결국 사람이 만든 기준 위에서 돌아가기 때문에, 채점 기준 자체도 검증해야 합니다.

## 5. 공정하게 보기 — Before가 "나쁜" 스키마는 아닙니다

Before의 스키마에는 After에 없는 장점도 있습니다.
- **계약 해제 거래 처리**: API의 `cdealType = 'O'`(해제된 거래)를 `is_canceled` 컬럼으로 남기고, "시세 분석할 때는 빼야 한다"고 표시했습니다. 해제된 거래를 시세에 섞으면 평균값이 틀어지기 때문에 실제로 중요한 부분입니다.
- **원천 데이터의 한계 인식**: "API에는 거래 한 건을 유일하게 식별할 키가 없다"는 점을 파악하고, 그래서 자동 증가 번호를 PK로 썼다고 설명했습니다.

즉 Before의 점수가 낮은 이유는 AI가 무능해서가 아니라 **우리 프로젝트의 기준을 전달받지 못했기 때문**입니다. 이번 결과는 해제 거래 처리처럼 **우리 기준에 빠져 있던 것**도 알려줬습니다. 이 부분은 `rules/ingestion.md`와 수집 스크립트에 반영할 예정입니다.

## 6. 직접 재현하는 방법

```bash
cd training/code
scripts/make_lab.sh                      # ~/harness-lab/before, ~/harness-lab/after 생성

cd ~/harness-lab/before && claude        # 프롬프트 입력 후 종료
cd ~/harness-lab/after  && claude        # 같은 프롬프트 입력 후 종료

cd -  # training/code로 돌아와서 채점
scripts/score_schema.sh ~/harness-lab/before/sql/schema.sql Before
scripts/score_schema.sh ~/harness-lab/after/sql/schema.sql  After
```

AI의 출력은 실행할 때마다 조금씩 달라집니다. 점수가 이 문서와 정확히 같지 않아도 정상이며, "기준이 있을 때 점수가 확실히 올라간다"는 방향이 핵심입니다.
