# Thin Technical Vertical Slice

## Purpose

The first production slice should prove the complete relationship loop with the least possible infrastructure:

`account -> invite -> accept -> shared home -> one shared moment -> disconnect`

It should not attempt to prove every future capability.

## Definition of the slice

Two physical mobile devices must be able to:

1. create independent accounts,
2. pair through a private invitation,
3. see a shared `Right Now` home,
4. update a lightweight mood/availability state,
5. create one shared story item,
6. receive a realtime invitation,
7. accept or decline it explicitly,
8. complete one voice session,
9. end the session from either device,
10. disconnect the relationship,
11. verify that old pair-scoped access no longer works.

## Deliberately excluded from slice 1

- background location,
- screen sharing,
- video,
- watch-together,
- AI,
- translation,
- widgets,
- billing,
- contact-book import,
- social graph,
- public profiles,
- relationship scoring,
- message interception,
- remote device control.

The goal is to prove the pair lifecycle and emotional core before introducing platform-sensitive capabilities.

## Proposed repository structure

```text
allineedislove/
  apps/
    mobile/
      src/
        app/
        components/
        features/
          auth/
          pair/
          presence/
          story/
          together/
          settings/
        services/
          api/
          realtime/
          push/
        design/
  packages/
    domain/
    contracts/
    analytics/
  supabase/
    migrations/
    functions/
    tests/
  docs/
    adr/
  prototype/
```

## Mobile foundation

Working choice: React Native with TypeScript.

Rules:
- keep domain rules outside screens,
- keep provider-specific realtime code behind interfaces,
- use native Kotlin/Swift modules only when a validated product capability needs them,
- do not put pair/consent authority in client-only state.

## Backend foundation

Working choice: Supabase.

Use initially for:
- Auth,
- Postgres,
- Row Level Security,
- Realtime database subscriptions where useful,
- Storage for explicitly saved shared media,
- Edge Functions / controlled RPC for sensitive state transitions.

## Minimal schema

### profiles
```text
user_id
name
timezone
avatar_path
created_at
```

### devices
```text
id
user_id
platform
push_token
last_seen_at
revoked_at
```

### pair_invites
```text
id
created_by
invite_hash
expires_at
accepted_by
accepted_at
revoked_at
```

### pairs
```text
id
status
created_at
disconnected_at
```

### pair_members
```text
pair_id
user_id
joined_at
```

### presence_state
```text
pair_id
user_id
mood
availability
status_text
updated_at
```

### timeline_items
```text
id
pair_id
owner_user_id
kind
body
created_at
deleted_at
```

### realtime_sessions
```text
id
pair_id
initiated_by
kind
state
provider
provider_ref
requested_at
accepted_at
ended_at
```

### consent_events
For slice 1 this records realtime invitation lifecycle and pair disconnect events.

```text
id
pair_id
actor_user_id
event
resource_type
resource_id
created_at
```

## Pair invariants

For MVP:
- one account may belong to at most one active romantic pair,
- one active pair has exactly two members,
- no client can add itself directly to a pair,
- invitation acceptance occurs server-side,
- the inviter cannot accept on behalf of the recipient,
- disconnect can be initiated by either member,
- disconnect invalidates active pair-scoped realtime sessions.

## RLS rules

### profiles
A user can update their own profile.

### pair data
A row with `pair_id` is readable only if the current user is an active member of that pair.

### presence
A user updates only their own presence row.
The partner may read it while the pair remains active.

### timeline
A member can add their own item into an active pair.
Both active members can read pair timeline items.

### sessions
Session state changes must enforce actor permissions:
- either member may request,
- only the recipient may accept/decline,
- either participant may end an active session.

## Realtime abstraction

Do not hard-wire UI/domain code to one vendor.

```ts
export interface RealtimeProvider {
  createRoom(input: CreateRoomInput): Promise<RoomGrant>;
  joinRoom(input: JoinRoomInput): Promise<JoinedRoom>;
  leaveRoom(sessionId: string): Promise<void>;
}
```

For the first slice only voice is required.

Provider choice should be made after a physical-device spike rather than from marketing pages alone.

## Event model

Minimum analytics events:

```text
account_created
pair_invite_created
pair_invite_opened
pair_accepted
right_now_opened
presence_updated
story_item_created
shared_moment_requested
shared_moment_accepted
shared_moment_declined
realtime_connected
realtime_failed
realtime_ended
pair_disconnected
```

Every pair-level funnel metric should use anonymised pair identifiers rather than treating two accounts as unrelated users.

## First meaningful funnel

```text
account
  -> invite sent
  -> invite accepted
  -> pair active
  -> both open Right Now
  -> first shared item or presence update
  -> first Come Sit With Me request
  -> accepted
  -> realtime connected
  -> second mutual interaction within 7 days
```

## Error states that must exist before alpha

- invite expired,
- invite already used,
- recipient already has an active pair,
- sender disconnected while invite was open,
- request declined,
- request expired,
- receiver offline,
- push delayed,
- realtime join fails,
- network drops mid-session,
- pair disconnected during active session,
- user logs in on replacement device.

## Security baseline

Before real couples:
- RLS tests for every table,
- no service-role key in mobile app,
- signed/short-lived media grants,
- server-side invitation acceptance,
- server-side disconnect transition,
- private content removed from logs,
- rate limiting on invites and session creation,
- device-session revocation,
- dependency and secret scanning.

## Test sequence

### Test A — happy path
Two fresh devices pair and create a shared moment.

### Test B — decline
Recipient declines. No session begins and no relationship penalty appears.

### Test C — malicious client assumption
Attempt direct API writes that would:
- add a third pair member,
- change the partner's presence,
- accept a session on behalf of recipient.

All must fail.

### Test D — disconnect
One user disconnects. Existing pair reads and active session credentials cease to work.

### Test E — network recovery
Voice call switches Wi-Fi -> mobile data and survives or fails clearly/recoverably.

## Implementation sequence

### Slice 1A
- mobile app shell,
- design tokens,
- auth,
- profile/timezone.

### Slice 1B
- pair invite,
- deep link,
- acceptance,
- pair lifecycle tests.

### Slice 1C
- Right Now,
- mood/availability,
- basic push.

### Slice 1D
- Our Story with one text/photo moment type.

### Slice 1E
- Come Sit With Me voice request,
- accept/decline,
- realtime voice adapter.

### Slice 1F
- disconnect,
- deletion/export skeleton,
- analytics,
- abuse/error hardening.

## Go/no-go gate

Do not add video, location or shared presentation until:
- pair lifecycle is reliable,
- users understand who controls what,
- couples return to Right Now / Together without pressure,
- realtime voice reliability is acceptable on real devices,
- disconnect passes destructive-access tests,
- and early users describe value in terms of closeness rather than monitoring.
