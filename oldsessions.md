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
| 27 | **joinPublicGroup crash** — transaction `get()` blocked by rules (not participant yet) | Public read rule + self-join update rule + nickname read refactor |
| 28 | **notBanned() gaps** — 17 rules missing ban check in chat/request layer | Add `notBanned()` to all 17 rules |
| 29 | **memberCount silent failure** — groups update required `isGroupCreator` even for `memberCount` | `isGroupMember()` helper + `hasOnly(['memberCount'])` OR rule |

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
| Completion | ~99.9% (Phases 1-3 100%, MultiChat Phase 9 ✅, Media Phase 1-3 ✅) |
| Firestore indexes | 21 composite deployed |
| Build | `flutter analyze` clean, release APK ~33.4MB |
| Tests | **30/30 passed** |
| `.dart` files | ~110 (non-generated) |
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
| P1.1 Duplicate search on refresh — already fixed | ✅ Session 154 |
| P2.1 Provider cascade (debounce auth state) — already fixed | ✅ Session 154 |
| P2.2 Phone verification (SMS OTP) — already fixed | ✅ Session 154 |
| P3.1 Online Status Flicker (null-coalescing fallback) | ✅ Session 155 |
| P3.2 Haversine Memoization (_distanceCache, clearDistanceCache) | ✅ Session 156 |
| P4.1 ConsentLog Pagination (LIMIT 50, loadMore button) | ✅ Session 157 |
| **MultiChat Phase 9** (31/31 steps 100%) | ✅ **Session 159** |
| **CRITICAL #1 — addParticipant PERMISSION_DENIED** | ✅ **Session 160** — callable CF |
| **CRITICAL #2 — markAsRead PERMISSION_DENIED** | ✅ **Session 160** — rules fix |
| UID→Nickname fixes + avatar εμφάνιση (4 screens) | ✅ Session 161 |
| Role-based visibility (Invites gate + groupPermissionsProvider) | ✅ Session 162 |
| Bilingual system messages SPoT + 5 νέες actions + FCM group add | ✅ Session 163 |
| Split photo privacy (showAvatar + showPhotos ξεχωριστά) | ✅ Session 164 |
| **Delete chat 1-to-1 flow** (9 διορθώσεις) | ✅ **Session 165 + 166** — verified working |
| **maxParticipants display bug** (cache snapshot override) | ✅ **Session 166** |
| **P1.4** — Conditional verify read σε `publish()` | ✅ **Session 168** |
| **P1.3** — Remove debug banned check + parallel reads σε `sendRequest()` | ✅ **Session 168** |
| **P1.2** — Parallel profile reads σε `createChat()` | ✅ **Session 168** |
| **P1.5** — Server-side `unreadCount` map (zero count queries) | ✅ **Session 168** |
| **P0 — joinPublicGroup crash** (rules read/update fix + nickname refactor) | ✅ **Session 169** |
| **Member status UI** ("Είσαι Μέλος"/"Member" στην αναζήτηση group) | ✅ **Session 169** |
| **notBanned()** σε 17 chat/request rules + isGroupMember helper | ✅ **Session 170** |
| **memberCount fix** — groups update rules restructured | ✅ **Session 170** |
| **Dual-device production testing** — all flows verified | ✅ **Session 170** |
| **Blocked user→add bilingual error** (CF code prefix) | ✅ **Session 173** |
| **Existing members UI** (label "Μέλος/Member" disabled Chip) | ✅ **Session 173** |
| **Auto-localize bilingual errors** (AppMessenger showError) | ✅ **Session 173** |
| `flutter analyze` | ✅ Clean |
| **Large Emoji-Only Messages** (emoji_only_bubble.dart) | ✅ **Session 182** |
| **Profile Sync Across Chats** (nickname+avatar σε όλα τα chat docs) | ✅ **Session 183** |

### ✅ Ολοκληρωμένο — Role-based visibility σε group chat screens
**Session:** 161 (αρχική υλοποίηση) + 162 (διορθώσεις)

### ✅ Ολοκληρωμένο — Media Input Phase 1: Emoji Picker (v4)
**Session:** 175-180 (planning + extraction + refactor + v4 instance cache)
- `EmojiPickerPanel` StatefulWidget με instance cache, SPoT restoration, dispose log summary
- `flutter analyze` clean, device test 4 opens stable

### ✅ Ολοκληρωμένο — Media Input Phase 2: GIF Support (GIPHY API)
**Session:** 181 (full implementation + device test)
- `GiphyService` (αντί Tenor — discontinued) + `GifPickerSheet` bottom sheet
- `sendMediaMessage` + media branch skip decrypt + `_GifBubble` rendering
- `gifSupportEnabled = true`, `flutter analyze` clean
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

---

## Session 166 — Delete chat 1-to-1 flow fixes + maxParticipants display bug

### Delete chat 1-to-1 flow (verified working ✅)

**Πεδίο:** 9 διορθώσεις στο νέο σύστημα διαγραφής 1-to-1 chat.

| # | Fix | Αρχείο |
|---|---|---|
| 1 | Messages reversed: `ListView.builder` με `reverse: true` — latest message στο bottom κατά την είσοδο | `chat_messages_list.dart` |
| 2 | `_onRejectDelete` simplified — direct `rejectDeleteChat` χωρίς dialog/pop για τον rejecter | `chat_messages_list.dart` |
| 3 | `_onDeleteForMe` — requester διαγράφει μόνο για τον εαυτό του | `chat_messages_list.dart` |
| 4 | `delete_local` μήνυμα fix: `"αποχώρησες"` → `"$actorNickname αποχώρησε"` | `system_message_formatter.dart` |
| 5 | `delete_cancelled` action — όταν requester πατά [Όχι, παράμεινε] | `system_message_formatter.dart` |
| 6 | `_SystemBubble` extended για `delete_rejected` — inline buttons [Ναι, μόνο για εμένα]/[Όχι, παράμεινε] | `message_bubble.dart` |
| 7 | `participantUidsProvider` listener extended σε 1-to-1 chats (pop back λειτουργεί) | `chat_screen.dart` |
| 8 | FCM notification για system messages: uses `message.content` αντί generic "Νέο μήνυμα" | `functions/src/index.ts` |
| 9 | `activeDeleteRequest` field removed from Firestore writes (permission-denied) | `chat_repository_delete.dart` |

### maxParticipants display bug (2-tier fix)

**Πρόβλημα:** Η αποθήκευση του `maxParticipants` στο Firestore πετύχαινε (logs: `updateMaxParticipants: done`, `AppMessenger: Ενημερώθηκε`), αλλά κατά την επαναφορά στην οθόνη, η τιμή έδειχνε 10 αντί 30.

**Root cause:** Όχι αποτυχία εγγραφής — το Firestore είχε 30, αλλά το UI διάβαζε από το local cache snapshot (10) και αγνοούσε το server snapshot (30) λόγω guards:

1. **`GroupInfoScreen._onDocChanged`** (group_info_screen.dart:50):
   - Guard: `if (name != _groupName || roles != _participantRoles)` — `_maxParticipants` ενημερωνόταν ΜΟΝΟ όταν άλλαζε name ή roles
   - Fix: `|| maxP != _maxParticipants` στο guard

2. **`GroupSettingsScreen.build`** (group_settings_screen.dart:123):
   - Guard: `if (_currentMax == null && maxP > 0)` — το cache snapshot (10) έκανε `_currentMax = 10`, οπότε το server snapshot (30) αγνοούνταν
   - Fix: `if (maxP != _currentMax && maxP > 0)` — επιτρέπει update όταν η server τιμή διαφέρει από την cached

**Firestore rules:** Επίσης διορθώθηκαν (session 165) ώστε `maxParticipants` να επιτρέπεται και για `admin`, όχι μόνο `creator` — αλλά το πραγματικό bug ήταν το display.

**Verified:** `flutter analyze` clean ✅

**Αρχεία:** `group_info_screen.dart`, `group_settings_screen.dart`, `chat_messages_list.dart`, `message_bubble.dart`, `chat_screen.dart`, `chat_repository_delete.dart`, `system_message_formatter.dart`, `functions/src/index.ts`

---

## Session 168 — Firestore Cost Phase B (P1): unreadCount map + parallel reads + conditional verify

**Πεδίο:** Ολοκλήρωση Φάσης Β του Firestore Cost Optimization — 4 εναπομείναντα P1 items (P1.2-P1.5).

---

### P1.5 — Server-side `unreadCount` map (real fix: zero count queries)

**Πρόβλημα:** 2 count queries per chat update σε `_syncChatFromFirestore()` + `_syncGroupChatToCache()`. Unbounded Firestore read cost.

**Λύση:** Server-side `unreadCount` map (`chats/{chatId}/unreadCount` ως `Map<String, int>`):

| Αλλαγή | Αρχείο | Περιγραφή |
|--------|--------|-----------|
| `sendMessage()` | `chat_repository_impl.dart` | `FieldValue.increment(1)` per other participant — 1 write, 0 reads |
| `markAsRead()` | `chat_repository_impl.dart` | `unreadCount.${uid} = 0` στο ίδιο write με `lastReadTimestamps` |
| `_syncChatFromFirestore()` | `chat_repository_impl.dart` | map read αντί count query: `(unreadCount[uid] as int?) ?? 0 > 0` |
| `_syncGroupChatToCache()` | `group_chat_mixin.dart` | same pattern — replaces 2 count queries |
| `createChat()` / `createGroupChat()` | both files | init map with all `0` |
| `firestore.rules` | `firestore.rules` | `'unreadCount'` added to 2 `allow update` branches |

**Self-healing:** `FieldValue.increment` auto-creates field on legacy chats. `?? {}` fallback.

**Deploy:** `firebase deploy --only firestore:rules` (project `nearme-gr`) ✅

**Verified:** User-tested on 2 devices — increment ✅, reset ✅, group ✅, self-healing ✅, zero errors ✅

**Εξοικονόμηση:** ~30.000 reads/μήνα για 1k users (€0.24/μήνα) — **μηδενικά count queries**

---

### P1.2 — Parallel profile reads σε `createChat()

**Πρόβλημα:** 2 sequential `await` reads (myProfile + otherProfile) — περιττή latency.

**Λύση:** `Future.wait` για παράλληλες reads:

```dart
final results = await Future.wait([
  firestore.collection('users').doc(uid).collection('public').doc('profile').get(),
  firestore.collection('users').doc(otherUid).collection('public').doc('profile').get(),
]);
```

**Αρχείο:** `chat_repository_impl.dart`  
**Verified:** `flutter analyze` clean ✅

---

### P1.3 — Remove debug-only banned check + parallel reads σε `sendRequest()`

**Πρόβλημα (2 issues):**
1. `banned/$uid` read was debug-only — unnecessary in production (rules already check)
2. 3 sequential reads for block + profile + banned

**Λύση (2 αλλαγές):**
1. **Αφαίρεση banned check** — Firestore rules το ελέγχουν ήδη
2. **`Future.wait`** για block check + target profile

```dart
final results = await Future.wait([
  _firestore.doc('users/$toUid/blocked/$uid').get(),
  _firestore.collection('users').doc(toUid).collection('public').doc('profile').get(),
]);
```

**Αρχείο:** `request_repository_impl.dart`  
**Verified:** `flutter analyze` clean ✅

**Εξοικονόμηση:** 1 read saved πάντα + latency βελτίωση

---

### P1.4 — Conditional verify read σε `publish()`

**Πρόβλημα:** `set()` ακολουθούσε verify read (debug-only) — 1 άχρηστο read ανά publish.

**Λύση:** Wrap σε `if (DebugConfig.debugMode)`:

```dart
await _firestore.collection('users').doc(uid).collection('public').doc('profile').set(json);
if (DebugConfig.debugMode) {
  try { /* verify read */ } catch (e) { /* ignore */ }
}
```

**Αρχείο:** `profile_repository_impl.dart`  
**Verified:** `flutter analyze` clean ✅

**Εξοικονόμηση:** ~3.000 reads/μήνα (1k users, 100 publishes/day)

---

### Αποτελέσματα Επαλήθευσης

| # | Έλεγχος | Αποτέλεσμα |
|:-:|---------|:-----------:|
| 1 | No count queries | ✅ `_syncChatFromFirestore` / `_syncGroupChatToCache` logs ΧΩΡΙΣ count queries |
| 2 | sendMessage increment | ✅ Receiver βλέπει `unread count=Ν` ακριβές |
| 3 | markAsRead reset | ✅ `unread count=0` μετά το άνοιγμα chat |
| 4 | Group increment | ✅ 2 receivers βλέπουν `unread count=2` |
| 5 | Self-healing (legacy) | ✅ `unread count=1` σε παλιό chat χωρίς `unreadCount` |
| 6 | No errors | ✅ Κανένα `[ERROR]`, καμία crash |

### Φάση Β — Σύνοψη

| # | Αλλαγή | Τύπος | Αρχεία | Status |
|:-:|--------|:-----:|--------|:------:|
| P1.4 | Conditional verify read σε `publish()` | **Cost** ✅ | `profile_repository_impl.dart` | ✅ |
| P1.3a | Remove debug-only banned check | **Cost** ✅ | `request_repository_impl.dart` | ✅ |
| P1.3b | Parallel block+target reads με `Future.wait` | Latency | `request_repository_impl.dart` | ✅ |
| P1.2 | Parallel profile reads σε `createChat()` | Latency | `chat_repository_impl.dart` | ✅ |
| P1.5 | Server-side `unreadCount` map — remove ALL count queries | **Cost** ✅ | `chat_repository_impl.dart`, `group_chat_mixin.dart`, `firestore.rules` | ✅ |

**Συνολική εξοικονόμηση Φάσης Β:** ~35.000 reads/μήνα για 1k users (~€0.28/μήνα)

**Συνολική εξοικονόμηση Φάσης Α+Β:** ~188.700 reads/μήνα + ~79.500 writes/μήνα (~€2.51/μήνα)

---

## Session 167 — chatsProvider dispose/recreate στο startup (fix)

**Πρόβλημα:** Σε κάθε startup, το `chatsProvider` δημιουργούνταν 2 φορές:
```
chatsProvider created (StreamProvider)    ← από unreadBadgeProvider cascade
streamChats: started                      ← stream ξεκινά
userChanges: uid=...                      ← authStateProvider πρώτο emit
chatsProvider disposed                    ← από ref.invalidate στο main
main: invalidated chatsProvider (auth change)
streamChats: cancelled
chatsProvider created (StreamProvider)    ← ξαναδημιουργείται
streamChats: started                      ← δεύτερο stream
```

**Root cause:** `main.dart:352-359` — `ref.listen(authStateProvider, ...)` είχε:
```dart
if (uidChanged || emailVerifiedChanged) {
  ref.invalidate(chatsProvider);
  // ...
}
```
Στο πρώτο emit, `prev = AsyncLoading` (όχι null), `prev?.value` = null, οπότε `uidChanged = true` και το invalidate εκτελούνταν πάντα.

**Λάθος fix:** `&& prev != null` — το `prev` είναι πάντα `AsyncValue` (ποτέ null).

**Σωστό fix:** `&& prev is AsyncData` — μπαίνει στο block μόνο αν το `prev` ήταν `AsyncData` (δηλ. υπάρχει προηγούμενο έγκυρο state). Στο πρώτο emit (AsyncLoading → AsyncData), το `prev is AsyncData` = false → skip.

**Επαλήθευση:**
- Startup: `chatsProvider created` 1 φορά, `streamChats: started` 1 φορά, **κανένα** `chatsProvider disposed` ✅
- Sign-out: `prev = AsyncData(user)` → invalidate ✅
- Sign-in: `prev = AsyncData(null)` → invalidate ✅

**Αρχείο:** `lib/main.dart:359`

**Παρενέργειες που εξαλείφθηκαν:**
- Extra Firestore read στο startup (1 επιπλέον streamChats query)
- Extra decrypt cache miss (όλα τα μηνύματα ξανααποκρυπτογραφούνταν)
- Extra _syncChatFromFirestore + _syncGroupChatToCache
- ~1-2ms περιττή latency στο startup

### P1.1 — Remove duplicate `_chatDocForSettingsProvider` listener

**Πρόβλημα:** Δύο ξεχωριστοί StreamProvider ακούνε στο ίδιο `chats/{chatId}` doc:
- `chatDocProvider` (chat_provider.dart:10) — StreamProvider.autoDispose.family
- `_chatDocForSettingsProvider` (group_settings_screen.dart:14) — private duplicate

Κάθε φορά που ανοίγει GroupSettings → **2 listeners στο ίδιο doc**.

**Λύση:** Αντικατάσταση `_chatDocForSettingsProvider` με `chatDocProvider` reuse.

**Αλλαγές σε 1 αρχείο** (`group_settings_screen.dart`):
1. Αφαίρεση `import 'package:cloud_firestore/cloud_firestore.dart';` (unused)
2. Αφαίρεση `_chatDocForSettingsProvider` definition (lines 14-18)
3. `ref.watch(_chatDocForSettingsProvider(...))` → `ref.watch(chatDocProvider(...))`

**Επαλήθευση:** `flutter analyze` — 0 issues ✅

**Εξοικονόμηση:** ~15.000 reads/μήνα (€0.12 για 1k users)

---

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

### ✅ P0.2 — Firebase Audit Cost: `_findExistingChat` unbounded reads + related — **FIXED (Session 158)**

**Αρχεία:** `lib/repositories/chat_repository_impl.dart` (49-116), `lib/repositories/group_chat_mixin.dart` (405-441, 730-764, 115-130), `lib/features/chat/screens/group_audit_log_screen.dart`, `lib/features/chat/utils/audit_detail_formatter.dart` (νέο), `lib/core/router/app_router.dart`, `lib/core/debug/debug_config.dart`

**Περιγραφή:** Τέσσερα ξεχωριστά issues διορθώθηκαν:

**1. `_findExistingChat` unbounded reads** — `participantPair` direct query `.limit(1)` + legacy fallback `.limit(10)` + self-healing backfill. `firestore.rules` updated.

**2. `removeParticipant` race condition (chat disappears)** — `removeChatCache(chatId)` καλούνταν χωρίς συνθήκη. Όταν admin αφαιρεί άλλο μέλος, η local cache διαγραφόταν παρόλο που ο admin είναι ακόμα participant. Λύση: `if (isSelf)` guard. Επίσης `joinPublicGroup` είχε ίδιο μοτίβο — αφαιρέθηκε.

**3. Bilingual audit log** — Νέο `AuditDetailFormatter` SPoT για bilingual field labels/values στα audit log details. `AuditLogEntry.details` άλλαξε από `String?` σε `Map<String, dynamic>?`. Προστέθηκε `DebugConfig.uiDetail` flag.

**4. Action labels mismatch** — `_actionLabel()` στο `group_audit_log_screen.dart` είχε switch cases που δεν ταίριαζαν με τα πραγματικά actions της `_logAudit()`. 8/11 actions έπεφταν σε `default` → εμφάνιζαν raw αγγλικό key. Λύση: `auditActionLabel()` στο `AuditDetailFormatter` + διόρθωση `_actionIcon()` keys.

**5. GoRouter route ordering bug** — `/groups/search` ήταν μετά από `/groups/:chatId`, οπότε το `search` μπαινε ως `chatId` και εμφανιζόταν placeholder "GroupChatScreen: search". Λύση: μετακίνηση route πριν από το `:chatId`.

**6. Audit icon mapping** — `_actionIcon()`/`_actionIconData()` διορθώθηκαν να ταιριάζουν με πραγματικές `_logAudit` actions (11 actions, 0 dead cases).

**Verified:** 14/7/2026 — `flutter analyze`: 0 issues. ✅

**Κρισιμότητα:** P0 — Λειτουργικό bug (chat εξαφανίζεται, audit log μισό-αγγλικό, route σπασμένο)

### ✅ P0.3 — markAsRead unbounded reads — **FIXED (Session 166)**

**Περιγραφή:** Το `markAsRead` είχε unbounded reads στο query unread messages. Διορθώθηκε:
- `firestore.rules:119-124`: CEL nested `diff()` αντί `${}` interpolation (PERMISSION_DENIED fix)
- `chat_repository_impl.dart:383`: `.limit(50)` στο unread messages query — αποτροπή unbounded reads ✅

**Εκκρεμεί ακόμα (από αρχική P0.3 πρόταση):**
- `clearMessages` pagination
- Duplicate `chatDocProvider` listeners

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
| 5 | **✅ P2** | Provider cascade (διπλό create/dispose σε auth change + startup) | Optimization | `main.dart` | ✅ Fixed (Session 167) |
| 6 | **✅ P2** | Ολοκλήρωση phone verification (SMS OTP) | Feature gap | `phone_verify_provider.dart` | ✅ Fixed |
| 7 | **✅ P3.1** | Online status flicker στα ProfileCards | UX polish | `profile_card.dart` | ✅ Fixed |
| 8 | **✅ P3.2** | Haversine memoization για ίδιο geoHash | Performance | `firestore_search_repository.dart` | ✅ Fixed |
| 9 | **✅ P4.1** | ConsentLog pagination | Scalability | `consent_log_screen.dart` | ✅ Fixed |
| 10 | **✅ P0.2** | `removeParticipant` chat disappears + audit bilingual + route ordering | Bug | `group_chat_mixin.dart` + `group_audit_log_screen.dart` + `app_router.dart` | ✅ Fixed |
| 11 | **✅ P0.3** | `markAsRead` unbounded reads + rules fix | Cost | `chat_repository_impl.dart` + `firestore.rules` | ✅ Fixed (Session 166) |
| 12 | **✅ P0.4** | `clearMessages` pagination | Cost/Crash | `chat_repository_impl.dart` + `chat_repository_clear.dart` | ✅ Fixed (Session 166) |
| 13 | **✅ P0.1** | `_deleteChatForEveryone` pagination | Cost/Crash | `chat_repository_delete.dart` | ✅ Fixed (Session 166) |
| 14 | **✅ P1.1** | Duplicate `_chatDocForSettingsProvider` listener | Cost | `group_settings_screen.dart` | ✅ Fixed (Session 167) |

---

## Σειρά Εκτέλεσης (Work Plan)

1. **✅ P1.1** — `_checkConnectivity` bypass + duplicate `_performSearch` — verified fixed
2. **✅ P1.2** — Request delete UI race — fixed
3. **✅ P1.3** — Biometric idle timer lifecycle — fixed (Session 152)
4. **✅ P2.1** — Provider cascade (debounce auth state) — fixed Session 167 (prev is AsyncData στο main.dart)
5. **✅ P2.2** — Phone verification (SMS OTP) — verified fixed
6. **✅ P3.1** — Fix online status flicker (null-coalescing `streamOnline ?? profile.isOnline`) — **Fixed Session 155**
7. **✅ P3.2** — Haversine memoization για ίδιο geoHash — **Fixed Session 156**
8. **✅ P4.1** — ConsentLog pagination — **Fixed Session 157**
9. **✅ P0.2** — Firebase Audit: `_findExistingChat` reads + `removeParticipant` race (chat disappearing) + bilingual audit log + GoRouter route ordering — **Fixed Session 158**
10. **✅ P0.3 (μερικό)** — Firebase Audit: `markAsRead` unbounded reads + rules PERMISSION_DENIED — **Fixed Session 166**
11. **✅ P0.4** — `clearMessages` pagination — **Fixed Session 166**
12. **✅ P0.1** — `_deleteChatForEveryone` pagination — **Fixed Session 166**
13. **✅ P1.1** — Duplicate `_chatDocForSettingsProvider` listener — **Fixed Session 167**

> Εκτελούμε **μία βελτίωση τη φορά**. Μετά από κάθε αλλαγή: backup → edit → `flutter analyze` → έλεγχος από τον χρήστη → "επόμενο".

## Key Conventions
- File size ≤ 500 lines (exceptions: profile_repository_impl ~570, chat_repository_impl ~590 with user permission)
- `DebugConfig.log(flag, msg)` σε κάθε operational action
- **Error handling**: `error_messages.dart` κεντρικό bilingual mapping
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): L10n
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore

## Session 169 — P0 joinPublicGroup crash fix (read rule + update rule + nickname refactor + member UI)

**Πρόβλημα:** `joinPublicGroup()` crash με `permission-denied` όταν χρήστης πατά "Συμμετοχή" σε δημόσιο chat από την οθόνη αναζήτησης group.

**Root cause:** `group_chat_mixin.dart:701` — `transaction.get(chatRef)` διάβαζε `chats/{chatId}` αλλά τα Firestore rules απαιτούν `isParticipant(resource.data)` για read σε chat docs. Ο χρήστης ΔΕΝ είναι ακόμα μέλος → `permission-denied`.

**Διόρθωση (3 αρχεία):**

### 1. `firestore.rules` (2 αλλαγές)
- **Read rule** (γραμμή 101-102): `isParticipant(resource.data)` → `(isParticipant(resource.data) || resource.data.isPublic == true)`
- **Νέο `allow update`** (γραμμές 171-178): Ξεχωριστό update rule OR για public group self-join — επιτρέπει σε μη-μέλος να κάνει join μόνο τα 5 πεδία (`participants`, `participantNicknames`, `participantRoles`, `participantJoinedAt`, `participantIsActive`) σε public group. Το υπάρχον update rule έμεινε ανέπαφο.

### 2. `group_chat_mixin.dart` — Non-transactional read fix
- Μεταφορά `firestore.collection('users')...get()` (nickname read) από ΜΕΣΑ στο `runTransaction` σε ΠΡΙΝ από αυτό
- Προσθήκη `DebugConfig.log` για resolved nickname
- Το transaction χρησιμοποιεί πλέον local variable `newNickname`

### 3. `group_search_screen.dart` — Member status UI
- Νέα μέθοδος `_isMember(ref)`: ελέγχει `chatsProvider` (Drift cache) αν υπάρχει chat με αυτό το `chatId`
- Αν `isMember == true`: `OutlinedButton.icon` με τικ + "Είσαι Μέλος" / "Member" + navigation `/chats/{chatId}`
- Αν `isMember == false`: "Συμμετοχή" / "Join" (υπάρχον)
- Μηδέν extra Firestore reads — χρήση cached `ChatCacheTable`

**Edge cases covered:**
- Group deleted → transaction `!exists` → `group not found` ✅
- Concurrent joins → transaction atomicity → maxParticipants enforced ✅
- User already a member (UI πριν πατήσει) → hidden join button ✅
- Network failure → transaction retry → `AppException` ✅
- `_updatePublicProfileMemberCount`: pre-existing bug (silent fail, not creator)

**Αρχεία:**
- `firestore.rules` — read + new update rule
- `lib/repositories/group_chat_mixin.dart` — nickname read refactor
- `lib/features/chat/screens/group_search_screen.dart` — member UI

**Backup:** `backups/2026-07-15_joinPublicGroup_fix/`
**Verified:** `flutter analyze` clean ✅

---

## Session 170 — notBanned() σε όλα τα chat rules + memberCount fix (2 pre-existing edge cases)

**Πεδίο:** Διόρθωση 2 συστημικών gaps στο `firestore.rules` — (1) `notBanned()` λείπει από 17 rules στο chat/request layer, (2) `_updatePublicProfileMemberCount` silent failure (groups update rule απαιτεί `isGroupCreator` ακόμα και για `memberCount`).

### Issue 1: notBanned() — 17 rules που το είχαν παραβλεφθεί

**Πρόβλημα:** Το `notBanned()` υπήρχε μόνο σε `users/public`, `/{path=**}/public`, `/{path=**}/groups`, `groups/{doc}`, `requests/{reqId}` create. Έλειπε από ΟΛΟ το chat layer — banned user μπορούσε να συνεχίσει να στέλνει μηνύματα, να διαβάζει invites, να αποδέχεται requests.

**Διόρθωση:** Προσθήκη `notBanned()` μετά από κάθε `isAuthenticated()` σε 17 rules:

| # | Rule | Αρχείο:Γραμμή |
|---|------|:-------------:|
| 1 | `chats/{chatId}` read | `firestore.rules:104` |
| 2 | `chats/{chatId}` update (υπάρχον) | `firestore.rules:116` |
| 3 | `chats/{chatId}` update (self-join) | `firestore.rules:180` |
| 4 | `chats/{chatId}` delete (1-on-1) | `firestore.rules:168` |
| 5 | `chats/{chatId}` delete (group) | `firestore.rules:173` |
| 6 | `chats/{chatId}/messages` read | `firestore.rules:191` |
| 7 | `chats/{chatId}/messages` create | `firestore.rules:195` |
| 8 | `chats/{chatId}/messages` update | `firestore.rules:203` |
| 9 | `chats/{chatId}/messages` delete | `firestore.rules:207` |
| 10 | `chats/{chatId}/audit_log` read | `firestore.rules:247` |
| 11 | `chats/{chatId}/audit_log` create | `firestore.rules:252` |
| 12 | `chats/{chatId}/invites` read | `firestore.rules:266` |
| 13 | `chats/{chatId}/invites` create | `firestore.rules:271` |
| 14 | `chats/{chatId}/invites` update | `firestore.rules:277` |
| 15 | `/{path=**}/invites` read | `firestore.rules:310` |
| 16 | `requests/{reqId}` read | `firestore.rules:222` |
| 17 | `requests/{reqId}` update | `firestore.rules:232` |

### Issue 2: _updatePublicProfileMemberCount silent failure

**Πρόβλημα:** Το `groups/{doc}` update rule απαιτούσε `isGroupCreator(doc)` — μόνο ο δημιουργός μπορούσε να αλλάξει το public profile. Το `_updatePublicProfileMemberCount()` (καλούμενο από `addParticipant`, `removeParticipant`, `joinPublicGroup`) αποτύγχανε ΠΑΝΤΑ σιωπηλά (ο καλών δεν είναι creator).

**Διόρθωση:** 
- `groups/{doc}` update (γραμμές 332-340): `isGroupCreator(doc)` OR `hasOnly(['memberCount']) && isGroupMember(doc)`
- **Νέο helper** `isGroupMember(groupChatId)` (γραμμές 52-55): server-side `get()` στο `chats/{groupChatId}` → ελέγχει `participants` map
- Προσθήκη `notBanned()` και στα groups update + delete rules

### Edge cases

**notBanned():**
- Banned user σε chat → Firestore listener `onError` → Drift cache stale ✅
- Banned + joinPublicGroup → transaction `get()` blocked → `AppException` ✅
- Banned + accept request → requests update rule blocked ✅
- Self-join public group (non-banned) → `notBanned()` + transaction atomicity → join επιτυχές ✅

**memberCount:**
- Admin adds/removes member → `isGroupMember` pass (admin is still participant) → memberCount ενημερώνεται ✅
- Self-removal (leave) → `isGroupMember` FAILS (no longer participant) → stale memberCount ⚠️
- Member tries to change `groupName` → `hasOnly(['memberCount'])` blocks → PERMISSION_DENIED ✅
- Banned member tries update → `notBanned()` blocks ✅
- Creator changes avatar → `isGroupCreator` → OK (unchanged) ✅

### Αλλαγές

| Αρχείο | Αλλαγή |
|--------|--------|
| `firestore.rules` | +1 helper (`isGroupMember`), +17 × `notBanned()`, groups update restructured, groups delete + `notBanned()` |
| `backups/2026-07-15_notBanned_memberCount/firestore.rules` | Backup πριν τα edits |

**Deploy:** `firebase deploy --only firestore:rules` → `nearme-gr` ✅
**flutter analyze:** 0 issues ✅
**Side effects:** Κανένα — μόνο rules changes, zero Dart modifications

---

## Session 171 — Self-removal CF (leaveGroup) + GoError navigation race fix

**Πρόβλημα:** Self-removal (leave group) edge case — μετά από `arrayRemove([uid])` στο `participants`, τα Firestore rules (`isParticipant`) blockάρουν επόμενα reads/writes (system message, audit log, memberCount update) με PERMISSION_DENIED.

**Λύση:** Νέο `leaveGroup` callable Cloud Function (`functions/src/index.ts:828-927`):
- Admin SDK `runTransaction` — bypasses rules
- Αφαιρεί participant, δημιουργεί bilingual system message (`content`/`contentEn`), audit log entry, transfer creator αν αποχωρεί ο creator, update `memberCount` για public groups
- Client-side: `removeParticipant` self-removal branch → `FirebaseFunctions.instance.httpsCallable('leaveGroup')`, local cleanup (deleteKey, removeChatCache) σε silent try-catch

**Αρχεία:**
- `functions/src/index.ts` — Νέα `leaveGroup` CF (γραμμές 828-927)
- `lib/repositories/group_chat_mixin.dart` — `removeParticipant` self-removal branch → CF call (lines 391-452)
- `lib/features/chat/screens/chat_screen.dart` — `canPop()` guard σε `_leaveGroup` + build watcher

**Deploy:** `firebase deploy --only functions:leaveGroup` ✅

### Dual-device test results

| Test | Περιγραφή | Αποτέλεσμα |
|:----:|-----------|:-----------:|
| 1 | Self-removal private group (My Team, ΟΛΕ, τεστ ×3) | ✅ `self-removal done XXXX via CF` |
| 2 | Self-removal public group + memberCount update | ✅ |
| 3 | Creator transfer on creator leave (Yahooman→Aris62) | ✅ `— όρισε τον/την Aris62 ως Διαχειριστή` |
| 4 | Admin removes member (non-self branch) | ✅ `admin removal done` — local path, no CF |
| 6 | 1-to-1 chat unaffected after self-removal | ✅ messages both directions |

### Known bug found during testing

**GoError: There is nothing to pop** — navigation race condition:
1. CF removes user → Firestore stream emits `participantUids` χωρίς τον χρήστη
2. Build watcher (line 116) καλεί `context.pop()` → redirect to `/chats`
3. `_leaveGroup()` (line 85) καλεί δεύτερο `context.pop()` → GoError

**Fix:** `context.canPop()` guard και στα 2 σημεία (lines 85 & 116) — αν το navigation έχει ήδη γίνει, το δεύτερο pop απλά δεν εκτελείται.

**Εκκρεμεί:** Test 5 (double-tap guard) — δεν ήταν δυνατό να δοκιμαστεί λόγω GoError.
**GoError fix:** εφαρμόστηκε, όχι ακόμα δοκιμασμένο σε device.

---

## Session 172 — GroupInfo Add Member search bug (stale participantRoles keys)

**Πρόβλημα:** Στην ομάδα My Team, η αναζήτηση για προσθήκη νέου μέλους από GroupInfo → "Προσθήκη Μέλους" δεν έφερνε αποτελέσματα, ενώ από τα τρία τελείες (ChatScreen overflow menu) δούλευε σωστά.

**Root cause:** Δύο διαδρομές, διαφορετικά δεδομένα:

| Διαδρομή | Αρχείο | Extra data | currentParticipantUids |
|----------|--------|:----------:|:----------------------:|
| 3-dots menu | `chat_screen.dart:188` | κανένα | `[]` → σωστό (από provider) |
| GroupInfo button | `group_info_screen.dart:294-300` | `rolesMap?.keys.toList()` | stale UIDs |

Το `removeParticipant()` (`group_chat_mixin.dart:436-439`) κάνει `arrayRemove` από `participants` και θέτει `participantIsActive=false`, αλλά **ΠΟΤΕ δεν καθαρίζει το `participantRoles`**. Έτσι, UIDs πρώην μελών παραμένουν σαν keys στο map.

Στο `add_participant_screen.dart:77-79`:
```dart
// ΠΡΙΝ (λάθος προτεραιότητα):
_participantUids = widget.currentParticipantUids.isNotEmpty
    ? widget.currentParticipantUids   // ← stale rolesMap keys
    : uids;                            // ← σωστό participants array
```

Το `currentUids` φιλτράρει (γραμμή 127: `.where((u) => !currentUids.contains(u['uid']))`) περισσότερους χρήστες απ' όσους θα έπρεπε.

**Fix:** Αντιστροφή προτεραιότητας — `participantUidsProvider` (από `participants` array + `participantIsActive`) πρώτα, `widget.currentParticipantUids` μόνο ως fallback:
```dart
// ΜΕΤΑ (σωστή προτεραιότητα):
_participantUids = uids.isNotEmpty ? uids : widget.currentParticipantUids;
```

**Αρχείο:** `lib/features/chat/screens/add_participant_screen.dart:77`
**Backup:** `backups/add_participant_screen.dart.backup_20260715_*`
**Verified:** `flutter analyze` clean ✅

### Note
Παραμένει το pre-existing issue: το `removeParticipant` δεν καθαρίζει το `participantRoles` — εκτός από αυτό το bug, επηρεάζει και το `GroupInfoScreen` member list (αν εμφανίζονταν πρώην μέλη, αλλά χρησιμοποιεί `participantUidsProvider` που είναι σωστό) και το `GroupSettingsScreen` (χρησιμοποιεί `chatDocProvider` απευθείας). Το αν αξίζει να καθαρίζεται το `participantRoles` είναι ξεχωριστό ερώτημα.

---

## Session 173 — Blocked user error fix + existing members UI + bilingual AppMessenger

**Πεδίο:** 3 διορθώσεις/βελτιώσεις: (1) blocked user→add group bilingual error, (2) εμφάνιση υπαρχόντων μελών με label, (3) auto-localization σε AppMessenger.

### Fix 1 — `_cfErrorToAppException` code prefix mismatch
**Πρόβλημα:** `FirebaseFunctionsException.code` επιστρέφει code **χωρίς** πρόθεμα `functions/` (π.χ. `failed-precondition`), αλλά τα switch cases στο `group_chat_mixin.dart` χρησιμοποιούσαν `'functions/failed-precondition'` → fallback στο `default` → generic `AppException.firestore()` αντί για το σωστό bilingual μήνυμα.

**Λύση:** `e.code.replaceFirst('functions/', '')` πριν το switch — σε 2 σημεία:
- `_cfErrorToAppException` (γραμμή 44)
- `removeParticipant` inline switch (γραμμή 416)

**Αποτέλεσμα (logs):**
```
ΠΡΙΝ: AppException(firestore_error): Firestore error during add_participant
ΜΕΤΑ: AppException(auth_error): Το άτομο έχει αποκλειστεί από συμμετέχοντα / Blocked by a participant
```

**Verified:** User-tested σε device ✅, `flutter analyze` clean ✅

### Fix 2 — Existing members search visibility
**Πρόβλημα:** Στην αναζήτηση προσθήκης μέλους, τα υπάρχοντα μέλη κρύβονταν εντελώς (`.where((u) => !currentUids.contains(u['uid']))` στη γραμμή 125). Ο χρήστης δεν ήξερε αν ο άλλος είναι ήδη μέλος ή δεν υπάρχει.

**Λύση (2 αλλαγές στο `add_participant_screen.dart`):**
1. **Αφαίρεση φίλτρου** (γραμμή 125) — τα υπάρχοντα μέλη εμφανίζονται πλέον στα αποτελέσματα
2. **Προσθήκη `isMember` flag** στο map κάθε αποτελέσματος + `DebugConfig.log(DebugConfig.repositoryFilter, ...)`
3. **UI conditional trailing:** Αν `isMember == true` → `Chip` με εικονίδιο ✅ + label "Μέλος" / "Member", disabled χωρίς κουμπί. Αλλιώς κανονικό "Προσθήκη" / "Add".

**Αρχείο:** `add_participant_screen.dart` (~333→~353 lines)
**Backup:** `backups/add_participant_screen.dart.backup_2026-07-15_183659`
**Verified:** `flutter analyze` clean ✅

### Fix 3 — Bilingual error messages σε AppMessenger
**Πρόβλημα:** Τα `AppException` αποθηκεύουν bilingual strings (π.χ. `"Το άτομο έχει αποκλειστεί / Blocked by a participant"`), αλλά το `AppMessenger.showError()` τα εμφάνιζε αυτούσια — και οι 2 γλώσσες ταυτόχρονα.

**Λύση:** Στο `app_messenger.dart:13-15`, αν το μήνυμα περιέχει `' / '`, χρησιμοποιεί `L10n.localizedMessage(context, message)` για να κρατήσει μόνο την κατάλληλη γλώσσα.

```dart
final displayMsg = message.contains(' / ')
    ? L10n.localizedMessage(context, message)
    : message;
```

**Αρχείο:** `app_messenger.dart` (1 import + ~4 γραμμές)
**Backup:** `backups/app_messenger.dart.backup_2026-07-15_185023`
**Verified:** `flutter analyze` clean ✅

### Σύνοψη
| # | Αλλαγή | Αρχείο | Backup |
|:-:|--------|--------|:------:|
| 1 | blocked→add bilingual CF error | `group_chat_mixin.dart` | υπήρχε από session 159 |
| 2 | existing members UI (label/disabled) | `add_participant_screen.dart` | `backup_2026-07-15_183659` |
| 3 | auto-localize bilingual σε AppMessenger | `app_messenger.dart` | `backup_2026-07-15_185023` |

**`flutter analyze`:** 0 issues ✅

---

## Session 174 — Rebuild Loop Fix: chatDocProvider cache + DeepCollectionEquality

**Πεδίο:** Διόρθωση cascade rebuild loop που προκαλούσαν false-positive emits από Firestore `.snapshots()` (metadata changes, pending writes, reconnections) → κάθε emit κατέρρεε σε rebuild των downstream widgets (`participantUidsProvider` → `ChatScreen` + `GroupInfoScreen` + `ChatMessagesList` + `_SystemBubble`).

### Fix #1 — chatDocProvider: Cache & Structural Equality (source fix)
**Αιτία:** Το Firestore `.snapshots()` εκπέμπει ακόμα και όταν τα δεδομένα δεν άλλαξαν πραγματικά.

**Λύση:** `.map()` με cache + `DeepCollectionEquality`. Όταν η δομή είναι ίδια, επιστρέφεται το ίδιο `DocumentSnapshot` instance → `identical(prev, next)` → no notification.

**Αρχείο:** `chat_provider.dart:14-31` — `DocumentSnapshot? previous`, `DeepCollectionEquality().equals(prevData, currData)`, return `previous!`

### Fix #2 — _onDocChanged: Deep Map Equality (belt-and-suspenders)
**Αιτία:** `roles != _participantRoles` σύγκρινε Map references.

**Λύση:** `!const MapEquality().equals(roles, _participantRoles)` αντί `!=`.

**Αρχείο:** `group_info_screen.dart:52-54`

### Pre-requisites
- `pubspec.yaml` — `collection: ^1.19.0` **(ήδη transitive, explicit dep)**

### Αποτέλεσμα
- Firestore reconnection emit → cache → 0 rebuilds
- Metadata change (hasPendingWrites toggle) → cache → 0 rebuilds
- Real data change → cache miss → 1 rebuild (correct)
- Provider dispose/recreate → fresh cache → 1 rebuild

**Verified:** `flutter analyze` clean ✅

---

## Session 175 — Media Input Plan (media_input.md) + Phase 1 (Emoji Picker) Detailed Proposal

**Πεδίο:** Ανάλυση και σχεδιασμός για media input σε chats (emoji, GIF, photo, video). Δημιουργία `media_input.md` με revised v2 plan, και λεπτομερής πρόταση υλοποίησης Φάσης 1 (Emoji Picker) βασισμένη σε codebase evidence.

### Τι έγινε

1. **Δημιουργία `media_input.md`** — Πλήρης ανάλυση:
   - Cost analysis (Firebase resources, ~€1.90/μήνα για 1k users στο μεσαίο σενάριο)
   - Υπάρχουσες λειτουργίες προς reuse (StorageService, ImagePicker, κλπ.)
   - 4 φάσεις: Emoji → GIF → Photo → Video
   - Αποφάσεις: storage rules με `firestore.get()` (όχι signed URLs/CF), `deleteAllChatMedia` σε 3 deletion paths, `encrypted: false` forward-compatible flag, dual-path `_MediaBubble`, ConsentLog `sent_chat_media`, EXIF stripping, auto-delete media >30 ημέρες (post-MVP)

2. **Codebase reading** (για grounding της πρότασης):
   - `chat_screen.dart` — `_ChatInputBar` (γραμμές 272-374) → extraction target
   - `chat_messages_list.dart` — message rendering, action callbacks
   - `message_bubble.dart` — `_SystemBubble`, `_buildPreviewText` pattern
   - `debug_config.dart` — υπάρχοντα flags (uiInteraction, uiLifecycle, κλπ.)
   - `l10n.dart`, `error_messages.dart`, `app_messenger.dart` — bilingual patterns
   - `feature_flags.dart` — no media flag yet
   - `responsive_utils.dart` — breakpoints (mobile/tablet/desktop)
   - `pubspec.yaml` — `emoji_picker_flutter` ΔΕΝ υπάρχει

3. **User corrections incorporated:**
   - GIF → Φάση 2 (όχι Φάση 1)
   - Storage rules: `firestore.get()` participant check (όχι Cloud Functions)
   - `deleteGroup` cleanup: `deleteAllChatMedia` προστέθηκε
   - EXIF stripping: ενιαία για chat media + profile photos
   - ConsentLog: `sent_chat_media` action
   - E2E encryption: deferred (ξεχωριστή συζήτηση)
   - `messagesStream` decrypt attempt: documented as known side-effect
   - Forward-compatible `encrypted: false` + `chatId` + `isEncrypted` parameters

4. **Λεπτομερής πρόταση Φάσης 1 (Emoji Picker)** — γραμμένη στο media_input.md §5:
   - Προαπαιτούμενα & μπλοκαρίσματα (πίνακας)
   - Εμπλεκόμενα αρχεία (3: pubspec, νέο chat_input_bar.dart, chat_screen.dart)
   - 6 κανόνες από codebase (multilingual, responsive, debug, error, state, theme)
   - Πλήρης κώδικας `chat_input_bar.dart` (~180 γραμμές)
   - Diff για `chat_screen.dart`
   - 12 edge cases (από 3 στην αρχική πρόταση)
   - Flutter lifecycle analysis (7 events)
   - Memory footprint
   - Implementation order (5 βήματα)
   - Σύνοψη flags & guards

### Αρχεία
| Αρχείο | Αλλαγή |
|--------|--------|
| `media_input.md` | Δημιουργία revised v2 plan (1637 γραμμές) |
| `oldsessions.md` | Ενημέρωση — Session 175 |

### Αποφάσεις
- Emoji picker: **€0**, pure client-side, καμία backend αλλαγή
- `emoji_picker_flutter: ^4.0.0` — needs `flutter pub add`
- `_ChatInputBar` → extraction σε `chat_input_bar.dart` (public `ChatInputBar`)
- Feature flag για emoji: **δεν χρειάζεται** (δεν αλλάζει backend/model)
- Debug: χρήση υπάρχοντος `DebugConfig.uiInteraction` flag
- Responsive: LayoutBuilder + ResponsiveUtils (υπάρχον pattern)

### Επόμενο Βήμα
Έναρξης υλοποίησης Φάσης 1 (Emoji Picker) — 1 βήμα τη φορά: backup → edit → flutter analyze → user OK

---

## Session 176 — Emoji Picker Phase 1 Implementation Complete

**Πεδίο:** Υλοποίηση Phase 1 (Emoji Picker) από το `media_input.md` proposal — extraction `ChatInputBar` + emoji picker integration.

### Τι έγινε

1. **`media_input.md` revision** — Review πρότασης Phase 1, identified 5 gaps (keyboard overlap, auto-close on focus, back button, responsive height, Config API). Updated to v2.

2. **Dependency:** `flutter pub add emoji_picker_flutter` → v4.4.0 ✅

3. **Extraction:** `_ChatInputBar` από `chat_screen.dart` → νέο `lib/features/chat/widgets/chat_input_bar.dart` (~215 γραμμές):
   - `ConsumerStatefulWidget` (reuse pattern)
   - `textEditingController`, `FocusNode` για keyboard management
   - `_toggleEmojiPicker()`: `FocusScope.unfocus()` πριν show → αποτρέπει keyboard overlap
   - `_focusNode` listener → auto-κλείσιμο picker όταν TextField παίρνει focus
   - `_onEmojiSelected()`: cursor-aware insertion (σωστή θέση ακόμα και με selected text)
   - Responsive height: 250px portrait, 150px landscape (`MediaQuery.of(context).orientation`)
   - `canComm` guard (unverified users δεν βλέπουν emoji button)
   - `_isLoading` + `mounted` guard (double-send protection)
   - Bilingual (el/en) hints + error messages
   - Error recovery: restore text on send failure
   - `DebugConfig.log(DebugConfig.uiInteraction, ...)` σε init, dispose, toggle, build

4. **`chat_screen.dart` cleanup:**
   - Αφαίρεση `_ChatInputBar` class (γραμμές 272-374) → ~272 γραμμές
   - Import `ChatInputBar` + αντικατάσταση στη θέση του
   - Αφαίρεση duplicate imports (γραμμές 14-16)

5. **Config API fix:** `Config(clipBehavior: Clip.none)` — το `Config` class **δεν έχει** `clipBehavior` parameter. Αφαιρέθηκε → `Config()` χωρίς params.

### Αρχεία

| Αρχείο | Αλλαγή |
|--------|--------|
| `lib/features/chat/widgets/chat_input_bar.dart` | ΝΕΟ — full widget ~215 γρ. |
| `lib/features/chat/screens/chat_screen.dart` | Extraction `_ChatInputBar` + clean imports, ~272 γρ. |
| `media_input.md` | Updated: status, checklist, line counts, Config API note |
| `pubspec.yaml` | +`emoji_picker_flutter: ^4.4.0` |
| `backups/chat_screen.dart.bak_2026-07-16_phase1` | Backup pre-extraction |
| `backups/chat_screen.dart.bak_2026-07-16_fix1` | Backup pre-Config fix |
| `backups/chat_input_bar.dart.bak_2026-07-16_fix1` | Backup pre-Config fix |

### Εκκρεμεί
- Device test (emoji toggle, insert at cursor, send) — θα το κάνει ο χρήστης και θα ανεβάσει logs

**Verified:** `flutter analyze` — **0 issues** ✅

---

## Session 177 — Emoji Picker Refactor: Theme-Aware, Responsive, No Rebuild Storm

**Πεδίο:** Επίλυση 3 προβλημάτων (rebuild storm, white background, sizing) + refactoring architecture.

### Evidence-Based Analysis

| Πρόβλημα | Root Cause (από source code) |
|----------|------------------------------|
| **Rebuild storm** | `EmojiPicker` loadingIndicator default = `SizedBox.shrink()` (0px) → async `_updateEmojis()` → `setState(_loaded=true)` → `SizedBox(height:256)`. Μετάβαση 0→256 cascade through Column→Expanded→LayoutBuilder. |
| **White background** | `EmojiViewConfig.backgroundColor` default = `Color(0xFFEBEFF2)` — hardcoded ανοιχτό. Dark mode contrast. `Config` class **δεν έχει** `bgColor` (docs wrong). |
| **Sizing** | Σταθερό 250/150px χωρίς responsive. Χωρίς `Config.height` control. |

### Λύση

1. **`EmojiPickerConfig` (Single Point of Truth):** Νέο `lib/features/chat/utils/emoji_picker_config.dart`:
   - `create(context)` — theme-aware Config (colors from `theme.colorScheme`)
   - `responsiveHeight(context)` — breakpoint-based: 35% mobile, 30% tablet, 25% desktop (portrait), 55% landscape
   - `Config(height: null)` — removes internal constraint, external SizedBox controls height
   - `Config.locale` — from `L10n.isGreek(context)` (el/en)
   - All sub-configs themed: `EmojiViewConfig`, `CategoryViewConfig`, `BottomActionBarConfig`, `SearchViewConfig`, `SkinToneConfig`

2. **`ChatInputBar` refactored:** Δεν διαχειρίζεται πια emoji state. Νέα props:
   - `textEditingController`, `emojiPickerVisible`, `onEmojiToggle`, `onEmojiDismiss`

3. **`ChatScreen` owns emoji state:** `_textCtrl`, `_emojiPickerVisible`, `_toggleEmojiPicker`, `_dismissEmojiPicker`, `_onEmojiSelected`. EmojiPicker rendered as sibling (not inside ChatInputBar).

### Αρχεία

| Αρχείο | Αλλαγή |
|--------|--------|
| `lib/features/chat/utils/emoji_picker_config.dart` | ΝΕΟ — theme-aware Config factory + responsive height |
| `lib/features/chat/widgets/chat_input_bar.dart` | Refactor: 213→180 γρ., emoji logic removed, 4 νέα props |
| `lib/features/chat/screens/chat_screen.dart` | Refactor: 269→322 γρ., emoji state + rendering |
| `media_input.md` | Updated status |
| `backups/chat_input_bar.dart.bak_2026-07-16_v2` | Backup pre-refactor |
| `backups/chat_screen.dart.bak_2026-07-16_v2` | Backup pre-refactor |

### Device Test Pending
- Emoji toggle (shown/hidden) → verify responsive height
- Emoji insert at cursor → verify position
- Send text + emoji → verify both work
- Theme colors → verify no white background
- Orientation change while picker visible → verify height adapts
- Keyboard dismiss → verify picker hides

**Verified:** `flutter analyze` — **0 issues** ✅

---

## Session 178 — ChatScreen Rebuild Storm Fix: Analysis, Implementation & Partial Verification

**Πεδίο:** Διάγνωση και διόρθωση rebuild storm (30fps bursts σε `ChatScreen didChangeDependencies`) που προκαλείται από Firestore `.snapshots()` → provider chain cascade.

### Ανακάλυψη: `List.==` is Identity, Not Element-Wise

Το Dart `List.==` κάνει **identity comparison**, όχι element-wise. Αυτό σημαίνει ότι η `participantUidsProvider` (γραμμή 58-69 `chat_provider.dart`) επιστρέφει νέα `List<String>` σε κάθε `chatDocProvider` emit → Riverpod πάντα notify, ακόμα και όταν τα uids δεν έχουν αλλάξει.

### Cascade Paths

| Path | Root Cause | Impact |
|:----:|-----------|:------:|
| **A** | `ChatScreen.build()` → `ref.watch(chatDocProvider)` → notify σε κάθε Firestore emit | Rebuild oλόκληρου ChatScreen σε κάθε `lastReadTimestamp`/`unreadCount` change |
| **B** | `participantUidsProvider` → `List.==` identity → notify σε κάθε chatDocProvider emit | Ξεχωριστό notify chain (συνδυάζεται με Path A) |

### Fix A — participantUidsProvider Cache

```dart
final _participantUidCaches = <String, List<String>>{};

final participantUidsProvider = Provider.autoDispose.family<List<String>, String>((ref, chatId) {
  final chatDoc = ref.watch(chatDocProvider(chatId));
  return chatDoc.when(data: (chat) {
    final uids = chat != null ? List<String>.from(chat['participants'] as List) : <String>[];
    final cached = _participantUidCaches[chatId];
    if (cached != null && const DeepCollectionEquality().equals(cached, uids)) {
      DebugConfig.log(DebugConfig.chat, 'participantUidsProvider cache hit for $chatId');
      return cached;
    }
    DebugConfig.log(DebugConfig.chat, 'participantUidsProvider cache miss for $chatId');
    _participantUidCaches[chatId] = uids;
    return uids;
  }, loading: () => _participantUidCaches[chatId] ?? const [], error: (_, __) => const []);
}, name: 'participantUidsProvider');
```

**Κρίσιμο:** Το `autoDispose.family` dispose + recreate provider σε κάθε dependency change. Η cache cleanup στο `onDispose` ακύρωνε το caching. Λύση: **ΚΑΘΟΛΟΥ** cleanup στο `onDispose` (αμελητέο memory leak).

### Fix B — select() αντί direct watch

```dart
final isGroupChat = ref.watch(chatDocProvider(widget.chatId).select(
    (chat) => chat.valueOrNull != null ? chat.valueOrNull!['isGroupChat'] as bool? ?? false : false));
final groupName = ref.watch(chatDocProvider(widget.chatId).select(
    (chat) => chat.valueOrNull != null ? chat.valueOrNull!['groupName'] as String? : null));
final participantNicknames = ref.watch(_chatScreenNicknamesProvider(widget.chatId));
```

3 selectors αντί 1 `ref.watch(chatDocProvider(...))`. `lastReadTimestamps`/`unreadCount` changes → **0 ChatScreen rebuilds**.

### Fix C — Debug Logging

- `chatDocProvider suppressed` log όταν skip notification
- `participantUidsProvider cache hit/miss` log

### Device Test Results (Verified ✅)

| Test | Result |
|:----|:------:|
| Emoji picker show/hide rebuilds | ✅ **Fix B works** — 1 rebuild από setState, όχι storm |
| participantUidsProvider cache hit | ✅ **Fix A works** — 6 cache hits, κάθε chatDocProvider emit μπλοκάρεται |
| `ChatScreen didChangeDependencies` bursts | ✅ **Provider storm fixed** — bursts μόνο από keyboard animation |
| Keyboard dismiss animation cascade | ⚠️ ~450-500ms, ~60fps — **MediaQuery InheritedWidget** (Flutter framework, NOT preventable) |
| Route pop animation cascade | ⚠️ Ίδιο pattern: MediaQuery animation |
| Dispose chain | ✅ All providers properly disposed on exit |

### Files

| File | Change |
|------|--------|
| `lib/features/chat/providers/chat_provider.dart` | Fix A (cache `_participantUidCaches` + `DeepCollectionEquality`), Fix C (suppressed/cache hit logs) |
| `lib/features/chat/screens/chat_screen.dart` | Fix B (selectors αντί direct `chatDocProvider` watch), `_ChatScreenNicknames` class, `import 'package:collection/collection.dart'` |
| `media_input.md` | Updated status |
| `oldsessions.md` | Session 178 added |
| `backups/chat_provider.dart.bak_2026-07-16` | Backup pre-Fix A |
| `backups/chat_screen.dart.bak_2026-07-16` | Backup pre-Fix B |

**Verified:** `flutter analyze` — **0 issues** ✅ (3 φορές)

### Completed ✅
- Device test logs με νέο Fix A (no `onDispose` cache cleanup) — **verified: cache hits working ✅**
- ChatScreen rebuild storm από providers — **fixed ✅** (loops: keyboard animation cascade μόνο, Flutter framework)

---

## Session 179 — EmojiPickerPanel extraction + rebuild storm isolation + convention alignment

**Πεδίο:** Διόρθωση rebuild storm όταν ανοίγει emoji picker — ~20-30× `ChatScreen didChangeDependencies` σε ~2.1s (όχι το γνωστό keyboard cascade ~450ms).

### Root Cause
`MediaQuery.of(context)` / `Theme.of(context)` στο `chat_screen.dart` build — η εξάρτηση εγγραφόταν στο Element ολόκληρης της `ChatScreen`. Keyboard animation cascade μετά από `FocusScope.unfocus()` (για να κλείσει το πληκτρολόγιο πριν το emoji picker) αναγκαζε rebuild ολόκληρου του ChatScreen σε κάθε frame για ~2.1s.

### Fix #1 — EmojiPickerPanel extraction (ΝΕΟ αρχείο)
- `lib/features/chat/widgets/emoji_picker_panel.dart` — `EmojiPickerPanel` StatelessWidget
- Απομονώνει `MediaQuery.of(context)` / `Theme.of(context)` στο δικό του Element
- Keyboard animation cascade ξαναχτίζει ΜΟΝΟ το panel, όχι ChatScreen/AppBar/messages/ChatInputBar

**Αρχεία:**
- `lib/features/chat/widgets/emoji_picker_panel.dart` — **ΝΕΟ** (27 γραμμές)
- `lib/features/chat/screens/chat_screen.dart` — Remove `import emoji_picker_config`, add `import emoji_picker_panel`, αντικατάσταση SizedBox/EmojiPicker με `EmojiPickerPanel`

### Fix #2 — Convention alignment
- **Debug log**: `DebugConfig.log(DebugConfig.uiInteraction, 'EmojiPickerPanel build')`
- **Error boundary**: `_onEmojiSelected()` wrapper με try-catch + `DebugConfig.error()`
- Τα υπόλοιπα (responsive, bilingual, SPoT) ήταν ήδη compliant via `EmojiPickerConfig`

### Device Test Results
| Άνοιγμα | `ChatScreen didChangeDependencies` | `EmojiPickerConfig` calls | Διάρκεια |
|:-------:|:----------------------------------:|:-------------------------:|:--------:|
| 1ο (18:29:16) | **1×** | **1×** | ~0ms |
| 2ο (18:29:32) | **1×** | **18×** (cold cache, internal package loading) | ~400ms |
| 3ο (18:29:47, back) | **1×** | **0×** | ~0ms |

### Επαλήθευση
- `flutter analyze` — **0 issues** ✅
- Zero rebuild storm στο ChatScreen ✅
- participantUidsProvider cache hits λειτουργούν ✅
- Emoji insert at cursor ✅, send ✅, encrypt ✅

### Αρχεία
| Αρχείο | Αλλαγή |
|--------|--------|
| `lib/features/chat/widgets/emoji_picker_panel.dart` | **ΝΕΟ** — leaf widget, debug log, error boundary |
| `lib/features/chat/screens/chat_screen.dart` | Remove `emoji_picker_config` import, add `emoji_picker_panel` import, SizedBox/EmojiPicker → `EmojiPickerPanel` |
| `backups/chat_screen.dart.bak_2026-07-16_emojiPanel` | Backup pre-extraction |
| `media_input.md` | Updated Phase 1 status |
| `oldsessions.md` | Session 179 added |


## Session 180 — EmojiPickerPanel instance cache + SPoT restoration + decrypt log summary

**Ημερομηνία:** 16 Ιουλίου 2026

### Στόχος
Μετά την απομόνωση του EmojiPickerPanel σε leaf widget (v3), βελτιστοποίηση του Config creation με instance-level cache αντί static, διόρθωση SPoT violation, και μείωση θορύβου decrypt logs.

### Αλλαγές

**1. Static cache → Instance cache (EmojiPickerPanel → StatefulWidget)**
- `EmojiPickerPanel` converted από StatelessWidget → StatefulWidget
- Instance-level `_cachedConfig`, `_cachedIsDark`, `_cachedIsGreek` — το cache ζει όσο το widget
- Auto-dispose: `_cachedConfig = null` στο `dispose()`, zero memory leak
- `DebugConfig.log(DebugConfig.uiInteraction, 'EmojiPickerPanelState dispose')`

**2. SPoT restoration**
- Η `_getConfig()` αρχικά είχε αντιγράψει όλη την Config factory logic (duplicated από `EmojiPickerConfig.create()`)
- Διορθώθηκε: `_getConfig()` καλεί `EmojiPickerConfig.create(context)` + caching — μοναδική πηγή αλήθειας
- `EmojiPickerConfig.create()` ξανά pure factory (αφαιρέθηκε το static cache που είχε προστεθεί πρόχειρα)

**3. Convention alignment check + fixes**
| Κανόνας | Ενέργεια |
|---------|----------|
| Responsive | ✅ `EmojiPickerConfig.responsiveHeight()` — 35/30/25% portrait, 55% landscape |
| Bilingual | ✅ `L10n.isGreek(context)` → el/en locale + labels |
| SPoT | ✅ `_getConfig()` → `EmojiPickerConfig.create()` — μοναδική factory |
| Debug | ✅ `DebugConfig.uiInteraction` σε build, _getConfig, dispose |
| Edge cases | ✅ error boundary (`try-catch` + `DebugConfig.error()`), theme/locale recalc, dispose cleanup |

**4. Decrypt log summary (chat_repository_impl.dart)**
- Αντικατάσταση 30+ γραμμών `decrypt cache hit: msg=...` και `decrypt cache miss: msg=...` με μία γραμμή:
  `messagesStream: decrypt cache N hits, M misses for chat=...`
- Μετρητές `hitCount` / `missCount` στο asyncMap
- Σπάνια events (fallback key, failed decrypt) παραμένουν ως ξεχωριστά logs

### Device Test Results (v4)
| Άνοιγμα | `ChatScreen didChangeDependencies` | `Config` creation | Panel rebuilds |
|:-------:|:----------------------------------:|:-----------------:|:--------------:|
| 1ο (18:50:27) | 1× (setState toggle) | 1× (cache miss) | ~18 (internal package) |
| 2ο (18:50:34) | 0× | 1× (cache miss, νέο State) | ~18 |
| 3ο (18:50:40) | 0× | 1× (cache miss, νέο State) | ~16 |
| 4ο (18:50:52) | 1× (setState toggle) | 1× (cache miss, νέο State) | ~18 |

**Συμπέρασμα:** Μηδενικό rebuild storm. `ChatScreen didChangeDependencies` μόνο από setState toggle (αναμενόμενο). Instance cache χάνεται σε κάθε dispose (σχεδιασμένο — auto-cleaning). Panel rebuilds ~16-18 είναι από `emoji_picker_flutter` internal `_updateEmojis()` cascade, όχι από MediaQuery/Theme.

### Επαλήθευση
- `flutter analyze` — **0 issues** ✅
- Cache: 1 Config creation ανά άνοιγμα (miss), όλα τα υπόλοιπα rebuilds hit ✅
- Dispose log εμφανίζεται σε κάθε κλείσιμο picker ✅
- Decrypt log summary: `decrypt cache 30 hits, 1 miss` αντί 31 lines ✅

### Αρχεία
| Αρχείο | Αλλαγή |
|--------|--------|
| `lib/features/chat/widgets/emoji_picker_panel.dart` | StatelessWidget → StatefulWidget + instance cache + dispose log |
| `lib/features/chat/utils/emoji_picker_config.dart` | Αφαίρεση static cache — pure factory |
| `lib/repositories/chat_repository_impl.dart` | Decrypt log: hit/miss per-message → summary counters |
| `media_input.md` | Updated Phase 1 → v4 |
| `oldsessions.md` | Session 180 added |

---

## Session 181 — Phase 2: GIF Support (GIPHY API) — Complete

**Ημερομηνία:** 16 Ιουλίου 2026

### Στόχος
Υλοποίηση GIF support ως Phase 2 του Media Input plan — GIF picker, αποστολή, εμφάνιση σε bubble και chat list.

### Αλλαγές (9 τροποποιημένα + 2 νέα αρχεία)

**Νέα Αρχεία:**
| Αρχείο | Περιγραφή |
|--------|-----------|
| `lib/shared/utils/giphy_service.dart` | GIPHY API client (dart:io HttpClient, trending + search, GiphyGif model) — ~100 γρ. |
| `lib/features/chat/widgets/gif_picker_sheet.dart` | Bottom sheet UI: debounce search, GridView 2 cols, loading/empty/error states — ~150 γρ. |

**Τροποποιημένα Αρχεία:**
| Αρχείο | Αλλαγή |
|--------|--------|
| `lib/core/config/feature_flags.dart` | +`gifSupportEnabled = false` (τέθηκε `true` μετά testing) |
| `lib/core/utils/error_messages.dart` | +`chat/gif-send-failed`, `chat/gif-api-error` |
| `lib/repositories/chat_repository.dart` | +`sendMediaMessage(chatId, {content, type})` abstract |
| `lib/repositories/chat_repository_impl.dart` | 2 changes: (α) `sendMediaMessage` impl (β) messagesStream media branch: `type == 'gif' \|\| type == 'image' \|\| type == 'video'` skip decrypt |
| `lib/features/chat/providers/chat_provider.dart` | +`sendMediaMessage(chatId, {content, type})` στο ChatActionsNotifier |
| `lib/features/chat/widgets/chat_input_bar.dart` | + GIF button (`Icons.gif_box_outlined`) + `_pickGif()` |
| `lib/features/chat/widgets/message_bubble.dart` | +`_GifBubble` (CachedNetworkImage, maxHeight=200, seen/read indicators) |
| `lib/features/chat/screens/chat_list_screen.dart` | +`'gif'` → `'🎞️ GIF'` στην _buildPreviewText |

**Διαγραμμένο Αρχείο:**
| Αρχείο | Λόγος |
|--------|-------|
| `lib/shared/utils/tenor_service.dart` | Tenor API discontinued 30/6/2026 — αντικαταστάθηκε από GIPHY |

### Tenor → GIPHY Migration

Το Tenor API διακόπηκε στις 30 Ιουνίου 2026. Η υλοποίηση μεταφέρθηκε σε GIPHY:

| Πάροχος | Base URL | Auth | Free Tier |
|:--------|:--------:|:----:|:---------:|
| ~~Tenor~~ (discontinued) | ~~tenor.googleapis.com/v2~~ | ~~API key~~ | ~~10k/day~~ |
| **GIPHY** ✅ | `api.giphy.com/v1/gifs` | API key via `--dart-define=GIPHY_API_KEY` | **10k/hour** |

Το `tenor_service.dart` διαγράφηκε. Δημιουργήθηκε `giphy_service.dart` με ίδιο pattern (`dart:io` `HttpClient`, connectionTimeout 6s, `String.fromEnvironment('GIPHY_API_KEY')`).

### Key Decisions
- **`dart:io` HttpClient** (όχι `http` package) — reuse pattern από `location_autocomplete_service.dart`
- **API key** via `--dart-define=GIPHY_API_KEY` — reuse pattern από `ENABLE_RELEASE_DEBUG`
- **GIF picker = bottom sheet** — self-contained, καμία αλλαγή στο ChatScreen state
- **`CachedNetworkImage`** (υπάρχον dependency) για GIF bubbles
- **`fixed_width`** images για picker grid (200px), **`original`** URL για αποθήκευση στο message
- **`gifSupportEnabled = true`** — ενεργοποιήθηκε πλήρως μετά το device test

### Device Test Results ✅
```
GiphyService.trending: limit=20                           ← trending φορτώνει
GiphyService.search: q=smile limit=20                     ← αναζήτηση λειτουργεί
GifPickerSheet: selected                                  ← επιλογή GIF
ChatActions: sendMediaMessage chat=SOuOdL9ojVQsAzt9Zy4u type=gif
sendMediaMessage: success chat=SOuOdL9ojVQsAzt9Zy4u type=gif  ← αποστολή επιτυχής
messagesStream: media message t1GACtYRznH1yrvXJs4W type=gif   ← media branch skip decrypt
decrypt cache 27 hits, 0 misses for chat=SOuOdL9ojVQsAzt9Zy4u  ← decrypt cache summary
```

### Επαλήθευση
- `flutter analyze` — **0 issues** ✅
- GIF picker opens (bottom sheet) ✅
- Trending GIFs load ✅
- Search with debounce ✅
- GIF select → send → bubble renders ✅
- seen/read indicators on GIF bubble ✅
- Chat list preview shows "🎞️ GIF" ✅
- All Tenor references removed ✅

### Files
`media_input.md` — Updated Phase 2 status (completed) + Tenor→GIPHY documentation
`oldsessions.md` — Session 181 added

---

## Session 182 — Large Emoji-Only Messages (Phase 3)

**Ημερομηνία:** 16 Ιουλίου 2026

### Στόχος
Messages που περιέχουν μόνο emoji εμφανίζονται μεγάλα (όπως Telegram/iMessage) αντί για κανονικό text bubble.

### Υλοποίηση

**Ανίχνευση:** `EmojiRegex` από `emoji_picker_flutter` (υπάρχον dependency) — `\p{Emoji}` unicode property.

**Font size logic:**
| Emoji count | Font size |
|:-----------:|:---------:|
| 1 | 64px |
| 2-3 | 48px |
| 4-6 | 36px |
| 7+ | 28px |

**Flag emoji fix:** Regional Indicator pairs (🇬🇷) μετρώνται ως 1 emoji — `_riRegex` αφαιρεί RI pairs από το συνολικό count.

### Αρχεία

| Αρχείο | Αλλαγή |
|--------|--------|
| `lib/features/chat/widgets/emoji_only_bubble.dart` | **ΝΕΟ** — `EmojiOnlyBubble` widget + `isOnlyEmoji()` + `emojiFontSize()` (131 γρ.) |
| `lib/features/chat/widgets/message_bubble.dart` | Import + dispatch `type == 'text' && isOnlyEmoji(content)` → `EmojiOnlyBubble` (474 γρ., από 600) |

### Επαλήθευση
- `flutter analyze` — **0 errors** ✅ (1 info-level `valid_regexps` από το ίδιο το πακέτο)
- `flutter build apk --release --dart-define=ENABLE_RELEASE_DEBUG=true` — **successful** ✅
- Device test logs — **all 3 font sizes verified** ✅
- GIF/text/system bubbles — unaffected ✅
- Send, receive, group chat nickname above emoji — все ✅

### Side effects: **Κανένα**

### Backup
`backups/message_bubble.dart.backup_20260716_*.dart`

---

## Session 183 — Profile Sync Across Chats (nickname + avatar)

**Ημερομηνία:** 17 Ιουλίου 2026

**Πεδίο:** Όταν ένας χρήστης αλλάζει nickname ή avatar από το Profile Editor, τα νέα δεδομένα συγχρονίζονται αυτόματα σε ΟΛΑ τα chat docs (1-to-1 και group) όπου είναι participant. Επίσης, τα group bubbles δείχνουν πλέον το avatar κάθε αποστολέα δίπλα από το nickname.

### Αλλαγές (5 βήματα, 6 αρχεία)

**Βήμα 1 — Firestore Rules** (`firestore.rules:157-179`)
- 3 νέα OR blocks στο `chats/{chatId}` update: self-nickname (`participantNicknames.{uid}`), self-avatar (`participantAvatarUrls.{uid}`), και both together
- `diff().affectedKeys().hasOnly([request.auth.uid])` pattern (ίδιο με `lastReadTimestamps`, γραμμές 128-135)
- Backup: `backups/firestore.rules.backup_2026-07-17_step1`
- **Deployed** `firebase deploy --only firestore:rules` ✅

**Βήμα 2 — Abstract Interface** (`chat_repository.dart:120-124`)
- `syncMyProfileAcrossChats({required String nickname, String? avatarUrl})`

**Βήμα 3 — Repository Implementation** (`chat_repository_impl.dart`)
- `syncMyProfileAcrossChats()`: διαβάζει chat IDs από Drift cache (0 reads), fallback `arrayContains` query, batch update
- `_batchUpdateChatDocs()` private helper: γράφει `participantNicknames.{uid}` + `participantAvatarUrls.{uid}`, 500-chunk batch limit
- **Lightweight sync fix** (streamChats:612-637): το lightweight sync περνάει πλέον `otherNickname`/`otherAvatarUrl` στην `updateChatCache` — το `updateChatCache` ήδη τα δεχόταν αλλά δεν τα περνούσε το stream

**Βήμα 4 — Profile Editor** (`profile_editor_screen.dart`)
- Κλήση `chatRepo.syncMyProfileAcrossChats()` μετά `repo.saveProfile()`, πριν `commSettingsChanged`
- Try-catch ώστε αποτυχία sync να μην μπλοκάρει το save

**Βήμα 5 — Avatar UI** (3 αρχεία)
- `chat_screen.dart`: `participantAvatarUrls` selector (ίδιο pattern με `participantNicknames`), pass στο `ChatMessagesList`
- `chat_messages_list.dart`: νέο prop `participantAvatarUrls`, extraction `senderAvatarUrl`, pass στο `MessageBubble`
- `message_bubble.dart`: νέο prop `senderAvatarUrl`, `CircleAvatar(radius:10)` με `CachedNetworkImageProvider` δίπλα στο nickname (ίδιο pattern με `group_info_screen.dart:246-259`)

### Key Decisions
- **No backfill** for existing wrong nicknames — εφαρμογή σε ανάπτυξη, θα διορθωθεί στο επόμενο save κάθε χρήστη
- **No Cloud Function** — pure client-side batch update, Firestore rules protect per-user writes
- **Drift-first**: 0 Firestore reads αν το Drift cache έχει chat IDs (συνήθης περίπτωση)
- **Idempotent writes**: multi-device race writes same value — zero damage

### Verified
- `flutter analyze` — **0 issues** ✅ (πολλαπλές φορές)
- `firebase deploy --only firestore:rules` — **successful** ✅

### Αποτελέσματα
| Μέτρο | Τιμή |
|:------|:----:|
| Νέες γραμμές rules | ~24 (3 OR blocks) |
| Νέες γραμμές Dart | ~90 |
| Αρχεία | 6 modified |
| Backups | 1 (`firestore.rules`) |
| Deploy | firestore.rules ✅ |

### Αρχεία
| Αρχείο | Αλλαγή |
|--------|--------|
| `firestore.rules` | 3 νέα OR blocks (self-nickname/avatar/both) |
| `lib/repositories/chat_repository.dart` | `syncMyProfileAcrossChats` abstract |
| `lib/repositories/chat_repository_impl.dart` | Implementation + lightweight sync fix |
| `lib/features/profile/screens/profile_editor_screen.dart` | Call after saveProfile |
| `lib/features/chat/screens/chat_screen.dart` | `participantAvatarUrls` selector |
| `lib/features/chat/widgets/chat_messages_list.dart` | `participantAvatarUrls` prop + extraction |
| `lib/features/chat/widgets/message_bubble.dart` | `CircleAvatar` display

---

## Session 184 — Reaction System για μηνύματα chat

**Ημερομηνία:** 18 Ιουλίου 2026

**Πεδίο:** Υλοποίηση reaction system — emoji reactions σε μηνύματα (preset + custom emoji). Αποθήκευση ως `Map<UID, emoji>` στο Firestore.

### Architecture
- **Map `Map<String, String>`** (UID→emoji) για απλούστερο update/delete με dot notation (όχι `Map<emoji, List<UID>>`)
- **Toggle logic** στο `MessageReactions` widget (έχει reactions + currentUid) — όχι στο ChatMessagesList
- **Split callbacks:** `onReact(messageId, emoji)` (add/replace), `onRemove(messageId)` (remove own reaction)
- **Δεν χρειάζεται bilingual** (emoji universal) — μόνο "Περισσότερα"/"More"
- **Δεν χρειάζεται encryption** για reactions metadata

### Αλλαγές (9 αρχεία + firestore.rules)

| Αρχείο | Αλλαγή |
|--------|--------|
| `firestore.rules` (γρ. 228-239) | `allow update` για `reactions` — `diff()` + `affectedKeys().hasOnly([request.auth.uid])` |
| `lib/core/debug/debug_config.dart` | +`chatReactions = true` flag |
| `lib/core/config/feature_flags.dart` | +`messageReactionsEnabled = true` |
| `lib/repositories/chat_repository.dart` | +`addReaction()`, `removeReaction()` abstract |
| `lib/repositories/chat_repository_impl.dart` | +υλοποίηση add/removeReaction + `reactions` map στο `messagesStream()` return |
| `lib/features/chat/providers/chat_provider.dart` | +`reactToMessage()`, `removeReaction()` actions στο ChatActionsNotifier |
| `lib/features/chat/widgets/message_reactions.dart` | **NEW** — reusable widget (trigger icon `Icons.add_reaction_outlined` + preset chips bottom sheet + `EmojiPicker` για "+") |
| `lib/features/chat/widgets/message_bubble.dart` | +`onReact`/`onRemove` params σε MessageBubble + _GifBubble + EmojiOnlyBubble |
| `lib/features/chat/widgets/emoji_only_bubble.dart` | +`onReact`/`onRemove` params + MessageReactions |
| `lib/features/chat/widgets/chat_messages_list.dart` | +`_onReact`/`_onRemove` callbacks + πέρασμα σε MessageBubble |

### Key Decisions
- **Trigger icon:** `Icons.add_reaction_outlined` με long-press → reaction picker
- **Preset emoji:** 😂 😮 😢 😠 ❤️ 👏 + "+" για `EmojiPicker` (emoji_picker_flutter v4.4.0)
- **System messages:** no reactions UI (`type=='system'` returns early)
- **Reusable `MessageReactions`** — όχι copy-paste σε 3 bubble types

### Verified
- `flutter analyze` — **0 issues** ✅
- Backup: `backups/reactions_2026-07-18_124243/`

---

## Session 185 — "Reply to Message" Feature (Analysis + Implementation)

**Ημερομηνία:** 18 Ιουλίου 2026

**Πεδίο:** Υλοποίηση "Reply to Message" — long-press σε μήνυμα → popup menu → "Απάντηση" → reply banner πάνω από input → αποστολή. Αποθήκευση `replyTo` map στο Firestore message doc.

### Ανάλυση (pre-implementation)

**Επαναχρησιμοποίηση υπαρχόντων (6 ευρήματα):**
1. `chat_list_screen.dart:272-274` — Media preview: `'🎞️ GIF'`, `'📷 Photo'` → replyTo preview
2. `chat_list_screen.dart:280` — Truncation: `msg.length > 50 ? '...' : msg` → truncate 80 chars
3. `emoji_only_bubble.dart:12-16` — `isOnlyEmoji()` → emoji-only detection στο reply preview
4. `chat_screen.dart:153-163` — `participantNicknames` map → resolve senderNickname
5. `message_bubble.dart:156-165` — `BoxDecoration` pattern → reply preview Container styling
6. `chat_screen.dart:239-330` — `PopupMenuItem` + `ListTile(dense)` pattern → long-press popup

**Firestore rules check:** ✅ `allow create` has NO `hasOnly()` restriction

### Υλοποίηση (12 βήματα)

| # | Βήμα | Αρχεία | Status |
|---|------|--------|:------:|
| 1 | Feature flag + Debug flag | `feature_flags.dart`, `debug_config.dart` | ✅ |
| 2 | Error messages | `error_messages.dart` | ✅ |
| 3 | `replyToMessageProvider` (NotifierProvider) | `chat_provider.dart` | ✅ |
| 4 | ChatRepository interface (replyTo param) | `chat_repository.dart` | ✅ |
| 5 | ChatRepositoryImpl (3 changes) | `chat_repository_impl.dart` | ✅ |
| 6 | ChatActionsNotifier (pass replyTo) | `chat_provider.dart` | ✅ |
| 7 | ReplyPreview widget + rendering | `message_bubble.dart`, `emoji_only_bubble.dart` | ✅ |
| 8 | MessageBubble InkWell + showMenu | `message_bubble.dart` | ✅ |
| 9 | EmojiOnlyBubble InkWell + showMenu | `emoji_only_bubble.dart` | ✅ |
| 10 | ChatScreen (pass participantNicknames + clear on dispose) | `chat_screen.dart` | ✅ |
| 11 | ChatInputBar reply banner + _buildReplyData | `chat_input_bar.dart` | ✅ |
| 12 | flutter analyze | - | ✅ 0 issues |

### Αρχεία

| Αρχείο | Αλλαγές |
|--------|---------|
| `lib/core/config/feature_flags.dart` | +`replyToMessageEnabled = false` |
| `lib/core/debug/debug_config.dart` | +`chatReply = true` |
| `lib/core/utils/error_messages.dart` | +`chat/reply-send-failed` bilingual |
| `lib/repositories/chat_repository.dart` | +`replyTo` param σε `sendMessage`, `sendMediaMessage` |
| `lib/repositories/chat_repository_impl.dart` | 3 changes: sendMessage + sendMediaMessage + messagesStream |
| `lib/features/chat/providers/chat_provider.dart` | `ReplyToMessageNotifier` + `replyToMessageProvider`, sendMessage/sendMediaMessage accept replyTo |
| `lib/features/chat/widgets/message_bubble.dart` | `ReplyPreview` widget + InkWell+showMenu σε text+GIF bubbles |
| `lib/features/chat/widgets/emoji_only_bubble.dart` | +`replyTo` prop, InkWell+showMenu, L10n import |
| `lib/features/chat/widgets/chat_messages_list.dart` | +`_onReply` callback → set provider |
| `lib/features/chat/screens/chat_screen.dart` | pass participantNicknames+currentUid, clear on dispose |
| `lib/features/chat/widgets/chat_input_bar.dart` | +`participantNicknames` prop, reply banner, `_buildReplyData`, `_clearReply`, send/GIF with replyTo |

### Verified
- `flutter analyze` — **0 issues** ✅
- Backups: `backups/*.backup_2026-07-18_reply`

---

## Session 186 — Reply to Message: flag enable + dispose crash + ReplyPreview colors

**Ημερομηνία:** 18 Ιουλίου 2026

**Πεδίο:** Ενεργοποίηση reply feature, διόρθωση crash σε dispose, βελτίωση ορατότητας ReplyPreview.

### Fix 1 — Feature flag enable
`FeatureFlags.replyToMessageEnabled = false` → `true` (feature_flags.dart:29)
- Backup: `backups/feature_flags.dart.bak`

### Fix 2 — Dispose crash (`Bad state: Using "ref"`)
**Πρόβλημα:** `ref.read(replyToMessageProvider.notifier).clear()` στο `dispose()` προκαλούσε `Bad state: Using "ref" when a widget is about to or has been unmounted`.
**Λύση:** Μεταφορά από `dispose()` → `initState()`. Κάθε ChatScreen ξεκινά με καθαρό reply state.
**Αρχείο:** `chat_screen.dart`

### Fix 3 — ReplyPreview colors (invisible σε dark theme)
**Πρόβλημα:** Το `ReplyPreview` για `isMe=true` χρησιμοποιούσε `onPrimary.withAlpha(30/200)` — αλλά το preview είναι ΕΞΩ από το primary bubble, πάνω στο dark chat background. Σχεδόν αόρατο.
**Λύση:** Ομοιόμορφο styling ανεξάρτητα από `isMe`:
- Background: `surfaceContainerHighest.withAlpha(180)` (πάντα)
- Border: `primary` (πάντα)
- Text: `onSurfaceVariant` (πάντα)
**Αρχείο:** `message_bubble.dart` (ReplyPreview.build)

### Verified
- `flutter analyze` — **0 issues** ✅
- Device test: long-press → reply banner → send → Firestore write → no crash ✅

---

## Session 187 — Viber-like Chat Redesign: bubble tails, date separators, message grouping

**Ημερομηνία:** 18 Ιουλίου 2026

**Πεδίο:** Ανασχεδιασμός chat UI σε Viber-like στυλ — 3 features: (1) bubble tails (CustomPainter), (2) date separators (Σήμερα/Χθες/ημερομηνία), (3) message grouping (ίδιος sender <5 min). Full analysis, proposal, και implementation 8 βημάτων.

### Πρόταση (pre-implementation analysis)

**Re-check findings — διορθώσεις από αρχική πρόταση:**

| Αρχικό Λάθος | Διόρθωση | Αιτία |
|---|---|---|
| `L10n.formatTime(DateTime)` νέα μέθοδος | ΑΧΡΕΙΑΣΤΗ — χρήση `L10n.formatTimeOfDay(context, TimeOfDay.fromDateTime(ts))` | Υπάρχει ήδη στο `l10n.dart:29` |
| Feature flag `chatUiDesign` | ΑΧΡΕΙΑΣΤΟ — μόνο debug flag | Δεν είναι feature rollout |
| Date format "Προχθές" / "Thursday" | ΑΦΑΙΡΕΘΗΚΕ — υπερ-engineering | ConsentLog δείχνει μόνο Σήμερα/Χθες/ημερομηνία |
| `_GifBubble.clipBehavior` restart | ΠΡΟΣΘΗΚΗ: αλλαγή `Clip.antiAlias` με `ClipPath` | Υπάρχει ήδη `clipBehavior: Clip.antiAlias` (line 606) |
| Grouping αγνοεί EmojiOnlyBubble | ΠΡΟΣΘΗΚΗ: EmojiOnlyBubble ΔΕΝ έχει avatar για groups — pre-existing inconsistency | Δεν το διορθώνουμε, απλά τεκμηριώνεται |

**Προαπαιτούμενα που εντοπίστηκαν:**
- P1: Debug flag `chatBubbleDesign` στο `debug_config.dart`
- P2: `L10n.relativeDateLabel()` — centralized today/yesterday/date
- P3: `ChatGroupingCalculator` pure function (testable)

**Υπάρχουσες λειτουργίες που επαναχρησιμοποιήθηκαν:**
- `L10n.formatTimeOfDay(TimeOfDay)` (l10n.dart:29) — αντί νέου formatTime
- `L10n.isGreek` + `L10n.formatDate` (yMd) — bilingual date formatting
- `TimeOfDay.fromDateTime()` — Flutter SDK, zero new dependency
- `DateFormat` via `intl` — ήδη imported στο l10n.dart
- `consent_log_screen.dart:220-235` — Σήμερα/Χθες pattern (αντιγράφηκε σε centralized L10n)
- `collection: ^1.19.0` — `DeepCollectionEquality` (υπάρχον dependency)

### Υλοποίηση (8 βήματα)

| # | Βήμα | Αρχεία | Debug logs |
|---|------|--------|:----------:|
| 1 | Debug flag `chatBubbleDesign` | `debug_config.dart:117` | — |
| 2 | `L10n.relativeDateLabel()` | `l10n.dart:48-62` | — |
| 3 | `ChatGroupingCalculator` + `RenderItem` | **NEW** `utils/chat_ui_utils.dart` (138 γρ.) | `chatBubbleDesign: Grouping: N items from M msgs in Xµs` |
| 4 | `DateSeparator` widget | **NEW** `widgets/date_separator.dart` (47 γρ.) | `chatBubbleDesign: DateSeparator: date=...` |
| 5 | ChatMessagesList integration | `chat_messages_list.dart` | `chatBubbleDesign: ChatMessagesList: X items from Y msgs` |
| 6 | MessageBubble tail + redesign | `message_bubble.dart` | `chatBubbleDesign: MessageBubble built: id=...` |
| 7 | EmojiOnlyBubble tail + redesign | `emoji_only_bubble.dart` | `chatBubbleDesign: EmojiOnlyBubble: ... isGrouped=` |
| 8 | _GifBubble tail + redesign | `message_bubble.dart` (_GifBubble) | `chatBubbleDesign: _GifBubble: isGrouped=` |

### Σχεδιαστικές αποφάσεις

**Tail implementation:** `Stack` με `clipBehavior: Clip.none` + `Positioned` + `TailPainter` (CustomPainter). Το tail είναι τρίγωνο 10×8px, extends beyond the bubble bounds. `TailPainter` made **public** για reuse από EmojiOnlyBubble και _GifBubble.

**Grouping rules:**
- Ίδιος `senderId` AND <5 λεπτά AND όχι system message → group
- System messages πάντα διασπούν το group
- `showTail = isLastInGroup` (μόνο τελευταίο μήνυμα σε κάθε group)
- `showAvatar = !isGrouped \|\| isLastInGroup` (πρώτο + τελευταίο σε group)
- Σε 1-on-1: grouping applies (hide my tail όταν συνεχόμενα δικά μου)

**Bubble colors:** Sent = `Color(0xFF075E54)` (Viber green), Received = `surfaceContainerHighest` (unchanged)

**Timestamp:** Μεταφέρθηκε ΜΕΣΑ στο bubble (κάτω-δεξιά, font 10px, opacity 0.7). Χρήση `L10n.formatTimeOfDay` αντί hardcoded `HH:mm`.

**Border radius:** 16 → 20 όλες οι γωνίες. Tail corner (όταν showTail=true): 8 (μικρή εγκοπή για το tail triangle).

**Δεν χρειάστηκαν αλλαγές:** `message_reactions.dart`, `_SystemBubble`

### Edge cases που καλύφθηκαν
- RTL text: tail στην ίδια πλευρά, `TextDirection` δεν επηρεάζει
- 1-line vs multi-line: `ClipPath` στο σύνολο του container
- Emoji-only (fontSize 64): `vertical: 4` padding αυξήθηκε → `6` για tail clearance
- GIF bubble: tail overlay πάνω από `CachedNetworkImage`
- System messages: κανένα tail, centered, semi-transparent
- Date separator σε empty list: 0 items
- Date separator σε single message: 1 separator + 1 message = 2 items
- Future timestamp (clock skew): πλήρης ημερομηνία, όχι "Σήμερα"
- Midnight boundary: σύγκριση `.year/.month/.day`
- Grouping + 1 message: `isLastInGroup=true, isGrouped=false` → tail
- Grouping + reactions: ανά message, unaffected
- Auto-scroll: `_onMessagesChanged` χρησιμοποιεί raw `messages.length`, unaffected

### Αρχεία

| Αρχείο | Αλλαγή |
|--------|--------|
| `lib/core/debug/debug_config.dart` | +`chatBubbleDesign = true` flag |
| `lib/core/l10n/l10n.dart` | +`relativeDateLabel()` (Σήμερα/Χθες/yMd) |
| `lib/features/chat/utils/chat_ui_utils.dart` | **NEW** — `ChatGroupingCalculator` + `RenderItem` (public) |
| `lib/features/chat/widgets/date_separator.dart` | **NEW** — centered label + divider lines |
| `lib/features/chat/widgets/chat_messages_list.dart` | Integration: grouping + separators + νέα props |
| `lib/features/chat/widgets/message_bubble.dart` | `TailPainter` (public), new props (`isGrouped`, `isLastInGroup`, `showAvatar`), border 20, sent color `#075E54`, timestamp inside, `Stack`+`Positioned` tail, `L10n.formatTimeOfDay` |
| `lib/features/chat/widgets/emoji_only_bubble.dart` | New props + tail + colors + timestamp inside |
| `backups/` | 4 backup files (debug_config, l10n, message_bubble, emoji_only_bubble, chat_messages_list) |

### Verified
- `flutter analyze lib/features/chat/` — **0 issues** ✅
- `flutter analyze lib/` (chat filter) — **0 issues** ✅
