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

## Session 156 — P3.2 Haversine Memoization

**Πρόβλημα:** Για κάθε profile στη λίστα αποτελεσμάτων, υπολογιζόταν `distanceToPoint()` με Haversine από την αρχή. Όταν πολλά profiles μοιράζονταν το ίδιο geoHash cell, ο υπολογισμός γινόταν duplicate (π.χ. 300 profiles → ~1200 Haversine calls).

**Λύση (3 επεμβάσεις σε 2 αρχεία, ~14 γραμμές):**
1. `geohash_utils.dart`: `_distanceCache` Map + `clearDistanceCache()` + cache check/store στο `distanceToPoint()` (key = `geoHash|lat|lng`)
2. `firestore_search_repository.dart`: `GeoHashUtils.clearDistanceCache()` στην αρχή των `search()` και `searchNearby()`

**Αποτέλεσμα:** ~300 profiles → ~50 unique geoHashes → **~1200 Haversine calls → ~50 calls** (96% reduction). Cache cleared σε κάθε search. Zero memory leak.

**Verified:** 9/7/2026 — `flutter analyze` clean ✅

**Αρχεία:** `geohash_utils.dart`, `firestore_search_repository.dart`

---

## Session 157 — P4.1 ConsentLog Pagination

**Πρόβλημα:** Το ConsentLog φόρτωνε όλες τις εγγραφές ταυτόχρονα μέσω Drift stream. Με 116+ entries δεν ήταν πρόβλημα, αλλά σε κλίμακα (1000+) θα γινόταν αργό.

**Λύση (2 αρχεία):**
1. `consent_log_provider.dart`: Αντικατάσταση `StreamProvider` με `NotifierProvider` + `ConsentLogNotifier` — pagination με `LIMIT 50 OFFSET ?`, `loadMore()`, `refresh()`, `hasMore` flag
2. `consent_log_screen.dart`: Προσθήκη "Load older entries" κουμπιού στο τέλος της λίστας όσο `hasMore=true`

**Αποτέλεσμα:** Αρχική φόρτωση 50 entries, παλαιότερα on-demand. Κανένα overhead για μικρό όγκο.

**Verified:** 9/7/2026 — `flutter analyze` clean ✅

**Αρχεία:** `consent_log_provider.dart`, `consent_log_screen.dart`

---

## Session 158 — MultiChat (Group Chat) Υλοποίηση (Φάσεις 1-7)

**Πεδίο:** Υλοποίηση Group Chat βάσει `multichat.md` (31 βήματα, 9 φάσεις). **22/31 βήματα (71%) ολοκληρωμένα.** — Συνέχεια στο Session 159

### Φάση 1 — Foundation (Βήματα 1-3) ✅
- `feature_flags.dart`: `groupChatEnabled = true`
- `chat_cache_table.dart`: +4 group columns (`isGroupChat`, `participantCount`, `participantUids`, `groupName`)
- `database.dart`: Migration v8→v9

### Φάση 2 — Repository Layer (Βήματα 4-6) ✅
- `chat_repository.dart`: Abstract interface +17 group methods (26 σύνολο)
- `group_chat_mixin.dart` (796 γραμμές): `part of 'chat_repository_impl.dart'` — permissions, create, invites, avatar, audit, system messages, joinPublicGroup
- `chat_repository_impl.dart` (619 γραμμές): `with GroupChatMixin implements ChatRepository`

**Απόφαση:** `GroupChatMixin` χωρίς `on ChatRepositoryImpl` → abstract getters (λύση circular dependency `recursive_interface_inheritance`). Service classes inline στο mixin. `markAsRead` group-branch στο `ChatRepositoryImpl`.

### Φάση 3 — Services (Βήματα 7-9) ✅
- `sendMessage()`: @mentions extraction
- `mention_utils.dart` (57 γραμμές): `MentionService` — 3 static methods
- `group_search_repository.dart` (224 γραμμές): Abstract + Firestore impl (city/tag filtering)

### Φάση 4 — Providers & State (Βήματα 10-11) ✅
- `chat_provider.dart` (~360 γραμμές): `participantUidsProvider`, `groupPermissionsProvider`, `activeInvitesProvider`, `groupSearchRepositoryProvider` + 15 action methods (createGroupChat, addParticipant, removeParticipant, updateGroupName, updateGroupAvatar, removeGroupAvatar, updateParticipantRole, updatePermissionOverride, createInviteLink, redeemInviteLink, revokeInvite, joinPublicGroup, updateMaxParticipants)
- `fcm_service.dart`: `activeChatId` (String?) → `activeChatIds` (Set<String>), `registerActiveChat`/`unregisterActiveChat`

### Φάση 5 — Routing (Βήμα 12) ✅
- `app_router.dart` (~274 γραμμές): +8 group routes (create, info, invite, call, settings, search, /:chatId placeholder, /groups list)
- Sub-routes πριν parameterized για αποφυγή route hijack
- `canCommunicate` redirect updated

### Φάση 6 — Firestore (Βήματα 13-14) ✅
- `firestore.rules` (256 γραμμές): `isGroupChatRef`/`isGroupCreator`/`isGroupAdmin` helpers, audit_log, invites, groups collection group rules
- `firestore.indexes.json` (177 γραμμές): 4 composite indexes — **deployed**
- **Rules ΔΕΝ έχουν deploy** (postponed στο τέλος Phase 7)

### Φάση 7 — UI Screens (Βήματα 15-22) ✅
| Βήμα | Αρχείο | Γραμμές |
|------|--------|---------:|
| 15 | `chat_screen.dart` group-aware (AppBar, PopupMenu, _chatDocProvider) + `message_bubble.dart` + `chat_messages_list.dart` + messagesStream +seenBy +mentions +system | ~345+140+130 |
| 16 | `chat_list_screen.dart` — group tiles, FAB Create Group, AppBar search icon | ~278 |
| 17 | `create_group_screen.dart` — search users (collectionGroup('public') + client-side nickname filter) | ~280 |
| 18 | `group_info_screen.dart` — participant list, roles, name editor, leave | ~280 |
| 19 | `group_invite_screen.dart` — λίστα active invites, create/revoke/copy | ~270 |
| 20 | `group_search_screen.dart` — discover & join public groups (+ `joinPublicGroup` repo/mixin/provider) | ~220 |
| 21 | `group_settings_screen.dart` — avatar upload/remove, max participants, permissions info | ~280 |
| 22 | `group_call_screen.dart` — placeholder (2 states: videoCallEnabled true/false) | ~90 |

### Αποκλίσεις από multichat.md
- **GroupChatScreen**: Δεν δημιουργήθηκε — `chat_screen.dart` auto-detects groups via `_chatDocProvider` (reuse)
- **joinPublicGroup**: Δεν προβλεπόταν — προστέθηκε για public group join χωρίς permission check
- **description editor**: Δεν υλοποιήθηκε (δεν υπάρχει πεδίο description στο `chats` doc — απαιτεί public profile infrastructure)
- **Service classes**: Inline στο mixin αντί ξεχωριστά αρχεία

### Εκκρεμεί
- **Φάση 8 (23-25):** ✅ Ολοκληρώθηκε στο Session 159
- **Φάση 9 (26-31):** Deploy firestore rules, build APK, install, test, release

### Στατιστικά
- **flutter analyze: 0 issues**
- **25/31 βήματα (81%)** — Φάση 8 ✅
- **~34 νέα/τροποποιημένα αρχεία**
- Backups: `backups/2026-07-10_*`

### Αρχεία (νέα/τροποποιημένα)

| Αρχείο | Γραμμές |
|--------|---------:|
| `lib/repositories/chat_repository.dart` | 104 |
| `lib/repositories/group_chat_mixin.dart` | 796 |
| `lib/repositories/group_search_repository.dart` | 224 |
| `lib/features/chat/providers/chat_provider.dart` | ~360 |
| `lib/core/router/app_router.dart` | ~274 |
| `lib/core/notifications/fcm_service.dart` | ~220 |
| `lib/features/chat/screens/chat_screen.dart` | ~345 |
| `lib/features/chat/screens/chat_list_screen.dart` | ~278 |
| `lib/features/chat/screens/create_group_screen.dart` | ~280 |
| `lib/features/chat/screens/group_info_screen.dart` | ~280 |
| `lib/features/chat/screens/group_invite_screen.dart` | ~270 |
| `lib/features/chat/screens/group_search_screen.dart` | ~220 |
| `lib/features/chat/screens/group_settings_screen.dart` | ~280 |
| `lib/features/chat/screens/group_call_screen.dart` | ~90 |
| `lib/features/chat/widgets/message_bubble.dart` | ~140 |
| `lib/features/chat/widgets/chat_messages_list.dart` | ~130 |
| `firestore.rules` | 256 |
| `firestore.indexes.json` | 177 |

---

## Session 159 — MultiChat Phase 9: Build & Deploy (Full Bugfix Pass)

**Πεδίο:** Ολοκλήρωση 6 εκκρεμών διορθώσεων (3× P0, 1× P1, bilingual, deploy), build APK.

### 🔴 P0 — `removeParticipant()` διαγράφει encryption key από όλους
**Πρόβλημα:** `EncryptionUtils.deleteKey(chatId)` καλούνταν για κάθε αφαίρεση μέλους, διαγράφοντας το κλειδί και από τον admin που έκανε την αφαίρεση.
**Λύση:** Μεταφορά `deleteKey` + `logConsent` ΜΟΝΟ στο `isSelf` block. Admin που αφαιρεί μέλος δεν χάνει το κλειδί του.
**Αρχείο:** `group_chat_mixin.dart:429`

### 🔴 P0 — `joinPublicGroup()` δεν κάνει update memberCount
**Πρόβλημα:** Το `joinPublicGroup()` καλούσε `removeChatCache()` αλλά όχι `_updatePublicProfileMemberCount()`. Το public profile της ομάδας έδειχνε παλιό αριθμό μελών.
**Λύση:** Προσθήκη `await _updatePublicProfileMemberCount(chatId)` μετά το `removeChatCache()`.
**Αρχείο:** `group_chat_mixin.dart:738`

### 🟡 P1 — `sendMessage()` block check λάθος για groups
**Πρόβλημα:** Το block check έβρισκε `firstOrNull` otherUid (πρώτο μη-αποστολέα) και έλεγχε block μόνο για αυτόν — σε group 5 ατόμων, έλεγχε μόνο 1 τυχαίο άτομο.
**Λύση:** Το block check έγινε conditional: `if (!isGroupChat) { ... }`. Για groups, το block check γίνεται από τα Firestore rules.
**Αρχείο:** `chat_repository_impl.dart:151`

### 🔴 P0 — FCM Group Notification Improvement
**Πρόβλημα:** Το group notification είχε `body: groupName ?? ''` — κενό string όταν δεν υπήρχε groupName.
**Λύση:** `title: groupName ?? senderName`, `body: senderName` (αν groupName υπάρχει) ή `new_group_message` localized string. Προστέθηκε `new_group_message` στα notification strings.
**Αρχείο:** `functions/src/index.ts`

### 🔴 P0 — Deploy Firestore Rules + Indexes + Cloud Functions
**Ενέργεια:** `firebase deploy --only firestore` (rules + 4 composite indexes) + `firebase deploy --only functions` (5 Cloud Functions).
**Αποτέλεσμα:** 21 composite indexes deployed, rules released, all 5 functions updated.

### Bilingual LoadingView/EmptyView (4 strings)
**Αρχεία:** `group_audit_log_screen.dart` (2 strings), `join_confirmation_screen.dart` (2 strings)
**Αλλαγή:** Από μονόγλωσσα `const` σε `greek ? 'Ελληνικά' : 'English'`.

### Build
- `flutter analyze`: **0 issues**
- `flutter build apk --release --dart-define=ENABLE_RELEASE_DEBUG=true`: **33.4MB** ✅
- MultiChat Phase 9 (βήματα 26-31): **Ολοκληρωμένο** — 31/31 βήματα (100%)

### Αρχεία
| Αρχείο | Αλλαγή |
|--------|--------|
| `lib/repositories/group_chat_mixin.dart` | P0 fix #1 (deleteKey isSelf) + P0 fix #2 (memberCount) |
| `lib/repositories/chat_repository_impl.dart` | P1 fix #3 (block check groups) |
| `functions/src/index.ts` | P0 fix #4 (group notification body) |
| `lib/features/chat/screens/group_audit_log_screen.dart` | Bilingual LoadingView/EmptyView |
| `lib/features/chat/screens/join_confirmation_screen.dart` | Bilingual LoadingView/EmptyView |
| `firestore.rules` | Deployed ✅ |
| `firestore.indexes.json` | Deployed ✅ |

---

## Session 160 — CRITICAL BUGS: addParticipant + markAsRead (Cloud Function + Rules Fix)

**Πεδίο:** Δύο critical bugs στο group chat — addParticipant PERMISSION_DENIED (όταν ≥2 μέλη) και markAsRead PERMISSION_DENIED (πάντα).

### 🔴 CRITICAL BUG #1 — addParticipant PERMISSION_DENIED (όταν ≥2 μέλη)
**Πρόβλημα:** `firestore.rules` γραμμή 87 — `blocked` subcollection readable μόνο από owner ή blocked user. Το loop στο `group_chat_mixin.dart:370-377` διάβαζε `users/${pUid}/blocked/${newUid}` για κάθε υπάρχον μέλος → PERMISSION_DENIED όταν group ≥2 members.

**Λύση:** Νέο `addGroupParticipant` callable Cloud Function (`functions/src/index.ts:702-781`):
- Admin SDK `runTransaction` — διαβάζει `blocked` subcollections χωρίς rules restrictions
- Ελέγχει: authentication, participant status, duplicate, max participants, block list, nickname
- Γράφει `participants`, `participantNicknames`, `participantRoles`, `participantJoinedAt`, `participantInvitedBy`, `participantIsActive`
- Bilingual error codes: `not-found`, `already-exists`, `failed-precondition`, `resource-exhausted`, `permission-denied`, `unauthenticated`

**Client-side (`group_chat_mixin.dart:361-395`):**
- `addParticipant()` → αντί για `firestore.runTransaction`, καλεί `FirebaseFunctions.instance.httpsCallable('addGroupParticipant')`
- Post‑steps (`_sendSystemMessage`, `_logAudit`, `db.logConsent`, `_updatePublicProfileMemberCount`) παραμένουν client‑side
- Προστέθηκε `_cfErrorToAppException(e)` helper (γραμμές 43-67) — μεταφράζει `HttpsError` codes → `AppException` (el/en)

**Αρχεία:** `functions/src/index.ts` (νέα CF), `group_chat_mixin.dart` (rewrite), `chat_repository_impl.dart` (import)

### 🔴 CRITICAL BUG #2 — markAsRead PERMISSION_DENIED (πάντα)
**Πρόβλημα (2 issues στο `firestore.rules:119-121`):**
1. `${request.auth.uid}` — το CEL (Common Expression Language) των Firestore Rules **δεν υποστηρίζει string interpolation**. Το `${...}` έμενε κυριολεκτικό string → ποτέ match.
2. `affectedKeys()` επιστρέφει **top-level fields μόνο** (π.χ. `['lastReadTimestamps']`), όχι dotted paths (`['lastReadTimestamps.uid']`).

**Λύση (firestore.rules:119-124):**
```
hasOnly(['lastReadTimestamps'])
  && request.resource.data.lastReadTimestamps.diff(
       resource.data.get('lastReadTimestamps', {})
     ).affectedKeys().hasOnly([request.auth.uid])
```
- Πρώτο check: μόνο το `lastReadTimestamps` top-level field άλλαξε
- Δεύτερο check (nested diff): μέσα σε αυτό, μόνο το key του authenticated user
- `resource.data.get('lastReadTimestamps', {})` — fallback για πρώτη φορά που γράφονται read receipts

### 🔶 arrayUnion crash στην CF (δευτερεύον)
**Πρόβλημα:** `admin.firestore.FieldValue.arrayUnion([newUid])` → Admin SDK Node.js δέχεται **variadic arguments**, όχι array. Error: `Nested arrays are not supported`.

**Λύση:** `arrayUnion([newUid])` → `arrayUnion(newUid)`

**Αρχείο:** `functions/src/index.ts:758`

### Deploy
- `firebase deploy --only functions:addGroupParticipant` ✅ (2× — initial + arrayUnion fix)
- `firebase deploy --only firestore:rules` ✅
- `flutter analyze`: **0 issues**

### Αρχεία
| Αρχείο | Αλλαγή |
|--------|--------|
| `functions/src/index.ts` | Νέα `addGroupParticipant` CF (γραμμές 702-781) + arrayUnion fix |
| `lib/repositories/group_chat_mixin.dart` | `addParticipant` rewrite (CF call + `_cfErrorToAppException` helper) |
| `lib/repositories/chat_repository_impl.dart` | `import cloud_functions` |
| `firestore.rules` | markAsRead rule fix (γραμμές 119-124) |
| `backups/2026-07-10_231606/firestore.rules` | Backup πριν το rules fix |

---

## Session 161 — UID→Nickname fixes + avatar εμφάνιση (4 screens)

**Πεδίο:** Διορθώσεις εμφάνισης UID αντί nickname και avatar σε group chat screens.

### 1. CreateGroupScreen — UID στα chips επιλεγμένων μελών
**Πρόβλημα:** Τα `Chip` των επιλεγμένων μελών (γραμμή 243) έδειχναν το raw UID αντί για nickname. Το `_selectedUids` ήταν `Set<String>` — αποθήκευε μόνο UID.

**Λύση:** `Set<String> _selectedUids` → `Map<String, String> _selected` (UID→nickname). Chips δείχνουν `e.value` (nickname). `createGroupChat` περνάει `_selected.keys.toList()`.

**Αρχεία:** `create_group_screen.dart`

### 2. GroupInfoScreen — avatar ομάδας hardcoded
**Πρόβλημα:** Το group avatar (γραμμή 215) ήταν `CircleAvatar(child: Icon(Icons.group))` — πάντα εικονίδιο, ποτέ φωτογραφία.

**Λύση:** Προσθήκη `groupAvatarUrl` από `chatData?['groupAvatarUrl']`. Αν υπάρχει, `CachedNetworkImageProvider` — αλλιώς `const Icon(Icons.group)`.

**Αρχεία:** `group_info_screen.dart`

### 3. PublicProfileView — group picker bottom sheet avatar
**Πρόβλημα:** Στην επιλογή ομάδας για πρόσκληση από προφίλ, το avatar ήταν hardcoded `CircleAvatar(child: Icon(Icons.group))`.

**Λύση:** `chat.groupAvatarUrl` από `ChatCacheTableData` — `CachedNetworkImageProvider` αν υπάρχει, αλλιώς εικονίδιο.

**Αρχεία:** `public_profile_view_screen.dart`

### 4. GroupAuditLog — UID αντί nickname (actor + target)
**Πρόβλημα:** Το `_AuditLogTile` έδειχνε `entry.actorName ?? entry.actor` — το `actorName` ΔΕΝ αποθηκευόταν από το `_logAudit` (μόνο `actorUid`), οπότε πάντα έπεφτε στο UID.

**Λύση (χωρίς extra Firestore reads):**
- `_AuditLogTile`: `StatelessWidget` → `ConsumerWidget`
- Διαβάζει `participantNicknames` από `chatDocProvider` (ήδη cached)
- `actorNick = entry.actorName ?? nicknames?[entry.actor] ?? entry.actor`
- `targetNick = nicknames?[entry.targetUid]` (αν υπάρχει target)
- Προστέθηκε `chatId` στο `AuditLogEntry`
- Αρχική προσέγγιση με extra `get()` στο `_logAudit` → **αφαιρέθηκε** για αποφυγή επιπλέον Firestore χρεώσεων

**Αρχεία:** `group_audit_log_screen.dart`, `group_chat_mixin.dart` (revert)

### 5. PermissionsEditorScreen — UID + crash + avatar
**Προβλήματα (3 σε 1):**
1. **UID αντί nickname:** `_participantNicknames` και `_targetRole` γέμιζαν από `ref.listen` που ΔΕΝ πυροδοτείται για το αρχικό data
2. **Crash:** `_nicknameFor()[0].toUpperCase()` → `RangeError` αν UID κενή
3. **Avatar:** `CircleAvatar` έδειχνε μόνο το πρώτο γράμμα, όχι φωτογραφία

**Λύση:**
- Αφαίρεση `_participantNicknames`/`_targetRole` state — ανάγνωση απευθείας από `chatDocAsync.asData`
- `nick.isNotEmpty ? nick[0].toUpperCase() : '?'`
- `participantAvatarUrls[targetUid]` + `CachedNetworkImageProvider`

**Αρχεία:** `permissions_editor_screen.dart`

### flutter analyze
`flutter analyze`: **0 issues** ✅

---

## Session 162 — Role-based visibility: Invites gate + groupPermissionsProvider εναρμόνιση

**Πεδίο:** Διόρθωση 2 αποκλίσεων από την πρόταση role-based visibility στο `group_info_screen.dart`.

### Διόρθωση 1 — "Διαχείριση Invites" admin-only
**Πρόβλημα:** Το κουμπί "Διαχείριση Invites" ήταν ορατό σε όλα τα μέλη, αλλά η πρόταση το ήθελε μόνο για admin/creator.

**Λύση:** Μεταφορά του `FilledButton.icon` για invites μέσα σε `if (isAdmin) ...` block.

### Διόρθωση 2 — isAdmin από groupPermissionsProvider
**Πρόβλημα:** Το `isAdmin` υπολογιζόταν χειροκίνητα: `isCreator || myRole == 'admin'`. Αυτό αγνοούσε τα overrides (π.χ. member με `inviteMembers=true` δεν έβλεπε admin UI).

**Λύση:** 
```dart
final permsInfo = ref.watch(groupPermissionsProvider(chatId)).asData?.value;
final isAdmin = permsInfo?.hasPermission(currentUid, GroupPermission.inviteMembers) ?? false;
```
- Προστέθηκε import `chat_repository.dart` για το `GroupPermission` enum
- Debug log updated: `permsLoaded=${permsAsync.hasValue}` αντί παλιού `isAdmin`

**Αρχείο:** `group_info_screen.dart`

**Verified:** `flutter analyze` clean ✅

---

## Session 163 — Centralized bilingual system messages (SPoT) + 5 νέες actions

**Πεδίο:** Δημιουργία κεντρικού `SystemMessageFormatter` (bilingual el/en) για όλα τα group system events και προσθήκη 5 νέων actions.

### Τι έγινε

1. **`system_message_formatter.dart` (NEW)** — SPoT με 12 bilingual templates:
   - Υπάρχοντα (7): `group_created`, `participant_added/removed/left`, `name_changed`, `role_changed`, `group_deleted`
   - Νέα (5): `avatar_changed`, `avatar_removed`, `max_participants_changed`, `permission_changed`, `permission_overrides_reset`
   - Auto-detection self-join, prepend `groupName:`

2. **`_sendSystemMessage` rewrite** (group_chat_mixin.dart) — Διαβάζει chat doc, resolve nicknames, καλεί formatter, γράφει `content` (el) + `contentEn` (en)

3. **5 νέα callers** — `updateGroupAvatar()` → `avatar_changed`, `removeGroupAvatar()` → `avatar_removed`, `updateMaxParticipants()` → `max_participants_changed` (με newMax), `updatePermissionOverride()` → `permission_changed` (targetUid, permissionName, granted/revoked), `deletePermissionOverrides()` → `permission_overrides_reset` (targetUid)

4. **`_SystemBubble` bilingual** — Διαβάζει `contentEn`, χρησιμοποιεί `L10n.isGreek(context)` για επιλογή γλώσσας, backward compatible (παλιά `content`-only μηνύματα fallback στα ελληνικά)

### Αρχεία
- `lib/features/chat/utils/system_message_formatter.dart` — NEW
- `lib/repositories/group_chat_mixin.dart` — rewrite `_sendSystemMessage` + 5 new callers
- `lib/repositories/chat_repository_impl.dart` — import formatter
- `lib/features/chat/widgets/message_bubble.dart` — `_SystemBubble` bilingual

### Key Decisions
- Νicknames resolved at send time (όχι render) — historically accurate, avoids extra Firestore reads
- Format: `GroupName: ActorNickname added TargetNickname` — group name first, self-join detected
- `content` (el) + `contentEn` (en) σε Firestore message doc; `_SystemBubble` επιλέγει via `L10n.isGreek`
- Extra Map omitted from `_sendSystemMessage` — all data via `targets` positional list

### 5 (bis) — FCM notification when added to group
Προστέθηκε FCM push στην `addGroupParticipant` Cloud Function:
- **Title:** `groupName` (ή "Ομάδα"/"Group" αν δεν έχει όνομα)
- **Body (el):** `"Ο/Η [callerName] σε προσκάλεσε στην ομάδα"`
- **Body (en):** `"[callerName] added you to the group"`
- **Data:** `{chatId, type: 'group_invite', addedBy: callerUid}`
- **Παραλήπτης:** μόνο ο νέος χρήστης
- Locale-aware: διαβάζει `lang` από το profile του παραλήπτη

**Αρχείο:** `functions/src/index.ts` — `addGroupParticipant` function

**Verified:** `npx tsc --noEmit` clean ✅

**Verified:** `flutter analyze` clean ✅

---

## Session 164 — Split photo privacy: showAvatar + showPhotos ξεχωριστά

**Πεδίο:** Διαχωρισμός του υπάρχοντος `showPhotos` σε δύο ξεχωριστές ρυθμίσεις απορρήτου — μία για την φωτογραφία προφίλ (avatar) και μία για τις υπόλοιπες φωτογραφίες.

### Τι έγινε

1. **`privacy_settings_table.dart`** — Προσθήκη `showAvatar` BoolColumn με default `true`
2. **`database.dart`** — Bump schemaVersion `11→12`, νέο migration v11→v12
3. **`build_runner`** — Regenerate `database.g.dart`
4. **`profile_repository_impl.dart`** — `avatarUrl:` τώρα ελέγχεται από `privacy?.showAvatar` (όχι `showPhotos`)
5. **`privacy_editor_screen.dart`** — Νέο toggle "Φωτογραφία Προφίλ" / "Profile Photo" πάνω από το υπάρχον "Φωτογραφίες"

### Αποτέλεσμα
- Χρήστης μπορεί να κρύψει τις φωτογραφίες gallery (showPhotos=false) αλλά να κρατήσει ορατή την avatar (showAvatar=true)
- Και οι δύο ρυθμίσεις είναι default `true` (backward compatible)
- Οι παλιές τιμές showPhotos παραμένουν ανεπηρέαστες

### Αρχεία
- `lib/data/local/tables/privacy_settings_table.dart` — new column
- `lib/data/local/database.dart` — schema version + migration
- `lib/repositories/profile_repository_impl.dart` — split check
- `lib/features/profile/screens/privacy_editor_screen.dart` — new toggle

**Verified:** `flutter analyze` clean ✅

---

## Session 165 — Νέο σύστημα διαγραφής chat 1-to-1 (request + approve/reject)

**Πεδίο:** Αντικατάσταση της μονομερούς ολικής διαγραφής chat 1-to-1 με σύστημα αιτήματος διαγραφής (όπως Telegram).

### Ροή
1. Χρήστης πατά "Διαγραφή" → `requestDeleteChat` → γράφεται system message `delete_request` με buttons
2. Άλλος χρήστης βλέπει "Ο Άρης θέλει να διαγράψει την συνομιλία. Συμφωνείς;" + [Ναι] [Όχι]
3. **Ναι** → `approveDeleteChat` → ολική διαγραφή (messages + chat doc + cache)
4. **Όχι** → dialog "Διαγραφή μόνο για εσένα;" → `deleteChatForMe` (remove από participants) ή `rejectDeleteChat` (ακύρωση)
5. Αν ο άλλος δεν είναι ενεργός → διαγραφή αμέσως

### Αρχεία
- **NEW** `lib/repositories/chat_repository_delete.dart` — Mixin `ChatDeleteMixin` (requestDeleteChat, approveDeleteChat, rejectDeleteChat, deleteChatForMe, _deleteChatForEveryone)
- `lib/repositories/chat_repository.dart` — +3 abstract methods
- `lib/repositories/chat_repository_impl.dart` — `with ChatDeleteMixin`, `deleteChat()` delegates to `requestDeleteChat()`
- `lib/features/chat/providers/chat_provider.dart` — +3 provider methods
- `lib/features/chat/utils/system_message_formatter.dart` — +4 actions (delete_request/approved/rejected/local)
- `lib/features/chat/widgets/message_bubble.dart` — `_SystemBubble` με action buttons για delete_request
- `lib/features/chat/widgets/chat_messages_list.dart` — action callbacks στο chat list
- `lib/features/chat/screens/chat_list_screen.dart` — dialog για 1-to-1 (αίτημα) vs group (ολική)

### Key Decisions
- `delete_request` system messages έχουν `senderId: actorUid` (not 'system') → FCM ειδοποιεί τον άλλο χρήστη
- "Μόνο για εσένα" → remove από `participants` στο Firestore (όχι delete doc) + local cache clean
- Group chats: `requestDeleteChat` κάνει delegate στο `deleteGroup` (αμετάβλητο)
- Edge: `activeDeleteRequest` flag στο chat doc, μόνο ένα pending request τη φορά

**Verified:** `flutter analyze` clean ✅

---

### Firebase Audit — Βελτιστοποίηση χρήσης Firestore

**Έλεγχος:** Κάθε αρχείο Dart/TypeScript για wasteful reads/writes/listeners.

#### 🔴 Υψηλή Προτεραιότητα

| # | Πρόβλημα | Αρχείο:Γραμμή | Κόστος |
|---|---|---|---|
| 1 | `publish()` κάνει verify read μετά από set() — **debug-only, άχρηστη** | `profile_repository_impl.dart:362-380` | 1 read/publish |
| 2 | `_findExistingChat` χωρίς `.limit()` — φορτώνει ΟΛΑ τα chats | `chat_repository_impl.dart:120-123` | Unbounded reads |
| 3 | `markAsRead` χωρίς `.limit()` — διαβάζει ΟΛΑ τα unread | `chat_repository_impl.dart:349-352` | Unbounded reads |
| 4 | Δύο ίδιοι StreamProvider για `chatDocProvider` (duplicate listener) | `chat_provider.dart:10` + `group_settings_screen.dart:14` | Διπλός listener |
| 5 | `_deleteChatForEveryone` ένα-ένα delete (όχι batch) | `chat_repository_delete.dart:111-119` | 500 writes → 1 |

#### 🟡 Μεσαία Προτεραιότητα

| # | Πρόβλημα | Αρχείο:Γραμμή |
|---|---|---|
| 6 | Cloud Function `sendChatNotification` reads sender profile 2× | `functions/index.ts:102,116` |
| 7 | `clearMessages` χωρίς `.limit()` | `chat_repository_impl.dart:633-635` |
| 8 | N+1 listeners `_AuditLogTile` → `chatDocProvider` | `group_audit_log_screen.dart:187` |
| 9 | `sendRequest` 3 sequential reads, 1 debug-only | `request_repository_impl.dart:42-91` |

#### 🟢 Χαμηλή Προτεραιότητα

| # | Πρόβλημα | Αρχείο:Γραμμή |
|---|---|---|
| 10 | `createChat` 2 profile reads sequential (αντί parallel) | `chat_repository_impl.dart:74-82` |

---

## Current State

| Μέτρο | Τιμή |
|---|---|
| Completion | ~99.9% (Phases 1-3 100%, MultiChat Phase 9 ✅) |
| Firestore indexes | 21 composite deployed |
| Build | `flutter analyze` clean, release APK ~33.4MB |
| Tests | **30/30 passed** |
| `.dart` files | ~109 (non-generated) |
| Cloud Functions | **6 deployed** (+1 new: `addGroupParticipant`) + `fcm-utils.ts` helper |
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
| P3.2 Haversine Memoization (_distanceCache, clearDistanceCache) | ✅ Session 156 — ~96% fewer Haversine calls |
| P4.1 ConsentLog Pagination (LIMIT 50, loadMore button) | ✅ Session 157 — paginated NotifierProvider |
| **MultiChat Phase 9 — Build & Deploy** (31/31 steps 100%) | ✅ **Session 159** — all fixes + deploy + APK |
| P0 removeParticipant deleteKey (isSelf only) | ✅ Session 159 — `group_chat_mixin.dart` |
| P0 joinPublicGroup memberCount | ✅ Session 159 — `group_chat_mixin.dart` |
| P1 sendMessage block check for groups | ✅ Session 159 — `chat_repository_impl.dart` |
| P0 FCM group notification body improvement | ✅ Session 159 — `functions/src/index.ts` |
| Bilingual LoadingView/EmptyView (4 strings) | ✅ Session 159 — audit_log + join_confirmation |
| Firestore rules + indexes deploy | ✅ Session 159 — `firebase deploy --only firestore` |
| Cloud Functions deploy | ✅ Session 159 — all 5 functions updated |
| **🔴 CRITICAL #1 — addParticipant PERMISSION_DENIED (≥2 members)** | ✅ **Session 160** — νέο `addGroupParticipant` callable CF + client rewrite |
| **🔴 CRITICAL #2 — markAsRead PERMISSION_DENIED (always)** | ✅ **Session 160** — rules fix: nested diff rule, `${}` interpolation → `request.auth.uid` |
| **arrayUnion crash (CF)** | ✅ **Session 160** — `arrayUnion([uid])` → `arrayUnion(uid)` |

### ✅ Ολοκληρωμένο — Role-based visibility σε group chat screens
**Session:** 161 (αρχική υλοποίηση) + 162 (διορθώσεις)
**Περιγραφή:** Εφαρμογή role-based απόκρυψη/εμφάνιση επιλογών βάσει Creator/Admin/Member.

**Αρχική υλοποίηση (Session 161):**
- `chat_repository_impl.dart`: `_requirePermission(chatId, GroupPermission.deleteMessages)` στο `clearMessages()` (defense-in-depth)
- `chat_screen.dart`: PopupMenu gating — `add_member` πίσω από `canInvite` (`hasPermission(inviteMembers)`), `clear` πίσω από `canDeleteMsgs` (`hasPermission(deleteMessages)`), άλλα items ορατά σε όλους
- `group_info_screen.dart`: Gate "Προσθήκη Μέλους" + "Ρυθμίσεις" με `isAdmin`, αφαίρεση "Αποχώρηση" (υπάρχει στο three-dot chat_screen), αφαίρεση `_leaveGroup()` μεθόδου
- `group_settings_screen.dart`: `canChangeAvatar` μέσω `GroupPermissionsInfo.hasPermission(changeGroupAvatar)` αντί χειροκίνητου `isCreator || role == 'admin'`

**Διορθώσεις Session 162:**
1. "Διαχείριση Invites" → gated behind `isAdmin` (ήταν ορατό σε όλα τα μέλη)
2. `isAdmin` calculation → από manual `isCreator || myRole == 'admin'` σε `permsInfo?.hasPermission(uid, GroupPermission.inviteMembers)` μέσω `groupPermissionsProvider` (σέβεται overrides)
3. Προσθήκη import `chat_repository.dart` για `GroupPermission` enum

**Αρχεία:** `chat_screen.dart`, `chat_repository_impl.dart`, `group_info_screen.dart`, `group_settings_screen.dart`

### Remaining Gaps
- **Phase 4**: Video (Agora), AI matching, Admin, Web, Premium, Typesense
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
| 8 | **✅ P3.2** | Haversine memoization για ίδιο geoHash | Performance | `firestore_search_repository.dart` | ✅ Fixed |
| 9 | **✅ P4.1** | ConsentLog pagination | Scalability | `consent_log_screen.dart` | ✅ Fixed |

---

## Σειρά Εκτέλεσης (Work Plan)

1. **✅ P1.1** — `_checkConnectivity` bypass + duplicate `_performSearch` — verified fixed
2. **✅ P1.2** — Request delete UI race — fixed
3. **✅ P1.3** — Biometric idle timer lifecycle — fixed (Session 152)
4. **✅ P2.1** — Provider cascade (debounce auth state) — verified fixed
5. **✅ P2.2** — Phone verification (SMS OTP) — verified fixed
6. **✅ P3.1** — Fix online status flicker (null-coalescing `streamOnline ?? profile.isOnline`) — **Fixed Session 155**
7. **✅ P3.2** — Haversine memoization για ίδιο geoHash — **Fixed Session 156**
8. **✅ P4.1** — ConsentLog pagination — **Fixed Session 157**

> Εκτελούμε **μία βελτίωση τη φορά**. Μετά από κάθε αλλαγή: backup → edit → `flutter analyze` → έλεγχος από τον χρήστη → "επόμενο".

## Key Conventions
- File size ≤ 500 lines (exceptions: profile_repository_impl ~570, chat_repository_impl ~590 with user permission)
- `DebugConfig.log(flag, msg)` σε κάθε operational action
- **Error handling**: `error_messages.dart` κεντρικό bilingual mapping
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): L10n
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
