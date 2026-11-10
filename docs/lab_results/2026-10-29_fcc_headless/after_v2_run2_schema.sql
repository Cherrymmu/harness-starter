-- 아파트 매매 실거래가 데이터 저장 테이블
-- CLAUDE.md Access Pattern에 따른 인덱스 설계:
--   ① 법정동·계약년월별 평균 거래가 조회  →  (region_code, deal_date) 인덱스 사용
--   ② 전용면적대별 시세 추이 조회        →  (area_band, deal_date) 인덱스 사용

CREATE TABLE IF NOT EXISTS fact_apt_trade (
    trade_id TEXT PRIMARY KEY,
    -- 형식: {region_code}-{계약일 YYYYMMDD}-{단지 식별자}-{exclusive_area_sqm}-{floor}-{deal_amount_krw}
    -- 단지 식별자: API aptSeq가 있으면 그것, 없으면 apt_name

    region_code VARCHAR(5) NOT NULL,
    -- 법정동코드, 5자리 문자열(앞자리 0 보존을 위해 문자열 타입)

    legal_dong TEXT NOT NULL,
    -- 법정동명

    apt_name TEXT NOT NULL,
    -- 아파트명

    exclusive_area_sqm NUMERIC(6, 2),
    -- 전용면적(㎡)

    deal_amount_krw BIGINT NOT NULL,
    -- 거래금액, 원 단위 정수(원본 API의 "만원" 단위 값을 원 단위로 변환)

    deal_date DATE NOT NULL,
    -- 계약일

    floor INTEGER,
    -- 층

    build_year INTEGER,
    -- 건축년도

    area_band TEXT GENERATED ALWAYS AS (
        CASE
            WHEN exclusive_area_sqm IS NULL THEN NULL
            WHEN exclusive_area_sqm <= 60 THEN 'le_60'
            WHEN exclusive_area_sqm <= 85 THEN '60_85'
            ELSE 'gt_85'
        END
    ) STORED,
    -- 전용면적대: le_60(60㎡ 이하) / 60_85(60~85㎡) / gt_85(85㎡ 초과)

    is_cancelled BOOLEAN NOT NULL DEFAULT FALSE,
    -- 계약 해제 여부(API cdealType이 'O'이면 true). 시세 계산 시 WHERE NOT is_cancelled로 제외

    collected_at TIMESTAMPTZ NOT NULL DEFAULT now()
    -- 이 레코드를 수집한 시각
);

COMMENT ON TABLE fact_apt_trade IS '국토교통부 아파트 매매 실거래가 OpenAPI에서 수집한 거래 건Fact 테이블';
COMMENT ON COLUMN fact_apt_trade.trade_id IS '거래 PK. {region_code}-{계약일}-{단지 식별자}-{전용면적}-{층}-{거래금액}';
COMMENT ON COLUMN fact_apt_trade.region_code IS '법정동코드, 5자리 문자열(앞자리 0 보존)';
COMMENT ON COLUMN fact_apt_trade.deal_amount_krw IS '거래금액, 원 단위';
COMMENT ON COLUMN fact_apt_trade.is_cancelled IS '계약 해제 여부. true면 시세 계산에서 제외';

-- Access Pattern ①: 법정동·계약년월별 평균 거래가 조회
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_region_deal_date
    ON fact_apt_trade (region_code, deal_date);

-- Access Pattern ②: 전용면적대별 시세 추이 조회
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_area_band_deal_date
    ON fact_apt_trade (area_band, deal_date);
