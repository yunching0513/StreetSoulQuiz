-- ============================================================
-- 街道靈魂測驗 · 造訪人數計數器
-- Street Soul Quiz · visit counter
-- ------------------------------------------------------------
-- 這個專案以前放過一個「假的」計數器，後來拿掉了（commit 411f36f）。
-- 所以這次的數字必須是真的。
--
-- 存什麼：一個隨機 UUID（存在訪客自己的 localStorage）＋ 一個日期。
--   沒有 IP、沒有 user agent、沒有 referrer、沒有任何識別碼。
--   (visitor, day) 當 primary key，所以同一個瀏覽器同一天只算一次。
--
-- 拿不到什麼：因為 id 是瀏覽器自己產生的，清掉瀏覽器資料就會變成新的一個，
--   無痕視窗也一樣。所以這是「造訪的瀏覽器數」的估計值，不是「真人數」。
--   而且理論上可以被腳本灌水（一直送新 UUID）。不加 IP 或 captcha 就沒得解，
--   而「不記錄 IP」對這個網站來說比精準計數更重要 → 刻意接受這個限制。
--   文案上不要把它講成精確的人數。
--
-- 附帶好處：每天有人來就會產生資料庫活動，
--   這剛好能避免 Supabase free 方案「7 天低活動自動暫停」把世界牆弄消失。
-- ============================================================

create table if not exists public.wall_visits (
  visitor uuid not null,
  day     date not null default current_date,
  primary key (visitor, day)
);

comment on table public.wall_visits is
  '造訪計數。只有隨機 UUID + 日期，沒有 IP、UA、referrer。同一瀏覽器同一天只算一次。';

create index if not exists wall_visits_day_idx on public.wall_visits (day);

alter table public.wall_visits enable row level security;

-- 前端完全碰不到這張表，只能透過下面兩支函式。
revoke all on public.wall_visits from anon, authenticated;

-- 記一次造訪（同一天重複呼叫不會重複計數）
create or replace function public.wall_log_visit(p_visitor uuid)
returns void
language sql
security definer
set search_path = public
as $fn$
  insert into public.wall_visits (visitor, day)
  values (p_visitor, current_date)
  on conflict (visitor, day) do nothing;
$fn$;

-- 讀計數。回傳的是數字，不是任何一列資料。
create or replace function public.wall_visit_stats()
returns table (total bigint, today bigint, since date)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    (select count(distinct visitor) from public.wall_visits)                as total,
    (select count(*) from public.wall_visits where day = current_date)      as today,
    (select min(day) from public.wall_visits)                               as since;
$fn$;

-- 兩層預設權限都要收（Postgres 給 PUBLIC，Supabase 另外給 anon/authenticated）
revoke execute on function public.wall_log_visit(uuid)  from public, anon, authenticated;
revoke execute on function public.wall_visit_stats()    from public, anon, authenticated;

grant execute on function public.wall_log_visit(uuid)   to anon, authenticated;
grant execute on function public.wall_visit_stats()     to anon, authenticated;
