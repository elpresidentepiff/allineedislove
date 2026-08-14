export type UserId = string;
export type PairId = string;
export type InviteId = string;
export type SessionId = string;

export type PairStatus = 'active' | 'disconnected';
export type Availability = 'available' | 'busy' | 'sleeping' | 'private';
export type SessionKind = 'voice' | 'video' | 'screen_share' | 'watch_together';
export type SessionState =
  | 'requested'
  | 'accepted'
  | 'declined'
  | 'connecting'
  | 'active'
  | 'ended'
  | 'failed';

export interface Profile {
  userId: UserId;
  displayName: string;
  timezone: string;
  avatarPath?: string;
}

export interface Pair {
  id: PairId;
  status: PairStatus;
  memberIds: readonly [UserId, UserId];
  createdAt: string;
  disconnectedAt?: string;
}

export interface PairInvite {
  id: InviteId;
  createdBy: UserId;
  expiresAt: string;
  acceptedBy?: UserId;
  acceptedAt?: string;
  revokedAt?: string;
}

export interface PresenceState {
  pairId: PairId;
  userId: UserId;
  mood?: string;
  availability?: Availability;
  statusText?: string;
  updatedAt: string;
}

export interface RealtimeSession {
  id: SessionId;
  pairId: PairId;
  initiatedBy: UserId;
  recipientId: UserId;
  kind: SessionKind;
  state: SessionState;
  requestedAt: string;
  acceptedAt?: string;
  endedAt?: string;
}

export function assertPairMembers(pair: Pair): void {
  const [a, b] = pair.memberIds;
  if (!a || !b || a === b) {
    throw new Error('A pair must contain exactly two distinct users.');
  }
}

export function assertUserInActivePair(pair: Pair, userId: UserId): void {
  assertPairMembers(pair);
  if (pair.status !== 'active') {
    throw new Error('Pair is not active.');
  }
  if (!pair.memberIds.includes(userId)) {
    throw new Error('User is not a member of this pair.');
  }
}

export function otherMember(pair: Pair, userId: UserId): UserId {
  assertUserInActivePair(pair, userId);
  const [a, b] = pair.memberIds;
  return a === userId ? b : a;
}

export function canAcceptSession(session: RealtimeSession, actorUserId: UserId): boolean {
  return session.state === 'requested' && session.recipientId === actorUserId;
}

export function canEndSession(session: RealtimeSession, actorUserId: UserId): boolean {
  const participant = session.initiatedBy === actorUserId || session.recipientId === actorUserId;
  return participant && ['accepted', 'connecting', 'active'].includes(session.state);
}

export function isInviteUsable(invite: PairInvite, nowIso: string): boolean {
  if (invite.revokedAt || invite.acceptedAt) return false;
  return new Date(invite.expiresAt).getTime() > new Date(nowIso).getTime();
}
