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

### Φάση 3 — Communication (~100%, 12/12)
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
- ✅ Phone verification (P2.5, SMS)

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

## Current Project State (Session 81)

| Μέτρο | Τιμή |
|---|---|
| Total `.dart` files | ~97+ (implemented) |
| Backup files (.bak) | session-only (cleaned periodically) |
| Files > 400 lines | — (όριο μη δεσμευτικό) |
| Cloud Functions | 3 deployed |
| Firestore indexes | 13+ composite deployed |
| Build | `flutter analyze` clean ✅, release APK ~14.5MB |
| Completion | ~99% (Phase 1 ~100%, Phase 2 100%, Phase 3 100%) |

### Remaining Gaps
- **P3.6**: Auto-lock timer (schema exists, no runtime)
- **Phase 4**: Video (Agora), AI matching, Groups, Admin, Web, Premium, Typesense
- **Activate dead `SearchFilters.country`**: filter updateCountry/dropdown/client-side filter

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

## 📍 Current Status — Session 81

### ✅ Completed (Phone Verification — P2.5)
- `phone_verify_provider.dart`: `PhoneVerifyNotifier` + state machine (6 states) + `checkIfAlreadyVerified()`
- `phone_verify_screen.dart`: full phone → OTP → success flow + guards + bilingual error messages
- `auth_repository_impl.dart`: Firebase Phone Auth via `Completer<String>`, 8 error codes mapped
- `settings_screen.dart`: "Verify Phone" ListTile (gated: email verified + non-anonymous)
- `app_router.dart`: route `/settings/phone-verify`
- Debug flag `authPhone` in `debug_config.dart`
- `l10n.dart`: `phoneCountryCode()` based on device locale
- Phone number hidden from success views (privacy)
- `provider-already-linked` treated as success
- `reloadUser()` before `checkIfAlreadyVerified()` for accurate server state
- Firebase: Phone Auth enabled + SHA-1 + SMS Region Policy (GR) + test phone number

### ✅ Completed (Previous Sessions)
- Country feature: `showCountry` toggle + display + publish + tests
- Profile Editor confirm dialog (`_loadedProfile`, `_isDirty`, `_onBack()`, `PopScope`)
- Biometric lock fix (`_lastPauseTime` + 60s short-pause skip)
- `showPhotos` feature (column, migration v3→v4, conditional `avatarUrl`/`photoUrls`)
- `isPublished` fix (save preserves published state)
- `showExactLocation` dead toggle removal (UI only, column stays)
- Geo-precision search fix (precision 3 + `'~'` sentinel)
- Full geo handling audit (19 files mapped, 3 bugs found/fixed)

### ⏳ Pending / Optional
- **P3.6**: Auto-lock timer (schema exists, no runtime)
- **Phase 4**: Typesense, Video (Agora), AI matching, Groups, Verified badge, Premium, Web, Admin panel
- **Activate dead `SearchFilters.country`** — `filters_provider.dart` updateCountry(), `search_filters_screen.dart` dropdown, `firestore_search_repository.dart` client-side country filter
- **Instant Greek SMS**: Custom SMS provider (Twilio/Vonage) via Cloud Function for carrier-grade deliverability

---

---

### Session 81 — Phone Verification (P2.5) — Implemented & Tested

**Goal**: SMS-based phone verification, gated behind email verification.

**New files** (2):
- `lib/features/auth/providers/phone_verify_provider.dart` — `PhoneVerifyNotifier` with state machine: idle/loading/otpSent/verified/error/autoVerified
- `lib/features/auth/screens/phone_verify_screen.dart` — Full screen: phone input → OTP input → success views, guard for anonymous/non-email-verified

**Modified files** (6):
- `lib/core/l10n/l10n.dart` — `phoneCountryCode()` method: detects device locale country code → dial code (GR→+30, US→+1, κλπ.)
- `lib/repositories/auth_repository.dart` — 3 abstract methods: `sendPhoneOtp()`, `verifyPhoneOtp()`, `isPhoneVerified`
- `lib/repositories/auth_repository_impl.dart` — Firebase callback-based `verifyPhoneNumber` bridged via `Completer<String>`; `_mapPhoneError()` handles 8+ error codes; `isPhoneVerified` getter checks `currentUser?.phoneNumber`
- `lib/core/router/app_router.dart` — route `/settings/phone-verify`
- `lib/features/settings/screens/settings_screen.dart` — "Verify Phone" ListTile (visible only when `!isAnonymous && user.emailVerified`)
- `lib/core/debug/debug_config.dart` — flag `authPhone` (default true)

**Phone provider**:
- `sendOtp()`: calls repo → `otpSent` with `verificationId` or `autoVerified` (SMS auto-retrieval)
- `verifyOtp()`: calls repo with code → `verified` or `error`
- `checkIfAlreadyVerified()`: calls `reloadUser()` then `isPhoneVerified` → skip straight to `verified` if already linked
- `provider-already-linked` treated as success (not error) in both `sendOtp`/`verifyOtp`

**Screen**:
- `initState`: pre-fills country code from device locale + calls `checkIfAlreadyVerified()` via `addPostFrameCallback`
- Guards: anonymous or email-not-verified → message + "Verify Email" button
- States: loading → spinner, otpSent → 6-digit code field, verified/autoVerified → success view (no phone number displayed), error → `ErrorView` with retry → `reset()`
- `_sendOtp` strips spaces for E.164 format
- `_errorText()`: bilingual messages for all error codes including `operation-not-allowed`

**Testing (real device)**:
- `operation-not-allowed` → fixed by enabling Phone provider + SHA-1 in Firebase Console
- `SMS Region Policy` → enabled Greece (GR) in Authentication → Settings
- OTP received after ~5min delay (Firebase international aggregator routing)
- `test phone number` (Firebase Console) → instant OTP verification ✅
- `provider-already-linked` → handled gracefully as "already verified" ✅
- `checkIfAlreadyVerified()` → reloads user before checking cached `phoneNumber` ✅
- Invalid phone `+30123` → `auth/invalid-phone` error correctly displayed ✅

**Note**: Phone verification uses Firebase Phone Auth (international SMS aggregators, ~$0.01/SMS after 10 free/day). For instant Greek SMS (like banks/carriers), architecture change needed: Firebase Auth with Identity Platform + custom SMS provider (Twilio/Vonage) via Cloud Function.

**`flutter analyze`**: clean ✅
**Backups**: 5 `.bak` files created ✅

---

### Session 82 — Phone verify stale state fix + authStateChanges→userChanges

**Problem 1 — Stale provider state:** `phoneVerifyProvider` δεν είναι `autoDispose`. Αν χρήστης έφευγε από την οθόνη σε κατάσταση `otpSent` ή `error` και ξαναμπαίνει, το `initState()` καλούσε μόνο `checkIfAlreadyVerified()` (που κάνει κάτι μόνο αν ήδη verified) χωρίς `reset()`. Αποτέλεσμα: ληγμένο `verificationId` ή stale error message.

**Fix:** `phone_verify_screen.dart:38-42` — `reset()` πριν `checkIfAlreadyVerified()` στο `initState()`. Πάντα καθαρή κατάσταση σε κάθε είσοδο.

**Problem 2 — Stale `emailVerified`:** Το `authStateProvider` βασιζόταν σε `authStateChanges()` που εκπέμπει ΜΟΝΟ σε sign-in/out. Μετά από `reloadUser()` (π.χ. email verification), το `emailVerified` παρέμενε stale στο Riverpod state. Το `phone_verify_screen.dart:79` διάβαζε `user?.emailVerified` από αυτό το stale snapshot.

**Fix:** `auth_repository_impl.dart:163` — `_auth.authStateChanges()` → `_auth.userChanges()`. Το `userChanges()` εκπέμπει και σε profile reload, όχι μόνο σε sign-in/out. Τα 2 ξεχωριστά listeners (`app_router.dart`, `presence_service.dart`) παρέμειναν σε `authStateChanges()` — σκόπιμα, γιατί θέλουν events μόνο σε login/logout.

**Backup cleanup:** 28 `.bak` files deleted.

**Edge cases covered:**
- Stale OTP/error on re-entry ✅
- Already verified user re-enters → reset() + checkIfAlreadyVerified() → verified ✅
- Rapid reloads → userChanges() coalesces ✅
- Router redirect → remains on authStateChanges() ✅
- Presence heartbeat → remains on authStateChanges() ✅

**`flutter analyze`**: clean ✅

---

### Session 83 — Completer safety timeout for sendPhoneOtp

**Problem:** `sendPhoneOtp()` χρησιμοποιεί `Completer<String>` που γίνεται `complete` από τα callbacks `verificationCompleted` / `verificationFailed` / `codeSent`. Αν για οποιονδήποτε λόγο δεν κληθεί κανένα (π.χ. Firebase SDK bug, σπάνιο network condition), το `completer.future` μένει forever pending. Το `LoadingView` δεν έχει cancel button → χρήστης κολλάει επ' αόριστον.

**Fix — 3 αρχεία, 4 γραμμές:**

1. `auth_repository_impl.dart:219-224` — `return completer.future` → `return completer.future.timeout(30s, onTimeout: () => throw AppException(...))`. 30s safety net. Debug log σε timeout.

2. `phone_verify_provider.dart:105` — `_friendlyError`: `msg.contains('phone-timeout')` → `auth/phone-timeout`.

3. `phone_verify_screen.dart:288-289` — `_errorText`: `case 'auth/phone-timeout':` bilingual "Το αίτημα επαλήθευσης έληξε / Verification request timed out".

**Edge cases covered:**
- Normal ροή (codeSent) → timeout δεν φτάνει ποτέ ✅
- Auto-verify (verificationCompleted) → timeout δεν φτάνει ποτέ ✅
- Σφάλμα (verificationFailed) → timeout δεν φτάνει ποτέ ✅
- Κανένα callback → 30s → `AppException` → `ErrorView` with retry ✅
- `provider-already-linked` → πιάνεται σε catch πριν `_friendlyError` ✅
- Το `reset()` (Session 82) δίνει retry path: ErrorView → Retry → reset() → sendOtp() ξανά ✅

**`flutter analyze`**: clean ✅

---

### Session 84 — Inline spinners αντί full-screen LoadingView στο PhoneVerifyScreen

**Problem:** Όταν ο χρήστης πατούσε "Επαναποστολή κωδικού" ή "Επαλήθευση", το state του provider γινόταν `loading` και το UI αντικαθιστούσε ΟΛΟΚΛΗΡΗ την οθόνη με `LoadingView`, χάνοντας το OTP form και δημιουργώντας visual flash.

**Fix — `phone_verify_screen.dart`:**
1. **Αφαίρεση full-screen LoadingView:** Οι 2 συνθήκες `state.status == loading && _isSending/Verifying → LoadingView` αφαιρέθηκαν. Το `ListView` εμφανίζεται πάντα (εκτός autoVerified/verified).
2. **Local `_otpFormActive` flag:** Παρακολουθεί μέσω `ref.listen` πότε ο provider φτάνει σε `otpSent` state. Όταν true, το OTP form παραμένει ορατό ακόμα και κατά το resend/verify (όταν provider είναι temporary σε `loading`).
3. **Inline spinner στο resend:** Αντί να εξαφανίζεται το κουμπί, το εικονίδιο αντικαθίσταται με `CircularProgressIndicator(strokeWidth: 2)` όσο `_isSending == true`.
4. **Disabled inputs:** `enabled: !_isSending` στο phone field, `enabled: !_isVerifying` στο OTP field — αποτροπή αλλαγών κατά την επεξεργασία.

**Edge cases covered:**
- Πρώτη αποστολή (idle → loading → otpSent): phone form + spinner στο Send Code ✅
- Επαναποστολή (otpSent → loading → otpSent): OTP form stays, spinner στο resend ✅
- Επαλήθευση (otpSent → loading → verified): OTP form stays, spinner στο Verify ✅
- Error σε resend: `_otpFormActive` stays true, ErrorView inline, retry → reset() → phone form ✅
- Back → re-enter: `reset()` στο initState → `_otpFormActive = false` → fresh start ✅
- `_otpFormActive` resets on `idle` (retry/back) και on `verified`/`autoVerified` ✅

**Conventions:**
- Responsive: ❌ δεν άλλαξε (ResponsiveUtils.maxContentWidth παραμένει)
- Multilanguage: ✅ bilingual στα μηνύματα
- Single source of truth: ✅ provider state + local UI flags, clear separation
- AppMessenger/ErrorView: ✅ ErrorView inline, phone validation με AppMessenger.showError
- DebugConfig: ✅ log στο `ref.listen` + υπάρχοντα logs στα buttons

**`flutter analyze`**: clean ✅

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

---

### Session 85 — Clear _otpCtrl on resend

**Problem:** `_otpCtrl` δεν καθαριζόταν όταν ο χρήστης πατούσε Resend — ο προηγούμενος (άκυρος) κωδικός παρέμενε στο πεδίο.

**Fix — `phone_verify_screen.dart`:** `_sendOtp()`: αν `_otpFormActive == true`, κάνει `_otpCtrl.clear()` πριν στείλει νέο OTP.

**`flutter analyze`**: clean ✅

---

### Session 86 — Country code as prefixText (όχι editable)

**Problem:** Το country code (`+30`) μπαινε στο `_phoneCtrl.text` (editable) ΚΑΙ στο `labelText` — διπλή εμφάνιση + κίνδυνος αλλοίωσης από τον χρήστη, άρα invalid E.164 στο Firebase.

**Fix:**
- `initState()`: αφαιρέθηκε το `_phoneCtrl.text = '$code '` (δεν μπαίνει πια στο controller)
- `InputDecoration`: `labelText` δείχνει μόνο `'6XX XXXXXXX'`, προστέθηκε `prefixText: '+30 '` (μη editable, στο input field)
- `_sendOtp()`: προθέτει `'$code'` στο `_phoneCtrl.text` αν δεν ξεκινάει ήδη με `+`

**`flutter analyze`**: clean ✅

---

### Session 87 — Client-side phone validation

**Problem:** Δεν υπήρχε validation μήκους/μορφής του αριθμού στο client — μόνο `isEmpty` check. Firebase γυρνούσε error αλλά με χειρότερο UX (καθυστέρηση + generic error).

**Fix — `phone_verify_screen.dart` `_sendOtp()`:**
- Αφαίρεση όλων non-digit chars
- Regex `^[1-9]\d{6,14}$` (7-15 digits, E.164 standard)
- Αν δεν κάνει match: άμεσο error μήνυμα «Μη έγκυρος αριθμός τηλεφώνου / Invalid phone number»
- Προσθήκη `+` μετά το validation για proper E.164

**`flutter analyze`**: clean ✅

---

### Session 88 — AppColors.online αντί hardcoded Color (single source of truth)

**Problem:** `_buildAutoVerified` / `_buildVerified` χρησιμοποιούσαν `const Color(0xFF4CAF50)` αντί για το `AppColors.online` που ήδη υπάρχει με την ίδια τιμή.

**Fix — `phone_verify_screen.dart`:** 2 αλλαγές (lines 251, 275): `Color(0xFF4CAF50)` → `AppColors.online`.

**`flutter analyze`**: clean ✅

---

### Session 89 — Status indicator στο settings phone tile

**Problem:** Το ListTile "Verify Phone" στο settings_screen ήταν ίδιο είτε το τηλέφωνο ήταν επαληθευμένο είτε όχι — κανένα visual feedback.

**Fix — `settings_screen.dart`:**
- Νέο `phoneVerified = user!.phoneNumber != null` στο build method
- Subtitle: «Επαληθεύτηκε / Verified» όταν verified
- Trailing: `Icons.check_circle` (πράσινο) αντί για `chevron_right` όταν verified

**`flutter analyze`**: clean ✅

---

### Session 90 — Remove redundant _friendlyError string matching

**Problem:** Το `_friendlyError()` στο `phone_verify_provider.dart` έκανε 9 `contains()` checks πάνω σε `error.toString()` — redundant, γιατί το `_mapPhoneError()` στο `auth_repository_impl.dart` ήδη παράγει `AppException` με σωστό `code`.

**Fix — `phone_verify_provider.dart`:**
```dart
String _friendlyError(Object error) {
  if (error is AppException) return error.code;
  return 'auth/unknown-error';
}
```
Προστέθηκε `import '../../../core/utils/app_exception.dart'`.

**`flutter analyze`**: clean ✅

---


### Session 91 � Fix isPhoneVerified: empty string vs null (firebase_auth 6.5.1)

**Problem:** irebase_auth ^6.5.1 returns "" (empty string) instead of 
ull for phoneNumber / email on unverified users. phone != null evaluated 	rue even when not verified.

**Fix � uth_repository_impl.dart:**
- Line 252: phone != null ? phone != null && phone.isNotEmpty
- Line 79: user.email != null ? user.email != null && user.email!.isNotEmpty

**Side effect fix � settings_screen.dart:** Line 75: user!.phoneNumber != null ? ef.read(authRepositoryProvider).isPhoneVerified (???s? repository ?? SSOT).

**Confirmation:** Logs showed isPhoneVerified: false phone= before, isPhoneVerified: true phone=+306975799063 after verification.

---

### Session 92 � Eliminate SettingsScreen cascade rebuilds

**Problem:** ~35 rebuilds of SettingsScreen during navigation. Root cause: uthStateProvider uses userChanges() (emits on token refresh, not just login/logout) and SettingsScreen had 2 ef.watch (uthStateProvider + ppSettingsProvider) causing cascade rebuilds.

**Fix � settings_screen.dart:**
- Converted ConsumerWidget ? ConsumerStatefulWidget with _authUser: User? field
- ef.listen with field-level comparison (uid, isAnonymous, emailVerified, phoneNumber) � ignores token refresh emits
- Extracted _DeviceSecuritySection as separate ConsumerWidget (isolates ppSettingsProvider watch)

**Confirmation:** Logs show SettingsScreen build and _DeviceSecuritySection build only 1 time each on navigation.

---

### Session 93 � Unlink Phone (in progress)

**Next:**
1. Add Future<void> unlinkPhone() to AuthRepository (abstract) and AuthRepositoryImpl (Firebase user.unlink('phone'))
2. Add "Unlink Phone" ListTile in settings_screen (gated on phoneVerified == true) with confirmation dialog
3. lutter analyze � verify zero issues
4. User to build/test release APK

**Completed — Session 93:**
- `auth_repository.dart`: Added `Future<void> unlinkPhone()` abstract
- `auth_repository_impl.dart`: `user.unlink('phone')` + `user.reload()` for cache refresh. Handles `no-such-provider` gracefully (server-side already unlinked), separate error handling for unlink vs reload failures
- `settings_screen.dart`: "Remove Phone" ListTile (gated `phoneVerified`) with dialog + `_isUnlinking` guard + `setState` with fresh `currentUser` after success
- Edge cases: stale cache, double tap, reload failure
- `flutter analyze`: clean

**Confirmation logs:**
```
Phone already unlinked server-side
isPhoneVerified: false phone=null
SettingsScreen build  ← UI updated immediately
```

---

### Session 94 — Unlink Phone bug: stale Firebase Auth cache

**Problem:** After `user.unlink('phone')` succeeds server-side, `_auth.currentUser?.phoneNumber` still returns old value from local cache. On second attempt, `unlink()` throws `no-such-provider` (already unlinked) but cache never gets refreshed.

**Root cause:** `user.unlink()` doesn't update Firebase Auth local persistent cache immediately. Without explicit `reload()`, stale `phoneNumber` persists across app restarts.

**Fix — `auth_repository_impl.dart`:**
1. Separated error handling: `unlink()` failures (FirebaseAuthException) vs `reload()` failures (any)
2. `no-such-provider` handled as success (phone already unlinked server-side)
3. `await _auth.currentUser?.reload()` after successful unlink (or no-such-provider)
4. `settings_screen.dart`: `setState(() => _authUser = ref.read(authRepositoryProvider).currentUser)` after unlink to force UI update with fresh user object

**Trigger for fix:** Logs showed `isPhoneVerified: true phone=+306975799063` immediately after `Phone unlinked successfully` — cache stale even after successful unlink.

---

### Session 95 — Phone verification: unlink not appearing after verify + cascade rebuild analysis

**Part A — Unlink not visible after phone verification**

**Problem:** After phone verification (PhoneVerifyScreen → verified), navigating back to SettingsScreen didn't show the "Remove Phone" option. Had to close and re-enter SettingsScreen.

**Root cause:** `userChanges()` stream emits BEFORE `linkWithCredential()` completes, so SettingsScreen's `ref.listen` receives stale data. The `AsyncValue` from `authStateProvider` isn't updated with the new phone number.

**Fix — `auth_repository_impl.dart`:**
- Added `await _auth.currentUser?.reload()` after `await user.linkWithCredential(credential)` in `verifyPhoneOtp()` — forces server refresh so subsequent `isPhoneVerified` returns correct value

**Note:** This fix also prevents the issue from manifesting in the future. For this session, the user confirmed the Firebase Console showed phone removed but local cache still had it.

---

**Part B — Cascade rebuilds analysis (critical finding)**

**Observation:** SettingsScreen rebuilds ~50 times in ~650ms at 60fps (every ~16ms) when PhoneVerifyScreen is on top and keyboard animates. The rebuilds appear in batches:
```
PhoneVerifyScreen opened         → ~650ms of 60fps rebuilds
sendOtp() called                 → ~400ms of 60fps rebuilds
OTP sent + form switch           → ~400ms of 60fps rebuilds
verifyOtp() called               → ~400ms of 60fps rebuilds
```

**Root cause (corrected from Session 92 analysis):**
- **NOT** `appSettingsProvider` — `_DeviceSecuritySection` is a separate `ConsumerWidget`, its `ref.watch(appSettingsProvider)` only rebuilds itself, not SettingsScreen
- **NOT** `authStateProvider` — Firebase streams don't emit at 60fps
- **CORRECT:** `MediaQuery` changes during keyboard animation. SettingsScreen calls `ResponsiveUtils.maxContentWidth(context)` → `MediaQuery.of(context).size.width` in build(). When keyboard appears/disappears, `MediaQuery` changes every frame (~16ms) during animation. Flutter rebuilds ALL widgets that depend on `MediaQuery`, regardless of whether they read the changed property.

**Evidence:**
- Rebuilds are frame-synchronized (~16ms intervals = 60fps)
- Coincide with keyboard show/hide/resize during form transitions
- Duration matches keyboard animation duration (~300-650ms)
- No provider emits at 60fps (Firebase streams, AppSettings, etc.)

**Note for future:** The fix from Session 92 (ConsumerStatefulWidget + ref.listen with field comparison + extracted _DeviceSecuritySection) correctly eliminated cascade rebuilds FROM PROVIDER CHANGES. The MediaQuery rebuilds are a separate, pre-existing Flutter behavior not addressed by that fix.

---

### Session 96 — Pending: Fix for MediaQuery cascade rebuilds

**Problem:** SettingsScreen rebuilds at 60fps during keyboard animation (when modals are on top) due to `MediaQuery.of(context)` dependency via `ResponsiveUtils.maxContentWidth(context)`.

**Planned solutions (not yet implemented):**

**Option A — RepaintBoundary (zero risk):**
Wrap SettingsScreen in `RepaintBoundary`. Prevents repainting but NOT rebuilding. Logs will still show `SettingsScreen build` messages, but GPU won't re-render.

**Option B — MediaQuery caching (low risk):**
Replace `MediaQuery.of(context)` calls in `ResponsiveUtils` with a value that doesn't change during keyboard animation. Approaches:
- Read `MediaQuery.size` once and cache it
- Use `LayoutBuilder` instead of `MediaQuery`
- Override `MediaQuery` at SettingsScreen root with a fixed size

**Option C — Extract MediaQuery-dependent parts into separate ConsumerWidget (low risk):**
Move the `ResponsiveUtils.maxContentWidth(context)` call into a dedicated widget that can rebuild independently without triggering SettingsScreen rebuild.

**Decision:** Pending user approval.

---

### Files modified this session (Sessions 91-95):

| File | Changes |
|---|---|
| `lib/repositories/auth_repository.dart` | Added `Future<void> unlinkPhone()` abstract |
| `lib/repositories/auth_repository_impl.dart` | `unlinkPhone()` + `reload()` + `no-such-provider` handling; `reload()` after `linkWithCredential` in `verifyPhoneOtp()` |
| `lib/features/settings/screens/settings_screen.dart` | ConsumerStatefulWidget + ref.listen + _DeviceSecuritySection + Unlink Phone ListTile + _unlinkPhone() method + reloadUser() fix |
| `oldsessions.md` | Updated with all session details |

### Current state:
- Phone verification indicator (green check): **FIXED**
- SettingsScreen cascade rebuilds from provider changes: **FIXED** (Session 92)
- SettingsScreen rebuilds from MediaQuery keyboard animation: **NOT FIXED** (awaiting decision)
- Unlink Phone: **FIXED AND TESTED** (works with fresh + stale cache)
- Unlink not visible after verification: **FIXED** (reload after linkWithCredential)

---

### Session 96 — BUG 1: isOnline overwrite by publish() — Read+Preserve fix

**Problem:** `publish()` wrote `isOnline: false` (default from `PublicProfile` model `@Default(false)`) to `users/{uid}/public/profile`, overwriting `presence_service`'s `isOnline: true`. Two mechanisms wrote to the same field.

**Root cause:** `profile_repository_impl.dart:publish()` → `publicProfile.toJson()` includes `isOnline: false` → `set(json)` full replace → presence heartbeat overwritten.

**First fix attempt (Session 96, earlier):** `..remove('isOnline')` — removed field from json. Problem: `set(json)` without merge replaced entire doc, so `isOnline` was **absent** from Firestore until next presence heartbeat (up to 60s gap). Users with `isOnlineNow` filter couldn't find recently published users.

**Final fix — Read+Preserve (`profile_repository_impl.dart:267-282`):**
1. `remove('isOnline')` — removes default `false` from model ✅
2. Read existing Firestore doc → if `isOnline` exists, add it back to `json` ✅
3. `set(json)` full replace — privacy toggle nulls still removed correctly ✅
4. If read fails → `DebugConfig.warn` → publish continues without isOnline → presence writes on next heartbeat ✅

**Edge cases covered:**
| Σενάριο | Συμπεριφορά |
|---|---|
| First publish (no existing doc) | `exists=false` → isOnline not included → presence writes on first heartbeat |
| Re-publish while online | Reads `isOnline: true` → preserved ✅ |
| Re-publish while offline | Reads `isOnline: false` → preserved ✅ |
| Read fails (network/permission) | Catch → continues without isOnline → presence fixes ≤60s |
| Privacy toggle OFF | null → `removeWhere` → `set` full replace → field removed from doc ✅ |
| Race publish + heartbeat | Unlikely (publish=manual) → heartbeat fixes within 60s |

**Tested on 2 devices (real-time):**
- Phone 1 (Yahooman, uid=scIChfVv3MRWnU1cWX67TepomCj2): published profile ✅
- Phone 2 (Aris62, uid=l48zEyS6U6Mpb3jVaZgtEqyt5EE3): search found 2 raw results → 1 after self-exclusion, PublicProfileViewScreen loaded ✅
- No `publish: failed to read existing isOnline` warnings in logs — read succeeded ✅

**Files modified:**
| File | Changes |
|---|---|
| `lib/repositories/profile_repository_impl.dart` | Added existing doc read + isOnline preserve block (lines 267-282); backup: `.bak` |
| `oldsessions.md` | Updated with session details |

**`flutter analyze`**: clean ✅
**Backup**: `profile_repository_impl.dart.bak` ✅

---

### Session 97 — Country filter activation + LocationService GPS-first + auto-fill profile

**Goal 1: Activate dead `SearchFilters.country`** — the field existed in the model but was never used in filters UI, provider, or search repository.

**Files modified (4):**
| File | Change |
|------|--------|
| `lib/features/discovery/providers/filters_provider.dart` | + `updateCountry()` method with debug log |
| `lib/features/discovery/screens/search_filters_screen.dart` | + `_countryCtrl`, dispose, load, apply, UI TextFormField (Icons.flag_outlined, bilingual label) |
| `lib/repositories/firestore_search_repository.dart` | + country check in `_passesFilters()` (client-side, no composite index needed) |
| `lib/features/discovery/widgets/public_profile_header.dart` | Simplified city+country display → `[city, country].where(...).join(', ')` (8 lines αντί 14) |

**Edge cases:** null/empty country, saved search restore, city+country AND, privacy toggle off.

**Goal 2: Professional GPS-first location** — users reported cached position from days ago (Αρτέμιδα) showing instead of current location (Περιστέρι).

**File modified (1):**
| File | Change |
|------|--------|
| `lib/features/profile/providers/location_service.dart` | New order: live GPS first → session cache (5min) → fallback to last known → failure |

**New logic:**
1. `getCurrentLocation(forceRefresh: true)` (default) — always live GPS
2. `getCurrentLocation(forceRefresh: false)` — returns session cache if <5min old
3. Live GPS timeout/error → fallback to `getLastKnownPosition()`
4. Nothing works → failure

**Test result:** `Position:` appears in logs (live GPS) instead of `Last known`. GPS inside building still gives WiFi-based positioning (expected — same as all apps).

**Revert note:** The GPS-first change was implemented, then reverted per user request, then re-implemented with session cache + fallback.

**Current proposal — Goal 3: Auto-fill city/country in profile from GPS:**
- In `discovery_screen.dart`, after GPS success: reverse geocode → if profile city/country empty → save
- Single file change (~15 lines), respects manual entries, no auto-publish
- Implementation pending user approval

**`flutter analyze`**: clean ✅
**Backups**: 5 `.bak` files (4 country + 1 location_service) ✅

---

### Session 98 — Auto-fill city/country + auto-publish on GPS success + auto-sync for published profiles

**Goal:** Auto-fill city/country in user profile on app start from GPS reverse geocode, and auto-publish to Firestore if profile is published.

**File modified (1):**
| File | Change |
|------|--------|
| `lib/features/discovery/screens/discovery_screen.dart` | + auto-fill (if city/country empty) + auto-publish (if published); + auto-sync (if published + GPS differs) |

**Logic implemented (`_performSearch` after GPS success):**
1. `needsCity || needsCountry` → reverse geocode → save locally → if `isPublished`, publish to Firestore
2. `else if (profile.isPublished)` → reverse geocode → if GPS city/country differs from stored → save + publish

**Edge cases covered:**
- City/country empty → fill + publish ✅
- City/country filled + not published → skip (respects manual entry without publish) ✅
- City/country filled + published + GPS unchanged → skip (no unnecessary writes) ✅
- City/country filled + published + GPS changed → update + publish ✅
- Reverse geocode fails (null) → skip gracefully ✅
- GPS failure → skip whole block, show location error message ✅

**Test results (user log confirmation):**
- First run: `profile.isPublished == false` → neither auto-fill nor auto-sync ran (expected)
- After re-publish in device 2 → auto-sync detected city difference → updated Firestore ✅
- Firestore now shows correct city (Περιστέρι) instead of old Αρτέμιδα ✅

**`flutter analyze`**: clean ✅
