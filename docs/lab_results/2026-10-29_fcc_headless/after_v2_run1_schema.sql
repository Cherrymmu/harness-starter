-- 아파트 매매 실거래가 거래 사실 테이블
-- 메인 Fact 테이블. 국토교통부 아파트 매매 실거래가 OpenAPI 응답을 정제해 저장한다.
-- PK trade_id는 거래 1건을 결정론적으로 구분한다:
--   {법정동코드}-{계약일 YYYYMMDD}-{단지 식별자(aptSeq 또는 apt_name)}-{전용면적}-{층}-{거래금액(원)}
-- 같은 날 같은 금액의 서로 다른 거래(다른 단지·호수)를 한 행으로 합쳐 유실하지 않기 위해
-- 단지 식별자를 PK에 포함한다.

CREATE TABLE fact_apt_trade (
    trade_id VARCHAR PRIMARY KEY,
    -- 거래 1건을 구분하는 결정론적 ID.
    -- 형식: {region_code}-{YYYYMMDD}-{aptSeq 또는 apt_name}-{exclusive_area_sqm}-{floor}-{deal_amount_krw}

    region_code VARCHAR(5) NOT NULL,
    -- 법정동코드. 5자리 문자열. 앞자리 0 보존을 위해 문자열 타입을 사용한다.

    legal_dong VARCHAR NOT NULL,
    -- 법정동명

    apt_name VARCHAR NOT NULL,
    -- 아파트명

    exclusive_area_sqm NUMERIC NOT NULL,
    -- 전용면적, 제곱미터 단위

    deal_amount_krw BIGINT NOT NULL,
    -- 거래금액, 원 단위 정수. API 원본의 "만원" 단위를 원 단위로 변환해 저장한다.

    deal_date DATE NOT NULL,
    -- 계약일

    floor INTEGER NOT NULL,
    -- 층

    build_year INTEGER,
    -- 건축년도

    area_band VARCHAR(10) GENERATED ALWAYS AS (
        CASE
            WHEN exclusive_area_sqm <= 60 THEN 'le_60'
            WHEN exclusive_area_sqm <= 85 THEN '60_85'
            ELSE 'gt_85'
        END
    ) STORED,
    -- 전용면적대. Access Pattern ②(면적대별 시세 추이)의 구간과 같다.
    -- le_60: 60㎡ 이하 / 60_85: 60~85㎡ / gt_85: 85㎡ 초과

    is_cancelled BOOLEAN NOT NULL DEFAULT FALSE,
    -- 계약 해제 여부. API cdealType이 'O'이면 true. 시세 계산 시 WHERE NOT is_cancelled로 제외한다.

    collected_at TIMESTAMPTZ NOT NULL DEFAULT now()
    -- 이 레코드를 수집한 시각
);

-- Access Pattern ①: 법정동·계약년월별 평균 거래가 조회에 사용
CREATE INDEX idx_fact_apt_trade_region_deal_date ON fact_apt_trade (region_code, deal_date);

-- Access Pattern ②: 전용면적대별 시세 추이 조회에 사용
CREATE INDEX idx_fact_apt_trade_area_band_deal_date ON fact_apt_trade (area_band, deal_date);

COMMENT ON COLUMN fact_apt_trade.region_code IS '법정동코드, 5자리 문자열';
COMMENT ON COLUMN fact_apt_trade.deal_amount_krw IS '거래금액, 원 단위 정수';
COMMENT ON COLUMN fact_apt_trade.deal_date IS '계약일, DATE 타입';
COMMENT ON COLUMN fact_apt_trade.exclusive_area_sqm IS '전용면적, 제곱미터 단위';
COMMENT ON COLUMN fact_apt_trade.is_cancelled IS '계약 해제 여부, BOOLEAN';
COMMENT ON COLUMN fact_apt_trade.collected_at IS '이 레코드를 수집한 시각';
