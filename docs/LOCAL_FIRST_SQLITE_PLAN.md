# Local-First SQLite Plan

This document explains how to make the app work primarily from local storage while still using the existing socket connection for realtime send/receive events.

Scope for phase 1:
- profile cache
- chat list
- message list
- message delivery/read state
- call history

This is a design and implementation plan only. It does not change runtime code.

## Goal

Move the UI to a local-first model:
- UI reads from SQLite, not directly from REST responses
- socket events update local tables immediately
- outgoing actions write locally first, then sync to backend
- app restart should preserve chat list, messages, profile snapshot, and call history

Backend still remains necessary for:
- auth
- token/session
- remote profile updates
- media/call signaling APIs
- message delivery to other users
- initial backfill / pagination / reconciliation

## Current Codebase State

Current important files:
- [lib/core/realtime/realtime_service.dart](/Users/rosdeb/All_Project/titra-mobile/lib/core/realtime/realtime_service.dart)
- [lib/features/chat/data/messaging_repository.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/chat/data/messaging_repository.dart)
- [lib/features/chat/presentation/view_models/chat_view_model.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/chat/presentation/view_models/chat_view_model.dart)
- [lib/features/home/data/conversations_repository.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/home/data/conversations_repository.dart)
- [lib/features/home/presentation/view_models/home_view_model.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/home/presentation/view_models/home_view_model.dart)
- [lib/features/call/data/calls_repository.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/call/data/calls_repository.dart)
- [lib/features/call/presentation/view_models/calls_view_model.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/call/presentation/view_models/calls_view_model.dart)
- [lib/features/profile/presentation/view_models/profile_view_model.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/profile/presentation/view_models/profile_view_model.dart)
- [lib/core/session/session_controller.dart](/Users/rosdeb/All_Project/titra-mobile/lib/core/session/session_controller.dart)

Current behavior:
- message list loads from `MessagingRepository` via API
- conversation list loads from `ConversationsRepository` via API
- call history loads from `CallsRepository` via API
- profile/session snapshot is mostly in `SharedPreferences` and secure storage
- realtime socket emits events, but UI still depends on remote fetch as the main source of truth

That means the app is not yet local-first. It is network-first with some cached bootstrap state.

## Recommended Stack

Use SQLite as the storage engine, but do not use raw SQL everywhere.

Recommended:
- `drift` for typed tables, streams, migrations, and testability
- SQLite underneath through `sqlite3_flutter_libs` or the standard mobile SQLite runtime

Why `drift` instead of plain `sqflite`:
- chat list and message screens need reactive streams
- call history and unread counters are easier with typed queries
- migrations will become safer as schema grows
- repository code stays cleaner than manual `Map<String, dynamic>` conversion

If you want the smallest possible dependency surface, `sqflite` can work, but the app will need more manual mapping and more custom stream wiring.

## Target Architecture

The target rule is simple:
- ViewModels read from local database only
- repositories write to local database and coordinate sync
- socket events never update UI directly; they write to SQLite first
- REST fetch is used for hydration, pagination, recovery, and reconciliation

High-level flow:

1. App opens.
2. Session hydrates from secure storage and prefs.
3. Local database opens.
4. Home/chat/profile/call screens subscribe to local DB streams.
5. Realtime socket connects.
6. Socket events write into local tables.
7. Background sync fetches missed remote data and merges into local tables.

## Database Modules To Add

Suggested new folder structure:

```text
lib/core/local_db/
  app_database.dart
  tables/
    users_table.dart
    profiles_table.dart
    conversations_table.dart
    conversation_members_table.dart
    messages_table.dart
    message_attachments_table.dart
    call_history_table.dart
    sync_queue_table.dart
    sync_state_table.dart
  daos/
    users_dao.dart
    conversations_dao.dart
    messages_dao.dart
    calls_dao.dart
    profile_dao.dart
    sync_dao.dart
```

Suggested sync coordinators:

```text
lib/core/sync/
  chat_sync_coordinator.dart
  conversation_sync_coordinator.dart
  call_sync_coordinator.dart
  profile_sync_coordinator.dart
```

## Proposed SQLite Schema

### `users`

Purpose:
- lightweight identity cache for participants

Columns:
- `id` text primary key
- `username` text
- `display_name` text
- `photo_url` text
- `phone` text nullable
- `updated_at` integer

### `profiles`

Purpose:
- current logged-in user snapshot plus mutable local profile fields

Columns:
- `user_id` text primary key
- `status_text` text
- `bio` text nullable
- `photo_url` text nullable
- `raw_json` text nullable
- `updated_at` integer
- `sync_state` text

### `conversations`

Purpose:
- chat list source of truth

Columns:
- `id` text primary key
- `type` text
- `title` text nullable
- `avatar_url` text nullable
- `last_message_id` text nullable
- `last_message_preview` text nullable
- `last_message_at` integer nullable
- `last_message_sender_id` text nullable
- `unread_count` integer default 0
- `is_archived` integer default 0
- `is_muted` integer default 0
- `server_version` integer nullable
- `updated_at` integer

### `conversation_members`

Purpose:
- participant mapping

Columns:
- `conversation_id` text
- `user_id` text
- `role` text nullable
- `joined_at` integer nullable

Composite primary key:
- `conversation_id`
- `user_id`

### `messages`

Purpose:
- main local message store

Columns:
- `local_id` text primary key
- `server_id` text nullable unique
- `conversation_id` text
- `sender_id` text
- `type` text
- `text` text nullable
- `attachment_count` integer default 0
- `reply_to_server_id` text nullable
- `reply_to_local_id` text nullable
- `sent_at` integer nullable
- `created_at_local` integer
- `delivered_at` integer nullable
- `read_at` integer nullable
- `status` text
- `sync_state` text
- `error_message` text nullable
- `raw_json` text nullable

Status values:
- `pending`
- `sending`
- `sent`
- `delivered`
- `read`
- `failed`

### `message_attachments`

Columns:
- `id` text primary key
- `message_local_id` text
- `remote_url` text nullable
- `local_path` text nullable
- `mime_type` text nullable
- `size_bytes` integer nullable
- `width` integer nullable
- `height` integer nullable

### `call_history`

Purpose:
- recent calls tab source of truth

Columns:
- `id` text primary key
- `call_session_id` text nullable
- `conversation_id` text nullable
- `peer_user_id` text nullable
- `direction` text
- `type` text
- `status` text
- `started_at` integer nullable
- `answered_at` integer nullable
- `ended_at` integer nullable
- `duration_seconds` integer nullable
- `reason` text nullable
- `raw_json` text nullable
- `updated_at` integer

### `sync_queue`

Purpose:
- local outbox for unsynced operations

Columns:
- `id` text primary key
- `entity_type` text
- `entity_id` text
- `operation` text
- `payload_json` text
- `attempt_count` integer default 0
- `next_retry_at` integer nullable
- `created_at` integer
- `last_error` text nullable

### `sync_state`

Purpose:
- remember cursors and last successful sync times

Columns:
- `key` text primary key
- `value` text
- `updated_at` integer

Examples:
- `messages:last_event_ts`
- `conversations:last_sync_ts`
- `calls:last_sync_ts`
- `profile:last_sync_ts`

## Runtime Rules

### Message Send Flow

Target flow:

1. User sends a message.
2. Create local row in `messages` with `local_id`, `status=pending`, `sync_state=queued`.
3. Update `conversations.last_message_*` immediately.
4. Try sending through existing transport.
5. On backend ack, attach `server_id`, mark `status=sent`, `sync_state=synced`.
6. On `message.delivered`, update local status to `delivered`.
7. On `message.read`, update local status to `read`.
8. On failure, mark `failed` and keep retry option.

Important rule:
- UI should render the local row immediately, without waiting for REST reload.

### Message Receive Flow

Target flow:

1. Socket emits `message.created`.
2. Realtime layer passes payload to a sync coordinator.
3. Coordinator upserts sender/user data.
4. Coordinator inserts or updates `messages`.
5. Coordinator updates conversation preview and unread counter.
6. Chat list and open chat screen update automatically from DB streams.

Important rule:
- home and chat screens should not call full reload on each incoming event.

### Chat List Flow

Target flow:
- home screen watches a local query over `conversations`
- unread count and preview are derived from local data
- REST conversation fetch is only used for:
  - first hydration
  - manual refresh
  - pagination
  - reconciliation if socket reconnect missed events

### Profile Flow

Target flow:
- `SessionController` still owns token/session/bootstrap identity
- profile screen reads editable profile data from SQLite
- successful remote profile update writes back to both SQLite and session cache if required

SharedPreferences should remain only for:
- auth token metadata already in secure storage/prefs
- tiny bootstrap flags
- device id

It should not remain the main profile data store.

### Call History Flow

Target flow:
- call tab reads `call_history` from SQLite
- call end / decline / missed / answered events update local rows
- periodic REST fetch backfills missing remote history

This is separate from live WebRTC state. Live call signaling can stay as-is for now.

## What Changes In Existing Files

### [lib/core/realtime/realtime_service.dart](/Users/rosdeb/All_Project/titra-mobile/lib/core/realtime/realtime_service.dart)

Current role:
- socket event transport

Change:
- keep socket connection and event parsing
- stop letting screens depend on socket events directly for UI state
- forward events into sync coordinators / local repositories

Should own:
- connection lifecycle
- event stream parsing
- reconnect hooks

Should not own:
- chat list state
- message list state
- unread counters

### [lib/features/chat/data/messaging_repository.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/chat/data/messaging_repository.dart)

Current role:
- fetch/send messages against remote API

Change:
- split into remote and local responsibilities

Suggested split:
- `MessagingRemoteDataSource`
- `MessagesDao`
- `MessagingSyncRepository`

New repository responsibilities:
- watch local messages for a conversation
- enqueue outgoing messages locally
- reconcile send ack with local row
- paginate older messages into local DB

### [lib/features/chat/presentation/view_models/chat_view_model.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/chat/presentation/view_models/chat_view_model.dart)

Current role:
- loads messages from repository
- listens to realtime events
- performs optimistic behavior in memory

Change:
- subscribe to local DB stream for messages
- stop manually merging socket events into in-memory list
- call repository methods like:
  - `watchConversationMessages(conversationId)`
  - `sendTextMessage(...)`
  - `retryFailedMessage(localId)`
  - `markConversationRead(...)`

This view model should become much thinner.

### [lib/features/home/data/conversations_repository.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/home/data/conversations_repository.dart)

Current role:
- remote conversation list access

Change:
- split into local and remote layers

Suggested responsibilities:
- local watch query for home chat list
- remote hydrate / refresh / pagination
- local upsert when message events arrive

### [lib/features/home/presentation/view_models/home_view_model.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/home/presentation/view_models/home_view_model.dart)

Current role:
- reloads conversations on incoming message events

Change:
- subscribe to local conversations stream
- remove full network reload on every socket event
- only trigger remote refresh on:
  - pull to refresh
  - reconnect recovery
  - app bootstrap reconciliation

### [lib/features/call/data/calls_repository.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/call/data/calls_repository.dart)

Current role:
- remote call lifecycle APIs and call history fetch

Change:
- keep remote call APIs for call control
- add local persistence for call history rows
- after call completion, persist local history immediately
- remote history fetch becomes a backfill/reconcile step

### [lib/features/call/presentation/view_models/calls_view_model.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/call/presentation/view_models/calls_view_model.dart)

Current role:
- loads recent calls from remote repository with short cache window

Change:
- read from local SQLite stream
- remote refresh only updates local DB

### [lib/features/profile/presentation/view_models/profile_view_model.dart](/Users/rosdeb/All_Project/titra-mobile/lib/features/profile/presentation/view_models/profile_view_model.dart)

Current role:
- wraps remote refresh/upload and local UI flags

Change:
- read current profile snapshot from local DB
- write status/profile fields locally first if you want offline edits later
- sync remote update in background

For phase 1, profile can still be simpler than messages:
- remote update first
- local DB mirror immediately after success

### [lib/core/session/session_controller.dart](/Users/rosdeb/All_Project/titra-mobile/lib/core/session/session_controller.dart)

Current role:
- session token, cached user summary, device id, onboarding flags

Change:
- keep it
- do not turn this into the main app database layer
- after login or `refreshMe`, also hydrate/update SQLite user/profile rows

This should remain bootstrap/session state, not chat storage.

## Sync Strategy

Do not try to make everything fully offline-sync at once.

Use this order:

### Phase 1: Local Read Model

Goal:
- UI reads from SQLite
- remote still used for hydration and sends

Includes:
- conversations table
- messages table
- call history table
- basic profile table

### Phase 2: Local Write Queue

Goal:
- message sends are stored locally before remote ack

Includes:
- `sync_queue`
- retry policy
- failed message state

### Phase 3: Reconnect Recovery

Goal:
- recover missed events after socket disconnect or app restart

Includes:
- last sync cursor in `sync_state`
- fetch missed messages/conversations from API
- idempotent upsert rules

### Phase 4: Optional Offline Editing

Goal:
- profile edits and other writes can queue offline

This can come later. Messages and chat list are the priority.

## File-by-File Implementation Plan

### Step 1: Add database foundation

Create:
- `lib/core/local_db/app_database.dart`
- all tables and DAOs

Result:
- one local source of truth exists

### Step 2: Mirror remote conversation data into SQLite

Change:
- `ConversationsRepository`
- `HomeViewModel`

Result:
- home chat list can render from local DB

### Step 3: Mirror messages into SQLite and switch chat screen to local watch

Change:
- `MessagingRepository`
- `ChatViewModel`
- `RealtimeService` event consumers

Result:
- open chat survives restart and updates locally on socket events

### Step 4: Add outgoing message outbox

Change:
- local queued messages
- ack reconciliation
- retry flow

Result:
- message send UX becomes instant and recoverable

### Step 5: Add local call history

Change:
- `CallsRepository`
- `CallsViewModel`
- call end event persistence

Result:
- calls tab works locally after restart

### Step 6: Add local profile mirror

Change:
- `ProfileViewModel`
- login / `refreshMe` path

Result:
- profile screen no longer depends on network for basic render

## Data Merge Rules

These rules are important to avoid duplicates and broken chat rows.

### Messages

Use:
- `server_id` as the stable remote key
- `local_id` as the stable local optimistic key

Merge rules:
- if same `server_id` exists, update existing row
- if pending local message later gets matching server ack, attach `server_id` instead of inserting a second row
- do not sort only by server timestamp; keep a stable local fallback

### Conversations

Merge rules:
- always update last message preview from the newest known message
- unread count should be local and deterministic
- if remote payload is older than local latest row, do not regress preview fields

### Call History

Merge rules:
- one row per final call record id
- partial active call state can be promoted into final history row on end

## Risks To Avoid

Do not do these in the first pass:
- do not replace `SessionController` with SQLite
- do not let both in-memory lists and SQLite be equal sources of truth
- do not keep socket event handling in view models once local streams exist
- do not depend on full conversation reload after every incoming message
- do not make message send path write directly to UI state without persisting locally

## Recommended First Deliverable

If the work is split into a safe first implementation, do this first:

1. Add SQLite foundation with `drift`
2. Add `conversations` and `messages` tables
3. Make `HomeViewModel` read local chat list
4. Make `ChatViewModel` read local message list
5. Feed socket `message.created`, `message.delivered`, and `message.read` into SQLite
6. Keep existing REST fetch as hydrate/backfill only

That gives the highest value quickly:
- chat list survives restart
- messages survive restart
- incoming socket events appear without full reload
- outgoing message state can be upgraded next

## Minimal Package Set

Recommended packages to add when implementation starts:
- `drift`
- `drift_flutter` or standard `drift` setup for Flutter
- `sqlite3_flutter_libs`
- `path_provider`
- `path`

Optional later:
- background worker / retry helper if outbox becomes more advanced

## Final Recommendation

Build this as a local-first data layer, not a set of UI patches.

The correct architecture for this repo is:
- socket for realtime transport
- SQLite for app state
- repositories/sync coordinators for merge rules
- ViewModels subscribed to local streams

If you do it in that order, message list, chat list, call history, and profile cache will all become stable locally without breaking the current backend integration.
