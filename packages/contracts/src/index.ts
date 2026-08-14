import type { PairId, SessionId, SessionKind, UserId } from '../../domain/src';

export interface RoomGrant {
  sessionId: SessionId;
  providerRoomId: string;
  joinToken: string;
  expiresAt: string;
}

export interface CreateRoomInput {
  pairId: PairId;
  sessionId: SessionId;
  kind: SessionKind;
  initiatedBy: UserId;
  recipientId: UserId;
}

export interface JoinRoomInput {
  sessionId: SessionId;
  userId: UserId;
}

export interface JoinedRoom {
  sessionId: SessionId;
  disconnect(): Promise<void>;
}

export interface RealtimeProvider {
  createRoom(input: CreateRoomInput): Promise<RoomGrant>;
  joinRoom(input: JoinRoomInput): Promise<JoinedRoom>;
  revokeRoom(sessionId: SessionId): Promise<void>;
}

export interface PushPayload {
  type: 'pair_invite' | 'pair_accepted' | 'shared_moment_request' | 'shared_moment_ended';
  entityId: string;
}

export interface PushProvider {
  send(userId: UserId, payload: PushPayload): Promise<void>;
}

export interface AnalyticsEvent {
  name:
    | 'account_created'
    | 'pair_invite_created'
    | 'pair_accepted'
    | 'right_now_opened'
    | 'presence_updated'
    | 'story_item_created'
    | 'shared_moment_requested'
    | 'shared_moment_accepted'
    | 'shared_moment_declined'
    | 'realtime_connected'
    | 'realtime_failed'
    | 'realtime_ended'
    | 'pair_disconnected';
  userId: UserId;
  pairId?: PairId;
  occurredAt: string;
  properties?: Record<string, string | number | boolean | null>;
}

export interface AnalyticsSink {
  track(event: AnalyticsEvent): Promise<void>;
}
