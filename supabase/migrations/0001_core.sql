-- All I Need Is Love
-- Core pair lifecycle schema for the first production vertical slice.
--
-- Principles:
-- 1. Two independent adult accounts form one active pair.
-- 2. Pair lifecycle mutations are controlled server-side.
-- 3. A user can mutate only their own presence/content.
-- 4. Pair-scoped reads require active membership.
-- 5. Disconnect invalidates relationship-scoped state.

create extension if not exists pgcrypto;

create type public.pair_status as enum ('active', 'disconnected');
create type public.device_platform as enum ('android', 'ios');
create type public.availability_state as enum ('available', 'busy', 'sleeping', 'private');
create type public.timeline_kind as enum ('photo', 'voice_note', 'note', 'moment', 'milestone');
create type public.session_kind as enum ('voice', 'video', 'screen_share', 'watch_together');
create type public.session_state as enum ('requested', 'accepted', 'declined', 'connecting', 'active', 'ended', 'failed');
create type public.consent_event_kind as enum ('requested', 'granted', 'declined', 'expired', 'revoked', 'disconnected');

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  timezone text not null,
  avatar_path text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform public.device_platform not null,
  push_token_ref text,
  app_version text,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index devices_user_id_idx on public.devices(user_id);

create table public.pairs (
  id uuid primary key default gen_random_uuid(),
  status public.pair_status not null default 'active',
  created_at timestamptz not null default now(),
  disconnected_at timestamptz,
  disconnected_by uuid references auth.users(id)
);

create table public.pair_members (
  pair_id uuid not null references public.pairs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (pair_id, user_id)
);
create index pair_members_user_id_idx on public.pair_members(user_id);

create table public.pair_invites (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  accepted_by uuid references auth.users(id),
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);
create index pair_invites_created_by_idx on public.pair_invites(created_by);

create table public.presence_state (
  pair_id uuid not null references public.pairs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  mood text,
  availability public.availability_state,
  status_text text check (status_text is null or char_length(status_text) <= 160),
  updated_at timestamptz not null default now(),
  primary key (pair_id, user_id)
);

create table public.timeline_items (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  kind public.timeline_kind not null,
  body jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index timeline_items_pair_created_idx on public.timeline_items(pair_id, created_at desc);

create table public.realtime_sessions (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs(id) on delete cascade,
  initiated_by uuid not null references auth.users(id),
  recipient_id uuid not null references auth.users(id),
  kind public.session_kind not null,
  state public.session_state not null default 'requested',
  provider text,
  provider_session_ref text,
  requested_at timestamptz not null default now(),
  accepted_at timestamptz,
  ended_at timestamptz,
  check (initiated_by <> recipient_id)
);
create index realtime_sessions_pair_requested_idx on public.realtime_sessions(pair_id, requested_at desc);

create table public.consent_events (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs(id) on delete cascade,
  actor_user_id uuid not null references auth.users(id),
  event public.consent_event_kind not null,
  resource_type text not null,
  resource_id uuid,
  policy_version text not null default 'v1',
  created_at timestamptz not null default now()
);
create index consent_events_pair_created_idx on public.consent_events(pair_id, created_at desc);

-- A user may be in at most one active romantic pair during MVP.
create unique index one_active_pair_membership_per_user
on public.pair_members(user_id)
where exists (
  select 1 from public.pairs p
  where p.id = pair_members.pair_id and p.status = 'active'
);

-- PostgreSQL does not allow a partial-index predicate with this cross-table
-- dependency on all hosted versions. If deployment rejects the index above,
-- replace it with a controlled pair-acceptance transaction that obtains an
-- advisory lock per user and checks active membership before insert.

-- Helper used by RLS. SECURITY DEFINER prevents recursive RLS evaluation.
create or replace function public.is_active_pair_member(p_pair_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.pair_members pm
    join public.pairs p on p.id = pm.pair_id
    where pm.pair_id = p_pair_id
      and pm.user_id = p_user_id
      and p.status = 'active'
  );
$$;

revoke all on function public.is_active_pair_member(uuid, uuid) from public;
grant execute on function public.is_active_pair_member(uuid, uuid) to authenticated;

-- Basic profile trigger. Users may edit the generated name later.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(user_id, display_name, timezone)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), 'New person'),
    coalesce(nullif(new.raw_user_meta_data->>'timezone', ''), 'UTC')
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Disconnect is intentionally a server-authoritative destructive transition.
create or replace function public.disconnect_pair(p_pair_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required';
  end if;

  if not public.is_active_pair_member(p_pair_id, actor) then
    raise exception 'not an active pair member';
  end if;

  update public.pairs
     set status = 'disconnected',
         disconnected_at = now(),
         disconnected_by = actor
   where id = p_pair_id
     and status = 'active';

  update public.realtime_sessions
     set state = 'ended', ended_at = coalesce(ended_at, now())
   where pair_id = p_pair_id
     and state in ('requested', 'accepted', 'connecting', 'active');

  insert into public.consent_events(pair_id, actor_user_id, event, resource_type, resource_id)
  values (p_pair_id, actor, 'disconnected', 'pair', p_pair_id);
end;
$$;

revoke all on function public.disconnect_pair(uuid) from public;
grant execute on function public.disconnect_pair(uuid) to authenticated;

-- RLS -----------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.pairs enable row level security;
alter table public.pair_members enable row level security;
alter table public.pair_invites enable row level security;
alter table public.presence_state enable row level security;
alter table public.timeline_items enable row level security;
alter table public.realtime_sessions enable row level security;
alter table public.consent_events enable row level security;

create policy profiles_read_self
on public.profiles for select
to authenticated
using (user_id = auth.uid());

create policy profiles_update_self
on public.profiles for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy devices_manage_self
on public.devices for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy pairs_read_active_member
on public.pairs for select
to authenticated
using (public.is_active_pair_member(id));

create policy pair_members_read_same_pair
on public.pair_members for select
to authenticated
using (public.is_active_pair_member(pair_id));

create policy pair_invites_read_creator
on public.pair_invites for select
to authenticated
using (created_by = auth.uid());

create policy presence_read_pair
on public.presence_state for select
to authenticated
using (public.is_active_pair_member(pair_id));

create policy presence_insert_self
on public.presence_state for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_active_pair_member(pair_id)
);

create policy presence_update_self
on public.presence_state for update
to authenticated
using (
  user_id = auth.uid()
  and public.is_active_pair_member(pair_id)
)
with check (
  user_id = auth.uid()
  and public.is_active_pair_member(pair_id)
);

create policy timeline_read_pair
on public.timeline_items for select
to authenticated
using (public.is_active_pair_member(pair_id));

create policy timeline_insert_self
on public.timeline_items for insert
to authenticated
with check (
  owner_user_id = auth.uid()
  and public.is_active_pair_member(pair_id)
);

create policy timeline_update_self
on public.timeline_items for update
to authenticated
using (
  owner_user_id = auth.uid()
  and public.is_active_pair_member(pair_id)
)
with check (
  owner_user_id = auth.uid()
  and public.is_active_pair_member(pair_id)
);

create policy sessions_read_pair
on public.realtime_sessions for select
to authenticated
using (public.is_active_pair_member(pair_id));

-- Session writes are intentionally omitted from direct client RLS in migration
-- 0001. Request/accept/decline/end transitions will be exposed through controlled
-- RPC/Edge Function paths after the physical-device realtime spike.

create policy consent_events_read_pair
on public.consent_events for select
to authenticated
using (public.is_active_pair_member(pair_id));

-- No direct insert/update/delete policy exists for pairs, pair_members,
-- consent_events or pair lifecycle fields. They are server-authoritative.
