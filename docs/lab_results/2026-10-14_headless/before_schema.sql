-- 아파트 매매 실거래가
-- 원천: 국토교통부 아파트 매매 실거래가 상세 자료 (RTMSDataSvcAptTradeDev)
-- DBMS: PostgreSQL
--
-- 적재 방식: 원천 데이터에는 거래를 유일하게 식별하는 키가 없고, 해제 신고 등으로
-- 과거 데이터가 수정된다. 따라서 (sgg_cd, 계약년월) 단위로 기존 행을 삭제한 뒤
-- 다시 적재하는 방식을 전제로 하며, 자연키 UNIQUE 제약은 두지 않는다.

CREATE TABLE apt_trade (
    id                  BIGSERIAL       PRIMARY KEY,

    -- 위치
    sgg_cd              CHAR(5)         NOT NULL,   -- 법정동 시군구코드 (LAWD_CD)
    umd_cd              CHAR(5),                    -- 법정동 읍면동코드
    umd_nm              VARCHAR(60)     NOT NULL,   -- 법정동명
    jibun               VARCHAR(20),                -- 지번
    road_nm             VARCHAR(100),               -- 도로명
    road_nm_bonbun      VARCHAR(5),                 -- 도로명 건물본번호
    road_nm_bubun       VARCHAR(5),                 -- 도로명 건물부번호

    -- 단지/세대
    apt_seq             VARCHAR(20),                -- 단지 일련번호
    apt_nm              VARCHAR(100)    NOT NULL,   -- 단지명
    apt_dong            VARCHAR(50),                -- 동
    floor               SMALLINT,                   -- 층 (지하는 음수)
    exclu_use_ar        NUMERIC(8, 4)   NOT NULL,   -- 전용면적(㎡)
    build_year          SMALLINT,                   -- 건축년도

    -- 거래
    deal_date           DATE            NOT NULL,   -- 계약일 (dealYear/dealMonth/dealDay)
    deal_amount         INTEGER         NOT NULL,   -- 거래금액(만원), 원천의 "82,500" → 82500
    dealing_gbn         VARCHAR(10),                -- 거래유형 (중개거래/직거래)
    estate_agent_sgg_nm VARCHAR(200),               -- 중개사 소재지
    rgst_date           DATE,                       -- 등기일자
    sler_gbn            VARCHAR(10),                -- 매도자 (개인/법인/공공기관/기타)
    buyer_gbn           VARCHAR(10),                -- 매수자 (개인/법인/공공기관/기타)
    land_leasehold_gbn  CHAR(1),                    -- 토지임대부 아파트 여부 (Y/N)

    -- 해제
    is_canceled         BOOLEAN         NOT NULL DEFAULT FALSE,  -- 해제여부 (cdealType = 'O')
    cdeal_day           DATE,                                    -- 해제사유 발생일

    -- 메타
    collected_at        TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT chk_apt_trade_amount CHECK (deal_amount > 0),
    CONSTRAINT chk_apt_trade_area   CHECK (exclu_use_ar > 0),
    CONSTRAINT chk_apt_trade_cancel CHECK (is_canceled OR cdeal_day IS NULL)
);

-- 지역·기간별 조회 및 (시군구, 월) 단위 재적재
CREATE INDEX idx_apt_trade_sgg_date ON apt_trade (sgg_cd, deal_date);

-- 단지별 시세 추이
CREATE INDEX idx_apt_trade_apt_date ON apt_trade (apt_seq, deal_date);

-- 전국 기간 조회
CREATE INDEX idx_apt_trade_date ON apt_trade (deal_date);

COMMENT ON TABLE  apt_trade              IS '아파트 매매 실거래가 (국토교통부)';
COMMENT ON COLUMN apt_trade.deal_amount  IS '거래금액(만원)';
COMMENT ON COLUMN apt_trade.exclu_use_ar IS '전용면적(㎡)';
COMMENT ON COLUMN apt_trade.is_canceled  IS '계약 해제 여부. 시세 분석 시 보통 제외';
