-- 아파트 매매 실거래가 데이터 테이블
--
-- 국토교통부 실거래가 공개시스템의 아파트 매매 실거래가 자료를 저장하기 위한 스키마입니다.
-- PostgreSQL 기준입니다.

CREATE TABLE IF NOT EXISTS apartment_sales_transaction (
    id BIGSERIAL PRIMARY KEY,

    -- 거래 기본 정보
    deal_date        DATE        NOT NULL,  -- 거래일자 (YYYY-MM-DD)
    region_code      VARCHAR(10) NOT NULL,  -- 지역코드 (시도 + 시군구 코드)
    sigungu          VARCHAR(50),           -- 시군구명
    legal_dong       VARCHAR(100),          -- 법정동명
    apartment_name   VARCHAR(200) NOT NULL, -- 아파트명

    -- 주택 정보
    exclusive_area   NUMERIC(10, 2) NOT NULL, -- 전용면적 (제곱미터, ㎡)
    lot_number       VARCHAR(50),             -- 지번
    floor            INTEGER,                 -- 층 (지하층은 음수 또는 0 처리 권장)
    construction_year INTEGER,               -- 건축년도

    -- 도로명 주소 정보
    road_name              VARCHAR(200), -- 도로명
    road_main_code         VARCHAR(10),  -- 도로명건물본번코드
    road_sub_code          VARCHAR(10),  -- 도로명건물부번코드
    road_sigungu_code      VARCHAR(10),  -- 도로명시군구코드
    road_legal_dong_code   VARCHAR(10),  -- 도로명법정동코드

    -- 거래 금액 및 유형
    deal_price   BIGINT   NOT NULL, -- 매매가격 (원)
    deal_type    VARCHAR(20),       -- 거래유형 (중개거래 / 직접거래 등)

    -- 해제 정보
    cancellation_date DATE,   -- 해제사유발생일 (계약 해제 시)
    is_cancelled      BOOLEAN NOT NULL DEFAULT FALSE, -- 해제여부 (Y/N)

    -- 부동산 중개사 정보
    agency_location VARCHAR(200), -- 중개사소재지

    -- 시스템 관리 컬럼
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE apartment_sales_transaction IS '아파트 매매 실거래가 데이터';

-- 조회 성능을 위한 인덱스
CREATE INDEX IF NOT EXISTS idx_apartment_sales_deal_date ON apartment_sales_transaction(deal_date);
CREATE INDEX IF NOT EXISTS idx_apartment_sales_region ON apartment_sales_transaction(region_code, sigungu);
CREATE INDEX IF NOT EXISTS idx_apartment_sales_legal_dong ON apartment_sales_transaction(region_code, legal_dong);
CREATE INDEX IF NOT EXISTS idx_apartment_sales_apartment ON apartment_sales_transaction(apartment_name);
CREATE INDEX IF NOT EXISTS idx_apartment_sales_price ON apartment_sales_transaction(deal_price);
CREATE INDEX IF NOT EXISTS idx_apartment_sales_area ON apartment_sales_transaction(exclusive_area);
CREATE INDEX IF NOT EXISTS idx_apartment_sales_is_cancelled ON apartment_sales_transaction(is_cancelled);

-- 동일한 거래가 중복 적재되는 것을 방지하는 유니크 인덱스
-- (거래일자 + 지역코드 + 아파트명 + 전용면적 + 매매가격 + 층이 모두 같으면 동일 건으로 간주)
CREATE UNIQUE INDEX IF NOT EXISTS idx_apartment_sales_unique
    ON apartment_sales_transaction (
        deal_date,
        region_code,
        apartment_name,
        exclusive_area,
        deal_price,
        floor
    )
    WHERE NOT is_cancelled;
