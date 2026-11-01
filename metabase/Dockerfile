# Metabase 공식 이미지 + 로그인·비밀번호 화면의 한국어 문구 교체 (ko_overrides.json)
# 버전을 올리면 원문이 바뀌었을 수 있다 — 빌드가 실패하면 ko_overrides.json의 키를 확인할 것
ARG MB_VERSION=v0.63.19.1
FROM metabase/metabase:${MB_VERSION} AS base

FROM python:3.12-slim AS patch
COPY --from=base /app/metabase.jar /work/metabase.jar
COPY patch_locale.py ko_overrides.json /work/
RUN python /work/patch_locale.py /work/metabase.jar /work/patched.jar /work/ko_overrides.json

FROM base
COPY --from=patch /work/patched.jar /app/metabase.jar
