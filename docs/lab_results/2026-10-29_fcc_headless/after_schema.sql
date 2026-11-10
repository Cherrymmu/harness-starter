-- 아파트 매매 실거래가 팩트 테이블 (fact_apt_trade)
--
-- 설계 근거: CLAUDE.md Access Pattern
--   1. 법정동·계약년월별 평균 거래가 조회
--   2. 전용면적대별(60㎡ 이하 / 60~85㎡ / 85㎡ 초과) 시세 추이 조회
--
-- 네이밍 규칙(.claude/rules/naming.md):
--   - 테이블/컬럼: snake_case, 한글·공백·camelCase 금지, 단위 명시(_krw, _sqm)
--   - PK: trade_id (법정동코드 + 계약일 + 거래금액 조합, 결정론적 ID)
--   - 중복 적재 방지: collector가 ON CONFLICT (trade_id) DO NOTHING 으로 upsert

CREATE TABLE IF NOT EXISTS fact_apt_trade (
    trade_id           VARCHAR(128) NOT NULL,
    region_code        CHAR(5)      NOT NULL, -- 법정동코드 5자리 (앞자리 0 보존, 문자열 타입)
    legal_dong         VARCHAR(80)  NOT NULL, -- 법정동명
    apt_name           VARCHAR(200) NOT NULL, -- 아파트명
    exclusive_area_sqm NUMERIC(8, 2) NOT NULL, -- 전용면적 (㎡)
    deal_amount_krw    BIGINT       NOT NULL, -- 거래금액 (원 단위, API "만원" 값 * 10000)
    deal_date          DATE         NOT NULL, -- 계약일
    floor              INTEGER,               -- 층 (수집 원본에 누락될 수 있어 Nullable)
    build_year         INTEGER,               -- 건축년도 (수집 원본에 누락될 수 있어 Nullable)
    collected_at       TIMESTAMPTZ NOT NULL DEFAULT now(), -- 이 레코드를 수집한 시각

    CONSTRAINT pk_fact_apt_trade PRIMARY KEY (trade_id)
);

-- Access Pattern 1: 법정동·계약년월별 평균 거래가 조회
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_region_deal_date
    ON fact_apt_trade (region_code, deal_date);

-- Access Pattern 2: 전용면적대별 시세 추이 조회
CREATE INDEX IF NOT EXISTS idx_fact_apt_trade_area_deal_date
    ON fact_apt_trade (exclusive_area_sqm, deal_date);

COMMENT ON TABLE fact_apt_trade IS '국토교통부 아파트 매매 실거래가 수집 데이터 (Fact 테이블)';
COMMENT ON COLUMN fact_apt_trade.trade_id IS '결정론적 PK: 법정동코드(5) + 계약일(YYYYMMDD) + 거래금액(원) 조합';
COMMENT ON COLUMN fact_apt_trade.region_code IS '법정동코드, 5자리 문자열 (예: 11680 = 서울 강남구)';
COMMENT ON COLUMN fact_apt_trade.legal_dong IS '법정동명';
COMMENT ON COLUMN fact_apt_trade.apt_name IS '아파트명';
COMMENT ON COLUMN fact_apt_trade.exclusive_area_sqm IS '전용면적, 제곱미터(㎡)';
COMMENT ON COLUMN fact_apt_trade.deal_amount_krw IS '거래금액, 원 단위 정수';
COMMENT ON COLUMN fact_apt_trade.deal_date IS '계약일, DATE 타입';
COMMENT ON COLUMN fact_apt_trade.floor IS '층';
COMMENT ON COLUMN fact_apt_trade.build_year IS '건축년도';
COMMENT ON COLUMN fact_apt_trade.collected_at IS '이 레코드를 수집한 시각';
