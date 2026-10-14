# 네이밍 규칙

## 테이블
- snake_case
- PK: `trade_id` — 법정동코드(5자리) + 계약일(YYYYMMDD) + 거래금액(원 단위) 조합으로 생성하는 결정론적 ID
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
- `collected_at` — 이 레코드를 수집한 시각

## 금지
- 테이블/컬럼명에 한글, 공백, camelCase 사용 금지
- `deal_amount`처럼 단위가 불명확한 이름 금지 — 반드시 단위를 이름에 포함 (`_krw`, `_sqm` 등)
