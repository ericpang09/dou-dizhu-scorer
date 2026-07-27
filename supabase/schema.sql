-- =========================================================================
--  鬥地主計分器 — 房間制 Schema（v2）
--  用法：Supabase Dashboard → SQL Editor → 貼呢段 → Run
--  特點：房間隔離 + 單局推送上推 + realtime 即時同步
-- =========================================================================

-- 房間表（一班朋友一個房）
create table if not exists public.rooms (
  id          text primary key,          -- 6位房間碼 e.g. AB3K9X
  name        text,
  created_at  bigint
);

-- 玩家表（綁房間）
create table if not exists public.players (
  id          text primary key,
  room_id     text not null references public.rooms(id) on delete cascade,
  name        text not null,
  created_at  bigint
);

-- 局數表（綁房間）
create table if not exists public.games (
  id           text primary key,
  room_id      text not null references public.rooms(id) on delete cascade,
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
-- RLS：anon key 可操作（簡單存取，由前端控制 room_id 隔離）
-- =========================================================================
alter table public.rooms   enable row level security;
alter table public.players enable row level security;
alter table public.games   enable row level security;

drop policy if exists "rooms_all"   on public.rooms;
drop policy if exists "players_all" on public.players;
drop policy if exists "games_all"   on public.games;
create policy "rooms_all"   on public.rooms   for all using (true) with check (true);
create policy "players_all" on public.players for all using (true) with check (true);
create policy "games_all"   on public.games   for all using (true) with check (true);

-- =========================================================================
-- 啟用 Realtime（即時同步用）—— 推送 games/players 變動俾同房所有人
-- =========================================================================
alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.players;
alter publication supabase_realtime add table public.games;

-- 索引（加快按房間查詢）
create index if not exists idx_players_room on public.players(room_id);
create index if not exists idx_games_room   on public.games(room_id);
