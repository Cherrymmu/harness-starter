# 환경 설치 — macOS

새로 이 프로젝트를 시작하는 macOS 사용자용. 이 문서가 끝나면 `docs/run.md`로 넘어간다.

## 1. Homebrew 설치 (이미 있으면 건너뛴다)
```bash
which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## 2. Docker — 둘 중 하나 선택

### 옵션 A: Docker Desktop (추천, 입문자용 — GUI 있음)
```bash
brew install --cask docker
```
설치 후 **Launchpad나 Applications 폴더에서 Docker.app을 한 번 직접 열어서** 라이선스 동의, 관리자 비밀번호 입력(최초 1회, 네트워크 권한용)까지 끝낸다. 메뉴바에 고래 아이콘이 뜨면 준비 완료.

### 옵션 B: Colima (CLI 전용, 가볍다 — GUI 앱 설치/실행 없이 전부 터미널로 끝남)
```bash
brew install colima docker docker-compose
mkdir -p ~/.docker
echo '{"cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]}' > ~/.docker/config.json
colima start
```
(Apple Silicon 기준 경로. Intel Mac이면 `/usr/local/lib/docker/cli-plugins`로 바꾼다 — `brew --prefix`로 확인)

### 확인 (둘 중 어느 쪽이든 동일)
```bash
docker version
docker compose version
```
에러 없이 버전이 출력되면 성공.

## 3. Python 확인
macOS는 보통 `python3`가 기본 포함돼 있다.
```bash
python3 --version   # 3.10 이상 권장
```
없거나 너무 오래됐으면: `brew install python@3.12`

## 4. AWS CLI 설치
```bash
brew install awscli
aws --version
```

## 5. AWS 자격 증명 등록 (중요: 이건 직접 한다)
```bash
aws configure
```
**Access Key ID/Secret Access Key는 비밀값이므로, Claude Code 세션이나 AI에게 붙여넣지 않는다.** 이 명령은 본인 터미널에서 직접 입력으로 끝낸다. (발급 방법은 `aws_preclass_setup.md` 3~4번 참고)

## 6. 프로젝트 받기
```bash
# 저장소로 공유받았다면
git clone <repo-url>
cd <repo>/training/code
# 폴더로 직접 공유받았다면 해당 경로로 이동
```

## 7. 다음 단계
→ `docs/data_portal_service_key.md`(공공데이터 서비스키) 와 `docs/run.md`(실제 실행)로 이동.
