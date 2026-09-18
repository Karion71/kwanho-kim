-- ============================================================
--  김관호 소개 사이트 — 문의 폼 테이블
--  실행 위치: Supabase 대시보드 > SQL Editor > New query > Run
-- ============================================================

-- 1) 테이블 ---------------------------------------------------
create table if not exists public.contact_messages (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  name       text not null check (char_length(name)    between 1 and 60),
  email      text not null check (char_length(email)   between 3 and 200),
  message    text not null check (char_length(message) between 5 and 4000)
);

create index if not exists contact_messages_created_at_idx
  on public.contact_messages (created_at desc);

-- 2) RLS 활성화 -----------------------------------------------
--    이게 빠지면 publishable key로 전체 내용을 읽어갈 수 있습니다.
alter table public.contact_messages enable row level security;

-- 3) 정책: 누구나 "쓰기만" 가능 --------------------------------
--    insert 정책만 만들고 select 정책은 만들지 않습니다.
--    → 방문자는 메시지를 남길 수 있지만, 아무도 API로 읽을 수 없습니다.
--    → 내용 확인은 대시보드(Table Editor)에서만 합니다.
drop policy if exists "anon can submit a message" on public.contact_messages;

create policy "anon can submit a message"
  on public.contact_messages
  for insert
  to anon
  with check (true);

-- 4) 권한 ------------------------------------------------------
--    Supabase 기본 설정으로 이미 부여되어 있지만, 명시해 둡니다.
grant usage  on schema public              to anon;
grant insert on public.contact_messages    to anon;

-- (혹시 select 권한이 열려 있다면 회수)
revoke select, update, delete on public.contact_messages from anon;


-- ============================================================
--  확인용 쿼리 — 위 실행 후 따로 돌려 보세요
-- ============================================================

-- RLS가 켜졌는지
-- select relname, relrowsecurity from pg_class where relname = 'contact_messages';

-- 정책이 insert 하나뿐인지
-- select policyname, cmd, roles from pg_policies where tablename = 'contact_messages';

-- 받은 메시지 확인 (SQL Editor는 관리자 권한이므로 잘 보입니다)
-- select created_at, name, email, message
--   from public.contact_messages
--  order by created_at desc;
