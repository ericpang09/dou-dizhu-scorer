-- =========================================================================
--  鬥地主計分器 — 房間制 Schema（v3，含自動清理）
--  用法：Supabase Dashboard → SQL Editor → 貼呢段 → Run
--  特點：房間隔離 + 單局推送 + realtime + 48小時自動清理
-- =========================================================================

-- 先剷走舊表（注意：會清除現有資料）
drop table if exists public.games;
drop table if exists public.players;
drop table if exists public.rooms;

-- 房間表（一班朋友一個房，含最後活動時間）
create table public.rooms (
  id             text primary key,          -- 房間碼 e.g. K7M-3QP
  name           text,
  created_at     bigint,
  last_activity  bigint default (extract(epoch from now())*1000)::bigint  -- 最後活動時間
);

-- 玩家表（綁房間）
create table public.players (
  id          text primary key,
  room_id     text references public.rooms(id) on delete cascade,
  name        text,
  created_at  bigint
);

-- 局數表（綁房間）
create table public.games (
  id           text primary key,
  room_id      text references public.rooms(id) on delete cascade,
  date         bigint,
  landlord_id  text,
  farmer_a_id  text,
  farmer_b_id  text,
  base_score   int,
  multipliers  jsonb,
  spring       text,
  winner       text,
  note         text
);

-- =========================================================================
-- RLS：anon key 可操作
-- =========================================================================
alter table public.rooms   enable row level security;
alter table public.players enable row level security;
alter table public.games   enable row level security;

create policy "rooms_all"   on public.rooms   for all using (true) with check (true);
create policy "players_all" on public.players for all using (true) with check (true);
create policy "games_all"   on public.games   for all using (true) with check (true);

-- =========================================================================
-- Realtime
-- =========================================================================
alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.players;
alter publication supabase_realtime add table public.games;

-- 索引
create index idx_players_room on public.players(room_id);
create index idx_games_room   on public.games(room_id);
create index idx_rooms_activity on public.rooms(last_activity);

-- =========================================================================
-- 自動清理：48 小時冇活動嘅房間 + 佢嘅 players/games（級聯刪除）
-- 需要 pg_cron extension（Supabase 免費版支援）
-- =========================================================================

-- 啟用 pg_cron（如果未啟用）
create extension if not exists pg_cron with schema extensions;

-- 排程：每日凌晨 4 點（HK time）清理 48 小時前冇活動嘅房間
-- 呢個 function 用 SECURITY DEFINER 繞過 RLS 執行刪除
create or replace function public.cleanup_old_rooms()
returns void
language plpgsql
security definer
as $$
begin
  delete from public.rooms
  where last_activity < (extract(epoch from now())*1000)::bigint - (48 * 3600 * 1000);
  -- on delete cascade 會自動剷走對應嘅 players 同 games
end;
$$;

-- 排程每日跑一次（cron: 分 時 日 月 星期，UTC 時間）
-- HK 凌晨 4 點 = UTC 20:00（前一日）
select cron.schedule(
  'cleanup-old-rooms-daily',
  '0 20 * * *',   -- UTC 20:00 = HK 04:00
  $$ select public.cleanup_old_rooms(); $$
);
