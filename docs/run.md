# 실행 가이드 (로컬 트랙 / AWS 트랙)

> **처음 세팅하는 환경이라면** Docker/Python/AWS CLI부터 설치해야 한다 — macOS는 `setup_mac.md`, Windows는 `setup_windows.md` 먼저 끝내고 여기로 돌아온다. 이미 다 설치돼 있다면 바로 아래부터.


## 0. 공통 준비
```bash
cd apt-dashboard-starter          # GitHub에서 받았다면 cd harness-starter
python3 -m venv .venv && source .venv/bin/activate   # 가상환경 (선택이지만 권장)
pip install -r requirements.txt
# 서비스키는 실습 폴더 바깥 ~/.env.secret에 한 줄로 넣어 둔다 (docs/data_portal_service_key.md 3번)
set -a; source ~/.env.secret; set +a
```

---

## 로컬 트랙

### 1. DB + Metabase 기동
```bash
docker compose --env-file .env.local --profile local up -d
```
- `db` 컨테이너가 처음 뜰 때 `sql/schema.sql`이 자동 실행되어 `fact_apt_trade` 테이블이 생성된다.
- 상태 확인: `docker compose ps` — `db`가 `healthy`가 될 때까지 기다린다.
- 처음 한 번은 Metabase 한국어 문구 이미지를 만드느라 1~2분 더 걸린다(`metabase/` 폴더). 두 번째부터는 바로 뜬다.

### 2. 데이터 수집
```bash
export DATABASE_URL=postgresql://apt_user:apt_pass@localhost:5432/apt
python collector.py --deal-ymd 202501
```
처음엔 `--raw` 옵션으로 원본 응답부터 확인하는 걸 권장:
```bash
python collector.py --deal-ymd 202501 --raw
python collector.py --deal-ymd 202501 --dry-run   # 파싱 건수·해제 건수·trade_id 충돌만 확인 (DB에 안 씀)
```
추이 차트용으로 여러 달을 한 번에: `python collector.py --from 202401 --to 202412`
- 출력의 `API totalCount`와 `파싱`·`고유 trade_id` 건수가 같은지 본다. 다르면 `rules/naming.md`의 trade_id 정의를 다시 확인한다.

### 3. Metabase 연결
1. 브라우저에서 http://localhost:3000 접속 → 초기 설정 마법사 진행
2. "데이터베이스 추가" → PostgreSQL 선택
3. 호스트: `db` (compose 네트워크 안에서는 컨테이너 이름으로 접속), 포트: `5432`, DB명: `apt`, 사용자/암호: `.env.local`과 동일
4. 연결 후 "새 질문" → `fact_apt_trade` 테이블로 `agents/dashboard-builder.md`에 적힌 차트 2개 생성
- Metabase 설정(질문·대시보드)은 `metabase_data` 볼륨에 저장되므로 `docker compose down` 해도 남는다(`down -v`는 지움).

---

## AWS 트랙

### 1. 사전 준비 확인
`docs/aws_preclass_setup.md`를 끝냈는지, RDS 상태가 "Available"인지 먼저 확인한다.

### 2. 스키마 적용 (RDS에는 자동 초기화 스크립트가 없으므로 수동 실행)
```bash
cp .env.aws.example .env.aws   # 실제 값으로 채운 뒤
psql "$(grep DATABASE_URL .env.aws | cut -d= -f2-)" -f sql/schema.sql
```

### 3. Metabase만 기동 (DB 컨테이너는 띄우지 않음)
```bash
docker compose --env-file .env.aws --profile aws up -d
```

### 4. 데이터 수집
```bash
export DATABASE_URL=$(grep DATABASE_URL .env.aws | cut -d= -f2-)
python collector.py --from 202401 --to 202412
psql "$DATABASE_URL" -c "select count(*), sum(is_cancelled::int) as cancelled from fact_apt_trade"
```

### 5. Metabase 연결
1. http://localhost:3000 접속
2. "데이터베이스 추가" → PostgreSQL → 호스트에 **RDS 엔드포인트**(컨테이너 이름 아님), 나머지는 `.env.aws` 값과 동일
3. 이후 과정은 로컬 트랙과 동일

---

## 정리
```bash
docker compose --profile local down    # 또는 --profile aws down
docker compose down -v                 # 볼륨까지 완전히 삭제하고 싶을 때
```
