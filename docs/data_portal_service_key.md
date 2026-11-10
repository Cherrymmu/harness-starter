# 공공데이터포털 서비스키 발급 (수업 전 준비, 로컬/AWS 트랙 공통 — AWS 계정과 무관)

> AWS 사전 준비(`aws_preclass_setup.md`)와 별개다. 이건 **로컬 트랙 학생도 전원 필요**하다 — 공공데이터 API 자체를 쓰려면 누구나 이 키가 있어야 한다.

## 1. 활용 신청
1. https://www.data.go.kr 접속 → 로그인(회원가입 필요)
2. 검색창에 "아파트 매매 실거래가" 검색
3. **"국토교통부_아파트 매매 실거래가 상세 자료"**(데이터셋 번호 15126468) 선택
4. "활용신청" 클릭
5. 활용 목적: "교육/실습" 선택, 간단한 사유 작성
6. **자동승인 서비스**라 신청 즉시(또는 수 분 내) 승인된다

## 2. 서비스키 확인
1. 승인 후 "마이페이지" → "개발계정" → "활용신청 현황"
2. 방금 신청한 항목 클릭 → **일반 인증키(Encoding) / 일반 인증키(Decoding)** 두 종류가 표시됨
3. **Decoding 키를 사용한다** — `requests` 라이브러리로 호출할 때 URL 인코딩을 라이브러리가 자동으로 해주기 때문에, 이미 인코딩된 키(Encoding)를 다시 넣으면 이중 인코딩되어 오류가 난다

## 3. 키를 파일에 넣어 두기 (`~/.env.secret`)
키를 코드나 실습 폴더 안에 쓰지 않는다. 홈 폴더의 `~/.env.secret` 파일 한 곳에만 넣는다.
실습 폴더 바깥이라 Claude Code가 실습 중에 이 파일을 읽을 일이 없다.

```bash
code ~/.env.secret        # VS Code로 새 파일 열기 (code가 없으면 setup_mac.md 6번)
chmod 600 ~/.env.secret   # 나만 읽을 수 있게
```

파일 안에는 아래 한 줄만 넣고 저장한다. **따옴표 없이**, `=` 앞뒤에 띄어쓰기 없이 Decoding 키를 그대로 붙인다.

```
APT_API_SERVICE_KEY=여기에Decoding키를그대로
```

터미널을 열 때마다 아래 줄로 불러온다. 숫자(키 길이)가 나오면 정상이다.

```bash
set -a; source ~/.env.secret; set +a
echo ${#APT_API_SERVICE_KEY}
```

## 4. 동작 확인
```bash
python collector.py --deal-ymd 202501 --raw
```
`--raw` 옵션은 DB에 넣지 않고 원본 XML만 그대로 출력한다. `<resultCode>000</resultCode>`가 보이면 정상. `SERVICE_KEY_IS_NOT_REGISTERED_ERROR` 같은 메시지가 보이면 키 등록 후 시간이 더 필요하거나(최대 1시간), Decoding/Encoding 키를 바꿔 넣은 것이니 확인한다.
