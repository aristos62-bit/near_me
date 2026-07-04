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

## Current State

| Μέτρο | Τιμή |
|---|---|
| Completion | ~99.9% (Phases 1-3 100%) |
| Firestore indexes | 17 composite deployed |
| Build | `flutter analyze` clean, release APK ~14.5MB |
| Tests | **30/30 passed** |
| `.dart` files | ~108 (non-generated) |
| Cloud Functions | 5 deployed (3 FCM + auto-ban + deleteUserData) |

### Known Issues
- `authStateProvider` first emission `null` κατά την 1η `watch()` — ProfileScreen βλέπει `canComm=false (null user)` για 1 frame πριν το `userChanges()` emit. ChatListScreen έχει fallback `?? FirebaseAuth.instance.currentUser`. ProfileScreen + ChatScreen ΔΕΝ έχουν — low priority (1 frame flash).

### Remaining Gaps
- **Phase 4**: Video (Agora), AI matching, Groups, Admin, Web, Premium, Typesense

### Tech Debt Backlog
| # | Item | Status |
|---|---|---|
| 1 | Search `searchNearby` 3-char geoHash fix | ✅ Session 122b |
| 2 | Gender composite index — 100% client-side | ✅ Session 125 |
| 3 | GPS fallback staleness (>5min rejection) | ✅ Session 126 |
| 4 | Mock location detection | Pending |

### Key Conventions
- File size ≤ 500 lines (1 exception: profile_repository_impl ~570)
- `DebugConfig.log(flag, msg)` σε κάθε operational action
- **Error handling**: `error_messages.dart` κεντρικό bilingual mapping
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): L10n
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
