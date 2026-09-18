-- ============================================================
--  새 문의가 들어오면 메일로 알려주는 트리거
--
--  실행 위치: Supabase 대시보드 > SQL Editor > New query > Run
--
--  !! 아래 2번 블록의 <RESEND_API_KEY> 를 실제 키로 바꾼 뒤 실행하세요.
--     바꾼 내용을 이 파일에 저장하지 마세요 — 이 저장소는 공개입니다.
--     SQL Editor 안에서만 바꿔서 실행하면 됩니다.
-- ============================================================


-- 1) pg_net 확장 --------------------------------------------
--    DB에서 바깥으로 HTTP 요청을 보낼 수 있게 해줍니다.
--    비동기라 메일 발송이 insert 를 붙잡지 않습니다.
create extension if not exists pg_net;


-- 2) API 키를 Vault 에 보관 ----------------------------------
--    테이블이나 함수 본문에 키를 박아두지 않기 위해서입니다.
--    이미 넣었다면 이 블록은 건너뛰어도 됩니다.
select vault.create_secret(
  '<RESEND_API_KEY>',                 -- ← 여기를 실제 키로 교체
  'resend_api_key',
  '소개 사이트 문의 알림용 Resend API key'
);


-- 3) 알림 함수 ------------------------------------------------
create or replace function public.notify_new_contact_message()
returns trigger
language plpgsql
security definer                      -- Vault 를 읽어야 하므로 소유자 권한으로 실행
set search_path = public, net, vault, extensions
as $$
declare
  api_key   text;
  sent_at   text;
  body_text text;
  body_html text;
begin
  select decrypted_secret into api_key
    from vault.decrypted_secrets
   where name = 'resend_api_key';

  -- 키가 없어도 문의 저장 자체는 성공시킨다. 알림만 건너뛴다.
  if api_key is null then
    raise warning '[알림] resend_api_key 가 Vault 에 없습니다. 메일을 건너뜁니다.';
    return new;
  end if;

  sent_at := to_char(new.created_at at time zone 'Asia/Seoul', 'YYYY-MM-DD HH24:MI');

  body_text :=
    '소개 사이트에 새 문의가 들어왔습니다.' || E'\n\n' ||
    '보낸 사람 : ' || new.name  || E'\n' ||
    '이메일    : ' || new.email || E'\n' ||
    '받은 시각 : ' || sent_at || ' (KST)' || E'\n\n' ||
    '────────────────────────' || E'\n' ||
    new.message || E'\n' ||
    '────────────────────────' || E'\n\n' ||
    '이 메일에 그대로 답장하면 보낸 사람에게 회신됩니다.';

  body_html :=
    '<div style="font-family:-apple-system,BlinkMacSystemFont,''Malgun Gothic'',sans-serif;'
    || 'max-width:560px;color:#131820;line-height:1.7">'
    || '<p style="font-size:12px;letter-spacing:.12em;color:#6E7C90;margin:0 0 18px">NEW MESSAGE</p>'
    || '<h2 style="font-size:19px;margin:0 0 20px">'
    ||   coalesce(replace(replace(new.name, '<', '&lt;'), '>', '&gt;'), '(이름 없음)')
    ||   '님의 새 문의</h2>'
    || '<table style="font-size:14px;border-collapse:collapse;margin-bottom:20px">'
    || '<tr><td style="color:#6E7C90;padding:3px 18px 3px 0">이메일</td><td>'
    ||   replace(replace(new.email, '<', '&lt;'), '>', '&gt;') || '</td></tr>'
    || '<tr><td style="color:#6E7C90;padding:3px 18px 3px 0">받은 시각</td><td>'
    ||   sent_at || ' (KST)</td></tr>'
    || '</table>'
    || '<div style="border-left:2px solid #1B3A5C;padding:2px 0 2px 18px;'
    || 'white-space:pre-wrap;font-size:15px">'
    ||   replace(replace(new.message, '<', '&lt;'), '>', '&gt;')
    || '</div>'
    || '<p style="font-size:12.5px;color:#6E7C90;margin-top:26px;'
    || 'border-top:1px solid #DBE0E8;padding-top:14px">'
    || '이 메일에 그대로 답장하면 보낸 사람에게 회신됩니다.</p>'
    || '</div>';

  perform net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer ' || api_key
               ),
    body    := jsonb_build_object(
                 'from',     '소개 사이트 <onboarding@resend.dev>',
                 'to',       jsonb_build_array('karion71@gmail.com'),
                 'reply_to', new.email,     -- 답장하면 문의한 사람에게 간다
                 'subject',  '[소개 사이트] ' || new.name || '님의 새 문의',
                 'text',     body_text,
                 'html',     body_html
               )
  );

  return new;
end;
$$;

revoke all on function public.notify_new_contact_message() from public, anon, authenticated;


-- 4) 트리거 연결 ----------------------------------------------
drop trigger if exists on_new_contact_message on public.contact_messages;

create trigger on_new_contact_message
  after insert on public.contact_messages
  for each row
  execute function public.notify_new_contact_message();


-- ============================================================
--  확인 및 문제 해결 — 위 실행 후 따로 돌려 보세요
-- ============================================================

-- (1) 테스트 메일 보내기: 아래 insert 후 메일함을 확인하세요.
--     확인이 끝나면 Table Editor 에서 이 행을 지우면 됩니다.
-- insert into public.contact_messages (name, email, message)
-- values ('알림 테스트', 'test@example.com', '메일 알림이 오는지 확인하는 중입니다.');

-- (2) 발송 결과 확인 — status_code 가 200 이면 성공.
--     pg_net 은 비동기라 몇 초 뒤에 기록이 남습니다.
-- select id, status_code, content, created
--   from net._http_response
--  order by created desc
--  limit 5;

-- (3) 트리거가 붙어 있는지
-- select tgname, tgenabled from pg_trigger
--  where tgrelid = 'public.contact_messages'::regclass and not tgisinternal;

-- (4) 키를 새 값으로 바꿀 때
-- select vault.update_secret(
--   (select id from vault.secrets where name = 'resend_api_key'),
--   '<새 RESEND_API_KEY>'
-- );

-- (5) 알림을 잠시 끄고 싶을 때 / 다시 켤 때
-- alter table public.contact_messages disable trigger on_new_contact_message;
-- alter table public.contact_messages enable  trigger on_new_contact_message;
