-- All I Need Is Love
-- Controlled pair invitation and acceptance lifecycle.
--
-- Raw invite tokens are returned once to the creator and only a SHA-256 hash is
-- stored. Pair creation is atomic and serialised per participating user so the
-- MVP invariant of at most one active romantic pair per user is enforced.

create or replace function public.has_active_pair(p_user_id uuid)
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
     where pm.user_id = p_user_id
       and p.status = 'active'
  );
$$;

revoke all on function public.has_active_pair(uuid) from public;
grant execute on function public.has_active_pair(uuid) to authenticated;

create or replace function public.create_pair_invite(
  p_ttl_minutes integer default 1440
)
returns table(
  invite_id uuid,
  invite_token text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  raw_token text;
  new_id uuid;
  expiry timestamptz;
begin
  if actor is null then
    raise exception 'authentication required';
  end if;

  if p_ttl_minutes < 5 or p_ttl_minutes > 10080 then
    raise exception 'invite ttl must be between 5 minutes and 7 days';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));

  if public.has_active_pair(actor) then
    raise exception 'user already belongs to an active pair';
  end if;

  -- Keep only one usable invite per creator during MVP.
  update public.pair_invites
     set revoked_at = now()
   where created_by = actor
     and accepted_at is null
     and revoked_at is null
     and expires_at > now();

  raw_token := encode(gen_random_bytes(24), 'hex');
  new_id := gen_random_uuid();
  expiry := now() + make_interval(mins => p_ttl_minutes);

  insert into public.pair_invites(
    id, created_by, token_hash, expires_at
  ) values (
    new_id,
    actor,
    encode(digest(raw_token, 'sha256'), 'hex'),
    expiry
  );

  return query select new_id, raw_token, expiry;
end;
$$;

revoke all on function public.create_pair_invite(integer) from public;
grant execute on function public.create_pair_invite(integer) to authenticated;

create or replace function public.revoke_pair_invite(p_invite_id uuid)
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

  update public.pair_invites
     set revoked_at = now()
   where id = p_invite_id
     and created_by = actor
     and accepted_at is null
     and revoked_at is null;

  if not found then
    raise exception 'invite not found or cannot be revoked';
  end if;
end;
$$;

revoke all on function public.revoke_pair_invite(uuid) from public;
grant execute on function public.revoke_pair_invite(uuid) to authenticated;

create or replace function public.accept_pair_invite(p_invite_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  invite_row public.pair_invites%rowtype;
  inviter uuid;
  new_pair_id uuid := gen_random_uuid();
  lock_first text;
  lock_second text;
begin
  if actor is null then
    raise exception 'authentication required';
  end if;

  if p_invite_token is null or char_length(p_invite_token) < 20 then
    raise exception 'invalid invite token';
  end if;

  select *
    into invite_row
    from public.pair_invites
   where token_hash = encode(digest(p_invite_token, 'sha256'), 'hex')
   for update;

  if not found then
    raise exception 'invite not found';
  end if;

  if invite_row.revoked_at is not null then
    raise exception 'invite revoked';
  end if;

  if invite_row.accepted_at is not null then
    raise exception 'invite already accepted';
  end if;

  if invite_row.expires_at <= now() then
    raise exception 'invite expired';
  end if;

  inviter := invite_row.created_by;

  if inviter = actor then
    raise exception 'cannot accept your own invite';
  end if;

  -- Lock both users in a deterministic order so concurrent invitations cannot
  -- create two active pairs for the same person.
  lock_first := least(inviter::text, actor::text);
  lock_second := greatest(inviter::text, actor::text);
  perform pg_advisory_xact_lock(hashtextextended(lock_first, 0));
  perform pg_advisory_xact_lock(hashtextextended(lock_second, 0));

  if public.has_active_pair(inviter) then
    raise exception 'inviter already belongs to an active pair';
  end if;

  if public.has_active_pair(actor) then
    raise exception 'recipient already belongs to an active pair';
  end if;

  insert into public.pairs(id, status)
  values (new_pair_id, 'active');

  insert into public.pair_members(pair_id, user_id)
  values
    (new_pair_id, inviter),
    (new_pair_id, actor);

  update public.pair_invites
     set accepted_by = actor,
         accepted_at = now()
   where id = invite_row.id;

  -- Revoke any other still-open invites from either newly paired user.
  update public.pair_invites
     set revoked_at = now()
   where created_by in (inviter, actor)
     and id <> invite_row.id
     and accepted_at is null
     and revoked_at is null;

  return new_pair_id;
end;
$$;

revoke all on function public.accept_pair_invite(text) from public;
grant execute on function public.accept_pair_invite(text) to authenticated;

-- Invite rows remain non-writable through direct client RLS. The functions
-- above are the only supported MVP lifecycle entry points.
