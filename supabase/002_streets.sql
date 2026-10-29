-- 남대문 같이지도 — 골목·거리 안에 가게를 넣을 수 있게 확장 (schema.sql, seed.sql 실행 후 1회)
-- kind: 'street'(골목·거리) / 'shop'(가게), parent_id: 가게가 속한 골목·거리
alter table public.places add column if not exists kind text not null default 'shop';
alter table public.places drop constraint if exists places_kind_chk;
alter table public.places add constraint places_kind_chk check (kind in ('shop','street'));
alter table public.places add column if not exists parent_id text references public.places(id) on delete set null;
create index if not exists places_parent_idx on public.places(parent_id);

-- 기존 장소 중 골목·거리
update public.places set kind = 'street'
where id in ('galchi','kalguksu','meokja','bedding','camera','glasses','kids','women','military','souvenir','stationery');

-- 갈치조림 골목 주소 보정(기존 '남대문시장4길 18-6'은 카카오 주소검색 결과 없음)
update public.places set
  addr = '남대문시장길 16-17',
  lat = 37.5596756422282, lng = 126.976924572369, coord_status = 'verified',
  coord_source = '카카오 주소검색 2026-10-29: 서울 중구 남대문시장길 16-17 (주소 출처: 서울시 미디어허브 2017.03.07 「서민의 맛을 만나다, 남대문 갈치골목」)'
where id = 'galchi';

-- 갈치조림 골목 안 가게 2곳 (출처 기사 기준 정보)
insert into public.places (id, name, zone, cat, addr, tip, source, lat, lng, coord_status, coord_source, status, kind, parent_id) values
  ('junganggalchi', '중앙갈치식당', 'galchi', '먹거리', '남대문시장길 22-12',
   '양은 냄비에 무를 깔고 자작하게 조린 갈치조림. 갈치조림을 시키면 작은 갈치구이가 같이 나와요. 매일 08:30~21:00(기사 기준)',
   '식신 「밥 두 공기는 기본… 무까지 맛있는 갈치조림 맛집 BEST 5」 (2026.08.02) https://v.daum.net/v/2EwvLdJ6r4',
   37.5597882067481, 126.977078575528, 'verified', '카카오 주소검색 2026-10-29: 서울 중구 남대문시장길 22-12 (건물·번지 기준 위치)',
   'published', 'shop', 'galchi'),
  ('heerakgalchi', '희락갈치', 'galchi', '먹거리', '남대문시장길 22-6',
   '칼칼하고 진한 양념의 갈치조림, 기본 찬으로 계란찜이 나와요. 월~토 07:00~21:00, 일요일 휴무(기사 기준)',
   '식신 「밥 두 공기는 기본… 무까지 맛있는 갈치조림 맛집 BEST 5」 (2026.08.02) https://v.daum.net/v/2EwvLdJ6r4',
   37.559902542991, 126.977077182341, 'verified', '카카오 주소검색 2026-10-29: 서울 중구 남대문시장길 22-6 (건물·번지 기준 위치)',
   'published', 'shop', 'galchi')
on conflict (id) do nothing;

select id, name, kind, parent_id, status from public.places where id in ('galchi','junganggalchi','heerakgalchi');
