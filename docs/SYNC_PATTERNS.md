# Sync Singleton Patterns

This document details patterns for working with the Sync singleton.

## Standard Screen Subscription Template

```dart
StreamSubscription<void>? _syncSubscription;

@override
void initState() {
  super.initState();
  Future<void>.microtask(() async {
    await ref.read(xNotifierProvider.notifier).refreshFromSync();
  });
  _syncSubscription = sync.onDataChanged.listen((_) {
    if (!mounted) return;
    ref.read(xNotifierProvider.notifier).loadFromSync();
  });
}

@override
void dispose() {
  _syncSubscription?.cancel();
  super.dispose();
}
```

## Sync Test Setup

When testing Sync, initialize all InvalidateSync fields:

```dart
setUp(() {
  sync = Sync();
  sync.sessionsSync = InvalidateSync(() async {});
  sync.settingsSync = InvalidateSync(() async {});
  sync.machinesSync = InvalidateSync(() async {});
  sync.messagesSync = InvalidateSync(() async {});
  sync.profileSync = InvalidateSync(() async {});
  sync.friendsSync = InvalidateSync(() async {});
  sync.feedSync = InvalidateSync(() async {});
  sync.artifactsSync = InvalidateSync(() async {});
  sync.todoSync = InvalidateSync(() async {});
});
```

## Key Methods

- `sync.create()` — Full init for new login; awaits settings/profile
- `sync.restore()` — Restore on app restart; does NOT await settings/profile
- `sync.onDataChanged` — Stream for data changes
- `sync.onSessionMessagesChanged` — Stream for session message changes

## InvalidateSync

Each data type has an `InvalidateSync` for debounced server fetches:
- Exponential backoff: 1s–5s
- Max retries: 5
