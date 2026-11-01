"""metabase.jar 안의 한국어 번역(ko.json)에서 ko_overrides.json에 적은 문구만 바꿔 새 jar를 만든다."""
import json
import re
import shutil
import sys
import zipfile

SRC, DST, OVR = sys.argv[1:4]
ENTRY = "frontend_client/app/locales/ko.json"   # 화면(프런트엔드) 문구
EDN = "i18n/ko.edn"                              # 서버가 내려보내는 문구 (컬렉션 이름 등)

conf = json.load(open(OVR, encoding="utf-8"))
overrides = {k: v for k, v in conf.items() if not k.startswith("_")}
backend = {k: v for k, v in conf.get("_backend", {}).items() if not k.startswith("_")}


def patch_edn(text: str) -> str:
    # ko.edn은 "원문"\n"번역" 쌍이 이어진 형식
    for k, v in backend.items():
        pat = re.compile('^' + re.escape(json.dumps(k, ensure_ascii=False)) + '\n"(?:[^"\\\\]|\\\\.)*"$', re.M)
        text, n = pat.subn(lambda m: json.dumps(k, ensure_ascii=False) + "\n" + json.dumps(v, ensure_ascii=False), text)
        if n != 1:
            sys.exit(f"[ERROR] ko.edn에서 원문을 찾지 못함: {k}")
    return text
with zipfile.ZipFile(SRC) as zin, zipfile.ZipFile(DST, "w") as zout:
    for info in zin.infolist():
        if info.filename == ENTRY:
            data = json.loads(zin.read(info))
            table = data["translations"][""]
            missing = [k for k in overrides if k not in table]
            if missing:
                sys.exit(f"[ERROR] 번역 원문이 없음 (Metabase 버전 확인): {missing}")
            # "New ..." 버튼·메뉴의 "새로운 X"는 "새 X"로 (Grafana ko-KR과 같은 말투)
            auto = 0
            for k, v in table.items():
                if k.startswith("New ") and k not in overrides and v["msgstr"][0].startswith("새로운 "):
                    v["msgstr"] = ["새 " + v["msgstr"][0][len("새로운 "):]]
                    auto += 1
            for k, v in overrides.items():
                table[k]["msgstr"] = [v]
            zout.writestr(info, json.dumps(data, ensure_ascii=False).encode("utf-8"))
            print(f"[OK] {len(overrides)}개 문구 교체, '새로운'→'새' {auto}개")
        elif info.filename == EDN:
            zout.writestr(info, patch_edn(zin.read(info).decode("utf-8")).encode("utf-8"))
            print(f"[OK] 서버 문구 {len(backend)}개 교체")
        else:
            with zin.open(info) as src, zout.open(info, "w") as dst:
                shutil.copyfileobj(src, dst, 1 << 20)
