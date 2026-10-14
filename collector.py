#!/usr/bin/env python3
"""국토교통부 아파트 매매 실거래가(상세 자료) 수집기 — 공공데이터포털 OpenAPI -> PostgreSQL 적재.

사용법:
    export APT_API_SERVICE_KEY="<공공데이터포털에서 발급받은 서비스키(Decoding/일반 인증키)>"
    export DATABASE_URL="postgresql://user:pass@localhost:5432/apt"
    python collector.py --deal-ymd 202501
    python collector.py --lawd-cd 11680 --deal-ymd 202501   # --lawd-cd 생략 시 강남구(11680) 기본값

CLAUDE.md의 rules/ingestion.md를 따른다:
  - 실패 시 최대 3회, 5초 간격 재시도
  - trade_id 기준 UPSERT로 중복 적재 방지 (ON CONFLICT DO NOTHING)
  - 원본 응답은 보관하지 않고 정제된 컬럼만 저장

주의: 공공데이터포털 API는 간혹 필드가 추가/변경될 수 있다. 처음 실행했는데 파싱 건수가 0이면
먼저 --raw 옵션으로 원본 XML을 그대로 출력해 태그명이 FIELD 상수와 일치하는지 확인할 것.
"""
import argparse
import os
import sys
import time
import xml.etree.ElementTree as ET
from datetime import date

import psycopg2
import requests
from psycopg2.extras import execute_values

# "상세 자료"(data.go.kr/data/15126468) API 엔드포인트
API_URL = "https://apis.data.go.kr/1613000/RTMSDataSvcAptTradeDev/getRTMSDataSvcAptTradeDev"
MAX_RETRIES = 3
RETRY_DELAY_SEC = 5
DEFAULT_LAWD_CD = "11680"  # 서울 강남구 (CLAUDE.md에서 확정한 실습 범위)


def fetch_raw_xml(service_key: str, lawd_cd: str, deal_ymd: str,
                   page_no: int = 1, num_of_rows: int = 1000) -> str:
    """rules/ingestion.md: 실패 시 최대 3회, 5초 간격 재시도."""
    params = {
        "serviceKey": service_key,
        "LAWD_CD": lawd_cd,
        "DEAL_YMD": deal_ymd,
        "pageNo": page_no,
        "numOfRows": num_of_rows,
    }
    last_err = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.get(API_URL, params=params, timeout=15)
            resp.raise_for_status()
            return resp.text
        except requests.RequestException as e:
            last_err = e
            print(f"[WARN] API 호출 실패 ({attempt}/{MAX_RETRIES}): {e}", file=sys.stderr)
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_DELAY_SEC)
    raise RuntimeError(f"API 호출 {MAX_RETRIES}회 모두 실패: {last_err}")


def parse_items(xml_text: str) -> list[dict]:
    """응답 XML(한글 태그)을 파싱해 rules/naming.md 컬럼명으로 변환한다."""
    root = ET.fromstring(xml_text)

    result_code = root.findtext(".//resultCode")
    if result_code not in (None, "000", "00"):
        result_msg = root.findtext(".//resultMsg")
        raise RuntimeError(f"API 에러 응답: code={result_code}, msg={result_msg}")

    items = []
    skipped = 0
    for item in root.findall(".//item"):
        def text(tag: str, default: str = "") -> str:
            v = item.findtext(tag)
            return v.strip() if v and v.strip() else default

        raw_amount = text("거래금액").replace(",", "")
        if not raw_amount:
            skipped += 1
            continue
        try:
            deal_amount_krw = int(raw_amount) * 10000  # 원본은 "만원" 단위 -> 원 단위로 변환
        except ValueError:
            skipped += 1
            continue

        year, month, day = text("년"), text("월"), text("일")
        try:
            deal_date = date(int(year), int(month), int(day))
        except (ValueError, TypeError):
            skipped += 1
            continue

        region_code = text("지역코드") or text("법정동코드") or DEFAULT_LAWD_CD
        legal_dong = text("법정동")
        apt_name = text("아파트")
        exclusive_area_raw = text("전용면적")
        floor_raw = text("층")
        build_year_raw = text("건축년도")
        serial_no = text("일련번호")

        # trade_id: 일련번호가 있으면 그걸 우선 사용, 없으면 핵심 필드 조합으로 결정론적 생성
        if serial_no:
            trade_id = f"{region_code}-{deal_date.strftime('%Y%m%d')}-{serial_no}"
        else:
            trade_id = (
                f"{region_code}-{deal_date.strftime('%Y%m%d')}-"
                f"{apt_name}-{exclusive_area_raw}-{floor_raw}-{deal_amount_krw}"
            )

        items.append({
            "trade_id": trade_id,
            "region_code": region_code,
            "legal_dong": legal_dong,
            "apt_name": apt_name,
            "exclusive_area_sqm": float(exclusive_area_raw) if exclusive_area_raw else None,
            "deal_amount_krw": deal_amount_krw,
            "deal_date": deal_date,
            "floor": int(floor_raw) if floor_raw.lstrip("-").isdigit() else None,
            "build_year": int(build_year_raw) if build_year_raw.isdigit() else None,
        })

    if skipped:
        print(f"[WARN] 파싱 실패/스킵된 레코드 {skipped}건 (원본 필드 누락 또는 형식 불일치)", file=sys.stderr)
    return items


def upsert(conn, rows: list[dict]) -> int:
    if not rows:
        return 0
    values = [
        (
            r["trade_id"], r["region_code"], r["legal_dong"], r["apt_name"],
            r["exclusive_area_sqm"], r["deal_amount_krw"], r["deal_date"],
            r["floor"], r["build_year"],
        )
        for r in rows
    ]
    with conn.cursor() as cur:
        execute_values(
            cur,
            """
            INSERT INTO fact_apt_trade
              (trade_id, region_code, legal_dong, apt_name, exclusive_area_sqm,
               deal_amount_krw, deal_date, floor, build_year, collected_at)
            VALUES %s
            ON CONFLICT (trade_id) DO NOTHING
            """,
            values,
            template="(%s,%s,%s,%s,%s,%s,%s,%s,%s, now())",
        )
    conn.commit()
    return len(values)


def main():
    parser = argparse.ArgumentParser(description="아파트 매매 실거래가 수집기")
    parser.add_argument("--lawd-cd", default=DEFAULT_LAWD_CD, help="법정동코드 5자리 (기본: 강남구 11680)")
    parser.add_argument("--deal-ymd", required=True, help="계약년월 YYYYMM (예: 202501)")
    parser.add_argument("--raw", action="store_true", help="파싱하지 않고 원본 XML 응답만 출력하고 종료 (디버깅용)")
    args = parser.parse_args()

    service_key = os.environ.get("APT_API_SERVICE_KEY")
    if not service_key:
        print("[ERROR] APT_API_SERVICE_KEY 환경변수가 설정되지 않았습니다. "
              "docs/data_portal_service_key.md 참고.", file=sys.stderr)
        sys.exit(1)

    try:
        xml_text = fetch_raw_xml(service_key, args.lawd_cd, args.deal_ymd)
    except RuntimeError as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(1)

    if args.raw:
        print(xml_text)
        return

    items = parse_items(xml_text)
    print(f"[INFO] 파싱된 거래 건수: {len(items)}")

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("[ERROR] DATABASE_URL 환경변수가 설정되지 않았습니다.", file=sys.stderr)
        sys.exit(1)

    conn = psycopg2.connect(database_url)
    try:
        inserted = upsert(conn, items)
        print(f"[INFO] 적재 시도 {inserted}건 (이미 있는 trade_id는 ON CONFLICT로 자동 스킵)")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
