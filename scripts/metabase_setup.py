#!/usr/bin/env python3
"""Metabase 초기 설정 + Access Pattern 대시보드 생성 (강사용, 여러 번 실행해도 안전).

agents/dashboard-builder.md의 "반드시 만들 차트" 2개만 만든다:
  - 월별 평균 거래가 — 라인 차트 (법정동 필터)
  - 전용면적대별 평균 거래가 추이 — 면적대 3개 라인 (법정동 필터)

사용법 (training/code에서):
    set -a; . ./.env.aws; . ./.env.secret; set +a
    ~/.venvs/apt-capstone/bin/python scripts/metabase_setup.py
필요한 환경변수:
    MB_ADMIN_EMAIL, MB_ADMIN_PASSWORD          — Metabase 관리자 로그인
    POSTGRES_HOST/PORT/DB/USER/PASSWORD        — 대시보드가 읽을 데이터 DB (.env.aws = RDS)
    METABASE_URL (선택, 기본 http://localhost:3000)
"""
import os
import sys

import requests

MB = os.environ.get("METABASE_URL", "http://localhost:3000")
DB_NAME = "아파트 실거래가 (RDS)"
DASHBOARD_NAME = "강남구 아파트 매매 대시보드"
# 예전 이름 — 있으면 새 이름으로 바꿔 재사용 (중복 생성 방지)
OLD_NAMES = {"강남구 아파트 매매 시세": DASHBOARD_NAME,
             "① 계약년월별 평균 거래가": "월별 평균 거래가",
             "② 전용면적대별 시세 추이": "전용면적대별 평균 거래가 추이"}

DASHBOARD_DESC = "서울 강남구(11680) 아파트 매매 실거래가 월별 대시보드 — 해제 거래 제외"

# 해제 거래는 시세에서 뺀다 (rules/naming.md is_cancelled)
Q1_SQL = """
SELECT date_trunc('month', deal_date)::date AS 계약년월,
       round(avg(deal_amount_krw) / 1e8, 2) AS "평균 거래가(억 원)",
       count(*) AS "거래 건수"
FROM fact_apt_trade
WHERE NOT is_cancelled
  [[AND legal_dong = {{legal_dong}}]]
GROUP BY 1
ORDER BY 1
""".strip()

Q2_SQL = """
SELECT date_trunc('month', deal_date)::date AS 계약년월,
       CASE area_band WHEN 'le_60' THEN '60㎡ 이하'
                      WHEN '60_85' THEN '60~85㎡'
                      ELSE '85㎡ 초과' END AS 면적대,
       round(avg(deal_amount_krw) / 1e8, 2) AS "평균 거래가(억 원)"
FROM fact_apt_trade
WHERE NOT is_cancelled AND area_band IS NOT NULL
  [[AND legal_dong = {{legal_dong}}]]
GROUP BY 1, 2
ORDER BY 1, 2
""".strip()

DONG_TAG = {
    "legal_dong": {
        "id": "4f0b2c1e-legal-dong",
        "name": "legal_dong",
        "display-name": "법정동",
        "type": "text",
    }
}


def check(r: requests.Response) -> requests.Response:
    if not r.ok:
        sys.exit(f"[ERROR] {r.request.method} {r.url} -> {r.status_code}: {r.text[:500]}")
    return r


def env(name: str) -> str:
    v = os.environ.get(name)
    if not v:
        sys.exit(f"[ERROR] 환경변수 {name}가 없습니다 (.env.aws / .env.secret 로드 확인)")
    return v


def main():
    s = requests.Session()
    props = s.get(f"{MB}/api/session/properties", timeout=10).json()

    # 1. 첫 실행이면 관리자 계정 생성
    if not props.get("has-user-setup"):
        r = s.post(f"{MB}/api/setup", json={
            "token": props["setup-token"],
            "user": {"email": env("MB_ADMIN_EMAIL"), "password": env("MB_ADMIN_PASSWORD"),
                     "first_name": "관리자", "last_name": None, "site_name": "아파트 실거래가 캡스톤"},
            "prefs": {"site_name": "아파트 실거래가 캡스톤", "site_locale": "ko", "allow_tracking": False},
        }, timeout=60)
        check(r)
        print("[OK] 관리자 계정 생성")

    r = s.post(f"{MB}/api/session", json={"username": env("MB_ADMIN_EMAIL"),
                                         "password": env("MB_ADMIN_PASSWORD")}, timeout=30)
    check(r)
    s.headers["X-Metabase-Session"] = r.json()["id"]

    # 2. 데이터 DB 연결 (이미 있으면 재사용)
    dbs = s.get(f"{MB}/api/database", timeout=30).json()
    dbs = dbs.get("data", dbs)
    db = next((d for d in dbs if d["name"] == DB_NAME), None)
    if db is None:
        r = s.post(f"{MB}/api/database", json={
            "engine": "postgres", "name": DB_NAME,
            "details": {"host": env("POSTGRES_HOST"), "port": int(env("POSTGRES_PORT")),
                        "dbname": env("POSTGRES_DB"), "user": env("POSTGRES_USER"),
                        "password": env("POSTGRES_PASSWORD"), "ssl": True, "ssl-mode": "require"},
        }, timeout=120)
        check(r)
        db = r.json()
        print(f"[OK] 데이터 DB 연결: {DB_NAME}")
    db_id = db["id"]

    # 3. 질문 2개 (이름이 같으면 내용을 덮어씀)
    cards = {c["name"]: c for c in s.get(f"{MB}/api/card", timeout=30).json()}
    for old, new in OLD_NAMES.items():
        if old in cards and new not in cards:
            cards[new] = cards.pop(old)

    def upsert_card(name, sql, display, viz):
        body = {
            "name": name, "display": display, "visualization_settings": viz,
            "dataset_query": {"type": "native", "database": db_id,
                              "native": {"query": sql, "template-tags": DONG_TAG}},
        }
        if name in cards:
            r = s.put(f"{MB}/api/card/{cards[name]['id']}", json=body, timeout=60)
        else:
            r = s.post(f"{MB}/api/card", json=body, timeout=60)
        check(r)
        print(f"[OK] 질문: {name}")
        return r.json()["id"]

    q1 = upsert_card(
        "월별 평균 거래가", Q1_SQL, "line",
        {"graph.dimensions": ["계약년월"], "graph.metrics": ["평균 거래가(억 원)"],
         "graph.y_axis.title_text": "평균 거래가 (억 원)", "graph.x_axis.title_text": "계약년월"},
    )
    q2 = upsert_card(
        "전용면적대별 평균 거래가 추이", Q2_SQL, "line",
        {"graph.dimensions": ["계약년월", "면적대"], "graph.metrics": ["평균 거래가(억 원)"],
         "graph.y_axis.title_text": "평균 거래가 (억 원)", "graph.x_axis.title_text": "계약년월"},
    )

    # 4. 대시보드 + 법정동 필터
    dashes = {d["name"]: d for d in s.get(f"{MB}/api/dashboard", timeout=30).json()}
    for old, new in OLD_NAMES.items():
        if old in dashes and new not in dashes:
            dashes[new] = dashes.pop(old)
    if DASHBOARD_NAME in dashes:
        dash_id = dashes[DASHBOARD_NAME]["id"]
    else:
        r = s.post(f"{MB}/api/dashboard", json={
            "name": DASHBOARD_NAME,
            "description": DASHBOARD_DESC,
        }, timeout=30)
        check(r)
        dash_id = r.json()["id"]
    param = {"id": "dong", "name": "법정동", "slug": "legal_dong", "type": "string/=",
             "sectionId": "string"}

    def mapping(card_id):
        return [{"parameter_id": "dong", "card_id": card_id,
                 "target": ["variable", ["template-tag", "legal_dong"]]}]

    r = s.put(f"{MB}/api/dashboard/{dash_id}", json={
        "name": DASHBOARD_NAME, "description": DASHBOARD_DESC,
        "parameters": [param],
        "dashcards": [
            {"id": -1, "card_id": q1, "row": 0, "col": 0, "size_x": 24, "size_y": 7,
             "parameter_mappings": mapping(q1)},
            {"id": -2, "card_id": q2, "row": 7, "col": 0, "size_x": 24, "size_y": 7,
             "parameter_mappings": mapping(q2)},
        ],
    }, timeout=60)
    check(r)
    print(f"[OK] 대시보드: {MB}/dashboard/{dash_id}")


if __name__ == "__main__":
    main()
