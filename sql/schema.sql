-- rules/naming.md를 따른다: snake_case, 단위를 컬럼명에 명시, trade_id를 PK로.
CREATE TABLE IF NOT EXISTS fact_apt_trade (
    trade_id            TEXT PRIMARY KEY,
    region_code         TEXT NOT NULL,
    legal_dong          TEXT,
    apt_name            TEXT,
    exclusive_area_sqm  NUMERIC,
    deal_amount_krw      BIGINT NOT NULL,
    deal_date           DATE NOT NULL,
    floor               INTEGER,
    build_year          INTEGER,
    collected_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Access Pattern ①: 법정동·계약년월별 평균 거래가 조회
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_region_date
    ON fact_apt_trade (region_code, deal_date);

-- Access Pattern ②: 전용면적대별 시세 추이 조회
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_area
    ON fact_apt_trade (exclusive_area_sqm);
