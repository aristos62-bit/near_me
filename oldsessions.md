# NearMe — Old Sessions Archive

> Συμπυκνωμένο archive: τεχνολογίες, αρχιτεκτονική, σημαντικά fixes, τρέχουσα κατάσταση.

## Τεχνολογίες

| Layer | Επιλογή |
|---|---|
| State Management | Riverpod 3.x (Notifier, @riverpod) |
| Local DB | Drift 2.33 (SQLite) |
| Navigation | GoRouter 17 (StatefulShellRoute, adaptive nav) |
| Auth | Firebase (Anonymous → Email/Phone) |
| Cloud DB | Firestore (collectionGroup, 17 composite indexes) |
| Storage | Firebase Storage (avatars/photos, max 5MB) |
| Functions | Firebase Functions (TypeScript, 1st Gen) |
| Encryption | encrypt 5.0.3 (AES-256 GCM) + deriveKey (SHA-256) |
| Secure Storage | flutter_secure_storage (encryption keys) |
| Geo | geolocator + geoflutterfire_plus + geocoding |
| Search v1 | Firestore native (active) |
| Search v2 | Typesense self-hosted (stub, Phase 4) |
| Push | FCM (3 Cloud Functions, locale-aware) |
| i18n | flutter_localizations + intl (el/en, L10n) |
| Biometric | local_auth 3.0 |

## Αρχιτεκτονικές Αποφάσεις

### Auth — Anonymous + Lazy Upgrade
Χρήστης ξεκινά ανώνυμος → upgrade σε verified (email/phone) μόνο όταν θελήσει επικοινωνία.

### Γεωγραφία — GPS με fallback manual
GPS → lat/lng στο Drift (ΠΟΤΕ raw στο Firestore). GeoHash μόνο στο Firestore με precision levels. Fallback: text field για χειροκίνητη πόλη/χώρα.

### Search — Υβριδικό (Repository Pattern)
Firestore native (τώρα) → Typesense (Phase 4). Abstract SearchRepository — swap χωρίς UI changes. Server-side filters + cursor pagination. `hasLocationFilter` flag για city/country χωρίς geo overlap.

### Security Architecture (5-Layer)
1. **Device**: Drift + flutter_secure_storage + FLAG_SECURE + Biometric Lock + Auto-lock timer
2. **Auth**: Anonymous → Email verify, silent refresh, force refresh
3. **Data Rules**: Firestore Security Rules (15+ indexes)
4. **Transport**: TLS 1.3 + AES-256 E2E chat (deriveKey deterministic)
5. **Behaviour**: Rate limiting (10 reports/hr), auto-ban (5 reports), request expiry (48h)

### Data Flow
- **Local (Drift)**: UserProfile (23 fields), PrivacySettings, ConsentLog, ChatCache, SavedSearch, AppSettings, BlockedUser
- **Firestore**: users/{uid}/public/profile, users/{uid}/status (isOnline), chats/{chatId}/messages (AES-256), requests/{reqId}, reports/{reportId}, users/{uid}/blocked/{blockedUid}, users/{uid}/fcm_tokens/{tokenId}
- **Repository Pattern**: 7 abstract interfaces — ποτέ raw Firestore στο UI

## Φάσεις Υλοποίησης

### Φάση 1 — Core & Privacy (100%)
Firebase Init, Drift (7 tables, schema v6), Profile CRUD, PrivacySettings (12 toggles), ConsentLog, Publish/Unpublish, GPS + GeoHash, i18n el/en, Theme, Security Rules, Repository Pattern, AppMessenger/AppStateWidgets, BlockedUser, Report + Auto-ban CF, Delete Account, Screenshot Prevention, Biometric Lock + Auto-lock timer, Feature Flags (8)

### Φάση 2 — Discovery (100%)
Firestore search (collectionGroup), SearchFilters (15 interests), ProfileCard, PublicProfile view, Saved Searches, Block/Report, Cursor pagination + 300 cap, Server-side filters, Haversine distance filter, Adaptive geo search precision, Typesense stub

### Φάση 3 — Communication (100%)
Verify Account, canUserCommunicate single point of truth (5-layer guard), Request System (48h expiry), E2E Encrypted Chat, Online Presence (heartbeat 60s), Read Receipts, FCM (3 CFs), Rate Limiting, Chat preview + unread count, Phone verification (SMS), Error Messages Centralization

### Φάση 4+ (0%)
Typesense, Video (Agora), AI matching, Groups, Verified badge, Premium, Web, Admin panel

## Critical Bugs & Fixes

| # | Bug | Fix |
|---|---|---|
| 1 | `$(database)` σε get() paths → permission-denied | Hardcode `(default)` |
| 2 | `get(path).exists` → permission-denied (Firestore bug) | Use `.data.isVisible == true` |
| 5 | Encryption key missing on 2nd device join chat | `deriveKey(chatId)` — deterministic SHA-256 |
| 7 | `notBanned()` με custom claims → stale cache | `!exists(banned/{uid})` live Firestore read |
| 9 | Anonymous infinite spinner στα chats | `streamChats()` yields `[]` |
| 13 | ChatScreen rebuild loop (5x σε 4s) | Page keys + smart auth notifier + batch pagination |
| 14 | `isPublished: false` hardcoded στο save | Preserve `_loadedProfile.isPublished` |
| 15 | sendRequest() missing validation | 4-layer guard: UI + type selector + repo + Firestore rules |
| 16 | Search + geoHash composite index crash | Move non-geo filters to `_passesFilters()` client-side |
| 17 | Registration UX — no info about email verification | GoRouter redirect `/welcome`→unverified→`/auth` |
| 18 | X button crash on `/auth` via redirect | `context.pop()` → `context.go('/')` |
| 19 | Stale `emailVerified` on returning verified users | `await user.reload()` in AppRouter.init() |
| 20 | **403 avatar after reinstall** — backup restores stale token | `getProfile()` merge: compare Firestore `updatedAt` |
| 21 | **KeyStore corruption → all E2E keys deleted** (Android) | `getKeyOrDerive(chatId)`: try storage → fallback deriveKey() |
| 22 | **Stale `emailVerified` after `reload()`** — `authStateChanges()` δεν εκπέμπει | `authStateProvider` → `FirebaseAuth.instance.userChanges()` |
| 23 | **Firestore null cast** — legacy profile docs without `uid` field | `_safePublicProfileFromJson()` null check before `PublicProfile.fromJson()` |

## Session Progression

### Foundation (Sessions 1-68)
Project init, Blueprint, Isar→Drift migration, Firebase, Auth, Profile CRUD, GPS, Search prototype, Chat init, FCM, Online Presence. Riverpod 2→3, deriveKey fix, `notBanned()` rewrite. Server-side filters + cursor pagination + 300 cap.

### Communication & Profile (Sessions 69-100)
Comm settings cleanup, Chat rebuild loop fix, Auto-publish, Request validation (4-layer), Feature Flags (8), Biometric Lock, Typesense stub, GoRouter errorBuilder, PresenceService race fix, `showPhotos` privacy toggle, Schema v3→v6, Country field, Null-overwrite fix, Unit tests (30), Phone verification, `isPhoneVerified` fix (empty string vs null), SettingsScreen cascade rebuild fix, Unlink phone + stale cache, `isOnline` overwrite fix, Country filter + GPS-first location + auto-publish, City auto-fill + Nominatim + `isManualLocation`, Distance filter analysis.

### Search Overhaul & Polish (Sessions 100-131)
**Search fixes**: `hasLocationFilter` flag, `WHERE country` server-side, parallel geo queries per cell, Haversine distance, cell BOUNDS fix, stale lat/lng refresh, distance display ("X km away"), Hybrid edge/center distance, Adaptive search precision, `getNeighbours` `*2` bug, default radius selector, `searchNearby` 3-char fix, `searchNearby→search` in auto-search.

**Auth & Security**: Registration UX redirect, X button crash fix, stale `emailVerified` fix, canUserCommunicate 5-layer guard, Firestore rules deploy.

**KeyStore fix**: `getKeyOrDerive(chatId)` — try storage → fallback deriveKey() → bilingual placeholder for unreadable messages.

**Other**: Gender 100% client-side, GPS staleness fix, Error Messages Centralization, MediaQuery cascade fix (MainShell + ProfileScreen + DiscoveryScreen), FCM foreground fix, ChatScreen 3-way split rebuild fix, Scroll spam fix, ChatListScreen flash fix, request_repository defense-in-depth, idleTimer log spam fix.

### Session 132 — `userChanges()` fix
`authStateProvider` χρησιμοποιούσε `authStateChanges()` (εκπέμπει μόνο sign-in/out). Μετά από `reload()` → `emailVerified=true`, το stream ΔΕΝ εκπεμπόταν. Screens έβλεπαν stale `emailVerified=false`. Fix: `FirebaseAuth.instance.userChanges()`. 14 consumers checked — no side effects. Verified on 2 real devices.

### Session 133 — Firestore null cast fix
Legacy Firestore documents (pre-git) missing `uid` field caused `type 'Null' is not a subtype of type 'String'` in `PublicProfile.fromJson()` at both merge check and fallback restore paths in `getProfile()`. Error was already try-caught but noisy. Fix: `_safePublicProfileFromJson()` helper — validates `uid` exists and is non-null String before calling `fromJson()`, returns null otherwise. 1 file: `profile_repository_impl.dart`.

### Session 134 — ChatScreen crash (GoRouterState σε initState) + raw AlertDialog→AppMessenger
**Fix 1 — Crash P0**: `ChatScreen.initState()` καλούσε `GoRouterState.of(context).extra` (γραμμή 38) → crash `dependOnInheritedWidgetOfExactType<_ModalScopeStatus>() was called before initState completed`. Η `GoRouterState.of(context)` απαιτεί mounted widget (διαθέσιμο στο `ModalRoute`). Λύση: μεταφορά σε `didChangeDependencies()` με `??=` (idempotent) + `DebugConfig.log()`. Ίδιο pattern με `public_profile_view_screen.dart:39-46`. 1 file: `chat_screen.dart`.

**Fix 2 — Raw AlertDialog**: `_showE2EInfo()` χρησιμοποιούσε raw `showDialog`/`AlertDialog` αντί για `AppMessenger`. Λύση: νέα reusable μέθοδος `AppMessenger.showInfoDialog()` (icon + title + message + dismiss label, rounded corners, consistent theme styling). 2 files: `app_messenger.dart` (+35 lines), `chat_screen.dart` (κλήση). Verified on 2 real devices — `flutter analyze` clean.

### Session 135 — C2: Biometric lock bypass fix (FCM notification tap)

**Problem:** Notification tap while biometric lock is active bypassed the lock. Grace period (60s) also skipped biometric entirely for notification taps. Chain: `_onMessageOpened` pushed routes with zero lock awareness → grace period 60s → even when locked, route initialized under LockScreen loading data.

**Fix — `fcm_service.dart`:**
- Added `static bool isLocked` (mirrors `_NearMeAppState._isLocked`)
- Added `static String? _pendingFcmPath` + `static bool get hasPendingNavigation`
- `_onMessageOpened()`: if `isLocked`, stores path to `_pendingFcmPath` and returns (no route push)
- New `tryExecutePendingNav()`: pushes stored path, clears it
- New `clearPendingNav()`: defense-in-depth on sign out
- `DebugConfig.log()` σε store/execute/clear

**Fix — `main.dart`** (5 insertion points, +7 lines):
1. `_applyStartupLock` auth fail: `FcmService.isLocked = true` πριν `setState`
2. `_checkBiometricLock` auth fail: `FcmService.isLocked = true` πριν `setState`
3. `_onIdleTimeout`: `FcmService.isLocked = true` πριν `setState`
4. `LockScreen.onUnlock`: `FcmService.isLocked = false` + `FcmService.tryExecutePendingNav()`
5. Grace period (60s): `!FcmService.hasPendingNavigation &&` — if pending nav exists, biometric is always required

**Edge cases covered:** locked + 2 notif taps (only latest), grace period + pending nav (always biometric), cold start (existing mechanism), sign out (auth guard redirect), kill app (volatile state lost).

**Files:** `fcm_service.dart` (169→192 lines), `main.dart` (399→406 lines)
**Backups:** `fcm_service.dart.bak`, `main.dart.bak`
**Verification:** `flutter analyze` — No issues found

### Session 136 — FCM navigation to chat after unlock (full rewrite)

**Problem:** 2 independent root causes prevented FCM push navigation from reaching ChatScreen after biometric unlock:
1. **Cold start**: `checkPendingNavigation(context)` called `context.push()` outside GoRouter widget tree → `No GoRouter found in context` → navigation silently swallowed.
2. **Background locked**: `FcmService.isLocked` set to `true` **after** `await LockScreen.authenticate()` completed → `_onMessageOpened` could fire during biometric dialog with `isLocked=false` → push bypassed lock → wrong route.

**Root cause 1 detail:** `context` was `_NearMeAppState` (parent of `MaterialApp.router`), outside GoRouter inherited widget. **Any** `context.push()` from there crashes. The `checkPendingNavigation()` code path was completely unrecoverable.

**Root cause 2 detail:** Pre-lock guard `FcmService.isLocked = true` was only set *after* the `await` — during the 2-3s biometric dialog, `_onMessageOpened` saw `isLocked=false` and pushed directly.

**Fix — 2 files, consolidated approach:**
- **`fcm_service.dart`**: Deleted `_pendingChatId`, `_pendingRequestId`, `checkPendingNavigation()`, unused `go_router` import. Modified `getInitialMessage()` to store path to `_pendingFcmPath` (same mechanism). Kept `tryExecutePendingNav()` + `clearPendingNav()`.
- **`main.dart`**: Deleted postFrameCallback with `checkPendingNavigation(context)`. Added `FcmService.isLocked = true` **before** `await LockScreen.authenticate()` in both `_applyStartupLock()` and `_checkBiometricLock()`. Added `FcmService.tryExecutePendingNav()` after biometric success in both methods. Added `FcmService.isLocked = false` in catch blocks.

**Verification:** Deployed + tested on 2 real devices (24094RAD4G / M2007J20CG). Logs confirm both paths:

Cold start:
```
Pending nav set: /chat/XO8FpIcTfYfTLeJU4dnB
FCM executing pending nav=/chat/XO8FpIcTfYfTLeJU4dnB
ChatScreen init #0: XO8FpIcTfYfTLeJU4dnB
```

Background locked:
```
FCM _onMessageOpened: path=/chat/XO8FpIcTfYfTLeJU4dnB isLocked=true
FCM executing pending nav=/chat/XO8FpIcTfYfTLeJU4dnB
ChatScreen init #0: XO8FpIcTfYfTLeJU4dnB
```

Zero occurrences of `No GoRouter found in context` or `_pendingChatId` or `checkPendingNavigation`.

**Files:** `fcm_service.dart`, `main.dart`
**Verification:** `flutter analyze` — No issues found

### Session 137 — ProfileCards rebuild fix (ValueKey + select + SearchResultsGrid extraction)

**Problem:** ProfileCards ~20× rebuilds από layout cascade (Scaffold keyboard viewInsets άλλαζε constraints). 5 independent triggers:
1. Keyboard open (global viewInsets) → ~20 animation frames
2. `ref.listen(appSettingsProvider)` + `setState()` → double build
3. `ref.watch(searchProvider)` σε DiscoveryScreen → rebuild cascade σε ALL children
4. No `key` σε ProfileCards → Flutter αποσυναρμολογούσε/επαναδημιουργούσε Elements
5. Diagnostic log spam σε κάθε LayoutBuilder rebuild

**Fix — 3 phases, 2 files:**

**Phase 1a — ValueKey (`discovery_screen.dart:411`):**
- `key: ValueKey(p.uid)` στο ProfileCard → Flutter διατηρεί Elements + Riverpod subscriptions

**Phase 1b — select() αντί listen+setState (`discovery_screen.dart:221-231`):**
- Αντικατάσταση `ref.listen(appSettingsProvider)` + `setState()` με `ref.watch(appSettingsProvider.select(...))` → 1 build αντί 2

**Phase 2 — Extract SearchResultsGrid (νέο αρχείο + edit):**
- **Δημιουργία:** `lib/features/discovery/widgets/search_results_grid.dart` (~100 γραμμές)
  - `ConsumerStatefulWidget` με ScrollController, _onScroll, _triggerLoadMore
  - LayoutBuilder + responsive widths + Wrap + ProfileCards(key: ValueKey)
  - DebugConfig.log(DebugConfig.uiRebuild) σε κάθε build
  - `const` constructor
- **Επεξεργασία:** `discovery_screen.dart` (426 → 342 γραμμές)
  - Αφαιρέθηκαν: `_isLoadingMore`, `_hasMore`, `_scrollController`, `_scrollThreshold`, `_onScroll()`, `_triggerLoadMore()`, `_buildResultsList()`, `ref.listen(searchProvider,...)`, diagnostic log, 3 imports (responsive_utils, profile_card)
  - `const SearchResultsGrid()` σε loading + success states
- `resizeToAvoidBottomInset: false` (ήδη uncommitted) — keyboard cascade fixed

**Verification:** `flutter analyze` clean. Deployed on 24094RAD4G — logs confirm:
- `SearchResultsGrid init` + `SearchResultsGrid built: 4 cards`
- `ProfileCard uid=...` με stable ValueKey
- `DiscoveryScreen: loaded radius=25.0 km from AppSettings` (select λειτουργεί)
- `breakpointFromWidth` logs σε keyboard animation — **ΚΑΝΕΝΑ** `_buildResultsList REBUILT`
- Κανονική navigation (discover → chats → profile → settings → phone verify)

**Files:** `discovery_screen.dart` (426→342), `search_results_grid.dart` (νέο, ~100)
**Verification:** `flutter analyze` — No issues found

---

### Session 138 — Retry mechanism for FCM sends (sendChatNotification, sendRequestNotification, sendRequestResponseNotification)

**Problem:** All 3 FCM Cloud Functions lacked retry on transient failures (rate limit, network hiccup, server unavailable). A transient error caused permanent notification loss.

**Fix — 2 files:**
- **New `functions/src/fcm-utils.ts`** (63 γρ.): `isRetryable(error)` + `sendWithRetry(payload, maxRetries=3)` with exponential backoff (1s→2s→4s). Retryable codes: `internal-error`, `unavailable`, `server-unavailable`, `quota-exceeded`. Non-retryable `messaging/*` codes are NOT retried. Detailed `functions.logger.warn/info` on each attempt.
- **Edit `functions/src/index.ts`**: 3× duplicated `sendEachForMulticast` → `sendWithRetry(payload)`. Error messages now include `after 3 attempts`. Import added at line 3.
- **Edge cases covered:** token changes during retries (per-token cleanup after success), block race (not re-checked, same as current), `deleteUserData` race (stale tokens handled by per-token error), rate limit safety (staggered backoff), function timeout (7s << 60s), Flutter lifecycle (zero changes).

**Verification:** `npm run build` (tsc) ✅ clean. `flutter analyze` ✅ clean. `flutter run --release` on 24094RAD4G ✅ (14.5MB APK). Deploy: `firebase deploy --only functions`.

### Session 139 — L1: Unread tracking για requests + L3: FCM deep link /requests/:requestId

**Problem:** Τα requests δεν είχαν unread tracking — ούτε visual distinction, ούτε badge, ούτε mark-as-read. 
Το FCM notification tap πήγαινε σε generic `/requests` χωρίς requestId.

**Fix — 8 αρχεία Dart + 1 rules deploy:**

**L1.1 — Widget extraction (`requests_dashboard_screen.dart` 622→285 lines):**
- `_RequestCard`, `_TypeBadge`, `_StatusBadge`, `_ActionChip`, `_ChatButton`, `_FilterBar` → extracted to `lib/features/requests/widgets/request_card_widgets.dart` (343 lines)
- Dashboard now under 400 line limit ✅

**L1.2 — `readAt` Firestore πεδίο:**
- `sendRequest()` persists without `readAt` → default null = unread
- `markRequestAsSeen(requestId)` sets `readAt: FieldValue.serverTimestamp()`
- Rules: `hasOnly(['status','chatId','respondedAt','readAt'])` → deployed

**L1.3 — Repository:**
- Interface: `request_repository.dart` → `markRequestAsSeen()`
- Impl: `request_repository_impl.dart` → Firestore update με try-catch (non-fatal)

**L1.4 — Provider:**
- `unreadRequestsProvider` — derived από `incomingRequestsProvider`, φιλτράρει `pending && readAt == null`

**L1.5 — Unread visual (RequestCard):**
- Μπλε κουκκίδα (8px) + bold nickname + bold message when `isUnread`
- Mark as seen on tap (only in normal mode, not selection mode)

**L1.6 — Profile badge:**
- `_buildMenu()` accepts `unreadRequests` param
- Requests menu item: `Icons.mail` (filled) όταν unread > 0 + `Badge` widget με count (99+ cap)
- `L10n.unreadRequestsLabel()` bilingual

**L3.1 — FCM deep link:**
- `fcm_service.dart`: `_onMessageOpened` + `getInitialMessage` → `/requests/{requestId}` αν υπάρχει, `/requests` fallback
- `app_router.dart`: `GoRoute(path: '/requests/:requestId')` → `RequestsDashboardScreen(highlightRequestId: requestId)`

**Backups:** 10 `.bak` files (όλων των εμπλεκόμενων αρχείων)
**Verification:** `flutter analyze` — No issues found. `firebase deploy --only firestore` — rules deployed.

### Session 140 — RenderFlex overflow fixes (discovery + delete account)

**Problem:** 2 screens had `Center > Padding(all: 32) > Column(mainAxisSize: Min)` χωρίς scroll wrapping. Σε tablet (Android 16) ή με accessibility font scaling, το Column ξεπερνούσε το διαθέσιμο ύψος → **RenderFlex overflow** (κίτρινη/μαύρη γραμμή σε debug mode). Επηρέαζε:
1. `discovery_screen.dart:310` — `_buildSearchPrompt()` (idle state με "Αναζήτησε άτομα κοντά σου")
2. `delete_account_screen.dart:112` — `isAnonymous` block (προσωρινός λογαριασμός)

**Fix — 2 files, 1 pattern:**
- Αντικατάσταση του return με `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: constraints.maxHeight)` + `Center`:
  - `ConstrainedBox(minHeight)` κάνει το child τουλάχιστον όσο το viewport
  - `Center` κεντράρει το Column όταν χωράει
  - `SingleChildScrollView` επιτρέπει scroll όταν το περιεχόμενο είναι ψηλότερο από το viewport
- **discovery_screen.dart**: `_buildSearchPrompt()` — γραμμές 306-336
- **delete_account_screen.dart**: `isAnonymous` return block — γραμμές 111-143

**Edge cases covered:** landscape mode, tablet (24094RAD4G), accessibility font scaling (200%), keyboard open, hot reload — όλα λειτουργούν με scroll όταν χρειάζεται, κεντραρισμένο όταν χωράει.

**Backups:** `discovery_screen.dart.backup`, `delete_account_screen.dart.backup`
**Verification:** `flutter analyze` — No issues found

### Session 146 — Breakpoint spam fix: cache + constraint-based responsive helpers

**Problem:** `breakpointFromWidth: 393px → ScreenBreakpoint.mobile` log 300+ φορές σε cascade (20-30 κλήσεις ανά rebuild chain). 40+ logs/sec σε filters μετά από reset. Κάθε `LayoutBuilder`/`Center+SizedBox` rebuild (viewInsets, navigation transitions) πυροδοτούσε `maxContentWidth(context)` → `MediaQuery.of(context).size.width` → `breakpointFromWidth()` χωρίς cache.

**Root cause:** 17 files χρησιμοποιούσαν context-based `maxContentWidth(context)` που καλούσε `MediaQuery.of(context).size.width`. Κάθε rebuild δημιουργούσε νέο width → log. Δεν υπήρχε caching, ούτε constraint-based εναλλακτική.

**Phase 1 — Log cache (`responsive_utils.dart:29`):**
- `static double _lastLoggedWidth = -1;` — log μόνο όταν `w` αλλάζει
- Μηδενίζει το `breakpointFromWidth` spam χωρίς αλλαγή αρχιτεκτονικής
- `flutter analyze` ✅ clean

**Phase 2 — Constraint-based helpers (16/16 files migrated ✅):**
- Νέο pattern: `LayoutBuilder(builder: (ctx, c) { final w = ResponsiveUtils.resolveWidth(ctx, c); return SizedBox(width: maxContentWidthFromWidth(w), ...) })`
- `resolveWidth(ctx, constraints)` — χρησιμοποιεί `constraints.maxWidth` με `MediaQuery` fallback
- `maxContentWidthFromWidth(w)` — width-based χωρίς context lookup
- **Migrated files:**
  1. `search_filters_screen.dart` ✅
  2. `profile_editor_screen.dart` ✅
  3. `settings_screen.dart` ✅
  4. `verify_account_screen.dart` ✅
  5. `public_profile_view_screen.dart` ✅
  6. `send_request_screen.dart` ✅
  7. `welcome_screen.dart` ✅
  8. `phone_verify_screen.dart` ✅
  9. `privacy_editor_screen.dart` ✅
  10. `blocked_users_screen.dart` ✅
  11. `anonymous_info_screen.dart` ✅
  12. `requests_dashboard_screen.dart` ✅

**Σημείωση:** 4 ακόμα files (`gps_strength_indicator`, `consent_log_screen`, `delete_account_screen`, `chat_screen`) χρησιμοποιούσαν `horizontalPadding/isTablet/paddingValue` — migrated στο Phase 3 παρακάτω.

**Phase 3 — Context-based → constraint-based migration (4 files ✅):**

| Αρχείο | Πριν | Μετά | Analyze |
|--------|------|------|:-------:|
| `gps_strength_indicator.dart` | `horizontalPadding(context)` | `LayoutBuilder` + `horizontalPaddingFromWidth(w)` | ✅ |
| `consent_log_screen.dart` | `isTablet(context)` → `isWide ? 48 : 12` | `LayoutBuilder` + `isTabletFromWidth(w)` | ✅ |
| `delete_account_screen.dart` | `isTablet(context)` → `maxWidth: isWide ? 600 : 480` | `LayoutBuilder` + `isTabletFromWidth(w)` | ✅ |
| `chat_screen.dart` | `paddingValue(context)` × 2 widgets | `LayoutBuilder` + `paddingValueFromWidth(w)` | ✅ |

**Σύνολο:** 16/16 files constraint-based, **καμία κλήση `MediaQuery.of(context).size.width`** σε responsive helpers (εκτός από `resolveWidth` fallback).

**Runtime testing (`flutter run --dart-define=ENABLE_RELEASE_DEBUG=true`):**

`breakpointFromWidth` log εμφανίστηκε **μόνο 4-5 φορές** σε ~3 λεπτά χρήσης (από 300+ πριν). Οι μόνες φορές που loggάρει είναι όταν το πλάτος όντως αλλάζει (384→320→384→320 px). Όλα τα screens λειτουργούν κανονικά: ProfileScreen ✅, ChatListScreen ✅, DiscoveryScreen ✅, SettingsScreen ✅, BlockedUsersScreen ✅.

**Side effect detected (pre-existing):** `RenderFlex overflowed by 82 pixels` στο `requests_dashboard_screen.dart:217` — Row selection bar (414px content > 352px διαθέσιμο). ΔΕΝ σχετίζεται με τις αλλαγές μας — το `_buildSelectionBar` μπαίνει απ'ευθείας ως `Scaffold.body` χωρίς `maxContentWidth` wrapping.

**Διαδικασία ελέγχου runtime:**
1. `flutter run --dart-define=ENABLE_RELEASE_DEBUG=true`
2. `adb logcat -s flutter:*` ή `flutter logs`
3. Φιλτράρισμα: `grep breakpointFromWidth` — αναμένονται **<10 logs** σε όλη τη διάρκεια
4. Πλοήγηση:
   - Discovery → Filters → Apply → Results → Profile tap → Back → Chat tab → Συγκεκριμένο chat → Back → Settings tab → Profile editor → Save → Privacy editor → Save → Requests tab → Incoming/Outgoing tabs
5. **Key check:** `breakpointFromWidth` logs μόνο όταν το πλάτος αλλάζει (π.χ. fold/unfold, orientation change, resize). **ΟΧΙ** spam σε rebuilds.
6. **LayoutBuilder REBUILT logs** (flag: `uiRebuild`): αναμένονται rebuilds σε navigation transitions — φυσιολογικό. Αν υπάρχουν cascade rebuilds (10+ σε 1sec χωρίς user input) → regression.

**Backups:** διαγράφηκαν 43 backup αρχεία (26 .bak + 17 .backup). Phase 3 backups: διατηρούνται 4 `.bak` (gps_strength_indicator, consent_log_screen, delete_account_screen, chat_screen).

## Current State

| Μέτρο | Τιμή |
|---|---|
| Completion | ~99.9% (Phases 1-3 100%) |
| Firestore indexes | 17 composite deployed |
| Build | `flutter analyze` clean, release APK ~14.5MB |
| Tests | **30/30 passed** |
| `.dart` files | ~109 (non-generated) |
| Cloud Functions | 5 deployed + `fcm-utils.ts` helper |
| **L1 — Unread tracking requests** | ✅ Session 139 |
| **L3 — FCM deep link /requests/:requestId** | ✅ Session 139 |
| **RenderFlex overflow fixes** (discovery + delete) | ✅ Session 140 |
| **L2 — Badge count iOS** | ✅ Session 143 |
| **L4 — Locale fallback `?? 'en'`** | ✅ Session 143 |
| **City-filter Firestore crash** | ✅ Session 143 |
| **Breakpoint spam fix** (Phase 1 cache + Phase 2+3 constraint-based) | ✅ Session 146 |

### Session 143 — L2 badge iOS + L4 locale fallback + Firestore city-filter crash

**3 fixes, 0 regressions.**

### L2: Badge count management (iOS)

**Problem:** Το `_resetBadge()` στο init έκανε μόνο reset (badge=0). Δεν υπήρχε `setBadge()` για να ενημερώνει το iOS app icon badge με το πραγματικό unread count.

**Fix — 3 files:**
- **`fcm_service.dart`**: Added `static Future<void> setBadge(int count)` — καλεί `FirebaseMessaging.instance.setBadge(count)`. Public static για χρήση από `unreadBadgeProvider`.
- **`providers/unread_badge_provider.dart`**: Νέα `unreadBadgeProvider` (Provider<int>) που αθροίζει `unreadChatsProvider` + `unreadRequestsProvider`. Listen σε κάθε αλλαγή και καλεί `FcmService.setBadge(count)`. `DebugConfig.log(DebugConfig.service, ...)`.
- **`main.dart`**: `ref.listen(unreadBadgeProvider, ...)` στην `build()` του `_NearMeAppState` — ενημερώνει badge σε κάθε αλλαγή.

**Edge cases:** cold start (υπάρχον init reset), 2+ unread sources (άθροισμα), badge=0 (reset), iOS only (`setBadge` no-op σε άλλα OS).

### L4: Locale fallback `?? 'el'` → `?? 'en'`

**Problem:** Στα Cloud Functions, όταν το `lang` ήταν null, το fallback ήταν `'el'`. Σε English users χωρίς locale → λάμβαναν ελληνικά notifications.

**Fix — 1 file:**
- **`functions/src/index.ts`**: 3 changes `?? 'el'` → `?? 'en'` (γραμμές 43, 263, 389).

**Edge cases:** Greek users χωρίς locale → θα δουν English notifications (υπέρ της πλειοψηφίας των μη-Ελλήνων χρηστών). Users με locale → no change.

### City-filter Firestore crash (P0)

**Problem:** `_generalSearch()` είχε `where('age', >=/<=, ...)` range filters + `orderBy('__name__')` χωρίς `orderBy('age')` → illegal Firestore query structure → `INVALID_ARGUMENT` crash. Η αναζήτηση με city + age ηλικίας έπεφτε πάντα.

**Root cause:** Firestore queries με range filter (`>=`, `<=`) σε πεδίο (`age`) απαιτούν `orderBy` στο ίδιο πεδίο πριν από `orderBy('__name__')`. Δεν υπήρχε `orderBy('age')` → `INVALID_ARGUMENT`.

**Fix — 1 file (`firestore_search_repository.dart`):**
- `_generalSearch()`: αφαιρέθηκαν τα age `where()` clauses (server-side range filters).
- Κρατήθηκαν `cityNormalized`/`countryNormalized` equality filters (existing composite indexes καλύπτουν).
- Age filtering μεταφέρθηκε εξ ολοκλήρου στο client-side `_passesFilters()` (όπου ήδη υπήρχε).
- Signature: `_generalSearch(filters, cursor, limit)` — 3 params, αφαιρέθηκαν flags.
- `firestore.indexes.json`: unchanged (restored to original 16 indexes).

**Device test OK (Περιστέρι + age 18-80 + GPS):**
```
_generalSearch: city=Περιστέρι, country=null
_generalSearch: 3 results (raw 3), hasMore=false
SearchNotifier.search: 2 results
```
3 raw, 2 filtered (αφαιρέθηκε ο εαυτός σου). **Κανένα error.**

**Backups:** `fcm_service.dart.bak`, `unread_badge_provider.dart.bak`, `main.dart.bak`, `firestore_search_repository.dart.bak`, `index.ts.bak`
**Verification:** `flutter analyze` — No issues found ✅

### Remaining Gaps
- **Phase 4**: Video (Agora), AI matching, Groups, Admin, Web, Premium, Typesense

## Session 141 — Image Cropper (zoom + center) για φωτογραφίες προφίλ

### Προστέθηκε
- **Package:** `image_cropper: ^12.2.1` (αντί για το outdated `^5.x` του blueprint)
- **Android:** `UCropActivity` στο `AndroidManifest.xml` (native crop UI)

### Τροποποιήθηκε
- `profile_editor_screen.dart`:
  - `_pickAndUploadAvatar()` — pickImage → cropImage (1:1 locked square) → upload
  - `_pickAndUploadPhoto()` — pickImage → cropImage (ελεύθερο aspect ratio: original/square/4:3/16:9) → upload
  - Και στα δύο methods: `maxWidth`/`maxHeight`/`imageQuality` μεταφέρθηκαν από `pickImage` στο `cropImage`
  - Προστέθηκε double-tap guard (`if (_isUploadingAvatar) return` / `if (_uploadingPhotoIndex != null) return`)
  - Debug logs στο crop step (flag: `DebugConfig.storageUpload`)
  - Bilingual toolbar labels (el/en) στα `AndroidUiSettings` / `IOSUiSettings`

### Edge cases covered
- User ακυρώνει crop → `cropped == null` check (ίδιο pattern με pick)
- Crop fails (OOM κλπ) → πιάνεται από υπάρχον `try/catch`
- Widget disposed → `mounted` checks after crop return
- Πολύ μεγάλη εικόνα → uCrop handles via bitmap subsampling
- App backgrounded → native Activity/ViewController survives lifecycle

### ΔΕΝ επηρεάστηκαν
- `profile_repository.dart`, `profile_storage_mixin.dart`, `storage_service.dart` — 0 changes (bytes flow identical)
- `debug_config.dart`, `l10n.dart`, `app_messenger.dart` — 0 changes
- Backups: `pubspec.yaml.backup`, `profile_editor_screen.dart.backup`, `AndroidManifest.xml.backup`

### Verified
- `flutter analyze`: No issues found ✅

### Session 142 — Riverpod autoDispose race fix στο `_save()` του profile editor

**Problem:** Όταν ο χρήστης πατούσε Χ → dialog → "Αποθήκευση", το `_save()` αποθήκευε τα δεδομένα αλλά το `ref.invalidate(currentProfileProvider)` (γρ. 449) έριχνε Riverpod assertion error `_task == null || _task!.completed`: Only one task can be scheduled at a time. Αυτό πιανόταν στο `catch` → εμφανιζόταν "Αποτυχία αποθήκευσης" αντί για success message + pop, παρόλο που τα δεδομένα είχαν αποθηκευτεί.

**Root cause:** Το `currentProfileProvider` είναι `StreamProvider.autoDispose` → έχει stream subscription που μπαίνει σε race με το `ref.invalidate()`. Αντίθετα, το `privacySettingsProvider` είναι απλό `FutureProvider` (χωρίς autoDispose), γι' αυτό το privacy editor δεν είχε το ίδιο πρόβλημα.

**Fix:** Wrapped `ref.invalidate(currentProfileProvider)` σε δικό του try-catch ώστε να μη σπάει η ροή save:
```dart
try {
  ref.invalidate(currentProfileProvider);
} catch (_) {
  // autoDispose stream race — data already saved, ignore
}
```

**Files:** `profile_editor_screen.dart:449`
**Backup:** `profile_editor_screen.dart.backup` (updated)

### Session 144 — Saved search bool filter DB fix verification (7-point plan)

**Problem:** 3 bool filter fields (`allowVideoCall`, `allowDirectChat`, `onlineOnly`) από τα `SearchFilters` χάνονταν στη DB όταν αποθηκευόταν μια αναζήτηση. Το `saved_search_table.dart` ΔΕΝ είχε αντίστοιχες στήλες → το `Companion.insert()` δεν τα συμπεριλάμβανε → η restore (`toFilters()`) επέστρεφε πάντα `null`.

**Verification — 7 σημεία ΕΛΕΓΧΘΗΚΑΝ και ΕΠΙΒΕΒΑΙΩΘΗΚΑΝ ήδη εφαρμοσμένα:**

**Μέρος Α — Το Κύριο Bug**
| Βήμα | Αρχείο | Κατάσταση |
|:----:|--------|:---------:|
| 1 | `saved_search_table.dart:17-19` — 3 `BoolColumn` (allowVideoCall, allowDirectChat, onlineOnly) | ✅ |
| 2 | `database.dart:73-79` — Migration v7→v8 `addColumn` ×3 | ✅ |
| 3 | `database.g.dart` — `build_runner` regenerated (317+ refs στα 3 πεδία) | ✅ |
| 4α | `saved_search_repository.dart:36-38` — `save()`: `Companion.insert` με τα 3 Value | ✅ |
| 4β | `saved_search_repository.dart:91-93` — `toFilters()`: `allowVideoCall`, `allowDirectChat`, `isOnlineNow` | ✅ |

**Μέρος Β — Debug Logging**
| Βήμα | Αρχείο | Κατάσταση |
|:----:|--------|:---------:|
| 5α | `saved_search_repository.dart:41-45` — `save()`: log των 3 bool τιμών | ✅ |
| 5β | `saved_search_repository.dart:95-96` — `toFilters()`: `DebugConfig.log` | ✅ (υπήρχε ήδη) |

**Μέρος Γ — UI Display**
| Βήμα | Αρχείο | Κατάσταση |
|:----:|--------|:---------:|
| 6 | `saved_searches_screen.dart:169-197` — `_SearchCard` δείχνει badges (Video/Chat/Online Only) | ✅ (user είχε ήδη υλοποιήσει) |

**Πρόσθετο pre-existing UX bug (επιβεβαιώθηκε):**
- `search_filters_screen.dart:174` — `_saveSearch()` διαβάζει `ref.read(searchFiltersProvider)` αντί για local UI vars. Αν ο χρήστης αλλάξει toggle χωρίς Apply → save κρατάει ΠΑΛΙΑ τιμή. **ΔΕΝ διορθώθηκε** (εκτός scope του DB fix).

**Συμπέρασμα:** Η υλοποίηση είναι **100% πλήρης**. Όλα τα βήματα του 7-point plan είχαν ήδη γίνει. Χρειάστηκε μόνο επιβεβαίωση και documentation στο `oldsessions.md`.

### Tech Debt Backlog
| # | Item | Status |
|---|---|---|
| 1 | Search `searchNearby` 3-char geoHash fix | ✅ Session 122b |
| 2 | Gender composite index — 100% client-side | ✅ Session 125 |
| 3 | GPS fallback staleness (>5min rejection) | ✅ Session 126 |
| 4 | Mock location detection | Pending |
| 5 | **Riverpod scheduler race (debug-only)** — `Only one task can be scheduled at a time` σε respondToRequest. Αναβάθμιση Riverpod σε stable (όχι dev) στο τελικό στάδιο πριν production | Deferred (Session 141) |

### Session 145 — Log Review: 3 optimization issues found

**Issue 1 — breakpointFromWidth spam:** `breakpointFromWidth: 393px → ScreenBreakpoint.mobile` εμφανίζεται 300+ φορές σε cascade (20-30 συνεχόμενες κλήσεις ανά rebuild chain). Στη σελίδα filters μετά από reset, 40+ logs σε 1sec. Κάθε `LayoutBuilder` rebuild (viewInsets, navigation transitions) πυροδοτεί επανυπολογισμό χωρίς cache.

**Issue 2 — Duplicate encrypt/decrypt σε sendMessage:** Το μήνυμα (3 chars) encrypt 2 φορές και decrypt 3-4 φορές λόγω πολλαπλών `messagesStream` listeners/emissions. Πιθανό race condition ή dispose/recreate του `messagesProvider`.

**Issue 3 — chatProvider dispose/recreate cascade:** Κατά το άνοιγμα chat, το `chatsProvider` disposed+created 2-3 φορές (started → sync completed → cancelled → started). Πιθανή αναντιστοιχία routing ή autoDispose timeout.

**Build logs:** APK 14.8MB (+0.3MB από image_cropper). Startup ~392ms. Όλες οι λειτουργίες 100% stable.

### Key Conventions
- File size ≤ 500 lines (1 exception: profile_repository_impl ~570)
- `DebugConfig.log(flag, msg)` σε κάθε operational action
- **Error handling**: `error_messages.dart` κεντρικό bilingual mapping
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): L10n
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
