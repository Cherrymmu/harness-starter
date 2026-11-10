> **정답본 (`solution` 브랜치)** — 수업에서 직접 만든 하네스 구성 요소의 정답과 강사 실행 결과입니다. 학생용 스타터(`main` 브랜치)에 아래를 더한 것입니다. 내 결과와 나란히 놓고 비교해 보세요.
> - `CLAUDE.md`, `.claude/`(rules · hooks · agents · settings.json), `sql/schema.sql` — 정답 하네스 (2026-10-29 실데이터로 검증한 trade_id 규칙 포함)
> - `scripts/score_schema.sh` — Before/After 채점기(11개 항목): `bash scripts/score_schema.sh <내 schema.sql>`
> - `scripts/metabase_setup.py` — 대시보드 자동 생성(강남구 아파트 매매 대시보드: 월별 평균 거래가, 전용면적대별 평균 거래가 추이, 법정동 필터), `scripts/make_lab.sh` — Before/After 실습 폴더 생성
> - `docs/slides/lab_slides_with_answers.pptx` — 수업 실습 자료 **정답 포함판** (STEP마다 정답 장 + 붙여 넣기용 전체 파일 장), `docs/slides/lecture_slides.pptx` — 수업 자료
> - `docs/before_after_lab.md`, `docs/lab_results/` — 강사 사전 실행 결과(2026-10-14 Claude, 2026-10-29 무료 모델)
>
> **수업 중에 바뀐 것 (2026-11-10)**
> - 서비스키: `export` 대신 실습 폴더 바깥 `~/.env.secret`에 한 줄(`APT_API_SERVICE_KEY=키`, 따옴표 없이)로 넣고 `set -a; source ~/.env.secret; set +a`로 불러옵니다 → `docs/data_portal_service_key.md` 3번
> - `collector.py --raw | head`로 앞부분만 볼 때 나던 BrokenPipeError Traceback을 없앴습니다
> - Mac에서 `code: command not found`일 때 설정 방법 → `docs/setup_mac.md` 6번
> - 실습 폴더 구조: `~/harness-lab/before`(빈 폴더, Before) · `~/harness-lab/after/apt-dashboard-starter`(After). 비교는 `cd ~/harness-lab && diff before/sql/schema.sql after/apt-dashboard-starter/sql/schema.sql`
> - 로컬 DB 접속 정보: 저장소에는 양식 `.env.local.example`만 있습니다. 처음 한 번 `cp .env.local.example .env.local` 후 `docker compose --env-file .env.local --profile local up -d` (zip으로 받았다면 `.env.local`이 이미 있습니다)
> - 적재 확인: `psql "$DATABASE_URL" -c "SELECT count(*) FROM fact_apt_trade;"` (psql이 없으면 `docker compose exec db psql -U apt_user -d apt -c "…"`), Metabase DB 연결의 호스트는 `localhost`가 아니라 `db`

# 아파트 실거래가 데이터 파이프라인과 대시보드 구현 — 실습 스타터

## 개요
국토교통부 아파트 매매 실거래가(공공데이터포털 OpenAPI)를 월 단위 배치로 수집해 PostgreSQL에 적재하고, Metabase 대시보드로 시각화합니다.
"VSCode & Claude Code 활용개론 — 하네스 엔지니어링" 특강의 실습용 스타터입니다.

이 폴더에는 **데이터 플로우(수집 스크립트, DB, 대시보드 설정)만** 들어 있습니다.
Claude Code가 이 프로젝트를 만들 때 따를 **하네스 구성 요소(CLAUDE.md · rules · hooks · agents)는 실습에서 직접 작성**합니다.

## 사용 기술
Python 3.10 이상
PostgreSQL 16 (로컬 Docker 또는 AWS RDS)
Metabase
Docker Compose
Claude Code (B 트랙: 무료 모델 `fcc-claude`)

## 아키텍처
```
공공데이터포털 OpenAPI ──▶ collector.py ──▶ PostgreSQL ──▶ Metabase 대시보드
 (아파트 매매 실거래가)     (월 단위 배치)     fact_apt_trade     (월별 평균 거래가,
                                           로컬 Docker / RDS     면적대별 추이)
```

## 폴더 구조
```
apt-dashboard-starter/
├── collector.py          # 공공데이터 API 호출 → PostgreSQL 적재
├── requirements.txt      # requests, psycopg2-binary
├── docker-compose.yml    # db(postgres:16, local 프로필) + metabase(local·aws 프로필)
├── metabase/             # Metabase 한국어 문구를 바꾼 이미지 설정 (손대지 않아도 됨)
├── .env.local.example    # 로컬 DB 접속 정보 양식 → cp로 .env.local을 만들어 씀
├── .env.aws.example      # AWS 트랙 템플릿 — 복사해서 .env.aws로 만들어 사용
├── sql/                  # 비어 있음 — 실습 STEP 6에서 Claude Code가 schema.sql을 만듭니다
└── docs/
    ├── setup_mac.md / setup_windows.md   # 도구 설치
    ├── data_portal_service_key.md        # 공공데이터 서비스키 발급
    ├── aws_preclass_setup.md             # AWS 트랙 사전 준비 (선택)
    └── run.md                            # 스택 실행 방법
```

실습에서 직접 만들 것:
```
apt-dashboard-starter/
├── CLAUDE.md             # 프로젝트 사실 기록 (목적, 데이터 소스, Access Pattern, DB 선택 이유)
└── .claude/
    ├── settings.json     # hooks 등록
    ├── rules/            # naming.md, ingestion.md
    ├── hooks/            # 규칙 위반을 막는 스크립트
    └── agents/           # 작업을 맡는 서브에이전트 정의
```
빈칸 템플릿과 체크포인트는 **수업 실습 자료 PPT**에 있습니다.

## 기능
- 서울 강남구(법정동코드 11680) 아파트 매매 거래를 계약년월 단위로 수집
- 같은 달을 다시 넣어도 건수가 늘지 않는 월 단위 교체 적재 (멱등 적재)
- API 오류 시 재시도
- 원본 응답 확인(`--raw`), DB에 쓰지 않고 결과만 확인(`--dry-run`), 기간 지정(`--from` · `--to`)
- 대시보드: 월별 평균 거래가 차트, 전용면적대별 평균 거래가 추이 차트, 법정동 필터
- Metabase 한국어 화면: 로그인·대시보드 문구를 자연스러운 말로 바꾼 이미지를 씁니다. 처음 실행할 때 이미지를 만드느라 1~2분 더 걸립니다

## 시작하기
```bash
# 받은 zip을 풀고 이 폴더로 이동 (GitHub에서 받았다면 cd harness-starter)
cd apt-dashboard-starter
cp .env.local.example .env.local   # 로컬 DB 접속 정보 (zip에는 이미 들어 있으면 건너뜀)

python3 -m venv .venv
source .venv/bin/activate          # Windows(WSL2 권장): 같은 명령
pip install -r requirements.txt

# 서비스키는 실습 폴더 바깥 ~/.env.secret에 한 줄로 넣어 둔다 (docs/data_portal_service_key.md 3번)
set -a; source ~/.env.secret; set +a
python collector.py --deal-ymd 202501 --raw     # resultCode 000이면 정상
```
도구 설치가 아직이면 `docs/setup_mac.md` 또는 `docs/setup_windows.md`부터 진행하세요. DB와 대시보드 실행은 `docs/run.md`에 있습니다.

## 실습 규칙
1. **프롬프트는 끝까지 바꾸지 않습니다.**
   `아파트 매매 실거래가 데이터를 저장할 테이블 하나 설계해서 sql/schema.sql로 저장해줘`
2. **Before는 이 폴더 바깥의 빈 폴더에서** 실행합니다. (`collector.py`에 컬럼 이름이 들어 있어서, 이 폴더 안에서 하면 "기준 없음" 상태가 되지 않습니다.)
3. 바뀌는 것은 하네스 구성 요소(CLAUDE.md · rules · hooks · agents)뿐입니다.
4. **B 트랙(Claude 구독 없이 무료 모델)**: 명령의 `claude`를 전부 `fcc-claude`로 바꿔 입력합니다. 준비 방법은 사전 준비 자료 Part 3-B.

## 주의
- `.env.aws`(RDS 비밀번호)와 AWS Access Key 파일은 **절대 커밋하지 마세요.** `.gitignore`에 이미 들어 있습니다.
- 수업이 끝나면 정답 하네스와 강사 실행 결과가 수업 후 자료로 공개됩니다. 자기 결과와 비교해 보세요.

## 한계
- 공공데이터 API는 일일 호출 횟수 제한이 있어, 여러 해를 한 번에 받으면 막힐 수 있습니다. 기간을 나눠 받으세요.
- 계약 후 신고까지 시간이 걸려 최근 1~2개월 데이터는 나중에 건수가 늘어납니다. 그 달을 다시 수집하면 반영됩니다.
- 해제된 거래도 함께 내려옵니다. 시세를 볼 때는 해제 거래를 빼야 합니다(어떻게 표시할지는 실습에서 rules로 정합니다).
