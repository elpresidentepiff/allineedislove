# All I Need Is Love

**Presence, not possession.**

All I Need Is Love is a consent-first relationship presence platform for couples living apart. It is designed to restore some of the ambient closeness that distance removes while keeping both people in control of what they choose to share.

## Product thesis

Long-distance relationships lose many small signals couples living together receive naturally: whether someone is home, busy, awake, available, or simply wanting company. The product gives two adults a private shared space for presence, memories, plans and user-initiated shared moments.

## Non-negotiable principles

1. Presence, not possession.
2. Every sensitive sharing feature requires clear, informed user choice.
3. Both partners retain equal control over their own sharing settings.
4. Private by default; minimise collection and retention.
5. The app remains useful even when optional sharing features are disabled.
6. Disconnecting a relationship immediately removes relationship access.

## Product layers

- Ambient Presence — status, local time, mood, distance, optional location, arrival moments and next-meeting countdowns.
- Shared Moments — user-initiated realtime voice, video and screen-sharing experiences.
- Shared Life — memories, photos, voice notes, plans, watch-together, rituals and a private couple timeline.
- Consent Engine — clear grants, expiry, audit history and simple revocation.
- Intelligence — later-stage translation, memory search, planning and relationship-aware assistance.

## MVP objective

Prove whether long-distance couples will invite a partner and repeatedly use consent-based ambient presence because it makes them feel meaningfully closer.

## Initial technical direction

- Mobile: React Native with native Kotlin/Swift modules where platform APIs require them.
- Backend: Supabase/Postgres for auth, relationship graph, consent grants, presence and shared-life metadata.
- Realtime: WebRTC with managed relay/SFU fallback where required.
- Push: APNs + FCM.
- Security: short-lived session grants, device binding, audit logs, immediate revocation and encryption for sensitive content.

## Repository map

Detailed product, architecture, security, economics and validation documents will live under `docs/`, with database migrations under `supabase/migrations/` and architectural decision records under `docs/adr/`.

## Status

Foundation / pre-MVP.
