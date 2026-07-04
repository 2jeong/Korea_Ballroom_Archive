-- Korea Ballroom Archive — Supabase schema (Phase 1: shared read + open registration)
-- Run this once in the Supabase SQL Editor.

create table public.houses (
  id uuid primary key default gen_random_uuid(),
  scene text not null check (scene in ('major','kiki','pier')),
  pier_type text,
  prefix text not null default 'House of',
  name text not null,
  sym text,
  accent text not null default '#D9A441',
  motto text,
  chant text,
  notes text,
  founded int not null,
  chapter int,
  photo_url text,
  legendary boolean not null default false,
  owner_token uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table public.members (
  id uuid primary key default gen_random_uuid(),
  house_id uuid not null references public.houses(id) on delete cascade,
  name text not null,
  role text not null default 'child',
  role_custom text,
  honor text,
  category text,
  since int,
  bio text,
  photo_url text,
  owner_token uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table public.agents (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  honor text,
  category text,
  since int,
  note text,
  bio text,
  photo_url text,
  owner_token uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);

alter table public.houses enable row level security;
alter table public.members enable row level security;
alter table public.agents enable row level security;

-- 누구나 읽기 가능 (공유 아카이브의 핵심)
create policy "read houses" on public.houses for select using (true);
create policy "read members" on public.members for select using (true);
create policy "read agents" on public.agents for select using (true);

-- 누구나 등록 가능 (로그인 없는 커뮤니티 등록 방식 유지)
create policy "insert houses" on public.houses for insert with check (true);
create policy "insert members" on public.members for insert with check (true);
create policy "insert agents" on public.agents for insert with check (true);

-- update/delete 정책은 아직 없음 → 지금은 아무도 수정・삭제 불가
-- (2단계에서 소유자 토큰 검증 정책을 추가할 예정)

-- photos 버킷 업로드 허용 (읽기는 Public bucket 설정으로 이미 가능)
create policy "public upload to photos"
on storage.objects for insert
to public
with check (bucket_id = 'photos');

-- ── 등록자 본인만 수정/삭제 가능하게 (브라우저 토큰 검증) ──
-- 등록 시 생성된 owner_token을 그 브라우저에 저장해두고, 수정/삭제 요청 때마다
-- x-owner-token 헤더로 실어보내면, 그 값이 실제 소유자 토큰과 일치할 때만 허용됩니다.
create policy "update own houses" on public.houses for update
  using (owner_token = nullif(current_setting('request.headers', true)::json->>'x-owner-token','')::uuid);
create policy "delete own houses" on public.houses for delete
  using (owner_token = nullif(current_setting('request.headers', true)::json->>'x-owner-token','')::uuid);

create policy "update own members" on public.members for update
  using (owner_token = nullif(current_setting('request.headers', true)::json->>'x-owner-token','')::uuid);
create policy "delete own members" on public.members for delete
  using (owner_token = nullif(current_setting('request.headers', true)::json->>'x-owner-token','')::uuid);

create policy "update own agents" on public.agents for update
  using (owner_token = nullif(current_setting('request.headers', true)::json->>'x-owner-token','')::uuid);
create policy "delete own agents" on public.agents for delete
  using (owner_token = nullif(current_setting('request.headers', true)::json->>'x-owner-token','')::uuid);

-- members.house_id는 커스텀 하우스(UUID)뿐 아니라 시드 하우스(예: "gucci" 같은
-- 고정 문자열 id)에도 걸릴 수 있어서 uuid FK 대신 text로 둡니다.
alter table public.members drop constraint members_house_id_fkey;
alter table public.members alter column house_id type text;
