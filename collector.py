#!/usr/bin/env python3
"""국토교통부 아파트 매매 실거래가(상세 자료) 수집기 — 공공데이터포털 OpenAPI -> PostgreSQL 적재.

사용법:
    export APT_API_SERVICE_KEY="<공공데이터포털에서 발급받은 서비스키(Decoding/일반 인증키)>"
    export DATABASE_URL="postgresql://user:pass@localhost:5432/apt"
    python collector.py --deal-ymd 202501                    # 한 달
    python collector.py --from 202401 --to 202412            # 여러 달
    python collector.py --lawd-cd 11680 --deal-ymd 202501    # --lawd-cd 생략 시 강남구(11680)
    python collector.py --deal-ymd 202501 --raw              # 원본 XML만 출력 (첫 페이지)
    python collector.py --deal-ymd 202501 --dry-run          # 파싱만 하고 DB에는 쓰지 않음

CLAUDE.md의 rules/ingestion.md를 따른다:
  - 실패 시 최대 3회, 5초 간격 재시도
  - HTTP 200이어도 resultCode가 000/00이 아니면 오류
  - totalCount가 한 페이지보다 많으면 다음 페이지까지 수집
  - 월 단위 교체 적재 (한 트랜잭션: 그 달 행 삭제 → 전체 입력, 실패하면 기존 행 유지)
  - 원본 응답은 보관하지 않고 정제된 컬럼만 저장

응답 태그는 영문(aptNm, dealAmount …)을 기본으로 읽고, 예전 한글 태그(아파트, 거래금액 …)도 지원한다.
처음 실행했는데 파싱 건수가 0이면 --raw로 원본 태그명을 확인할 것.
"""
import argparse
import os
import sys
import time
import xml.etree.ElementTree as ET
from datetime import date

import requests

# "상세 자료"(data.go.kr/data/15126468) API 엔드포인트
API_URL = "https://apis.data.go.kr/1613000/RTMSDataSvcAptTradeDev/getRTMSDataSvcAptTradeDev"
MAX_RETRIES = 3
RETRY_DELAY_SEC = 5
NUM_OF_ROWS = 1000
DEFAULT_LAWD_CD = "11680"  # 서울 강남구 (CLAUDE.md에서 확정한 실습 범위)

# 컬럼별로 읽을 태그 후보 — 앞에 있는 것부터 찾는다 (영문 우선, 한글은 예전 형식)
TAGS = {
    "amount": ("dealAmount", "거래금액"),
    "year": ("dealYear", "년"),
    "month": ("dealMonth", "월"),
    "day": ("dealDay", "일"),
    "region": ("sggCd", "지역코드", "법정동코드"),
    "dong": ("umdNm", "법정동"),
    "apt": ("aptNm", "아파트"),
    "apt_seq": ("aptSeq", "일련번호"),
    "area": ("excluUseAr", "전용면적"),
    "floor": ("floor", "층"),
    "build_year": ("buildYear", "건축년도"),
    "cancel_type": ("cdealType", "해제여부"),
    "cancel_day": ("cdealDay", "해제사유발생일"),
}


def fetch_raw_xml(service_key: str, lawd_cd: str, deal_ymd: str, page_no: int = 1) -> str:
    """rules/ingestion.md: 실패 시 최대 3회, 5초 간격 재시도."""
    params = {
        "serviceKey": service_key,
        "LAWD_CD": lawd_cd,
        "DEAL_YMD": deal_ymd,
        "pageNo": page_no,
        "numOfRows": NUM_OF_ROWS,
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


def check_result(root: ET.Element) -> int:
    """resultCode를 검사하고 totalCount를 돌려준다. HTTP 200 오류 응답도 여기서 잡는다."""
    result_code = root.findtext(".//resultCode")
    if result_code is None:
        # 키 오류 등은 OpenAPI_ServiceResponse 형식으로 온다
        err = root.findtext(".//returnAuthMsg") or root.findtext(".//errMsg")
        if err:
            raise RuntimeError(f"API 에러 응답: {err} (reason={root.findtext('.//returnReasonCode')})")
    elif result_code.strip() not in ("000", "00"):
        raise RuntimeError(f"API 에러 응답: code={result_code}, msg={root.findtext('.//resultMsg')}")
    total = root.findtext(".//totalCount")
    return int(total) if total and total.strip().isdigit() else 0


def parse_items(root: ET.Element, lawd_cd: str = DEFAULT_LAWD_CD,
                seen: dict | None = None) -> list[dict]:
    """응답 XML의 item을 rules/naming.md 컬럼명으로 변환한다.
    seen: 같은 달의 여러 페이지에 걸쳐 trade_id 중복 번호를 이어 매기기 위한 사전."""
    items = []
    skipped = 0
    seen = seen if seen is not None else {}
    for item in root.findall(".//item"):
        def text(key: str, default: str = "") -> str:
            for tag in TAGS[key]:
                v = item.findtext(tag)
                if v and v.strip():
                    return v.strip()
            return default

        raw_amount = text("amount").replace(",", "")
        try:
            deal_amount_krw = int(raw_amount) * 10000  # 원본은 "만원" 단위 -> 원 단위로 변환
            deal_date = date(int(text("year")), int(text("month")), int(text("day")))
        except (ValueError, TypeError):
            skipped += 1
            continue

        region_code = text("region") or lawd_cd
        apt_name = text("apt")
        area_raw = text("area")
        floor_raw = text("floor")
        build_year_raw = text("build_year")
        try:
            exclusive_area_sqm = round(float(area_raw), 2) if area_raw else None
        except ValueError:
            exclusive_area_sqm = None
        floor = int(floor_raw) if floor_raw.lstrip("-").isdigit() else None

        # trade_id: rules/naming.md 형식 — 법정동+계약일+금액만 쓰면 같은 날 같은 금액의 다른 거래가 합쳐진다
        complex_id = text("apt_seq") or apt_name
        is_cancelled = text("cancel_type").upper() == "O"
        trade_id = "-".join([
            region_code,
            deal_date.strftime("%Y%m%d"),
            complex_id,
            f"{exclusive_area_sqm:.2f}" if exclusive_area_sqm is not None else "",
            str(floor) if floor is not None else "",
            str(deal_amount_krw),
        ])
        if is_cancelled:
            # 해제 후 재계약은 정상 1줄 + 해제 줄이 같이 온다 → 해제 줄을 따로 구분
            trade_id += "-c" + "".join(ch for ch in text("cancel_day") if ch.isdigit())
        seen[trade_id] = seen.get(trade_id, 0) + 1
        if seen[trade_id] > 1:
            trade_id += f"-{seen[trade_id]}"  # 모든 값이 같은 다른 거래 (같은 층 다른 호수 등)

        items.append({
            "trade_id": trade_id,
            "region_code": region_code,
            "legal_dong": text("dong"),
            "apt_name": apt_name,
            "exclusive_area_sqm": exclusive_area_sqm,
            "deal_amount_krw": deal_amount_krw,
            "deal_date": deal_date,
            "floor": floor,
            "build_year": int(build_year_raw) if build_year_raw.isdigit() else None,
            "is_cancelled": is_cancelled,
        })

    if skipped:
        print(f"[WARN] 파싱 실패/스킵된 레코드 {skipped}건 (원본 필드 누락 또는 형식 불일치)", file=sys.stderr)
    return items


def collect_month(service_key: str, lawd_cd: str, deal_ymd: str) -> tuple[list[dict], int]:
    """한 달치를 모든 페이지에 걸쳐 수집한다. (행 목록, API totalCount)를 돌려준다."""
    rows: list[dict] = []
    seen: dict = {}
    page = 1
    while True:
        root = ET.fromstring(fetch_raw_xml(service_key, lawd_cd, deal_ymd, page))
        total = check_result(root)
        page_rows = parse_items(root, lawd_cd, seen)
        rows.extend(page_rows)
        if page * NUM_OF_ROWS >= total or not root.findall(".//item"):
            return rows, total
        page += 1


def month_range(start: str, end: str) -> list[str]:
    y, m = int(start[:4]), int(start[4:])
    ey, em = int(end[:4]), int(end[4:])
    out = []
    while (y, m) <= (ey, em):
        out.append(f"{y}{m:02d}")
        y, m = (y + 1, 1) if m == 12 else (y, m + 1)
    return out


def replace_month(conn, lawd_cd: str, deal_ymd: str, rows: list[dict]) -> int:
    """rules/ingestion.md: 한 트랜잭션 안에서 그 지역·그 달 행을 지우고 API 결과 전체를 넣는다.
    중간에 실패하면 롤백되어 기존 행이 그대로 남는다."""
    from psycopg2.extras import execute_values

    month_start = date(int(deal_ymd[:4]), int(deal_ymd[4:]), 1)
    values = [
        (
            r["trade_id"], r["region_code"], r["legal_dong"], r["apt_name"],
            r["exclusive_area_sqm"], r["deal_amount_krw"], r["deal_date"],
            r["floor"], r["build_year"], r["is_cancelled"],
        )
        for r in rows
    ]
    try:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM fact_apt_trade WHERE region_code = %s "
                "AND deal_date >= %s AND deal_date < (%s::date + interval '1 month')",
                (lawd_cd, month_start, month_start),
            )
            if values:
                execute_values(
                    cur,
                    """
                    INSERT INTO fact_apt_trade
                      (trade_id, region_code, legal_dong, apt_name, exclusive_area_sqm,
                       deal_amount_krw, deal_date, floor, build_year, is_cancelled, collected_at)
                    VALUES %s
                    """,
                    values,
                    template="(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s, now())",
                )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    return len(values)


def main():
    parser = argparse.ArgumentParser(description="아파트 매매 실거래가 수집기")
    parser.add_argument("--lawd-cd", default=DEFAULT_LAWD_CD, help="법정동코드 5자리 (기본: 강남구 11680)")
    parser.add_argument("--deal-ymd", help="계약년월 YYYYMM (한 달)")
    parser.add_argument("--from", dest="ymd_from", help="시작 계약년월 YYYYMM")
    parser.add_argument("--to", dest="ymd_to", help="끝 계약년월 YYYYMM (포함)")
    parser.add_argument("--raw", action="store_true", help="원본 XML 첫 페이지만 출력하고 종료 (디버깅용)")
    parser.add_argument("--dry-run", action="store_true", help="파싱 결과만 출력하고 DB에는 쓰지 않음")
    args = parser.parse_args()

    if args.deal_ymd:
        months = [args.deal_ymd]
    elif args.ymd_from and args.ymd_to:
        months = month_range(args.ymd_from, args.ymd_to)
    else:
        parser.error("--deal-ymd 또는 --from/--to 를 지정하세요")

    service_key = os.environ.get("APT_API_SERVICE_KEY")
    if not service_key:
        print("[ERROR] APT_API_SERVICE_KEY 환경변수가 설정되지 않았습니다. "
              "docs/data_portal_service_key.md 참고.", file=sys.stderr)
        sys.exit(1)

    if args.raw:
        print(fetch_raw_xml(service_key, args.lawd_cd, months[0]))
        return

    conn = None
    if not args.dry_run:
        database_url = os.environ.get("DATABASE_URL")
        if not database_url:
            print("[ERROR] DATABASE_URL 환경변수가 설정되지 않았습니다.", file=sys.stderr)
            sys.exit(1)
        import psycopg2
        conn = psycopg2.connect(database_url)

    try:
        for ymd in months:
            try:
                rows, total = collect_month(service_key, args.lawd_cd, ymd)
            except RuntimeError as e:
                # rules/ingestion.md: 실패한 달은 기록하고 다음으로 넘어간다
                print(f"[ERROR] {ymd}: {e}", file=sys.stderr)
                continue
            cancelled = sum(r["is_cancelled"] for r in rows)
            unique = len({r["trade_id"] for r in rows})
            msg = f"[INFO] {ymd}: API totalCount {total}, 파싱 {len(rows)}건 (해제 {cancelled}), 고유 trade_id {unique}"
            if unique < len(rows):
                msg += f" — trade_id 충돌 {len(rows) - unique}건, rules/naming.md 확인 필요"
            print(msg)
            if conn is not None:
                n = replace_month(conn, args.lawd_cd, ymd, rows)
                print(f"[INFO] {ymd}: DB에 {n}건 적재 (그 달 기존 행은 교체)")
    finally:
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    main()
