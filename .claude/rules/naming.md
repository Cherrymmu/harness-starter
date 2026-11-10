# 네이밍 규칙

## 테이블
- snake_case
- PK: `trade_id` — 거래 1건을 구분하는 결정론적 ID. 형식:
  `{region_code}-{계약일 YYYYMMDD}-{단지 식별자}-{exclusive_area_sqm}-{floor}-{deal_amount_krw}`
  - 단지 식별자: API의 단지 일련번호(`aptSeq`, 예: `11680-4800`)가 있으면 그것, 없으면 `apt_name`
  - 해제 건은 끝에 `-c{해제일 YYMMDD}`를 붙인다 — API는 "해제 후 같은 조건으로 재계약"을 정상 1줄 + 해제 1~2줄로 함께 준다(2026-10-29 실측, 강남구 2025년 1~3월 충돌 106건 중 95건). 붙이지 않으면 정상 거래가 해제로 덮여 시세에서 빠진다
  - 위 값이 모두 같은 거래가 또 있으면(같은 층 다른 호수 등, 3개월에 11건) 두 번째부터 `-2`, `-3`을 붙인다
  - 법정동+계약일+금액만으로 만들지 않는다 — 같은 날 같은 금액의 다른 거래가 한 건으로 합쳐져 유실된다
  - 확인: 적재 후 그 달의 DB 건수가 API `totalCount`와 같아야 한다
- 메인 테이블명: `fact_apt_trade` (Fact 테이블 — 거래라는 "사실/이벤트"를 담음)
- 지역 정보를 분리한다면: `dim_region` (Dimension 테이블 — 법정동 코드, 동 이름 등 속성)

## 컬럼
- `region_code` — 법정동코드, 5자리 문자열(앞자리 0 보존을 위해 반드시 문자열 타입)
- `legal_dong` — 법정동명
- `apt_name` — 아파트명
- `exclusive_area_sqm` — 전용면적
- `deal_amount_krw` — 거래금액, 원 단위 정수 (원본 API의 "만원" 단위 값을 반드시 원 단위로 변환)
- `deal_date` — 계약일, DATE 타입
- `floor` — 층
- `build_year` — 건축년도
- `area_band` — 전용면적대, `exclusive_area_sqm`에서 계산하는 생성 컬럼(GENERATED ALWAYS AS … STORED). 값은 `le_60`(60㎡ 이하) / `60_85`(60~85㎡) / `gt_85`(85㎡ 초과) — CLAUDE.md Access Pattern ②의 구간과 같다
- `is_cancelled` — 계약 해제 여부, BOOLEAN (API `cdealType`이 `O`이면 true). 시세 계산에서는 `WHERE NOT is_cancelled`로 뺀다
- `collected_at` — 이 레코드를 수집한 시각

## 인덱스 (Access Pattern별 1개씩)
- ① `(region_code, deal_date)` — 법정동·계약년월별 평균 거래가
- ② `(area_band, deal_date)` — 면적대별 시세 추이

## 금지
- 테이블/컬럼명에 한글, 공백, camelCase 사용 금지
- `deal_amount`처럼 단위가 불명확한 이름 금지 — 반드시 단위를 이름에 포함 (`_krw`, `_sqm` 등)
