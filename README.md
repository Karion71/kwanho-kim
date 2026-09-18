# 김관호 — 소개 사이트

AI 거버넌스 · 엔터프라이즈 SW 품질 전문가 김관호의 한 페이지 소개 사이트입니다.

**https://karion71.github.io/kwanho-kim/**

## 구성

| 파일 | 내용 |
|---|---|
| `index.html` | 사이트 전체 (HTML + CSS + JS 단일 파일) |
| `supabase-setup.sql` | 문의 폼용 Supabase 테이블·보안 정책 |

## 스택

의존성 없는 정적 페이지입니다. 빌드 과정이 없으며 `index.html` 하나만 서빙하면 동작합니다.

- **HTML + 순수 CSS** — CSS 변수 기반 토큰, 다크모드 자동 대응, 모바일 반응형
- **바닐라 JavaScript** — 프레임워크·라이브러리 없음
- **서체** — Hahmlet / IBM Plex Sans KR / IBM Plex Mono (Google Fonts)

## 문의 폼

방문자가 남긴 메시지는 Supabase의 `contact_messages` 테이블에 저장됩니다.
`supabase-js`를 쓰지 않고 PostgREST 엔드포인트로 직접 `fetch` 합니다.

소스에 노출된 키는 Supabase **publishable key** 로, 공개를 전제로 발급된 키입니다.
실제 보호는 테이블의 RLS 정책이 담당합니다.

- `insert` 정책만 존재 → 누구나 메시지를 남길 수 있음
- `select` 정책 없음 → **API로는 아무도 읽을 수 없음**
- 받은 메시지는 Supabase 대시보드의 Table Editor에서만 확인

스팸 대응은 숨은 유인 필드(honeypot)와 페이지 로드 후 3초 내 제출 차단 두 가지입니다.

## 로컬에서 보기

```bash
python -m http.server 8000
```

`http://localhost:8000` 으로 접속합니다. `file://` 로 직접 열면 브라우저 보안 정책 때문에
폼 전송이 차단될 수 있습니다.
