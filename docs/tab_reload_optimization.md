# Tab Reload Optimization

## Problem

Every time the user taps a bottom nav tab, the tab widget is rebuilt from scratch because
`BottomWrapperScreen.currentScreen` returns a **new widget instance** on every `setState`.
Each tab calls its load method in `initState`, so switching tabs always triggers a full
network fetch + loading spinner.

---

## Root Cause

In `bottom_nav_screen.dart`, `currentScreen` is a getter that creates a new widget:

```dart
Widget get currentScreen {
  switch (selectedIndex) {
    case 0: return ChatsTabContent(...);   // new instance every tap
    case 1: return StatusTabContent(...);  // new instance every tap
    ...
  }
}
```

Flutter destroys and recreates the widget tree on each switch, so every tab's `initState`
fires again → full reload every time.

---

## Fix: Use `IndexedStack`

Replace the single `currentScreen` getter with `IndexedStack`. This keeps all tab widgets
alive in the tree; only the visible one is shown. `initState` fires once per tab, not on
every switch.

### Files to Change

---

### 1. `lib/features/bottom_navigation/presentation/view/bottom_nav_screen.dart`

Replace the `currentScreen` getter and its usage in `body` with an `IndexedStack`:

**Remove:**
```dart
Widget get currentScreen {
  switch (selectedIndex) { ... }
}
```

**Replace `Expanded(child: currentScreen)` with:**
```dart
Expanded(
  child: IndexedStack(
    index: selectedIndex,
    children: [
      ChatsTabContent(scrollController: _scrollController),
      StatusTabContent(scrollController: _scrollController),
      CallsTabContent(scrollController: _scrollController),
      ProfileContent(scrollController: _scrollController),
    ],
  ),
),
```

---

### 2. `lib/features/home/presentation/view/calls_tab_content.dart`

`CallsTabContent` loads in `initState` with no guard — it will fire once and stay alive.
**No change needed** after the `IndexedStack` fix.

However, add a "refresh only if stale" guard so manual re-entry (e.g. app resume) doesn't
always re-fetch. Add a `_lastLoaded` timestamp:

```dart
DateTime? _lastLoaded;

Future<void> _load({bool force = false}) async {
  if (!force && _lastLoaded != null &&
      DateTime.now().difference(_lastLoaded!) < const Duration(minutes: 2)) {
    return; // data is fresh, skip
  }
  // ... existing load logic ...
  _lastLoaded = DateTime.now();
}
```

Call `_load()` (not `_load(force: true)`) from `initState`.
Call `_load(force: true)` from the `RefreshIndicator.onRefresh`.

---

### 3. `lib/features/status/presentation/view/status_tab_content.dart`

`StatusTabContent` already calls `loadFeed()` in `initState` and on app resume
(`didChangeAppLifecycleState`). With `IndexedStack` it won't reload on every tab switch.

Add the same staleness guard inside `StatusRepository.loadFeed()`:

```dart
DateTime? _lastLoaded;

Future<void> loadFeed({bool force = false}) async {
  if (!force && _lastLoaded != null &&
      DateTime.now().difference(_lastLoaded!) < const Duration(minutes: 2)) {
    return;
  }
  // ... existing logic ...
  _lastLoaded = DateTime.now();
}
```

The `didChangeAppLifecycleState` call passes no argument → uses the staleness check.
The `RefreshIndicator` / `createStoryFromFile` calls pass `force: true`.

---

### 4. `lib/features/home/presentation/view/chats_tab_content.dart`

Chats are driven by `HomeViewModel` which already has:
- `loadConversations()` called once from `BottomWrapperScreen.initState`
- Silent realtime refresh via `_messageCreatedSub`

With `IndexedStack`, the widget stays alive so no extra change is needed here.
The existing realtime subscription keeps data fresh without reloading on tab switch.

---

## Summary Table

| File | Change |
|---|---|
| `bottom_nav_screen.dart` | Replace `currentScreen` getter + `Expanded(child: currentScreen)` with `IndexedStack` |
| `calls_tab_content.dart` | Add `_lastLoaded` staleness guard in `_load()` |
| `status_repository.dart` | Add `_lastLoaded` staleness guard in `loadFeed()` |
| `chats_tab_content.dart` | No change needed |
| `profile_content.dart` | Check if it loads data in `initState`; apply same staleness guard if yes |

---

## Result

- Tab switch → **no network call**, no spinner, instant display of cached data.
- Pull-to-refresh → **force reload**, always fetches fresh data.
- App resume → only reloads if data is older than 2 minutes.
- New realtime message → chats list silently refreshes in background (already works).
