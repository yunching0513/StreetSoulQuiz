-- ============================================================
-- 街道靈魂測驗 · Phase 1「世界牆」
-- Street Soul Quiz · Phase 1 community wall
-- ------------------------------------------------------------
-- 設計原則：
--  1. 不碰 IP。網站對使用者承諾「沒有 IP」，所以連 rate limiting 都不用 IP
--     （代價是擋不住有心人灌水 → 真的發生再加 Turnstile + Edge Function）。
--  2. 前端只拿得到「安全欄位」。owner_token 永遠不會離開資料庫，
--     靠 column-level GRANT 實作，不是靠前端自律。
--  3. 審核走 security definer RPC，權限來源是 moderators 表，
--     不是「只要登入就是管理員」。
--  4. 表名一律 wall_ 前綴：這個 schema 可能跟別的應用共用，
--     前綴讓命名空間乾淨，也方便日後整批搬走。
--  5. 先顯示、後審核：送出即上牆，命中過濾規則的暱稱會被清成 null
--     （貼文照樣在，只是不顯示名字），不給使用者錯誤訊息去學怎麼規避。
-- ============================================================

-- ------------------------------------------------------------
-- 1. 暱稱封鎖字清單（管理者自己維護，不需要改程式碼）
-- ------------------------------------------------------------
create table if not exists public.wall_blocked_terms (
  term       text primary key,
  note       text,
  created_at timestamptz not null default now()
);

comment on table public.wall_blocked_terms is
  '暱稱過濾字串。命中的暱稱會被清成 null，貼文照樣上牆。刻意從空的開始：請依實際遇到的狀況自行補充，不要預先把髒話清單寫進公開的 repo。';

alter table public.wall_blocked_terms enable row level security;   -- 一般人完全讀不到

-- ------------------------------------------------------------
-- 2. 打卡本體
-- ------------------------------------------------------------
create table if not exists public.wall_souls (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),

  type_code         text not null check (type_code ~ '^[MR][EH][CS][YI]$'),

  -- 暱稱是選填。未滿 18 歲的參與者，前端根本不會送這個欄位。
  -- 命中過濾規則時會被 trigger 清成 null。
  nickname          text check (nickname is null or char_length(nickname) between 1 and 20),
  nickname_scrubbed boolean not null default false,   -- 只有管理者看得到，用來調整封鎖清單

  country           text check (country is null or char_length(country) <= 8),
  city              text check (city is null or char_length(city) <= 40),
  lang              text not null default 'zh' check (lang in ('zh','en','ja')),

  status            text not null default 'visible' check (status in ('visible','hidden')),
  reports           integer not null default 0 check (reports >= 0),

  -- 一個測驗 session 只能打一次卡
  session_id        text not null unique check (char_length(session_id) between 4 and 64),

  -- 讓使用者可以自己撤掉打卡；前端存在 localStorage，anon 讀不到這欄
  owner_token       text not null check (char_length(owner_token) between 16 and 64)
);

comment on table public.wall_souls is '世界牆上的打卡。彙總統計仍走 Google Sheet，這裡只存使用者主動同意公開的內容。';

create index if not exists wall_souls_recent_idx on public.wall_souls (created_at desc) where status = 'visible';
create index if not exists wall_souls_type_idx on public.wall_souls (type_code, created_at desc) where status = 'visible';

-- ------------------------------------------------------------
-- 3. 暱稱過濾 trigger
-- ------------------------------------------------------------
create or replace function public.wall_scrub_nickname()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  probe text;
  hit   boolean := false;
begin
  new.nickname := nullif(btrim(coalesce(new.nickname, '')), '');
  new.nickname_scrubbed := false;

  if new.nickname is null then
    return new;
  end if;

  -- 正規化：小寫 + 去掉所有非文數字（中日文字元屬於 alnum，會保留），
  -- 這樣 "a.d.m.i.n" / "ｖ ｚ ｔ" 這種規避寫法也擋得住。
  probe := lower(regexp_replace(new.nickname, '[^[:alnum:]]', '', 'g'));

  -- (a) 看起來像網址／帳號／email／電話 → 這是廣告或想公開別人的聯絡方式
  if new.nickname ~* '(https?://|www\.|\.com|\.net|\.org|\.tw|\.jp|@|[0-9]{7,})' then
    hit := true;
  end if;

  -- (b) 冒充主辦單位或管理身分
  if not hit and probe ~ '(vzt|visionzero|tcan|admin|moderator|官方|主辦|管理員|小編)' then
    hit := true;
  end if;

  -- (c) 同一個字元連續灌水
  if not hit and new.nickname ~ '(.)\1{5,}' then
    hit := true;
  end if;

  -- (d) 管理者自訂清單
  if not hit and exists (
    select 1 from public.wall_blocked_terms b
    where b.term <> '' and probe like '%' || lower(b.term) || '%'
  ) then
    hit := true;
  end if;

  if hit then
    new.nickname := null;
    new.nickname_scrubbed := true;
  end if;

  return new;
end;
$$;

drop trigger if exists wall_souls_scrub_nickname on public.wall_souls;
create trigger wall_souls_scrub_nickname
  before insert or update of nickname on public.wall_souls
  for each row execute function public.wall_scrub_nickname();

-- ------------------------------------------------------------
-- 4. 管理者名冊
-- ------------------------------------------------------------
create table if not exists public.wall_moderators (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  added_at timestamptz not null default now()
);
alter table public.wall_moderators enable row level security;

create or replace function public.wall_is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.wall_moderators m where m.user_id = auth.uid());
$$;

-- ------------------------------------------------------------
-- 5. 權限：前端只碰得到安全欄位
-- ------------------------------------------------------------
alter table public.wall_souls enable row level security;

revoke all on public.wall_souls from anon, authenticated;

-- 讀：不含 owner_token、session_id、nickname_scrubbed、status、reports
grant select (id, created_at, type_code, nickname, country, city, lang)
  on public.wall_souls to anon, authenticated;

-- 寫：不含 status / reports / nickname_scrubbed（只能吃預設值）
grant insert (type_code, nickname, country, city, lang, session_id, owner_token)
  on public.wall_souls to anon, authenticated;

drop policy if exists "read visible souls" on public.wall_souls;
create policy "read visible souls" on public.wall_souls
  for select to anon, authenticated
  using (status = 'visible');

drop policy if exists "anyone may add one soul" on public.wall_souls;
create policy "anyone may add one soul" on public.wall_souls
  for insert to anon, authenticated
  with check (true);

-- ------------------------------------------------------------
-- 6. RPC：使用者自己能做的兩件事
-- ------------------------------------------------------------

-- 撤掉自己的打卡（憑 localStorage 裡的 token）
create or replace function public.wall_delete_soul(p_id uuid, p_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  delete from public.wall_souls where id = p_id and owner_token = p_token;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

-- 檢舉。累積到門檻就自動下架，管理者可以再放回來。
-- 這確實可以被濫用來惡意下架，但對一個 NGO 來說「誤藏」的代價遠低於
-- 「歧視字眼掛在牆上三小時」，所以刻意選這邊。
create or replace function public.wall_report_soul(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  hide_at constant integer := 3;
begin
  update public.wall_souls
     set reports = reports + 1,
         status  = case when reports + 1 >= hide_at then 'hidden' else status end
   where id = p_id and status = 'visible';
end;
$$;

-- ------------------------------------------------------------
-- 7. RPC：管理者專用（權限在函式裡檢查，不是「登入就算」）
-- ------------------------------------------------------------
create or replace function public.wall_moderation_feed(p_limit integer default 100, p_only_flagged boolean default false)
returns table (
  id uuid, created_at timestamptz, type_code text,
  nickname text, nickname_scrubbed boolean,
  country text, city text, lang text,
  status text, reports integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.wall_is_moderator() then
    raise exception 'not a moderator' using errcode = '42501';
  end if;
  return query
    select s.id, s.created_at, s.type_code,
           s.nickname, s.nickname_scrubbed,
           s.country, s.city, s.lang,
           s.status, s.reports
      from public.wall_souls s
     where (not p_only_flagged) or s.reports > 0 or s.status = 'hidden' or s.nickname_scrubbed
     order by s.created_at desc
     limit least(greatest(coalesce(p_limit, 100), 1), 500);
end;
$$;

create or replace function public.wall_set_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.wall_is_moderator() then
    raise exception 'not a moderator' using errcode = '42501';
  end if;
  if p_status not in ('visible','hidden') then
    raise exception 'bad status';
  end if;
  update public.wall_souls set status = p_status where id = p_id;
end;
$$;

create or replace function public.wall_clear_nickname(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.wall_is_moderator() then
    raise exception 'not a moderator' using errcode = '42501';
  end if;
  update public.wall_souls set nickname = null, nickname_scrubbed = true where id = p_id;
end;
$$;

create or replace function public.wall_list_blocked_terms()
returns setof public.wall_blocked_terms
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.wall_is_moderator() then
    raise exception 'not a moderator' using errcode = '42501';
  end if;
  return query select * from public.wall_blocked_terms order by created_at desc;
end;
$$;

create or replace function public.wall_add_blocked_term(p_term text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.wall_is_moderator() then
    raise exception 'not a moderator' using errcode = '42501';
  end if;
  if btrim(coalesce(p_term,'')) = '' then
    raise exception 'empty term';
  end if;
  insert into public.wall_blocked_terms (term, note)
  values (lower(btrim(p_term)), p_note)
  on conflict (term) do nothing;
end;
$$;

create or replace function public.wall_remove_blocked_term(p_term text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.wall_is_moderator() then
    raise exception 'not a moderator' using errcode = '42501';
  end if;
  delete from public.wall_blocked_terms where term = lower(btrim(p_term));
end;
$$;

-- ------------------------------------------------------------
-- 8. 函式執行權限
-- ------------------------------------------------------------
-- 兩層預設權限都要收掉，缺一不可：
--  (1) Postgres 本身建立函式時就把 EXECUTE 給 PUBLIC
--  (2) Supabase 另外對 public schema 設了 default privileges，
--      會把新函式的 EXECUTE 直接給 anon / authenticated
-- 只收 (1) 的話，在 Supabase 上 anon 照樣叫得到管理者函式。
-- 管理者函式內部雖然都有 wall_is_moderator() 檢查，但權限要收在門口。
revoke execute on function public.wall_scrub_nickname()                  from public, anon, authenticated;
revoke execute on function public.wall_delete_soul(uuid, text)           from public, anon, authenticated;
revoke execute on function public.wall_report_soul(uuid)                 from public, anon, authenticated;
revoke execute on function public.wall_is_moderator()                    from public, anon, authenticated;
revoke execute on function public.wall_moderation_feed(integer, boolean) from public, anon, authenticated;
revoke execute on function public.wall_set_status(uuid, text)            from public, anon, authenticated;
revoke execute on function public.wall_clear_nickname(uuid)              from public, anon, authenticated;
revoke execute on function public.wall_list_blocked_terms()              from public, anon, authenticated;
revoke execute on function public.wall_add_blocked_term(text, text)      from public, anon, authenticated;
revoke execute on function public.wall_remove_blocked_term(text)         from public, anon, authenticated;

-- 使用者自己能做的兩件事
grant execute on function public.wall_delete_soul(uuid, text) to anon, authenticated;
grant execute on function public.wall_report_soul(uuid)       to anon, authenticated;

-- 只有登入者才碰得到（進去之後還要過 wall_is_moderator）
grant execute on function public.wall_is_moderator()                        to authenticated;
grant execute on function public.wall_moderation_feed(integer, boolean)     to authenticated;
grant execute on function public.wall_set_status(uuid, text)           to authenticated;
grant execute on function public.wall_clear_nickname(uuid)                  to authenticated;
grant execute on function public.wall_list_blocked_terms()                  to authenticated;
grant execute on function public.wall_add_blocked_term(text, text)          to authenticated;
grant execute on function public.wall_remove_blocked_term(text)             to authenticated;
