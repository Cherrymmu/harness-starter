# 실행 가이드 (로컬 트랙 / AWS 트랙)

> 도구 설치가 아직이면 `setup_mac.md` 또는 `setup_windows.md`부터 진행한 뒤 돌아오세요.
> `sql/schema.sql`은 실습 STEP 6에서 Claude Code가 만듭니다. 아래 "스키마 적용"은 그 뒤에 실행합니다.

## 0. 공통 준비
```bash
cd harness-starter
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export APT_API_SERVICE_KEY="<data_portal_service_key.md에서 발급받은 Decoding 키>"
python collector.py --deal-ymd 202501 --raw     # 원본 응답 확인 (DB에 넣지 않음)
```

---

## 로컬 트랙

### 1. DB + Metabase 기동
```bash
docker compose --env-file .env.local --profile local up -d
docker compose ps        # db가 healthy가 될 때까지 대기
```

### 2. 스키마 적용 (STEP 6에서 sql/schema.sql을 만든 뒤)
```bash
docker compose exec -T db psql -U apt_user -d apt < sql/schema.sql
```

### 3. 데이터 수집
```bash
export DATABASE_URL=postgresql://apt_user:apt_pass@localhost:5432/apt
python collector.py --deal-ymd 202501
docker compose exec db psql -U apt_user -d apt -c "SELECT count(*) FROM <내 테이블 이름>;"
```
"relation/column does not exist" 오류가 나면, 내 스키마와 `collector.py`의 INSERT 문이 기대하는 이름이 다르다는 뜻입니다.

### 4. Metabase 연결
1. http://localhost:3000 접속 → 초기 설정 (첫 기동은 1~2분 걸릴 수 있음)
2. 데이터베이스 추가 → PostgreSQL
3. 호스트 `db`, 포트 `5432`, DB `apt`, 사용자·암호는 `.env.local`과 동일
   (Metabase도 같은 Docker 네트워크 안에 있어서 localhost가 아니라 컨테이너 이름 `db`로 접속합니다)

---

## AWS 트랙

### 1. 사전 준비 확인
`aws_preclass_setup.md`를 끝냈고 RDS 상태가 "Available"인지 확인합니다.

### 2. 접속 정보와 스키마 적용
```bash
cp .env.aws.example .env.aws            # 실제 값으로 채우기 (커밋 금지)
export DATABASE_URL=$(grep DATABASE_URL .env.aws | cut -d= -f2-)
psql "$DATABASE_URL" -f sql/schema.sql   # STEP 6 이후
```

### 3. Metabase 기동과 수집
```bash
docker compose --env-file .env.aws --profile aws up -d
python collector.py --deal-ymd 202501
```

### 4. Metabase 연결
호스트에 RDS 엔드포인트를 넣고, 나머지는 `.env.aws` 값과 동일하게 입력합니다.

---

## 정리
```bash
docker compose --profile local down      # 또는 --profile aws down
docker compose --profile local down -v   # DB 볼륨까지 삭제 (데이터 초기화)
```
