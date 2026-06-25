# NearMe — Old Sessions Archive (Καθαρισμένο)

> Συμπυκνωμένο archive: τεχνολογίες, αρχιτεκτονική, σημαντικά fixes, τρέχουσα κατάσταση.

---

## Τεχνολογίες (Resolved — Ιούνιος 2026)

| Layer | Επιλογή |
|---|---|
| State Management | Riverpod 3.x (Notifier, @riverpod) |
| Local DB | Drift 2.33 (SQLite), από Isar 3.1 |
| Navigation | GoRouter 17 (StatefulShellRoute, adaptive nav) |
| Auth | Firebase (Anonymous → Email/Phone) |
| Cloud DB | Firestore (collectionGroup, 15+ composite indexes) |
| Storage | Firebase Storage (avatars/photos, JPEG max 5MB) |
| Functions | Firebase Functions (TypeScript, 1st Gen) |
| Encryption | encrypt 5.0.3 (AES-256 GCM) + deriveKey (SHA-256) |
| Secure Storage | flutter_secure_storage (encryption keys) |
| Geo | geolocator + geoflutterfire_plus + geocoding |
| Search v1 | Firestore native (active) |
| Search v2 | Typesense self-hosted (stub exists, Phase 4) |
| Push | FCM (3 Cloud Functions, locale-aware) |
| i18n | flutter_localizations + intl (el/en, `L10n`) |
| Biometric | local_auth 3.0 (active) |

## Αρχιτεκτονικές Αποφάσεις

### A: Authentication — Anonymous + Lazy Upgrade
- Χρήστης ξεκινά ανώνυμος → upgrade σε verified (email/phone) μόνο όταν θελήσει επικοινωνία
- Session 34: Welcome Screen, Session 57: AnonymousInfoScreen

### B: Γεωγραφία — GPS με fallback manual
- GPS → lat/lng στο Drift (ΠΟΤΕ raw στο Firestore)
- GeoHash μόνο στο Firestore με precision levels
- Fallback: text field για χειροκίνητη πόλη/χώρα
- Reverse geocode auto-fill city/country στο discovery_screen.dart

### Γ: Search — Υβριδικό (Repository Pattern)
- Firestore native (τώρα) → Typesense (Phase 4, 5k+ users)
- Abstract `SearchRepository` — swap χωρίς UI changes
- Server-side filters + cursor pagination (Session 65)
- `hasLocationFilter` flag: city OR country filter active → skip geo bounds + `ORDER BY geoHash`

### Security Architecture (5-Layer)
1. **Device**: Drift + flutter_secure_storage + FLAG_SECURE + Biometric Lock
2. **Auth**: Anonymous → Email verify, silent refresh, force refresh
3. **Data Rules**: Firestore Security Rules (~90%)
4. **Transport**: TLS 1.3 + AES-256 E2E chat (deriveKey deterministic)
5. **Behaviour**: Rate limiting (10 reports/hr), auto-ban (5 reports), request expiry (48h)

### Data Flow
- **Local (Drift)**: UserProfile (23 fields), PrivacySettings, ConsentLog, ChatCache, SavedSearch, AppSettings, BlockedUser
- **Firestore**: `users/{uid}/public/profile` (visible only), `users/{uid}/status` (isOnline), `chats/{chatId}/messages` (AES-256), `requests/{reqId}`, `reports/{reportId}`, `users/{uid}/blocked/{blockedUid}`, `users/{uid}/fcm_tokens/{tokenId}`
- **Repository Pattern**: 7 abstract interfaces (Auth, Profile, Search, Chat, Request, Block, Report) — ποτέ raw Firestore στο UI

---

## Φάσεις Υλοποίησης

### Φάση 1 — Core & Privacy (100%)
Firebase Init, Drift (7 tables, schema v5), Profile CRUD, PrivacySettings (12 toggles), ConsentLog, Publish/Unpublish, GPS + GeoHash, i18n el/en, Theme, Security Rules (15+ indexes), Repository Pattern, AppMessenger/AppStateWidgets, BlockedUser, Report + Auto-ban CF, Delete Account, Screenshot Prevention, Biometric Lock, Feature Flags (8)

### Φάση 2 — Discovery (100%)
Firestore search (collectionGroup), SearchFilters (15 interests), ProfileCard, PublicProfile view, Saved Searches, Block/Report, Cursor pagination + 300 cap, Server-side filters, Typesense stub

### Φάση 3 — Communication (100%)
Verify Account, Request System (48h expiry), Request→Chat Flow, E2E Encrypted Chat, Online Presence (heartbeat 60s), Read Receipts, FCM (3 CFs), Rate Limiting, Chat preview + unread count, Anonymous guards, Phone verification (SMS, P2.5)

### Φάση 4+ (0%)
Typesense, Video (Agora), AI matching, Groups, Verified badge, Premium, Web, Admin panel

---

## Critical Bugs & Fixes

| # | Bug | Fix |
|---|---|---|
| 1 | `$(database)` σε `get()` paths → permission-denied | Hardcode `(default)` |
| 2 | `get(path).exists` → permission-denied (Firestore engine bug) | Use `.data.isVisible == true` |
| 5 | Encryption key missing on 2nd device join chat | `deriveKey(chatId)` — deterministic SHA-256 |
| 7 | `notBanned()` με custom claims → stale cache | `!exists(banned/{uid})` live Firestore read |
| 9 | Anonymous infinite spinner σε chats | `streamChats()` yields `[]` |
| 13 | ChatScreen rebuild loop (5x σε 4s) | Page keys + smart auth notifier + batch pagination |
| 14 | `isPublished: false` hardcoded σε save | Preserve `_loadedProfile.isPublished` |
| 15 | sendRequest() missing validation | 4-layer: UI guard + type selector + repo validation + Firestore rules |
| 16 | Search filter + geoHash composite index crash | Move allowVideoCall/allowDirectChat/isOnline/lookingFor/interests → `_passesFilters()` |
| — | City/country filter returns 0 results (geoHash=null) | `hasLocationFilter` skips `ORDER BY geoHash`, `WHERE country = ...` server-side |
| 17 | Registration UX — no info about email verification after signup | GoRouter redirect: `/welcome`→unverified→`/auth`; `verify()` skips link for non-anonymous; auto-show emailSent state; ProfileScreen banner for unverified |
| 18 | X/Αρχική button crash on `/auth` when reached via redirect | `context.pop()` → `context.go('/')` (redirect replaces route history, nothing to pop) |
| 19 | Stale `emailVerified` on returning verified users → forced redirect to `/auth` | `await user.reload()` in `AppRouter.init()` before `_authNotifier.notify()`; `emailVerified` added to redirect & auth logs |
| 20 | **403 avatar after reinstall** — Android backup restores Drift with stale download token; `getProfile()` never checks Firestore if local exists | `getProfile()` merge: compare Firestore `updatedAt`; sync `avatarUrl`/`photoUrls` when newer, respecting privacy (`showPhotos`) |
| 21 | **KeyStore corruption → all E2E keys deleted** (Android 12 & 16) — `flutter_secure_storage` 10.3.1 `resetOnError` deletes ALL keys on first migration failure; `getKey()` returns null → chat ciphertext unreadable | `getKeyOrDerive(chatId)`: single point of truth — try storage, fallback to deterministic `deriveKey()`, best-effort cache; bilingual placeholder `[Μη αναγνώσιμο μήνυμα / Unreadable message]` |

---

## Key Changes per Session

### Sessions 1-68 (Foundation)
- Project init, Blueprint, Isar/Drift, Firebase, Auth, Profile, GPS, Search, Chat, FCM, Online Presence
- Isar→Drift migration (48-50), Riverpod 2→3, deriveKey fix, `notBanned()` rewrite
- **Session 65**: Server-side filters + cursor pagination + 300 cap
- **Session 69**: Comm settings cleanup, Anonymous UX fix, LookingFor +3 options
- **Session 70**: Chat rebuild loop fix (page keys, smart auth notifier, batch pagination)
- **Session 71**: Auto-publish on comm change, Request validation chain (4 layers), client-side search filtering
- **Session 72**: Feature Flags (P3.1, 8 flags), Security Rules `$(database)` (P3.9)
- **Session 73**: Biometric Lock (P3.5) — LockScreen widget + lifecycle hooks
- **Session 74**: Typesense stub (P3.7) — `implements SearchRepository`
- **Session 75**: GoRouter errorBuilder (themed error page)
- **Session 76**: PresenceService race condition fix + `Future.wait`
- **Session 77**: `showPhotos` privacy toggle (schema v3→v4)
- **Session 78**: Profile Editor unsaved-changes dialog + biometric lock short-pause skip
- **Session 79**: Country field — `showCountry` toggle, publish, display, schema v4→v5
- **Session 80**: Null-overwrite bug fix (`removeWhere`), unit tests (13), widget test fix
- **Session 81**: Phone verification (P2.5) — full screen + provider + state machine
- **Session 82-90**: Phone verify polish (stale state, 30s timeout, inline spinners, prefixText, validation, status indicator, `_friendlyError` cleanup)
- **Session 91**: `isPhoneVerified` fix — empty string vs null (firebase_auth 6.5.1)
- **Session 92**: SettingsScreen cascade rebuild fix — `ConsumerStatefulWidget` + `ref.listen` + extracted section
- **Session 93-94**: Unlink Phone + stale cache fix (`reload()` after unlink)
- **Session 95**: Unlink not visible after verify fix + MediaQuery cascade analysis
- **Session 96**: `isOnline` overwrite by `publish()` — Read+Preserve fix
- **Session 97**: Country filter activation + GPS-first location + session cache
- **Session 98**: Auto-fill city/country + auto-publish + Nominatim autocomplete + `isManualLocation` + search fix (null geoHash) + manual location indicators
- **Session 99**: Debug logs for city-filter diagnosis
- **Session 100**: **Search fix** — `hasLocationFilter` flag, `WHERE country = ...` server-side, 2 new composite indexes, cursor format split
- **Session 101**: Deploy indexes ✅, test country=Κίνα 1 result ✅, city=Λαμία 1 result ✅
- **Session 102**: **Registration UX fix** — GoRouter redirect sends unverified email users to `/auth` (welcome→emailVerified ? '/' : '/auth'); `verify()` skips `linkWithEmailAndPassword` for non-anonymous; initState auto-shows emailSent for post-registration; ProfileScreen shows verify banner also for email-not-verified users
- **Session 103**: **X/Αρχική crash fix** — X button (dismiss) + "Αρχική" (verified) on `/auth` changed from `context.pop()` to `context.go('/')` because GoRouter redirect replaces route history, leaving nothing to pop back to
- **Session 104**: **Stale emailVerified fix + unsaved-changes dialogs**
  - `AppRouter.init()`: `await user.reload()` before `_authNotifier.notify()` to ensure fresh `emailVerified` from server (prevents stale-cache redirect to `/auth` for verified users)
  - `ProfileEditorScreen._isDirty`: now works in create mode (`_loadedProfile==null`) by comparing fields against defaults
  - `PrivacyEditorScreen`: added `_originalSettings` tracking, `_isDirty`, `_onBack()` with confirm dialog, PopScope wrapper on both loading and loaded states
- **Session 105**: **Email/Phone display fix in discovery** — `showEmail`/`showPhone` toggles now actually publish and display email/phone
  - `PublicProfile` freezed model: added `String? email, phone` fields
  - `profile_repository_impl.dart` `publish()`: conditional mapping `email: privacy?.showEmail == true ? profile.email : null` (and same for phone)
  - `profile_repository_impl.dart` `getProfile()`: restore `email`/`phone` when reading from Firestore fallback
  - `public_profile_view_screen.dart`: new `_buildContactCard` (responsive, bilingual, debug logs, edge case: κρύβεται αν και τα δύο null/empty)
  - Old users: need to re-publish (toggle privacy → save) for email/phone to appear in Firestore
- **Session 106**: **Distance filter audit** — complete analysis of radius/kilometer filter pipeline
  - Findings documented in `oldsessions.md → Distance Filter Todo`
- **Session 107**: **Haversine distance filter (🔴1)** — geohash_utils decode+haversine, _passesFilters haversine check, searchNearby distance filter, city+radius combo fix
- **Session 108**: **Haversine false negatives fix** — isWithinRadius() με cell BOUNDS (όχι center) για σωστή απόσταση όταν search center είναι εντός του geohash cell. Προηγούμενη υλοποίηση σύγκρινε GPS με geohash center (απόκλιση ~86km σε precision-3).
- **Session 109**: **🔴3 Stale lat/lng fix** — `_apply()` στο SearchFiltersScreen refreshάρει GPS πριν το search. `_isApplying` guard για double-tap. `mounted` check μετά από async. `forceRefresh: false` (session cache 5min) για άμεσο UX. Comprehensive debugs. `flutter analyze` clean, tested on device.
- **Session 110**: **🟡4 "X km away" distance display** — 5 files modified. SearchState +3 fields (searchCenterLat/Lng, distances Map), `_computeDistances()` helper (geohash decode + haversine), ProfileCard/PublicProfileHeader +distanceKm display row, loadMore merge distances, guard chat→profile via `distances[uid]` lookup. 0 Freezed changes.
- **Session 111**: **🟡4 Hybrid distance improvement + precision label** — `GeoHashUtils.distanceToNearestEdge()` (nearest point on cell boundary). Hybrid logic in `_computeDistances()`: nearestDist > 0 → nearest edge, else → center distance (inside cell fallback). New label format "Απόσταση Πόλης εντός: X km" / "Απόσταση Συνοικίας εντός: X km" based on geohash length (3=city, 5+=neighborhood). Debug logs throughout.
- **Session 112**: **Geo search overhaul (Option B)** — 8 files modified. `geohash_utils.dart`: `getNeighbours()` (9 cells), antimeridian wrap, precision=7 street. `firestore_search_repository.dart`: parallel queries per cell + dedup, `_geoSearch()`/`_generalSearch()` split, cityNormalized/countryNormalized case-insensitive. Critical fix: `'{cell}~'` → `'$cell~'` string interpolation bug (γραμμές 86, 258). `firestore.indexes.json`: 3 new normalized indexes, 5 orphan indexes deleted via --force. `auth_repository_impl.dart`: `LocationService.clearSession()` στο signOut. Debug config: new `repositoryFilter` flag. Comprehensive debugs added to `_passesFilters()`, discovery_screen flow, and geohash utils. `flutter analyze` clean ✅.
- **Session 113**: **403 avatar bug after uninstall/reinstall fix** — root cause: Android auto-backup restores Drift DB with stale avatar download URL (token invalidated by re-upload). `getProfile()` returned local profile immediately without checking Firestore. Fix: merge logic in `getProfile()` (`profile_repository_impl.dart`) — when local profile exists, check Firestore `updatedAt`; if newer, merge `avatarUrl`/`photoUrls` (only fields present, respecting `showPhotos` privacy). Tested: merge works after reinstall (`getProfile: merged avatarUrl/photoUrls from Firestore`). Only one file modified. `flutter analyze` clean ✅.
- **Session 114**: **ChatScreen rebuild fix (P1)** — Split `ChatScreen` σε 3 ανεξάρτητα ConsumerStatefulWidgets: `ChatScreen` (shell, 0 provider dependencies), `_ChatMessagesList` (messages + deferred `markAsRead` + length guard), `_ChatInputBar` (μόνο authStateProvider). `messagesProvider` + `publicProfileStreamProvider` → `autoDispose` για cleanup streams. `_onMessagesChanged` με `mounted` check + `_lastMessageCount` guard για αποφυγή duplicate scroll animations. `Future.microtask` + `_hasMarkedRead` guard για single `markAsRead`. 35 backup files removed (.bak, .bak2, .backup). `flutter analyze` ✅, 14/14 tests ✅, verified on 2 devices: 2-3 rebuilds (από 15+).
- **Session P2 (115)**: **FCM foreground snackbar fix (P2)** — Root cause: `_onFcmForeground` used `this.context` (above `MaterialApp.router`). `ScaffoldMessenger` is created INSIDE `MaterialApp`, so `ScaffoldMessenger.maybeOf(NearMeAppContext)` → `null` → snackbar silently skipped. Fix: save `MaterialApp.router.builder` context in `BuildContext? _appContext` field (line 173), set inside builder (line 310), use in `_onFcmForeground` (lines 268–275). Only `main.dart` modified (7 lines diff). Zero changes to `app_messenger.dart`. `flutter analyze` ✅, 15/15 tests ✅ (new test: "AppMessenger with MaterialApp.builder context — P2 fix"). Verified on 2 devices: snackbar visible (no WARN).
- **Session 116**: **FlutterSecureStorage algorithm migration fix (🔴 P3.8)** — Root cause: Android KeyStore corruption on Android 12 & 16 causes `resetOnError` to delete ALL chat encryption keys. `messagesStream()` showed raw ciphertext instead of falling back to deterministic `deriveKey()`. Fix:
  - `encryption_utils.dart`: `AndroidOptions(resetOnError: true)` explicit; try/catch σε `getKey()`/`storeKey()`/`deleteKey()`/`clearAllKeys()` (PlatformException, "Data has been reset" sentinel, invalid base64). **NEW** `getKeyOrDerive(chatId)` → Single Point of Truth: try storage → fallback `deriveKey()` → best-effort cache. 8 new debug logs.
  - `chat_repository_impl.dart`: Removed `_ensureKeyDerived()` (−29 lines). All 4 callers (`createChat`, `sendMessage`, `messagesStream`, `_syncChatFromFirestore`) now use `getKeyOrDerive()`. Raw ciphertext replaced with bilingual placeholder `[Μη αναγνώσιμο μήνυμα / Unreadable message]`.
  - `test/utils/encryption_utils_test.dart` — 15 new unit tests (deriveKey, encrypt/decrypt round-trip, validation, getKeyOrDerive fallback, placeholder).
-   `flutter analyze` ✅, `flutter test` 30/30 ✅.
-   **Session 117**: **FCM foreground notification suppression + auto-scroll fix** — GoRouterState.of(context) fails outside route subtree even in MaterialApp.router.builder. Replaced GoRouter-dependent `currentRoute` with `FcmService.activeChatId` set directly by ChatScreen (initState/dispose). Changes:
    - `fcm_service.dart`: `currentRoute → activeChatId`; `shouldSuppressForeground()` compares `chatId == activeChatId`
    - `main.dart`: removed `GoRouterState.of(context).uri.toString()` + unused `go_router` import
    - `chat_screen.dart`: `FcmService.activeChatId = widget.chatId` in initState/dispose of `_ChatScreenState`
    - `flutter analyze` ✅, `flutter test` 30/30 ✅, verified on 2 devices (Android 12 + 16)

---

## Current State (Session 117 — FCM foreground noise fix)

| Μέτρο | Τιμή |
|---|---|
| Completion | ~99% (Phases 1-3 100%) |
| Firestore indexes | 17 composite deployed (5 orphan cleaned) |
| Build | `flutter analyze` clean, release APK ~14.5MB |
| Tests | **30/30 passed** ✅ (15 new: encryption_utils_test) |
| Backup files | 0 ✅ (Session 114 + P2 clean) |

### Remaining Gaps
- **P1**: ~~ChatScreen excessive rebuilds~~ ✅
- **P2**: ~~FCM foreground snackbar silently skipped~~ ✅
- **P3.6**: Auto-lock timer (schema exists, no runtime)
- **P3.8**: ~~FlutterSecureStorage algorithm migration (key loss)~~ ✅
- **P3.9**: ~~FCM foreground notification noise (redundant snackbar when in chat)~~ ✅ (Session 117)
- **Phase 4**: Video (Agora), AI matching, Groups, Admin, Web, Premium, Typesense

### Distance Filter Todo (ιεραρχημένο)

| Priority | Θέμα | Αρχείο(α) | Εκτίμηση |
|:--------:|------|-----------|:--------:|
| 🔴 **1** | **Haversine στο `_passesFilters()`** ✅ — isWithinRadius() με cell BOUNDS, όχι cell center | `geohash_utils.dart`, `firestore_search_repository.dart` | ✅ (Session 107-108) |
| 🔴 **2** | **Radius αγνοείται όταν active city/country** ✅ — διορθώθηκε ΠΑΡΕΜΠΙΠΤΟΝΤΩΣ από 🔴1 (isWithinRadius ανεξάρτητο από hasLocationFilter) | `firestore_search_repository.dart` | ✅ (Session 108) |
| 🔴 **3** | **Stale lat/lng στο SearchFilters state** — το radius υπολογίζεται από παλιά τοποθεσία χωρίς refresh ✅ | `search_filters_screen.dart` | ✅ (Session 109) |
| 🟡 **4** | **Εμφάνιση απόστασης "X km away"** στο ProfileCard και PublicProfileViewScreen ✅ | `search_provider.dart`, `geohash_utils.dart`, `profile_card.dart`, `public_profile_header.dart` | ✅ (Session 110-111) |
| 🟡 **5** | **Hardcoded 10km initial search** — ο χρήστης δεν μπορεί να αλλάξει default radius χωρίς να μπει στα φίλτρα | `discovery_screen.dart` | 30 λεπτά |
| 🟢 **6** | **UX: radius slider χωρίς reference scale** (10km=πόλη, 50km=νομός, 200km=περιφέρεια) | `search_filters_screen.dart` | 30 λεπτά |
| 🟢 **7** | **Confusion: radius + city/country** — όταν έχει επιλεγεί city, το radius αγνοείται αλλά ο χρήστης δεν το βλέπει | `search_filters_screen.dart` | 30 λεπτά |

### 🔴 1 — Haversine Distance Filter ✅ (Ολοκληρώθηκε Session 107)

**Στόχος**: Διόρθωση false positives από geohash bounding box (ορθογώνιο ≠ κύκλος).

**Εμπλεκόμενα αρχεία**:
- `lib/core/utils/geohash_utils.dart` — προσθήκη decode() + haversineDistance()
- `lib/repositories/firestore_search_repository.dart` — haversine filter σε _passesFilters() + searchNearby()

**Βήματα υλοποίησης**:

| Βήμα | Περιγραφή | Αρχείο |
|------|-----------|--------|
| 1 | decode(geohash) → (lat, lng) — κέντρο cell από base32 bits | `geohash_utils.dart` |
| 2 | haversineDistance(lat1, lon1, lat2, lon2) → km | `geohash_utils.dart` |
| 3 | haversine check στο _passesFilters() — πριν return true | `firestore_search_repository.dart` |
| 4 | haversine filter στο searchNearby() — μετά το Firestore fetch | `firestore_search_repository.dart` |
| 5 | flutter analyze + test | CLI |

**Edge cases** (όλα handled):
- `geoHash == null/empty` → skip (hidden location)
- `radiusKm == null/≤0` → skip
- geohash decode → ArgumentError (πιάνεται από catch)
- City + radius combo → haversine εφαρμόζεται (side-fix για 🔴2)
- Cursor pagination → unaffected (post-filter)
- searchNearby() + cursor → unaffected

**Known limitations** (pre-existing, όχι νέο από το fix):
- Αν haversine απορρίψει ΟΛΑ τα results, `hasMore=true` αλλά `loadMore()` ξανατρέχει Firestore (ίδιο limitation με τα υπόλοιπα client-side φίλτρα)

**Σημείωση**: Η λύση διορθώνει ΠΑΡΕΜΠΙΠΤΟΝΤΩΣ το **🔴2** (radius ignored with city/country), αφού το haversine στο `_passesFilters()` ελέγχεται ανεξάρτητα από το `hasLocationFilter`.

**Αλλαγές που έγιναν**:
- `geohash_utils.dart`: decode() → (lat, lng) + haversineDistance() → km + **isWithinRadius()** (cell bounds, not center)
- `firestore_search_repository.dart`: _passesFilters() haversine check + searchNearby() removeWhere
- **FIX (Session 108)**: isWithinRadius() αντί decode()+haversine — συγκρίνει με cell BOUNDS, όχι cell center. Λύνει false negatives όταν search center είναι μέσα στο geohash cell αλλά μακριά από το center.

---

### 🔴 3 — Stale lat/lng στο SearchFilters ✅ (Ολοκληρώθηκε Session 109)

**Στόχος**: Το `_apply()` ανανέωνε όλα τα φίλτρα ΕΚΤΟΣ από `latitude`/`longitude`. Η αναζήτηση χρησιμοποιούσε τοποθεσία από προηγούμενο auto-search (ώρες/μέρες πριν), οπότε το radius εφαρμοζόταν σε stale σημείο.

**Εμπλεκόμενα αρχεία**:
- `lib/features/discovery/screens/search_filters_screen.dart` (primary)
- Backup: `search_filters_screen.dart.bak`

**Αλλαγές**:
- `import LocationService` — πρόσβαση σε GPS session cache
- `bool _isApplying = false` — guard double-tap όσο το GPS εκτελείται
- `_apply()` → `Future<void> _apply() async` — await GPS refresh πριν search
- `_refreshLocation()` — `getCurrentLocation(forceRefresh: false)` (session cache 5min ή live GPS)
- `mounted` check μετά το async GPS — αποτροπή exception σε dispose mid-GPS
- Comprehensive debug logs σε κάθε βήμα

**Edge cases handled**:
- Διπλό/πολλαπλό tap Apply → `_isApplying` guard → SKIPPED log
- Dispose mid-GPS → `!mounted` return → aborted log
- GPS timeout/αποτυχία → cached location preserved → log με failure reason
- `updateLocation()` χωρίς `radiusKm` → διατηρεί το radius που μόλις ορίστηκε από `updateRadius()`

**Επαλήθευση**:
- `flutter analyze` clean
- Tested on device:
  - Apply μετά από 50'': `Session cache: age=0min` → 0ms delay ✅
  - Apply μετά από 1': `Session cache: age=1min` → 0ms delay ✅
  - Double tap (×2): `SKIPPED (already applying)` ✅
  - Rapid tap (×4): 4× `SKIPPED`, 1× execute ✅
  - `SearchNotifier.search` με φρέσκα lat/lng + σωστό `radiusKm: 10.0` ✅

---

### Key Conventions
- File size ≤ 400 lines (1 exception: profile_repository_impl)
- `DebugConfig.log(flag, msg)` σε κάθε operational action
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): `L10n.isGreek()` + `L10n.localizedMessage()`
- Backup files: **κανένα στο repo** (35 `.bak`/`.bak2`/`.backup` καθαρίστηκαν Session 114)
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
