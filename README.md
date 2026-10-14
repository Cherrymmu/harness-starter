# harness-starter — 아파트 실거래가 대시보드 실습 스타터

"VSCode·Claude Code 활용개론" 특강 실습용 스타터 저장소입니다.
국토교통부 아파트 매매 실거래가(공공데이터포털 OpenAPI) 데이터를 PostgreSQL에 적재하고 Metabase 대시보드로 시각화합니다.

이 저장소에는 **데이터가 흐르는 길(수집 스크립트, DB, 대시보드 설정)만** 들어 있습니다.
Claude Code가 이 프로젝트를 만들 때 따를 **기준 파일(하네스)은 실습에서 여러분이 직접 작성**합니다.

## 들어 있는 것

```
harness-starter/
├── collector.py          # 공공데이터 API 호출 → PostgreSQL 적재 (재시도, 중복 적재 방지, --raw)
├── requirements.txt      # requests, psycopg2-binary (Python 3.10 이상)
├── docker-compose.yml    # db(postgres:16, local 프로필) + metabase(local·aws 프로필)
├── .env.local            # 로컬 DB 접속 정보 (로컬 컨테이너 전용, 비밀값 아님)
├── .env.aws.example      # AWS 트랙 템플릿 — 복사해서 .env.aws로 만들어 사용
├── sql/                  # 비어 있음 — 실습 STEP 6에서 Claude Code가 schema.sql을 만듭니다
└── docs/
    ├── setup_mac.md / setup_windows.md   # 도구 설치
    ├── data_portal_service_key.md        # 공공데이터 서비스키 발급
    ├── aws_preclass_setup.md             # AWS 트랙 사전 준비 (선택)
    └── run.md                            # 스택 실행 방법
```

## 실습에서 직접 만들 것

```
harness-starter/
├── CLAUDE.md             # 프로젝트 사실 기록 (목적, 데이터 소스, Access Pattern, DB 선택 이유)
└── .claude/
    ├── settings.json     # hooks 등록
    ├── rules/            # naming.md, ingestion.md
    ├── hooks/            # 규칙 위반을 강제로 막는 스크립트
    └── agents/           # 작업을 맡는 서브에이전트 정의
```

빈칸 템플릿과 체크포인트는 수업 교재(PART 3 실습)에 있습니다.

## 시작하기

```bash
git clone https://github.com/Cherrymmu/harness-starter.git
cd harness-starter

python3 -m venv .venv
source .venv/bin/activate          # Windows(WSL2 권장): 같은 명령
pip install -r requirements.txt

export APT_API_SERVICE_KEY="<공공데이터포털 Decoding 키>"
python collector.py --deal-ymd 202501 --raw     # resultCode 000이면 정상
```

도구 설치가 아직이면 `docs/setup_mac.md` 또는 `docs/setup_windows.md`부터 진행하세요.

## 실습 규칙

1. **프롬프트는 끝까지 바꾸지 않습니다.**
   `아파트 매매 실거래가 데이터를 저장할 테이블 하나 설계해서 sql/schema.sql로 저장해줘`
2. **Before는 이 저장소 바깥의 빈 폴더에서** 실행합니다. (`collector.py`에 컬럼 이름이 들어 있어서, 저장소 안에서 하면 "기준 없음" 상태가 되지 않습니다.)
3. 바뀌는 것은 기준 파일(CLAUDE.md · rules · hooks · agents)뿐입니다.

## 주의

- `.env.aws`(RDS 암호)와 AWS Access Key 파일은 **절대 커밋하지 마세요.** `.gitignore`에 이미 들어 있습니다.
- 수업이 끝나면 이 저장소에 `solution` 브랜치가 공개됩니다. 자기 결과와 비교해 보세요.
  ```bash
  git fetch origin
  git checkout solution
  ```
