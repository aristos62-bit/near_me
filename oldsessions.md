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
Comm settings cleanup, Chat rebuild loop fix, Auto-publish, Request validation (4-layer), Feature Flags (8), Biometric Lock, Typesense stub, GoRouter errorBuilder, PresenceService race fix, `showPhotos` privacy toggle, Schema v3→v6, Country field, Null-overwrite fix, Unit tests (30), Phone verification, `isPhoneVerified` fix, SettingsScreen cascade rebuild fix, Unlink phone + stale cache, `isOnline` overwrite fix, Country filter + GPS-first location + auto-publish, City auto-fill + Nominatim + `isManualLocation`, Distance filter analysis.

### Search Overhaul & Polish (Sessions 100-131)
Search fixes: `hasLocationFilter` flag, `WHERE country` server-side, parallel geo queries per cell, Haversine distance, cell BOUNDS fix, stale lat/lng refresh, distance display, Hybrid edge/center distance, Adaptive search precision, `getNeighbours` `*2` bug, default radius selector, `searchNearby` 3-char fix, `searchNearby→search` in auto-search.

Auth & Security: Registration UX redirect, X button crash fix, stale `emailVerified` fix, canUserCommunicate 5-layer guard, Firestore rules deploy.

KeyStore fix: `getKeyOrDerive(chatId)` — try storage → fallback deriveKey() → bilingual placeholder for unreadable messages.

Other: Gender 100% client-side, GPS staleness fix, Error Messages Centralization, MediaQuery cascade fix (MainShell + ProfileScreen + DiscoveryScreen), FCM foreground fix, ChatScreen 3-way split rebuild fix, Scroll spam fix, ChatListScreen flash fix, request_repository defense-in-depth, idleTimer log spam fix.

### Session 132 — `userChanges()` fix
`authStateProvider` χρησιμοποιούσε `authStateChanges()` (εκπέμπει μόνο sign-in/out). Από `reload()`, το `emailVerified=true` δεν εκπεμπόταν ποτέ. Fix: `FirebaseAuth.instance.userChanges()`.

### Session 133 — Firestore null cast fix
Legacy Firestore docs missing `uid` → crash. Fix: `_safePublicProfileFromJson()` helper — validates `uid` before `fromJson()`.

### Session 134 — ChatScreen crash + raw AlertDialog→AppMessenger
- `GoRouterState.of(context)` σε `initState` → crash (πρέπει mounted). Fix: μεταφορά σε `didChangeDependencies()`.
- Raw `AlertDialog` → νέα `AppMessenger.showInfoDialog()`.

### Session 135 — Biometric lock bypass via FCM notification tap
Notification tap while locked bypassed biometric. Fix: `FcmService.isLocked` flag mirroring lock state. If locked, store path to `_pendingFcmPath` and push after unlock via `tryExecutePendingNav()`.

### Session 136 — FCM navigation to chat after unlock (full rewrite)
Δύο root causes: (1) `context.push()` outside GoRouter widget tree, (2) `isLocked` set too late. Fix: deleted `checkPendingNavigation()`, set `isLocked` before `await authenticate()`, use `tryExecutePendingNav()` after success.

### Session 137 — ProfileCards rebuild fix
ProfileCards ~20× rebuilds from layout cascade. Fix: `ValueKey(p.uid)` + `select()` αντί `listen+setState` + extract `SearchResultsGrid` to separate widget.

### Session 138 — Retry mechanism for FCM Cloud Functions
3 FCM CFs lacked retry on transient failures. Fix: new `fcm-utils.ts` with exponential backoff (1s→2s→4s), 3 retries for retryable codes.

### Session 139 — Unread tracking + FCM deep link για requests
- New `readAt` Firestore field, `markRequestAsSeen()`, `unreadRequestsProvider`.
- Unread visual: μπλε κουκκίδα + bold text. Profile badge with count.
- FCM deep link `/requests/:requestId`.
- Widget extraction: `request_card_widgets.dart` (343 lines).

### Session 140 — RenderFlex overflow fixes (discovery + delete account)
`Center > Padding > Column(mainAxisSize: Min)` χωρίς scroll → overflow. Fix: `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox`.

### Session 141 — Image Cropper για φωτογραφίες προφίλ
`image_cropper: ^12.2.1`. 1:1 locked square για avatar, ελεύθερο aspect ratio για photos.

### Session 142 — Riverpod autoDispose race στο `_save()`
`ref.invalidate(currentProfileProvider)` (autoDispose stream) → race. Fix: try-catch γύρω από το invalidate.

### Session 143 — L2 badge iOS + L4 locale fallback + Firestore city-filter crash
- L2: `FcmService.setBadge(count)` + `unreadBadgeProvider` for iOS app icon badge.
- L4: Cloud Functions locale fallback `?? 'el'` → `?? 'en'`.
- City-filter Firestore crash (P0): `_generalSearch()` age range + `orderBy('__name__')` χωρίς `orderBy('age')` → `INVALID_ARGUMENT`. Fix: remove age `where()` clauses, filter client-side via `_passesFilters()`.

### Session 144 — Saved search bool filter DB fix (7-point verification)
3 bool columns (`allowVideoCall`, `allowDirectChat`, `onlineOnly`) missing from `SavedSearchTable`. Fix: schema migration v7→v8, add columns + `Companion.insert` + `toFilters()`.

### Session 145 — Log Review: 3 optimization issues found
(1) breakpointFromWidth spam 300+ logs, (2) duplicate encrypt/decrypt σε sendMessage, (3) chatProvider dispose/recreate cascade.

### Session 146 — Breakpoint spam fix: cache + constraint-based responsive
Log cache (μόνο όταν width αλλάζει) + 16/16 files migrated from `MediaQuery.of(context)` to `LayoutBuilder` constraint-based helpers. Backups cleaned: 43 files deleted.

### Session 147 — `_saveSearch()` stale state fix + Session 147b: Duplicate Encrypt/Decrypt
- Save search: χρήση local UI vars αντί provider (prevent stale state).
- Duplicate encrypt/decrypt: (A) reuse encrypted string, (B) encrypt/decrypt cache, (Γ) remove `ref.invalidate(chatsProvider)` from `markAsRead()`.

### Session 148a — RenderFlex overflow fix (request_card_widgets)
Row με Spacer + chips → overflow 3.5px. Fix: `Row` → `Wrap`.

### Session 148β — Auto-scroll to last message on chat open
`_isFirstLoad` flag: `jumpTo(maxScroll)` στο πρώτο load, animation μόνο για νέα μηνύματα.

### Session 149 — Auto-search after reset filters
`_reset()` → preserve GPS, reset filters, restore GPS + auto-search. Without GPS → `clearResults()`.

### Session 150 — 3 fixes: saved search apply + city+radius combo + GPS refresh
- `saved_search_provider.dart`: `apply()` async, `updateCountry()`, GPS refresh.
- `saved_searches_screen.dart`: async onTap + mounted guard.
- `firestore_search_repository.dart`: city+radius → `_geoSearch` (όχι `_generalSearch`).

### Session 151 — PERMISSION_DENIED fix: Firestore listeners μετά από signOut
**Πρόβλημα:** 6× συνεχόμενα PERMISSION_DENIED μετά από signOut (4× userStatus + 1× requests + 1× chats). Οι Firestore listeners παρέμεναν ζωντανοί μετά την ακύρωση του auth token.
**Blocker:** `main.dart:336 ref.listen(unreadBadgeProvider, ...)` κρατούσε ζωντανή την αλυσίδα providers (κανένα autoDispose δεν αποδεσμευόταν).
**Λύση (3 επίπεδα):** (1) Static `isSigningOut` flag στο `AuthRepository` interface — set `true` πρώτο στο `signOut()`. Guards σε `streamChats()`, `streamIncomingRequests()`, `streamOutgoingRequests()`. (2) `userStatusProvider` → `StreamProvider.autoDispose.family` + `handleError()`. (3) Provider invalidation στο `settings_screen.dart:_signOut()` πριν την κλήση signOut.
**Αρχεία:** `auth_repository.dart`, `auth_repository_impl.dart`, `chat_repository_impl.dart`, `request_repository_impl.dart`, `status_provider.dart`, `settings_screen.dart`.
**Νέο αρχείο:** `PERMISSION_DENIED.md` — πλήρης τεκμηρίωση.

## Current State

| Μέτρο | Τιμή |
|---|---|
| Completion | ~99.9% (Phases 1-3 100%) |
| Firestore indexes | 17 composite deployed |
| Build | `flutter analyze` clean, release APK ~14.5MB |
| Tests | **30/30 passed** |
| `.dart` files | ~109 (non-generated) |
| Cloud Functions | 5 deployed + `fcm-utils.ts` helper |
| Unread tracking requests + FCM deep link | ✅ Session 139 |
| RenderFlex overflow fixes (discovery + delete + request_card) | ✅ Sessions 140, 148a |
| Badge count iOS + locale fallback + city-filter crash | ✅ Session 143 |
| Breakpoint spam fix (cache + constraint-based) | ✅ Session 146 |
| Duplicate encrypt/decrypt (3 fixes) | ✅ Session 147b |
| Auto-scroll to last message | ✅ Session 148β |
| Auto-search after reset filters | ✅ Session 149 |
| Saved search apply + city+radius combo + GPS refresh | ✅ Session 150 |
| PERMISSION_DENIED after signOut (6× listeners) | ✅ Session 151 |

### Remaining Gaps
- **Phase 4**: Video (Agora), AI matching, Groups, Admin, Web, Premium, Typesense
- Mock location detection (Pending)

### Tech Debt
- Riverpod scheduler race (debug-only) — `Only one task can be scheduled at a time` σε respondToRequest. Deferred.

## Key Conventions
- File size ≤ 500 lines (exceptions: profile_repository_impl ~570, chat_repository_impl ~590 with user permission)
- `DebugConfig.log(flag, msg)` σε κάθε operational action
- **Error handling**: `error_messages.dart` κεντρικό bilingual mapping
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): L10n
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
