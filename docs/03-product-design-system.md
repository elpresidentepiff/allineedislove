# Product Design System v1

## Emotional objective

All I Need Is Love should feel like **quiet intimacy**, not social media, therapy software, family tracking or device administration.

The product is designed for two adults who are physically apart but want a small shared layer of ordinary life.

## Design principles

### 1. Presence before features
The home screen should answer emotional questions before technical ones:
- How is my person?
- What time is it for them?
- Are they available?
- When do we meet again?
- Did they leave me a little piece of their day?

### 2. Calm over stimulation
Avoid:
- streak flames,
- points,
- red notification pressure,
- guilt-based copy,
- public engagement metrics,
- competitive relationship scoring.

Use whitespace, soft hierarchy and small moments instead.

### 3. Romantic shell, literal permission language
The surrounding product may say:
- **Come sit with me**
- **Our Story**
- **Right Now**
- **Private Time**

But when a sensitive capability is involved, copy becomes literal:
- Voice session
- Video session
- Share my screen
- Optional location
- Ask every time
- End session

Romance must never obscure what the device is doing.

### 4. Equal agency is visible
The interface must never imply one partner owns or administers the other.

Avoid:
- owner,
- dependent,
- monitored user,
- managed device,
- primary account controlling secondary account.

Use:
- **Our Space** for shared data,
- **Your Controls** for person-owned settings,
- independent consent and independent account ownership.

### 5. Private Time is normal
Private Time should feel as ordinary as putting a phone on Do Not Disturb.

The UI must not:
- ask for a reason,
- tell the partner why it was enabled,
- create a relationship penalty,
- restart optional sharing automatically,
- create an ominous warning state.

## Primary information architecture

The V1 navigation has four destinations.

### Right Now
The emotional home.

Contains:
- partner local time,
- mood / availability if shared,
- lightweight status,
- distance,
- next-meeting countdown,
- latest shared moment,
- primary `Come sit with me` action.

### Together
Realtime invitations.

Initial modes:
1. Just be here — voice.
2. See each other — video.
3. Look at this with me — user-started presentation/screen share.

### Our Story
Private shared history.

Contains:
- photos,
- notes,
- voice notes later,
- relationship milestones,
- saved shared moments,
- plans represented as story events when appropriate.

### Us
Relationship container.

Contains:
- pair identity,
- next meeting,
- shared plans,
- relationship dates,
- user-owned privacy/settings entry point.

## Visual language

### Palette
Working visual direction:
- warm off-white background,
- near-black primary ink,
- muted stone text,
- restrained blush/rose for human warmth,
- muted green only for positive availability/state,
- red reserved for destructive actions.

The product should not look stereotypically pink, childish or wedding-themed.

### Typography
Use a neutral modern sans serif initially.

Hierarchy:
- large emotional statement,
- small uppercase contextual kicker,
- compact explanatory body,
- microcopy for privacy/context.

### Shape
- generous rounded cards,
- soft surfaces,
- circular identity/moment elements,
- minimal hard borders,
- no dashboard-style dense data grids.

## Core language dictionary

| System concept | Product language |
|---|---|
| Pair | Our Space / Us |
| Presence home | Right Now |
| Realtime invitation | Come sit with me |
| Active session | Together Now |
| Timeline | Our Story |
| Temporary sharing pause | Private Time |
| Next visit countdown | Until We Meet |
| Session request | Shared moment |
| Privacy settings | Your Controls |

## Interaction contract

### Request
One person may request a shared moment.

### Accept
The other person explicitly accepts before the requested realtime interaction begins.

### Decline
Declining:
- requires no reason,
- must be one tap,
- does not disable anything else,
- does not trigger guilt copy.

### End
Either participant can end a realtime session immediately.

### Disconnect
Either person can close the relationship space. Pair-scoped access ends.

## Prototype V1 design test

A successful first-time tester should be able to say, without founder explanation:

> “It is a private place for two people who live apart, where they can feel involved in ordinary life and invite each other into moments, but each person still controls their own privacy.”

If people instead describe it as:
- tracking,
- checking up,
- catching cheating,
- remote phone access,
- surveillance,

then the experience or positioning has failed.

## Research build

The current design implementation is `prototype/v1/`.

It deliberately simulates:
- pair invitation,
- pair acceptance,
- Right Now,
- Together,
- explicit incoming-session consent,
- active-session visibility,
- Our Story,
- Us,
- Your Controls,
- Private Time,
- disconnect.

It performs no real device access.
