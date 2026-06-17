# NearMe — Old Sessions Archive (Καθαρισμένο)

> **4893 γραμμές → ~800 γραμμές.** Κρατήθηκαν: αρχιτεκτονικές αποφάσεις, milestones, σημαντικά bugs/fixes, migrations. Αφαιρέθηκαν: γραμμές κώδικα ανά αρχείο, backup logs, repetitive compliance lists, code snippets.

---

## Τεχνολογίες (Resolved — Μάιος 2026)

| Layer | Επιλογή |
|---|---|
| State Management | Riverpod 3.x (Notifier/AsyncNotifier, @riverpod) |
| Local DB | Drift 2.33 (SQLite), μετανάστευση από Isar 3.1 (Session 48–49) |
| Navigation | GoRouter 17 (StatefulShellRoute, adaptive nav) |
| Cloud Auth | Firebase Authentication (Anonymous → Email link) |
| Cloud DB | Firestore (real-time, security rules) |
| Cloud Storage | Firebase Storage (avatars/photos, JPEG, max 5MB) |
| Cloud Functions | Firebase Functions (TypeScript, 1st Gen, us-central1/europe-west1) |
| Encryption | encrypt 5.0.3 (AES-256 GCM) + deriveKey (SHA-256) |
| Secure Storage | flutter_secure_storage (encryption keys) |
| Geo | geolocator + geoflutterfire_plus + geocoding (reverse) |
| Search v1 | Firestore native (collectionGroup, composite indexes) |
| Search v2 | Typesense self-hosted (Phase 4+, stub exists) |
| Video Calls | Agora RTC (Phase 4) |
| Push | Firebase Cloud Messaging (3 Cloud Functions) |
| i18n | flutter_localizations + intl (el/en, `L10n` utility) |
| Code gen | freezed 3.x, json_serializable, riverpod_generator, drift_dev |
| Biometric | local_auth 3.0 (installed, runtime pending) |

---

## Αρχιτεκτονικές Αποφάσεις (Resolved)

### Απόφαση Α: Authentication — Anonymous + Lazy Upgrade
- Χρήστης ξεκινά ανώνυμος (Firebase Anonymous Auth)
- Upgrade σε verified (email/phone) μόνο όταν θελήσει να επικοινωνήσει
- `Session 34`: Προστέθηκε Welcome Screen για returning verified users (signIn/signUp/browse)
- `Session 57`: AnonymousInfoScreen (5s splash με informative μήνυμα)

### Απόφαση Β: Γεωγραφία — GPS με fallback manual
- GPS permission → lat/lng στο Drift (ΠΟΤΕ raw lat/lng στο Firestore)
- GeoHash μόνο στο Firestore με precision levels: city/neighborhood/hidden
- Fallback: text field για χειροκίνητη εισαγωγή πόλης/περιοχής
- `Session 44`: Reverse geocode (geocoding package) → auto city/country από GPS

### Απόφαση Γ: Search — Υβριδικό (Repository Pattern)
- Φάση 1 (0-5k users): Firestore native + composite indexes
- Φάση 2 (5k+): Typesense self-hosted (Phase 4)
- Abstract `SearchRepository` interface — swap χωρίς UI changes
- `Session 65`: Server-side filters + cursor pagination

### Security Architecture (5-Layer Model)
1. **Device**: Drift + flutter_secure_storage + FLAG_SECURE (Session 58) + auto-lock pending
2. **Auth**: Anonymous → Email verify, silent token refresh, force refresh on token issues (Session 68)
3. **Data Rules**: Firestore Security Rules (~90% coverage)
4. **Transport**: TLS 1.3 + AES-256 E2E chat encryption (deriveKey deterministic)
5. **Behaviour**: Rate limiting (10 reports/hr), auto-ban (5 reports), request expiry (48h)

### Data Architecture
```
ΚΙΝΗΤΟ (Drift/SQLite) ←→ FIREBASE (Cloud)
────────────────               ────────────────────────
UserProfile (full, 23 fields) → users/{uid}/public/profile (visible only)
PrivacySettings (14 toggles)   → users/{uid}/status (isOnline, lastSeen)
ConsentLog (local only)        → chats/{chatId}/messages (AES-256 encrypted)
ChatCache (sync'd)             → requests/{reqId}
SavedSearch (local only)       → reports/{reportId}
AppSettings (local only)       → users/{uid}/blocked/{blockedUid}
BlockedUser (sync'd)           → users/{uid}/fcm_tokens/{tokenId}
```

### Repository Pattern
- 7 abstract interfaces: Auth, Profile, Search, Chat, Request, Block, Report
- Implementation swap χωρίς UI changes (FirestoreSearch ↔ TypesenseSearch)
- **Ποτέ raw Firestore στο UI** — όλα pass από repository layer

---

## Φάσεις Υλοποίησης & Πρόοδος

### Φάση 1 — Core & Privacy (~100%, 24/24)
- ✅ Firebase Init + Anonymous Auth
- ✅ Local DB (Drift, 7 tables, schema v3)
- ✅ UserProfile CRUD (23 πεδία, 7 lookingFor options, lat/lng only local)
- ✅ PrivacySettings (14 toggles → 12 toggles, conservative defaults)
- ✅ Communication settings: Video Call + Direct Chat only in Profile Editor (removed from Privacy Editor)
- ✅ ConsentLog (GDPR, local-only, UI με φίλτρα)
- ✅ Publish/Unpublish (Firestore privacy-respecting)
- ✅ GPS + GeoHash (precision levels) + reverse geocode
- ✅ i18n (el/en, auto-detect, formatters, `L10n` utility)
- ✅ Dark/Light Theme (system mode)
- ✅ Firestore Security Rules + 9 composite indexes + `$(database)` fix (Session 72)
- ✅ Repository Pattern (7 abstract interfaces)
- ✅ Unified Error Handling (AppMessenger + AppStateWidgets)
- ✅ Shared Widgets (10+ widgets + utils + models)
- ✅ BlockedUser (local + Firestore sync)
- ✅ Report User + Auto-ban Cloud Function (6-step validation)
- ✅ Delete Account (local + cloud cleanup, requires-recent-login reauth)
- ✅ Screenshot Prevention (FLAG_SECURE, MethodChannel)
- ✅ Biometric Lock (runtime + overlay + lifecycle, Session 73)
- ✅ Feature flags (P3.1, 8 flags from blueprint)
- ✅ Biometric Lock (P3.5, runtime + overlay + lifecycle)
- ⏳ Auto-lock timer (P3.6)

### Φάση 2 — Discovery (100%)
- ✅ Firestore Search (collectionGroup, composite indexes)
- ✅ SearchFilters (freezed model + full UI, 15 interests)
- ✅ ProfileCard results (responsive Wrap → ListView, lookingFor badge)
- ✅ PublicProfile view (all visible fields, live stream)
- ✅ Saved Searches CRUD
- ✅ Block User (stream-based, search exclusion)
- ✅ Report User UI (shared widget)
- ✅ Auto-ban Cloud Function (6-step validation)
- ✅ Cursor pagination + 300-result cap (Session 65)
- ✅ Server-side filters (moved from client-side `_passesFilters`)
- ✅ Typesense stub proper `implements SearchRepository` (Session 74)

### Φάση 3 — Communication (~92%, 10/11)
- ✅ Verify Account / Welcome Screen (email/password link)
- ✅ Request System (send, accept/decline, 48h expiry, multi-delete)
- ✅ Request→Chat Flow (auto-create chat on accept)
- ✅ E2E Encrypted Chat (AES-256 GCM, deriveKey deterministic)
- ✅ Online Presence (heartbeat 60s, lifecycle-aware)
- ✅ Read Receipts (double-check marks)
- ✅ FCM: New Message + New Request + Accept/Decline (3 CFs, locale-aware)
- ✅ Rate Limiting (reports: 10/hour)
- ✅ Chat preview + unread count (encrypted lastMessage in chat doc)
- ✅ E2E encryption indicator (lock icon, tap dialog)
- ✅ Anonymous guards (block requests/messages/block/report, data leakage fix)
- ⏳ Phone verification (P2.5, SMS)

### Φάση 4+ (0% — planned)
- Typesense search, Video calls (Agora), AI matching, Groups, Verified badge, Premium, Web, Admin panel

---

## Milestones & Key Sessions

| Session | Milestone |
|---|---|
| 1 | Project init + Blueprint approval |
| 2 | Package selection + Isar dependency resolution (161 deps) |
| 3 | DebugConfig (33 flags, 3 levels) |
| 5 | Build fix: compileSdk 36 for isar_flutter_libs compat |
| 7 | Core infrastructure: IsarService, abstractions, shared widgets |
| 9 | GoRouter + adaptive shell (NavigationRail/NavigationBar) |
| 10–20 | Φάση 1 complete: Profile, Privacy, GPS, ConsentLog, Delete, Security Rules |
| 21–22 | FirestoreSearchRepository + SearchProvider |
| 23 | Codebase audit: extracted GradientHeader, SaveButton, ConsentActionConfig, L10n.isGreek |
| 24 | Discovery Screen + Search Filters UI |
| 25 | Firestore rules debug: collectionGroup rule + indexes deploy |
| 27 | PublicProfileViewScreen + L10n centralized labels |
| 28 | Block User feature (Isar + Firestore sync, full UI) |
| 30 | Verify Account (email/password link) |
| 31 | Report + Auto-ban Cloud Function + Blaze upgrade |
| 34 | Welcome Screen + email signIn/signUp + Router redirect fix |
| 37 | Requests Dashboard + Send Request + Firestore index fixes |
| **39** | **Firestore Rules Engine bugs discovered**: `$(database)` breaks `get()` paths, `.exists` causes permission-denied |
| 40 | AES-256 Chat Backend + Chat List + Chat Screen UI |
| 41 | FCM Push (3 CFs + foreground/background/killed handlers) |
| 42–43 | Online Presence + lifecycle-aware + live status provider |
| 44 | Photo Upload (avatar + gallery, Firebase Storage, reverse geocode) |
| **45–47** | **Real-time audit**: 4 gaps closed (PublicProfile, ChatList, Requests, ProfileScreen → all StreamProvider) |
| **48–50** | **Isar→Drift migration**: 7 tables, 5 repos, + Riverpod 2→3 (StateNotifier→Notifier) |
| 51 | Auto-create Privacy Settings on profile creation |
| 52 | Request→Chat Flow (auto-create chat on accept) |
| 53 | FCM Request notification CF |
| **55** | **deriveKey fix**: deterministic AES-256 key from chatId (cross-device compat, no Firestore storage) |
| 56 | Chat delete/clear, Request multi-delete, Drift duplicate fix, splash + app icon |
| **57–58** | **P1 Security fixes**: Block anonymous from requests/messages/block/report + FLAG_SECURE |
| **60** | **Block detection fix**: Firestore rule asymmetric + AppException.auth signature + L10n.localizedMessage |
| 61 | Language uniformity: 19 files, 70+ messages → bilingual pattern |
| 63–64 | FCM localization: `lang` field in public profile, locale-aware CF notifications |
| **65** | **Search pagination**: server-side filters + cursor pagination + 300-result cap |
| 66 | Chat preview (encrypted lastMessage in chat doc) + unread count badge |
| 67 | E2E encryption indicator (lock icon + tap dialog) |
| **68** | **`notBanned()` fix**: custom claims → Firestore doc exists (cached token unreliability) |
| **69** | **Comm settings cleanup**: removed duplicate Video Call/Direct Chat from Privacy Editor; publish() reads from UserProfile |
| **69** | **Anonymous UX fix**: ProfileScreen + ChatListScreen verification banners; streamChats() yields `[]` for anonymous |
| **69** | **LookingFor options**: +3 (exchange/help/employment) in l10n, editor, filters + badge in ProfileCard |
| **70** | **Chat rebuild loop fix**: page keys, smart auth notifier, Firestore rules + batch pagination |
| **72** | **Feature Flags (P3.1)**: 8 flags populated from blueprint §14 (typesense, videoCall, groupChat, aiMatching, verifiedBadge, premium, groupEvents, webVersion) — stub → πλήρες |
| **72** | **Security Rules (P3.9)**: 8× `(default)` → `$(database)` σε helpers (notBanned, isNotBlockedInChat, isNotBlockedByTarget, targetCommAllowed, inline gets) — multi-db safe πλέον |
| **73** | **Biometric Lock (P3.5)**: LockScreen widget + provider toggle + lifecycle hooks + iOS NSFaceIDUsageDescription + Android USE_BIOMETRIC |
| **74** | **Typesense stub (P3.7)**: `implements SearchRepository` + override methods with `UnimplementedError` — safe για compile όταν γίνει swap |

---

## Critical Bugs & Discoveries

| # | Bug | Discovered | Fix |
|---|---|---|---|
| 1 | `$(database)` σε `get()` paths → permission-denied | Session 39 | Hardcode `(default)` |
| 2 | `get(path).exists` → permission-denied (Firestore Rules engine bug) | Session 39 | Use `.data.isVisible == true` (null == true → false) |
| 3 | startup jank: 92 skipped frames | Session 17 | All init in `addPostFrameCallback`, splash with AnimatedSwitcher |
| 4 | `StreamProvider.valueOrNull` removed in Riverpod 3.x | Session 50 | `.value` returns `T?` directly |
| 5 | Encryption key missing on 2nd device join chat | Session 55 | `deriveKey(chatId)` — deterministic SHA-256 key |
| 6 | Drift duplicate rows: `getSingleOrNull()` crash | Session 56 | `get()` + cleanup duplicates |
| 7 | `notBanned()` with custom claims → stale token cache | Session 68 | Changed to `!exists(banned/{uid})` live Firestore read |
| 8 | `requires-recent-login` on deleteAccount | Session 38 | 3-level fix: optional password param → reauth dialog |
| 9 | Anonymous infinite spinner in chats | Session 68+ | `streamChats()` yields `[]` instead of bare `return` |
| 10 | PrivacySettings null on publish → missing geoHash | Session 51 | `_ensurePrivacySettings()` auto-create defaults |
| 11 | GoRouter redirect not firing after auth change | Session 34 | `refreshListenable: _AuthChangeNotifier` |
| 12 | Video Call / Direct Chat duplicates in Profile Editor + Privacy Editor | Session 69 | Removed from Privacy Editor; publish() reads from UserProfile |
| 13 | ChatScreen rebuild loop: messagesProvider recreated 5× in 4s — GoRouter page no key + authNotifier on token refresh | Session 70 | Page keys (`ValueKey`) in `_slideUp`/`_modal`; smart notifier filters token refresh; Firestore rules `isParticipant`; batch chunk pagination |
| 14 | `isPublished: false` hardcoded in ProfileEditor.save() → overwrites publish status after every edit (intentional for non-comm saves but breaks auto-publish detection) | Session 71 | Auto-publish now runs on any comm setting change regardless of `_wasPublished` |
| 15 | sendRequest() does not validate target's allowDirectChat/allowVideoCall — requests for disabled channels go through | Session 71 | Fix in progress (2 of 4 layers done: UI button guard + type selector; pending: repository validation + Firestore rules) |
| 16 | Search filters with allowVideoCall/allowDirectChat/isOnline + geoHash require composite index → crash | Session 71 | Moved to client-side filtering in `_passesFilters()` — no index needed |

---

## Migration Log

### Isar → Drift (Sessions 48–50)
- **Αιτία**: Isar 3 frozen, `isar_generator` pinned to analyzer <6.0 → blocked Riverpod 3.x upgrade
- **Πλεονέκτημα**: `watch()` emits initial + changes automatically (no manual initial yield)
- **7 tables**: UserProfile, PrivacySettings, ConsentLog, ChatCache, SavedSearch, AppSettings, BlockedUser
- **5 repositories migrated**: block, saved_search, consent_log, request, chat
- **Drift schema versions**: v1 (initial), v2 (+otherAvatarUrl), v3 (+lastMessage/preview columns)

### Riverpod 2.x → 3.x (Session 50)
- **6 Notifiers**: VerifyAccount, Welcome, SearchFilters, DeleteAccount, ChatActions, Search
- `StateNotifier` → `Notifier`, `StateNotifierProvider` → `NotifierProvider`
- `valueOrNull` → `value` (10 occurrences in 5 files)
- `ref.read(authStateProvider).valueOrNull?.uid` → `ref.read(authStateProvider).value?.uid`

---

## Current Project State (Session 76)

| Μέτρο | Τιμή |
|---|---|
| Total `.dart` files | ~95+ (implemented) |
| Backup files (.bak) | 0 (full cleanup) |
| Files > 400 lines | — (όριο μη δεσμευτικό) |
| Cloud Functions | 3 deployed: `onReportCreated`, `sendChatNotification`, `sendRequestNotification`, `sendRequestResponseNotification` |
| Firestore indexes | 13+ composite deployed |
| Build | `flutter analyze` clean ✅, release APK ~14.4MB |
| Completion | ~98% (Phase 1 ~100%, Phase 2 100%, Phase 3 ~95%) |

### Remaining Gaps
- **P2.5**: Phone verification (SMS) — pending implementation
- **P3.6**: Auto-lock timer (schema exists, no runtime)
- **Phase 4**: Video (Agora), AI matching, Groups, Admin, Web, Premium

### Session 69 Completed
- **Communication settings (Option A)**: Removed allowVideoCall/allowDirectChat from Privacy Editor; publish() reads from UserProfile
- **Anonymous UX**: ProfileScreen + ChatListScreen verification banners (locked state → `/auth`); streamChats() yields `[]` instead of bare `return`
- **LookingFor expansion**: +3 options (exchange/help/employment) in l10n.dart, profile_editor_screen.dart, search_filters_screen.dart
- **ProfileCard lookingFor badge**: Primary-colored chip with icon + label on discovery cards
- **Backup cleanup**: 32 `.bak` files deleted
- **oldsessions.md cleanup**: 4893 → 243 lines

### Session 70 — Chat rebuild loop fix
- **Page keys**: `_slideUp`/`_modal` now accept `ValueKey`; all pageBuilders pass stable keys (chat-$chatId, user-$uid, path) → GoRouter reuses pages on `refresh()`, prevents ChatScreen dispose/recreate
- **Smart auth notifier**: `AppRouter.init()` tracks `lastUser` (uid + isAnonymous), fires `_authNotifier.notify()` only on real auth state changes (login/logout/upgrade), NOT on token refresh → eliminates unnecessary `router.refresh()` cascade
- **Firestore rules**: `match /messages/{msgId}` update rule now requires `isParticipant()` check (security gap closed)
- **markAsRead pagination**: batch update split into chunks of 10 to stay within Firestore rules `get()` call limit per batch

### Session 71 — Auto-publish comm settings + Request validation chain + Search crash fix
- **Auto-publish on save** (`profile_editor_screen.dart`): After `saveProfile()`, if `allowVideoCall` or `allowDirectChat` changed since load, auto-call `publish()` to sync Firestore immediately — verified in test logs ✅
- **PublicProfileViewScreen button guard** (`public_profile_view_screen.dart:244`): Request button hidden when both `allowDirectChat == false AND allowVideoCall == false` ✅
- **SendRequestScreen type filter** (`send_request_screen.dart:111`): Chat chip only if `allowDirectChat == true`; Video chip only if `allowVideoCall == true`; disabled chips shown for unavailable types ✅
- **Client-side search filtering v1** (`firestore_search_repository.dart`): Removed `WHERE` clauses for `allowVideoCall`, `allowDirectChat`, `isOnline` → `_passesFilters()` ✅
- **RequestRepositoryImpl.sendRequest() validation** (`request_repository_impl.dart:55-82`): Reads target public profile, throws `AppException` if `type == 'chat'` and `allowDirectChat != true`, or `type == 'video'` and `allowVideoCall != true`. Defense-in-depth server-side parallel check ✅
- **Firestore rules** (`firestore.rules:37-42`): New `targetCommAllowed(toUid, type)` helper — single `get()` for `isVisible + allowDirectChat + allowVideoCall`, used in `allow create if` ✅
- **Client-side search filtering v2 — lookingFor/interests** (`firestore_search_repository.dart`): Moved `lookingFor` (WHERE equality) and `interests` (WHERE arrayContainsAny) to `_passesFilters()` with case-insensitive matching and null/empty guards. Eliminates 2 missing composite index crashes ✅
- **Backup cleanup**: 11 `.bak` files deleted (0 remaining) ✅

### Session 72 — Feature Flags (P3.1) + Security Rules (P3.9)
- **Feature Flags**: Populated `feature_flags.dart` with all 8 flags from blueprint §14 — all default `false`. `flutter analyze` ✅
- **Security Rules**: Replaced 8× hardcoded `(default)` → `$(database)` in `firestore.rules` helpers: `notBanned()`, `isNotBlockedInChat()`, `isNotBlockedByTarget()`, `targetCommAllowed()`, και 3 inline `get()` σε messages rules. Multi-db safe πλέον. Deployed ✅. Backup: `firestore.rules.bak`
- **Backups created**: `.bak` για feature_flags.dart + firestore.rules ✅

### Session 73 — Biometric Lock (P3.5)
- **New file**: `lib/core/utils/lock_screen.dart` — LockScreen widget (non-dismissible overlay) + static methods `authenticate()` + `canUseBiometric()`. Full bilingual, debug logging, edge case handling (no hardware, not enrolled, auth fail, lockout)
- **Provider**: `app_settings_provider.dart` — added `setBiometricLock(enabled)`: checks device capability + test auth before enabling, saves to DB. Follows same pattern as `setScreenshotPrevention()`
- **SettingsScreen**: Added Biometric Lock SwitchListTile under Screenshot Prevention (hidden for anonymous). Pre-check `canUseBiometric()` with error messaging if unavailable
- **main.dart**: `_NearMeAppState` startup lock check + lifecycle `resumed` → `_checkBiometricLock()`. MaterialApp.router builder wraps app in `Stack` with LockScreen overlay when `_isLocked == true`
- **iOS**: Added `NSFaceIDUsageDescription` to `Info.plist`
- **Android**: Added `android.permission.USE_BIOMETRIC` + `<uses-feature android:name="android.hardware.fingerprint" android:required="false" />`
- **3 analyze errors fixed** during implementation: `stickyAuth` param removed, `_isLocked` moved to correct scope, `valueOrNull` → `value` (Riverpod 3.x)
- **Edge cases**: No biometric hardware → toggle hidden via `canUseBiometric()`, not enrolled → error message, auth cancelled → stays locked, rapid lifecycle → `_isLocked` guard, anonymous → toggle hidden, first-time enable → test auth before save, lock screen non-dismissible (`PopScope(canPop: false)`)
- **`flutter analyze`**: clean ✅
- **Backups created**: `.bak` για 5 modified files (provider, settings_screen, main.dart, Info.plist, AndroidManifest.xml) ✅

### Session 74 — Typesense stub (P3.7)
- **`typesense_search_repository.dart`**: Added `implements SearchRepository` + `@override search()` + `searchNearby()` with `UnimplementedError`. Safe for compile-time when `FeatureFlags.typesenseEnabled` is toggled.
- **`flutter analyze`**: clean ✅
- **Backup**: `typesense_search_repository.dart.bak` ✅

### Session 75 — GoRouter errorBuilder
- **errorBuilder added to GoRouter**: Themed error page (`Material` + `Scaffold` + `AppBar` with `automaticallyImplyLeading: false`), bilingual strings via `L10n.localizedMessage()`, "Go Home / Αρχική" `FilledButton` via `context.go('/')`, `DebugConfig.warn()` logging for unknown route URIs. Handles malformed deep links and invalid routes gracefully, fully integrated with app theme/UX.
- **`flutter analyze`**: clean ✅

### Session 77 — showPhotos privacy toggle
- **Problem**: Photos (avatar + gallery) were always visible in public profile with no per-field toggle
- **New column**: `showPhotos` (boolean, default `true`) added to `PrivacySettingsTable` via Drift schema v3→v4 migration
- **publish()**: `avatarUrl` and `photoUrls` now respect `privacy.showPhotos` — set to `null` in Firestore when `false`
- **Privacy Editor**: New FormToggle "Φωτογραφίες / Photos" in Profile Content section (bilingual, zero new deps)
- **Edge cases**: null avatarUrl handled by existing fallbacks in ProfileCard, PublicProfileHeader, PublicProfileView; existing users get default `true` via migration; photos remain in local DB + Storage regardless of toggle
- **Backups**: 4 `.bak` files created
- **`flutter analyze`**: clean ✅

### Session 76 — PresenceService race condition fix + Future.wait
- **`presence_service.dart`**: Added `_isShuttingDown` flag, `reset()` public method, `handleLifecycle(resumed)` now reads uid from `FirebaseAuth.instance.currentUser?.uid` (authoritative source) instead of stale `_currentUid`. Added `AppLifecycleState.detached` to offline-writing states. `_stop()` refactored to call `reset()`. Removed unused `_currentUid` field.
- **`presence_service.dart`**: `_touch()` and `setOffline()` now use `Future.wait` for parallel writes to private and public docs, reducing both latency and the window for partial desync.
- **`auth_repository_impl.dart`**: `signOut()` calls `PresenceService.reset()` after `setOffline()` to immediately clear local state, preventing race where `resumed` lifecycle event re-writes `isOnline: true` during logout flow.
- **Edge cases covered**: logout + lifecycle race (`_isShuttingDown` guard + `reset()`), remote logout while backgrounded (`FirebaseAuth.instance.currentUser` null → skip), `detached` state, multiple rapid resume events, `reset()` during `_touch()` (null guard), `_stop()` after `reset()` (no-op).
- **`flutter analyze`**: clean ✅
- **Backups**: `presence_service.dart.bak` ✅, `auth_repository_impl.dart.bak` ✅

---

### Session 78 — Profile Editor unsaved-changes dialog + biometric lock fix
- **Problem 1**: Back press in Profile Editor silently discarded unsaved changes (Option A chosen via user preference — confirm dialog over auto-save or photo-undo)
- **Problem 2**: Biometric lock triggered on `image_picker` resume (short <60s pause to pick a photo was treated as unlock event)
- **Profile Editor** (`profile_editor_screen.dart`):
  - Added `_loadedProfile` field (`UserProfileTableData?`) — captured after `loadProfile()` emits
  - Added `_isDirty` getter — compares 17 form fields against loaded profile via `listEquals` from `dart:collection`
  - Added `_onBack()` async method — if dirty: `AppMessenger.showConfirmDialog` → save if accepted, pop if discarded; if clean: pop immediately. `_isSaving` guard prevents double-invocation
  - AppBar leading button (`IconButton(icon: Icons.close)`) changed from `context.pop()` to `_onBack`
  - Wrapped Scaffold with `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) _onBack(); })` for system back gesture interception
  - Fixed closing parenthesis mismatch (PopScope close was missing) — `flutter analyze` ✅
- **Biometric lock** (`main.dart`): Added `_lastPauseTime` tracking — if app was paused <60s (e.g., image_picker camera), skip biometric on resume. Only trigger lock on genuine backgrounding (>60s)
- **isPublished fix** (`profile_editor_screen.dart:251`): Changed hardcoded `isPublished: false` → `_loadedProfile?.isPublished ?? false` in `_save()` to prevent save from silently unpublishing profile
- **sqlite3_flutter_libs note**: `0.6.0+eol` is end-of-life no-op (sqlite3 3.x uses build hooks instead). Transient sqlite3 native library error resolved by rebuild.
- **Dead toggle removal**: Removed `showExactLocation` FormToggle from `privacy_editor_screen.dart` (γραμμή 121) — column παραμένει στη DB χωρίς migration, η `publish()` δεν το διάβαζε ποτέ ✅
- **Backups**: 5 `.bak` files created before edits ✅
- **`flutter analyze`**: clean ✅ (only pre-existing `use_build_context_synchronously` info)

---

### Session 79 — Country field: privacy toggle, display, publish
- **Goal**: add `showCountry` column + FormToggle, enable `country:` in publish(), display country in header/card, migration v4→v5
- **Backups**: 7 `.bak` files created ✅
- **Changes**:
  - `privacy_settings_table.dart`: Added `BoolColumn get showCountry => boolean().withDefault(const Constant(true))()`
  - `database.dart`: schemaVersion 4→5, migration step adds `showCountry` column with debug log
  - `public_profile.dart` (freezed): Added `String? country` field → build_runner regenerated `.freezed.dart` + `.g.dart`
  - `profile_repository_impl.dart publish()`: Added `country: privacy?.showCountry == true ? profile.country : null` + restored `country:` in Firestore→local restore
  - `privacy_editor_screen.dart`: Added `showCountry: true` to default constructor + FormToggle in Location section
  - `public_profile_header.dart`: Display "City, Country" pattern with conditional comma + ellipsis; location icon shown if either present
  - `profile_card.dart`: Combined `[profile.city, profile.country].where(...).join(', ')` for clean single-line display
- **Edge cases covered**:
  - Null/empty country → not displayed
  - City without country → only city shown
  - Country without city → only country shown (location icon still visible)
  - Both present → "City, Country" format
  - Privacy toggle off → country excluded from Firestore document
  - First-time user → `showCountry: true` default in constructor + DB default ✅
  - Existing users → migration adds column with default `true` ✅
- **`flutter analyze`**: clean ✅
- **`flutter pub run build_runner build`**: succeeded (203 outputs)

---

### Session 80 — Country feature polish: null-overwrite bug, unit tests, widget test fix
- **Bug fix**: `publish()` wrote null fields to Firestore, **overwriting existing values** when a privacy toggle was OFF (e.g., `showCountry=false` → `country: null` overwrote existing country)
  - **Fix**: `profile_repository_impl.dart:264` — added `..removeWhere((_, v) => v == null)` before `set()` to filter out null values
  - **Impact**: now when `showCountry=false`, the Firestore document **retains** the previous country value instead of having it erased
- **Unit tests** (new file `test/models/public_profile_test.dart` — 13 tests):
  - 6 tests for `PublicProfile` JSON serialization (toJson/fromJson with country, null, missing, round-trip)
  - 7 tests for city+country display formatting (both, city-only, country-only, empty, null, mixed)
  - **All passed** ✅
- **Widget test fix** (`test/widget_test.dart`): old test looked for `find.text('NearMe')` which never rendered — `MaterialApp(title: 'NearMe')` is metadata, not visible text. Fixed to check `find.byType(MaterialApp)` instead
- **Manual testing** across 3 devices (Android 9/12/16):
  - Migration v4→v5 ✅
  - Country displays on ProfileCard ✅
  - Country displays in PublicProfileHeader ✅
  - Publish/republish with toggle ON/OFF ✅
  - `flutter analyze`: clean ✅
  - `flutter test`: 14/14 passed ✅

---

## 📍 Current Status

### ✅ Completed (Country Feature)
- `privacy_settings_table.dart`: `showCountry` column added
- `database.dart`: schema 4→5 migration
- `public_profile.dart`: `String? country` field (freezed)
- `profile_repository_impl.dart`: conditional `country:` in `publish()`, Firestore→local restore
- `privacy_editor_screen.dart`: FormToggle + default `true`
- `public_profile_header.dart`: "City, Country" display
- `profile_card.dart`: `join(', ')` display
- `publish()` null-overwrite bug fix
- Unit tests (13) + widget test fix
- Manual test on 3 devices

### ✅ Completed (Previous Sessions)
- Profile Editor confirm dialog (`_loadedProfile`, `_isDirty`, `_onBack()`, `PopScope`)
- Biometric lock fix (`_lastPauseTime` + 60s short-pause skip)
- `showPhotos` feature (column, migration v3→v4, conditional `avatarUrl`/`photoUrls`)
- `isPublished` fix (save preserves published state)
- `showExactLocation` dead toggle removal (UI only, column stays)
- Geo-precision search fix (precision 3 + `'~'` sentinel)
- Full geo handling audit (19 files mapped, 3 bugs found/fixed)

### ⏳ Pending / Optional
- **Activate dead `SearchFilters.country`** — `filters_provider.dart` updateCountry(), `search_filters_screen.dart` dropdown, `firestore_search_repository.dart` client-side country filter

---

## Key Architecture Patterns (Conventions)

- **File size limit**: ≤ 400 lines (1 exception: profile_repository_impl)
- **Debug logging**: `DebugConfig.log(flag, msg)` in every operational action
- **Error handling**: `ErrorView`/`LoadingView`/`EmptyView` for async states, `AppMessenger` for transient messages
- **Responsive**: `ResponsiveUtils.maxContentWidth()`, `isMobile()`/`isTablet()` — every screen
- **Bilingual**: `L10n.isGreek(context)` for labels, `L10n.localizedMessage(context, 'Greek / English')` for dynamic messages
- **Backup before edit**: `.bak` file in same directory (cleaned periodically)
- **Repository pattern**: Abstract interface + impl, no raw Firestore in UI
- **Privacy-first**: Full profile in local DB only, minimal public snapshot in Firestore
- **Schema versioning**: Drift `MigrationStrategy` for schema evolution, no placeholder fields
