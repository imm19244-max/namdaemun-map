-- 남대문 같이지도 — Supabase 스키마 + 권한(RLS)
-- 실행: Supabase 대시보드 > SQL Editor > New query 에 전체 붙여넣고 Run (1회)
-- 비로그인: 공개된 장소·꿀팁·번역 읽기 / 로그인: 꿀팁·장소추천·찜·붐빔제보 / 관리자: 승인·숨김·신고처리

-- ───────── 1. 프로필 ─────────
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text check (char_length(nickname) <= 20),
  role text not null default 'user' check (role in ('user','admin')),
  created_at timestamptz not null default now()
);

-- 가입 시 프로필 자동 생성
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 관리자 여부
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- ───────── 2. 장소 ─────────
create table if not exists public.places (
  id text primary key default gen_random_uuid()::text,
  name text not null check (char_length(name) between 1 and 60),
  name_key text generated always as (lower(regexp_replace(name, '[\s()·\-]+', '', 'g'))) stored,
  zone text not null,
  cat text not null,
  addr text check (char_length(addr) <= 120),
  tip text check (char_length(tip) <= 200),
  source text check (char_length(source) <= 120),
  lat double precision,
  lng double precision,
  coord_status text not null default 'unverified' check (coord_status in ('unverified','verified')),
  coord_source text,
  status text not null default 'pending' check (status in ('pending','published','hidden')),
  created_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- 중복 등록 방지(이름에서 공백·괄호·가운뎃점·하이픈 제거 후 같은 이름 금지)
create unique index if not exists places_name_key_uq on public.places(name_key);

-- ───────── 3. 꿀팁 ─────────
create table if not exists public.tips (
  id uuid primary key default gen_random_uuid(),
  place_id text not null references public.places(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 200),
  lang text not null default 'ko',
  status text not null default 'published' check (status in ('published','hidden')),
  created_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists tips_place_idx on public.tips(place_id);

-- ───────── 4. 찜(가고싶어) ─────────
create table if not exists public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  place_id text not null references public.places(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, place_id)
);

-- ───────── 5. 붐빔 제보(기존 기능 유지) ─────────
create table if not exists public.crowd_reports (
  zone text not null,
  user_id uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  level smallint not null check (level between 1 and 3),
  created_at timestamptz not null default now(),
  primary key (zone, user_id)
);

-- ───────── 6. 번역 캐시(원문은 원래 테이블에 보존) ─────────
create table if not exists public.translations (
  id bigint generated always as identity primary key,
  source_table text not null check (source_table in ('places','tips')),
  source_id text not null,
  field text not null,
  lang text not null check (lang in ('ko','en','ja','zh-CN')),
  text text not null,
  provider text not null default 'manual',
  created_at timestamptz not null default now(),
  unique (source_table, source_id, field, lang)
);

-- ───────── 7. 신고 ─────────
create table if not exists public.reports (
  id bigint generated always as identity primary key,
  target_table text not null check (target_table in ('places','tips')),
  target_id text not null,
  reason text not null check (char_length(reason) between 1 and 300),
  status text not null default 'open' check (status in ('open','resolved')),
  created_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

-- updated_at 자동 갱신
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists places_touch on public.places;
create trigger places_touch before update on public.places for each row execute function public.touch_updated_at();
drop trigger if exists tips_touch on public.tips;
create trigger tips_touch before update on public.tips for each row execute function public.touch_updated_at();

-- ───────── RLS ─────────
alter table public.profiles      enable row level security;
alter table public.places        enable row level security;
alter table public.tips          enable row level security;
alter table public.favorites     enable row level security;
alter table public.crowd_reports enable row level security;
alter table public.translations  enable row level security;
alter table public.reports       enable row level security;

-- profiles: 본인·관리자만 조회, 본인은 닉네임만 수정(역할 변경 불가)
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update using (id = auth.uid() or public.is_admin());
revoke update on public.profiles from authenticated;
grant update (nickname) on public.profiles to authenticated;

-- places
drop policy if exists places_select on public.places;
create policy places_select on public.places for select
  using (status = 'published' or created_by = auth.uid() or public.is_admin());
drop policy if exists places_insert on public.places;
create policy places_insert on public.places for insert to authenticated
  with check (created_by = auth.uid() and status = 'pending' and coord_status = 'unverified');
drop policy if exists places_update on public.places;
create policy places_update on public.places for update to authenticated
  using ((created_by = auth.uid() and status = 'pending') or public.is_admin())
  with check ((created_by = auth.uid() and status = 'pending' and coord_status = 'unverified') or public.is_admin());
drop policy if exists places_delete on public.places;
create policy places_delete on public.places for delete to authenticated
  using ((created_by = auth.uid() and status = 'pending') or public.is_admin());

-- tips: 바로 공개, 숨김 처리된 글은 작성자도 되살릴 수 없음
drop policy if exists tips_select on public.tips;
create policy tips_select on public.tips for select
  using (status = 'published' or created_by = auth.uid() or public.is_admin());
drop policy if exists tips_insert on public.tips;
create policy tips_insert on public.tips for insert to authenticated
  with check (created_by = auth.uid() and status = 'published'
              and exists (select 1 from public.places p where p.id = place_id and p.status = 'published'));
drop policy if exists tips_update on public.tips;
create policy tips_update on public.tips for update to authenticated
  using ((created_by = auth.uid() and status = 'published') or public.is_admin())
  with check ((created_by = auth.uid() and status = 'published') or public.is_admin());
drop policy if exists tips_delete on public.tips;
create policy tips_delete on public.tips for delete to authenticated
  using (created_by = auth.uid() or public.is_admin());

-- favorites: 본인 것만
drop policy if exists fav_all on public.favorites;
create policy fav_all on public.favorites for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- crowd_reports: 본인 것만 쓰기(조회는 아래 함수로 익명 집계만)
drop policy if exists crowd_own on public.crowd_reports;
create policy crowd_own on public.crowd_reports for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- translations: 누구나 읽기, 관리자만 쓰기
drop policy if exists tr_select on public.translations;
create policy tr_select on public.translations for select using (true);
drop policy if exists tr_admin on public.translations;
create policy tr_admin on public.translations for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- reports: 로그인 사용자 신고, 본인·관리자 조회, 관리자 처리
drop policy if exists rep_insert on public.reports;
create policy rep_insert on public.reports for insert to authenticated
  with check (created_by = auth.uid() and status = 'open');
drop policy if exists rep_select on public.reports;
create policy rep_select on public.reports for select to authenticated
  using (created_by = auth.uid() or public.is_admin());
drop policy if exists rep_update on public.reports;
create policy rep_update on public.reports for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ───────── 공개 집계 함수(개인 식별정보 없이 숫자만) ─────────
create or replace function public.favorite_counts()
returns table(place_id text, n bigint)
language sql stable security definer set search_path = public as $$
  select f.place_id, count(*) from public.favorites f
  join public.places p on p.id = f.place_id and p.status = 'published'
  group by f.place_id;
$$;

create or replace function public.recent_crowd()
returns table(zone text, level smallint, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select zone, level, created_at from public.crowd_reports
  where created_at > now() - interval '1 hour';
$$;

grant execute on function public.favorite_counts() to anon, authenticated;
grant execute on function public.recent_crowd() to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;
