-- 아파트 매매 실거래가 Fact 테이블
-- 설계 기준: CLAUDE.md "Access Pattern", 네이밍: .claude/rules/naming.md
--   AP1. 법정동·계약년월별 평균 거래가 조회
--   AP2. 전용면적대별(60㎡ 이하 / 60~85㎡ / 85㎡ 초과) 시세 추이 조회

CREATE TABLE IF NOT EXISTS fact_apt_trade (
    -- 중복 적재 방지용 결정론적 ID (ON CONFLICT (trade_id) DO NOTHING)
    trade_id            TEXT          PRIMARY KEY,
    -- AP1: 법정동코드, 앞자리 0 보존을 위해 문자열
    region_code         VARCHAR(5)    NOT NULL CHECK (region_code ~ '^[0-9]{5}$'),
    -- AP1: 법정동명 (group by 대상)
    legal_dong          TEXT          NOT NULL,
    apt_name            TEXT          NOT NULL,
    -- AP2: 면적대 구분의 기준값
    exclusive_area_sqm  NUMERIC(7, 2),
    -- AP1·AP2: 집계 대상. 강남구는 21억 원을 넘는 거래가 흔하므로 INTEGER가 아닌 BIGINT
    deal_amount_krw     BIGINT        NOT NULL CHECK (deal_amount_krw > 0),
    -- AP1·AP2: 계약년월 집계 및 추이의 시간축
    deal_date           DATE          NOT NULL,
    -- 지하층은 음수로 들어올 수 있음
    floor               SMALLINT,
    build_year          SMALLINT,
    collected_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- AP2: 면적대를 저장 시점에 계산해 Metabase에서 CASE 식 없이 바로 group by 하도록 함
    area_band           TEXT GENERATED ALWAYS AS (
        CASE
            WHEN exclusive_area_sqm IS NULL THEN NULL
            WHEN exclusive_area_sqm <= 60   THEN '60㎡ 이하'
            WHEN exclusive_area_sqm <= 85   THEN '60~85㎡'
            ELSE                                 '85㎡ 초과'
        END
    ) STORED
);

-- AP1: 법정동별 + 계약일 범위(월) 필터 후 평균 거래가 — INCLUDE로 테이블 접근 없이 집계
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_dong_date
    ON fact_apt_trade (region_code, legal_dong, deal_date)
    INCLUDE (deal_amount_krw);

-- AP2: 면적대별 + 계약일 시간축 추이 — INCLUDE로 테이블 접근 없이 집계
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_area_band_date
    ON fact_apt_trade (area_band, deal_date)
    INCLUDE (deal_amount_krw);
