-- rules/naming.md를 따른다: snake_case, 단위를 컬럼명에 명시, trade_id를 PK로.
CREATE TABLE IF NOT EXISTS fact_apt_trade (
    trade_id            TEXT PRIMARY KEY,   -- {region_code}-{YYYYMMDD}-{단지}-{면적}-{층}-{금액}
    region_code         TEXT NOT NULL,      -- 5자리 문자열 (앞자리 0 보존)
    legal_dong          TEXT,
    apt_name            TEXT,
    exclusive_area_sqm  NUMERIC(8, 2),
    deal_amount_krw     BIGINT NOT NULL,    -- 원 단위 (API "만원" x 10000)
    deal_date           DATE NOT NULL,
    floor               INTEGER,
    build_year          INTEGER,
    is_cancelled        BOOLEAN NOT NULL DEFAULT false,  -- 계약 해제 (시세 계산에서 제외)
    area_band           TEXT GENERATED ALWAYS AS (
                            CASE
                                WHEN exclusive_area_sqm IS NULL THEN NULL
                                WHEN exclusive_area_sqm <= 60 THEN 'le_60'
                                WHEN exclusive_area_sqm <= 85 THEN '60_85'
                                ELSE 'gt_85'
                            END
                        ) STORED,
    collected_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Access Pattern ①: 법정동·계약년월별 평균 거래가 조회
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_region_date
    ON fact_apt_trade (region_code, deal_date);

-- Access Pattern ②: 전용면적대별 시세 추이 조회
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_area_band_date
    ON fact_apt_trade (area_band, deal_date);
