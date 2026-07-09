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
| 24 | **Biometric idle timer runs on `inactive`** — notification shade, phone call | Handle `AppLifecycleState.inactive` alongside `paused` — stop timer |
| 25 | **Idle timer active after sign-out** — LockScreen over welcome screen | `ref.listen(authStateProvider)` — stop timer + reset `_isLocked=false` |
| 26 | **Chat disappears from list after create** — `_saveChatCache` duplicate → cleanup UPDATE 0 rows | Remove `_saveChatCache` root cause + `var rows`/`rows=[]` defense-in-depth |

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

### Session 152 — P1.3 Biometric Idle Timer Lifecycle fix (inactive + sign-out)
**Πρόβλημα:** Δύο bugs: (1) Το `didChangeAppLifecycleState` αγνοούσε το `AppLifecycleState.inactive` (notification shade, τηλεφώνημα) — ο timer συνέχιζε να μετράει. (2) Μετά από sign-out, ο idle timer στο `_NearMeAppState` δεν σταματούσε — μπορούσε να εμφανίσει LockScreen πάνω από το welcome screen.
**Λύση:** (1) `AppLifecycleState.inactive` δίπλα στο `paused` — stop timer + `_lastPauseTime`. (2) `ref.listen(authStateProvider, ...)` στο build — όταν user→null, `_stopIdleTimer()` + reset `_isLocked=false`.
**Αρχεία:** `lib/main.dart` (import + lifecycle handler + build method listener)
**P1_3.md:** created — full analysis and fix documentation

## Session 153 — ChatCache duplicate bug fix (_syncChatFromFirestore + _updateChatCache)
**Πρόβλημα:** Σε createChat, το `_saveChatCache()` δημιουργούσε duplicate row (local Firestore cache) · το `_syncChatFromFirestore` έβρισκε 2 rows, τα διέγραφε, αλλά `final rows` κρατούσε old reference → UPDATE σε 0 rows · chat εξαφανιζόταν από τη λίστα.

**Λύση (3 αλλαγές):** (1) Αφαίρεση `_saveChatCache()` από `createChat()` + διαγραφή μεθόδου. (2-3) `final rows` → `var rows`, `rows = []` μετά delete.

**Αρχεία:** `chat_repository_impl.dart`  
**Verified:** 8/7/2026 — dual device ✅

## Session 154 — P1.1, P2.1 & P2.2 verification audit
- **P1.1**: ✅ **Fixed ήδη.** `_onRefresh` (discovery_screen.dart:187) καλεί `_performSearch` **μία φορά**. `_performSearch` (γραμμή 74) κάνει `await _checkConnectivity()` πριν προχωρήσει. Δεν υπάρχει duplicate search issue. Δεν χρειάζεται αλλαγή.
- **P2.1**: ✅ **Fixed ήδη.** Επαληθεύτηκε στον κώδικα: (1) `chat_provider.dart` — `chatsProvider` ΔΕΝ έχει `ref.watch(authStateProvider)`. (2) `settings_screen.dart` — ΔΕΝ έχει `ref.invalidate(chatsProvider)`. (3) `main.dart` — υπάρχει ήδη ο authStateProvider listener με uidChanged + emailVerifiedChanged guard + `ref.invalidate(chatsProvider)`. Συμφωνεί πλήρως με το σχέδιο του `P2_1.md`. **Δεν χρειάζεται αλλαγή.**
- **P2.2**: ✅ **Fixed ήδη.** Πλήρης ροή: `sendPhoneOtp()` (FirebaseAuth.verifyPhoneNumber με 4 callbacks, 60s timeout), `verifyOtp()` (PhoneAuthProvider.credential + linkWithCredential + reload), `isPhoneVerified`, `canUserCommunicate` με `|| hasPhone`. Provider με 6 states, Screen με phone→OTP→verify→success UI. **Δεν χρειάζεται αλλαγή.**

## Session 155 — P3.1 Online Status Flicker Fix
**Πρόβλημα:** Τα `ProfileCard` έκαναν render 2 φορές: (1) `isOnline=false` (stream null), (2) ~300ms μετά `isOnline=true` — οπτικό flicker.

**Λύση:** Null-coalescing fallback: `final isOnline = streamOnline ?? profile.isOnline;`
- `streamOnline` = από `userStatusProvider` (stream, ~300ms delay)
- `profile.isOnline` = από το public profile snapshot (διαθέσιμο αμέσως, γιατί η `PresenceService` γράφει `isOnline` απευθείας στο public doc)
- Εφαρμόστηκε και στο `PublicProfileHeader` (ίδιο pattern)

**Verified:** 9/7/2026 — logs: `isOnline=true (stream=null profile=true)` → `isOnline=true (stream=true profile=true)`. Zero flicker ✅

**Αρχεία:** `profile_card.dart` (γραμμή 28-30), `public_profile_header.dart` (γραμμή 29-31)

---

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
| P1.3 Biometric Idle Timer Lifecycle (inactive + sign-out) | ✅ Session 152 |
| ChatCache duplicate bug (_saveChatCache + final rows) | ✅ Session 153 |
| P1.1 Duplicate search on refresh — already fixed | ✅ Session 154 — verified στον κώδικα |
| P2.1 Provider cascade (debounce auth state) — already fixed | ✅ Session 154 — verified στον κώδικα, συμφωνεί με P2_1.md |
| P2.2 Phone verification (SMS OTP) — already fixed | ✅ Session 154 — verified: sendOtp→verifyOtp→isPhoneVerified→canUserCommunicate |
| P3.1 Online Status Flicker (null-coalescing fallback) | ✅ Session 155 — logs: zero flicker |

### Remaining Gaps
- **Phase 4**: Video (Agora), AI matching, Groups, Admin, Web, Premium, Typesense
- Mock location detection (Pending)

### Tech Debt
- Riverpod scheduler race (debug-only) — `Only one task can be scheduled at a time` σε respondToRequest. Deferred.

---

## Αναλυτική Παρουσίαση 9 Βελτιώσεων

### P1 — Διόρθωση Διπλού Search on Refresh (`_checkConnectivity` bypass)
**Αρχεία:** `lib/features/discovery/providers/search_provider.dart`

**Περιγραφή:** Στο `_onRefresh`, το `_performSearch` καλείται 2 φορές:
1. Από `getCurrentLocation()` → `_performSearch()` (μέσα στη ροή GPS)
2. Από `_onRefresh` → απευθείας `_performSearch()`

Επιπλέον, το `_checkConnectivity` **δεν γίνεται await** — η αναζήτηση τρέχει ακόμα και όταν ο χρήστης είναι offline, με αποτέλεσμα Firestore errors.

**Επίπτωση:** Διπλάσιος Firestore read cost, περιττά network requests, πιθανά errors όταν offline.

**Λύση:**
1. `await _checkConnectivity()` στην αρχή του refresh — αν offline, `setState(SearchState.error(…))` και return
2. Αφαίρεση της διπλής κλήσης `_performSearch()` — μία διαδρομή είτε από GPS callback είτε απευθείας

**Κρισιμότητα:** P1 — επηρεάζει χρέωση Firestore και user experience όταν offline

---

### ✅ P1.2 — Request Delete UI Race — **FIXED**
**Αρχεία:** `lib/features/requests/screens/requests_dashboard_screen.dart`

**Περιγραφή:** Το `deleteRequest()` ακολουθείται από `_exitSelectionMode()` ΠΡΙΝ προλάβει να κάνει propagate το stream του Firestore. Το UI για μια στιγμή δείχνει stale data (το διαγραμμένο request παραμένει ορατό).

**Επίπτωση:** Οπτικό flicker, σύγχυση χρήστη.

**Λύση:** `ref.invalidate()` πριν από `_exitSelectionMode()` + `Future.microtask` delay + partial failure handling + enhanced debug logging.

**Verified:** 7/7/2026 — log sequence `delete→invalidate→exitSelection→showSuccess`, clean analyze

---

### ✅ P1.3 — Biometric Idle Timer Lifecycle Gap — **FIXED (Session 152)**
**Αρχεία:** `lib/main.dart`

**Περιγραφή:** Δύο bugs: (1) `inactive` state (notification shade, τηλεφώνημα) δεν σταματούσε τον idle timer. (2) Sign-out δεν σταματούσε τον timer — LockScreen εμφανιζόταν πάνω από welcome screen.

**Επίπτωση:** Πιθανός auto-lock ενώ ο χρήστης κοιτάει ειδοποιήσεις, LockScreen μετά από sign-out.

**Λύση:**
1. `AppLifecycleState.inactive` δίπλα στο `paused` — stop timer + `_lastPauseTime`
2. `ref.listen(authStateProvider, ...)` στο build — stop timer + reset `_isLocked=false` σε sign-out

**Verified:** 7/7/2026 — logs επιβεβαιώνουν `inactive→stop`, `sign-out→stop`, `paused→stop`, `short pause skip biometric`, `timeout→lock`

---

### P2 — Provider Cascade (Διπλό create/dispose σε auth change)
**Αρχεία:** `lib/features/chat/providers/chat_provider.dart`, `lib/features/auth/providers/auth_provider.dart`

**Περιγραφή:** Σε κάθε auth state change (sign-in), το `chatsProvider` κάνει dispose + create 2-3 φορές:
```
chatsProvider disposed
chatsProvider created (StreamProvider)
streamChats: started
streamChats: cancelled
chatsProvider disposed
chatsProvider created (StreamProvider)
streamChats: started
```

Αυτό συμβαίνει γιατί το `authStateProvider` εκπέμπει πολλαπλά events:
1. `uid=null` (κατά τη μετάβαση)
2. `uid=scIChf…` (τελικό)

Κάθε φορά, δημιουργείται νέο Firestore stream listener.

**Επίπτωση:** 2-3× περιττά Firestore reads (αυξάνει κόστος), περιττά UI rebuilds.

**Λύση:** Debounce ή buffer στο auth state πριν την αντίδραση providers. Εναλλακτικά: skip first null event με `skip(1)` ή `distinct()`.

**Κρισιμότητα:** P2 — δεν επηρεάζει UX αλλά αυξάνει Firestore read cost

---

### ✅ P2 — Ολοκλήρωση Phone Verification (SMS OTP) — **FIXED**
**Αρχεία:** `lib/features/auth/providers/phone_verify_provider.dart`, `lib/features/auth/screens/phone_verify_screen.dart`

**Περιγραφή:** Ο χρήστης (`scIChf…`) είχε `hasPhone=false`. Μπήκε στην οθόνη phone verification αλλά ΔΕΝ ολοκλήρωσε το SMS OTP flow.

**Λύση:** `sendPhoneOtp()` (FirebaseAuth.verifyPhoneNumber, 4 callbacks, 60s timeout), `verifyOtp()` (PhoneAuthProvider.credential + linkWithCredential + reload), `isPhoneVerified`, `canUserCommunicate` με `|| hasPhone`. Provider με 6 states, Screen με phone→OTP→verify→success UI.

**Verified:** 9/7/2026 — Session 154 audit: πλήρης ροή στον κώδικα ✅

**Κρισιμότητα:** P2 — λειτουργικό έλλειμμα, δεν μπλοκάρει άλλες λειτουργίες

---

### ✅ P3.1 — Online Status Flicker στα ProfileCards — **FIXED (Session 155)**
**Αρχεία:** `lib/shared/widgets/profile_card.dart`, `lib/features/discovery/widgets/public_profile_header.dart`

**Περιγραφή:** Τα `ProfileCard` κάνουν render 2 φορές:
1. Αρχικό render με `isOnline=false` (stream=null fallback)
2. Μετά από ~300ms, render με `isOnline=true` (σωστό status)

Αυτό συμβαίνει γιατί το `userStatus` stream family κάνει fetch από Firestore μετά το αρχικό build.

**Επίπτωση:** Οπτικό flicker — η πράσινη κουκκίδα εμφανίζεται με καθυστέρηση.

**Λύση:** Null-coalescing fallback: `final isOnline = streamOnline ?? profile.isOnline;`
- `streamOnline` = από `userStatusProvider` (stream, ~300ms καθυστέρηση)
- `profile.isOnline` = από το public profile snapshot (διαθέσιμο αμέσως, γιατί η `PresenceService` γράφει το `isOnline` απευθείας στο public doc)
- Το `isOnline` από το Firestore snapshot λειτουργεί ως fallback μέχρι να έρθει το stream

**Verified:** 9/7/2026 — logs επιβεβαιώνουν: `isOnline=true (stream=null profile=true)` στο πρώτο render → `isOnline=true (stream=true profile=true)` μετά το stream. Κανένα flicker. ✅

**Κρισιμότητα:** P3 — αισθητικό, δεν επηρεάζει λειτουργικότητα

---

### P3 — Haversine Memoization για ίδιο geoHash
**Αρχεία:** `lib/repositories/firestore_search_repository.dart`

**Περιγραφή:** Για κάθε profile στη λίστα αποτελεσμάτων, υπολογίζεται `distanceToNearestEdge()` με Haversine. Όταν πολλά profiles μοιράζονται το ίδιο geoHash cell, ο υπολογισμός γίνεται από την αρχή για κάθε profile.

Για 300 profiles (cap): ~1200 Haversine calls (300 × 4 neighbors).

**Λύση:** Cache/memoization: `Map<String, double> _edgeDistanceCache` κλειδί = `geohash+lat+lng`. Αν το ίδιο geoHash έχει ήδη υπολογιστεί, επιστροφή cached τιμής.

**Κρισιμότητα:** P3 — optimization, όχι bug

---

### P4 — ConsentLog Pagination
**Αρχεία:** `lib/features/profile/screens/consent_log_screen.dart`, `lib/data/local/database.dart` (ConsentLogTable)

**Περιγραφή:** Αυτή τη στιγμή υπάρχουν 116 entries στο ConsentLog. Φορτώνονται όλα μαζί σε ένα Drift query. Καθώς ο αριθμός μεγαλώνει (π.χ. 1000+ entries), η αρχική φόρτωση θα γίνεται πιο αργή και η λίστα θα είναι δύσχρηστη.

**Λύση:** Pagination με Drift `LIMIT 50 OFFSET ?` + load more button / infinite scroll.

**Κρισιμότητα:** P4 — προληπτικό, δεν αποτελεί πρόβλημα ακόμα

---

## Πίνακας Προτεραιοτήτων

| # | Priority | Θέμα | Τύπος | Αρχείο |
|---|:--------:|------|:-----:|--------|
| # | Priority | Θέμα | Τύπος | Αρχείο | Status |
|---|:--------:|------|:-----:|--------|:------:|
| 1 | **✅ P1** | Διπλό search on refresh (`_checkConnectivity` bypass) | Bug | `search_provider.dart` | ✅ Fixed |
| 2 | **✅ P1** | `_checkConnectivity` — skip αν offline | Bug | `search_provider.dart` | ✅ Fixed |
| 3 | **✅ P1.2** | Requested delete UI race — wait for stream propagation | Bug | `requests_dashboard_screen.dart` | ✅ Fixed |
| 4 | **✅ P1.3** | Biometric idle timer lifecycle gap (inbox + sign-out) | Bug | `main.dart` | ✅ Fixed |
| 5 | **✅ P2** | Provider cascade (διπλό create/dispose σε auth change) | Optimization | `chat_provider.dart` | ✅ Fixed |
| 6 | **✅ P2** | Ολοκλήρωση phone verification (SMS OTP) | Feature gap | `phone_verify_provider.dart` | ✅ Fixed |
| 7 | **✅ P3.1** | Online status flicker στα ProfileCards | UX polish | `profile_card.dart` | ✅ Fixed |
| 8 | **P3.2** | Haversine memoization για ίδιο geoHash | Performance | `firestore_search_repository.dart` | |
| 9 | **P4** | ConsentLog pagination | Scalability | `consent_log_screen.dart` | |

---

## Σειρά Εκτέλεσης (Work Plan)

1. **✅ P1.1** — `_checkConnectivity` bypass + duplicate `_performSearch` — verified fixed
2. **✅ P1.2** — Request delete UI race — fixed
3. **✅ P1.3** — Biometric idle timer lifecycle — fixed (Session 152)
4. **✅ P2.1** — Provider cascade (debounce auth state) — verified fixed
5. **✅ P2.2** — Phone verification (SMS OTP) — verified fixed
6. **✅ P3.1** — Fix online status flicker (null-coalescing `streamOnline ?? profile.isOnline`) — **Fixed Session 155**
7. **P3.2** — Haversine memoization για ίδιο geoHash
8. **P4.1** — ConsentLog pagination

> Εκτελούμε **μία βελτίωση τη φορά**. Μετά από κάθε αλλαγή: backup → edit → `flutter analyze` → έλεγχος από τον χρήστη → "επόμενο".

## Key Conventions
- File size ≤ 500 lines (exceptions: profile_repository_impl ~570, chat_repository_impl ~590 with user permission)
- `DebugConfig.log(flag, msg)` σε κάθε operational action
- **Error handling**: `error_messages.dart` κεντρικό bilingual mapping
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): L10n
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
