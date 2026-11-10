# 환경 설치 — Windows

새로 이 프로젝트를 시작하는 Windows 사용자용. **핵심 원칙: WSL2(리눅스) 환경 안에서 작업한다.** PowerShell/CMD에서 직접 하지 않는 이유는, 이 프로젝트의 모든 명령어(`docs/run.md` 등)가 bash 기준으로 작성돼 있어서 WSL2 Ubuntu 터미널에서 그대로 복붙해 쓸 수 있기 때문이다 — macOS/Linux 사용자와 똑같은 명령어를 쓰게 된다.

## 1. WSL2 설치
PowerShell을 **관리자 권한**으로 열고:
```powershell
wsl --install
```
완료되면 **재부팅**한다. 재부팅 후 Ubuntu 터미널이 자동으로 뜨고, 리눅스용 사용자 이름/비밀번호를 설정하라고 나온다(윈도우 로그인 계정과 별개, 아무거나 정해도 됨).

이미 WSL이 깔려 있다면 Ubuntu가 설치돼 있는지만 확인:
```powershell
wsl --list --verbose
```
없으면: `wsl --install -d Ubuntu`

## 2. Docker Desktop 설치
1. https://www.docker.com/products/docker-desktop/ 에서 Windows용 설치파일 다운로드·실행
2. 설치 중 **"Use WSL 2 instead of Hyper-V"** 옵션이 나오면 체크(최근 버전은 기본값)
3. 설치 후 Docker Desktop 실행 → 설정(Settings) → **Resources → WSL Integration** → "Enable integration with my default WSL distro" 켜고, Ubuntu도 켜져 있는지 확인
4. 작업 표시줄에 고래 아이콘이 뜨고 "Docker Desktop is running"이 보이면 준비 완료

## 3. 이제부터는 전부 WSL2(Ubuntu) 터미널에서 작업
시작 메뉴에서 "Ubuntu" 검색해서 실행. 아래는 전부 이 터미널 안에서.

### Python 확인
```bash
python3 --version
```
없으면: `sudo apt update && sudo apt install -y python3 python3-pip python3-venv`

### AWS CLI 설치
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install -y unzip
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

### Docker 확인 (Docker Desktop의 WSL 통합이 제대로 됐는지)
```bash
docker version
docker compose version
```
"command not found"가 뜨면 Docker Desktop의 WSL Integration 설정(2-3번)을 다시 확인한다.

## 4. AWS 자격 증명 등록 (중요: 이건 직접 한다)
```bash
aws configure
```
**Access Key ID/Secret Access Key는 비밀값이므로, Claude Code 세션이나 AI에게 붙여넣지 않는다.** 발급 방법은 `aws_preclass_setup.md` 3~4번 참고.

## 5. 프로젝트 받기
```bash
# WSL2 안의 리눅스 파일시스템에 두는 게 성능상 좋다 (Windows 쪽 /mnt/c/... 말고)
cd ~
git clone <repo-url>
cd harness-starter
```

## 6. 다음 단계
→ `docs/data_portal_service_key.md`(공공데이터 서비스키) 와 `docs/run.md`(실제 실행)로 이동. 이후 모든 명령어는 계속 이 WSL2 Ubuntu 터미널에서 실행한다.
