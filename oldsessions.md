# NearMe — Old Sessions Archive

> Συμπυκνωμένο archive: τεχνολογίες, αρχιτεκτονική, σημαντικά fixes, τρέχουσα κατάσταση.

## ΚΕΦΑΛΑΙΟ 1 — ΤΕΧΝΟΛΟΓΙΕΣ

| Layer | Επιλογή |
|---|---|
| State Management | Riverpod 3.x (Notifier, @riverpod) |
| Local DB | Drift 2.33 (SQLite, schema v12) |
| Navigation | GoRouter 17 (StatefulShellRoute) |
| Auth | Firebase (Anonymous → Email/Phone) |
| Cloud DB | Firestore (collectionGroup, 21 composite indexes) |
| Storage | Firebase Storage (avatars/photos 5MB, chat_media 50MB) |
| Functions | Firebase Functions (TypeScript, 1st Gen, 6 deployed) |
| Encryption | encrypt 5.0.3 (AES-256 GCM) + deriveKey (SHA-256) |
| Secure Storage | flutter_secure_storage (encryption keys) |
| Geo | geolocator + geoflutterfire_plus + geocoding |
| Search v1 | Firestore native (active) |
| Search v2 | Typesense self-hosted (stub, Phase 4) |
| Push | FCM (3 Cloud Functions + addGroupParticipant + leaveGroup + fcm-utils) |
| i18n | flutter_localizations + intl (el/en, L10n) |
| Biometric | local_auth 3.0 |
| Emoji | emoji_picker_flutter v4.4.0 |
| GIF | GIPHY API (dart:io HttpClient) |
| Images | image_picker + image_cropper + cached_network_image |

## ΚΕΦΑΛΑΙΟ 2 — ΑΡΧΙΤΕΚΤΟΝΙΚΕΣ ΑΠΟΦΑΣΕΙΣ

### Auth — Anonymous + Lazy Upgrade
Χρήστης ξεκινά ανώνυμος → upgrade σε verified (email/phone) μόνο όταν θελήσει επικοινωνία. `canUserCommunicate` = `!user.isAnonymous && (user.emailVerified || hasPhone)`.

### Γεωγραφία — GPS με fallback manual
GPS → lat/lng στο Drift (ΠΟΤΕ raw στο Firestore). GeoHash μόνο στο Firestore με precision levels (default: neighborhood ~2.5km²). Fallback: text field για χειροκίνητη πόλη/χώρα.

### Search — Υβριδικό (Repository Pattern)
Firestore native (τώρα) → Typesense (Phase 4). Abstract SearchRepository — swap χωρίς UI changes. 4 query paths: GPS-only, City+radius, City-only, Country-only. Cursor pagination + 300 cap.

### Security Architecture (5-Layer)
1. **Device**: Drift + flutter_secure_storage + FLAG_SECURE + Biometric Lock + Auto-lock timer
2. **Auth**: Anonymous → Email/Phone verify, `userChanges()` (όχι `authStateChanges()`)
3. **Data Rules**: Firestore Security Rules (7 helpers, 21 composite indexes)
4. **Transport**: TLS 1.3 + AES-256 GCM E2E chat (deriveKey deterministic)
5. **Behaviour**: Rate limiting (10 reports/hr), auto-ban (5 reports), request expiry (48h), 6 Cloud Functions

### Data Flow
- **Local (Drift)**: UserProfile (23 fields), PrivacySettings (13 toggles), ConsentLog (paginated LIMIT 50), ChatCache, SavedSearch, AppSettings, BlockedUser
- **Firestore**: users/{uid}/public (snapshot), status (isOnline), blocked, fcm_tokens, chats/{chatId}/messages (AES-256), requests, reports, banned
- **Repository Pattern**: 7 abstract interfaces — ποτέ raw Firestore στο UI

## ΚΕΦΑΛΑΙΟ 3 — ΦΑΣΕΙΣ ΥΛΟΠΟΙΗΣΗΣ

### Φάση 1 — Core & Privacy (100%)
Firebase Init, Drift (7 tables, schema v12), Profile CRUD, PrivacySettings (13 toggles: +showAvatar Session 164), ConsentLog (paginated Session 157), Publish/Unpublish, GPS + GeoHash, i18n el/en, Theme, Security Rules, Repository Pattern, AppMessenger/AppStateWidgets, BlockedUser, Report + Auto-ban CF, Delete Account, Screenshot Prevention, Biometric Lock + Auto-lock timer, Feature Flags (10)

### Φάση 2 — Discovery (100%)
Firestore search (collectionGroup, 4 query paths), SearchFilters (15 interests), ProfileCard, PublicProfile view, Saved Searches (schema v8: +3 bool filters), Block/Report, Cursor pagination + 300 cap, Server-side filters + `_passesFilters()` client safety net, Typesense stub, Nominatim autocomplete (800ms debounce)

### Φάση 3 — Communication (100%)
Verify Account (email), Phone verification (SMS, state machine 5 states), E2E Encrypted Chat (AES-256 GCM), Request System (48h expiry, readAt unread tracking), Online Presence (heartbeat 60s), Read Receipts, FCM (5 CFs), Rate limiting, Chat preview + unread count, E2E encryption indicator

### MultiChat (Group Chat) — 100% (Sessions 158-163)
31/31 steps. Group CRUD, roles (creator/admin/member), invites, public groups, permissions, audit log, bilingual system messages, FCM group add notification, callable CF for addParticipant + leaveGroup. 4 composite indexes deployed.

### Media Input — 100% (Sessions 175-191)
Phase 1: Emoji Picker (v4.4.0, theme-aware, responsive, instance cache). Phase 2: GIF Support (GIPHY API, Tenor discontinued). Phase 3: Image Messages (gallery/camera, upload to Storage, full-screen preview, storage cleanup on delete). Phase 4: Media "+" popup + multiline TextField.

### Chat UI Redesign — 100% (Sessions 187-199)
Viber-like: bubble tails (CustomPainter), date separators (Σήμερα/Χθες/ημερομηνία), message grouping (ίδιος sender <5min), sent color `#075E54`, timestamp inside bubble, `ReadReceiptIndicator` shared widget, emoji without bubble card, resizeToAvoidBottomInset=false, rebuild cascade fixes (5 phases), `_SafeInputArea`, pending=true suppression.

### Φάση 4+ (0%)
Typesense, Video (Agora), AI matching, Groups extra features, Verified badge, Premium, Web, Admin panel

## ΚΕΦΑΛΑΙΟ 4 — ΚΡΙΣΙΜΑ BUGS & FIXES

### Layer 1 — Device & Local Storage
| # | Bug | Fix | Session |
|---|---|---|---|
| 5 | Encryption key missing on 2nd device join chat | `deriveKey(chatId)` — deterministic SHA-256 | 21 |
| 21 | KeyStore corruption → όλα τα E2E keys deleted (Android) | `getKeyOrDerive(chatId)`: try storage → fallback deriveKey() | 21 |
| 24 | Biometric idle timer runs on `inactive` (notification shade, phone call) | Handle `AppLifecycleState.inactive` alongside `paused` | 152 |
| 25 | Idle timer active after sign-out — LockScreen over welcome screen | `ref.listen(authStateProvider)` — stop timer + reset `_isLocked=false` | 152 |

### Layer 2 — Authentication
| # | Bug | Fix | Session |
|---|---|---|---|
| 22 | Stale `emailVerified` after `reload()` — `authStateChanges()` δεν εκπέμπει | `authStateProvider` → `FirebaseAuth.instance.userChanges()` | 132 |
| 18 | X button crash on `/auth` via redirect | `context.pop()` → `context.go('/')` | — |
| 19 | Stale `emailVerified` on returning verified users | `await user.reload()` in AppRouter.init() | — |
| 151 | 6× PERMISSION_DENIED after signOut — Firestore listeners ζωντανοί μετά auth token ακύρωση | Static `isSigningOut` flag + `StreamProvider.autoDispose.family` + provider invalidation πριν signOut | 151 |

### Layer 3 — Data Rules & Firestore
| # | Bug | Fix | Session |
|---|---|---|---|
| 1 | `$(database)` σε get() paths → permission-denied | Hardcode `(default)` | 72 |
| 2 | `get(path).exists` → permission-denied | Use `.data.isVisible == true` | 72 |
| 7 | `notBanned()` με custom claims → stale cache | `!exists(banned/{uid})` live Firestore read | 68 |
| 20 | 403 avatar after reinstall — backup restores stale token | `getProfile()` merge: compare Firestore `updatedAt` | — |
| 23 | Firestore null cast — legacy profile docs without `uid` field | `_safePublicProfileFromJson()` null check | 133 |
| 27 | joinPublicGroup crash — transaction `get()` blocked by rules (not participant yet) | Public read rule `isPublic == true` + self-join update rule OR | 169 |
| 28 | `notBanned()` gaps — 17 rules missing ban check in chat/request layer | Add `notBanned()` to all 17 rules | 170 |
| 29 | memberCount silent failure — groups update required `isGroupCreator` even for `memberCount` | `isGroupMember()` helper + `hasOnly(['memberCount'])` OR rule | 170 |
| 143 | City-filter Firestore crash — age range + `orderBy('__name__')` without `orderBy('age')` | Remove age `where()`, filter client-side via `_passesFilters()` | 143 |
| 160 | addParticipant PERMISSION_DENIED (όταν ≥2 μέλη) — blocked subcollection read | New `addGroupParticipant` callable CF (Admin SDK bypass) | 160 |
| 160 | markAsRead PERMISSION_DENIED — CEL string interpolation `${}` not supported + `affectedKeys()` top-level only | `diff().affectedKeys().hasOnly([request.auth.uid])` nested | 160 |

### Chat & Messages
| # | Bug | Fix | Session |
|---|---|---|---|
| 13 | ChatScreen rebuild loop (5x σε 4s) | Page keys + smart auth notifier + batch pagination | 70 |
| 26 | Chat disappears from list after create — `_saveChatCache` duplicate → UPDATE 0 rows | Remove `_saveChatCache` root cause + `var rows`/`rows=[]` defense | 153 |
| 134 | ChatScreen crash — `GoRouterState` σε `initState` | Μεταφορά σε `didChangeDependencies()` | 134 |
| 137 | ProfileCards ~20× rebuilds | `ValueKey(p.uid)` + `select()` + extract `SearchResultsGrid` | 137 |
| 147b | Duplicate Encrypt/Decrypt | Reuse encrypted string + encrypt/decrypt cache + remove `ref.invalidate(chatsProvider)` from markAsRead | 147b |
| 155 | Online Status Flicker — ProfileCard renders 2× (null→300ms→true) | Null-coalescing fallback: `streamOnline ?? profile.isOnline` | 155 |
| 156 | Haversine Memoization — ~1200 calls per search | `_distanceCache` Map + `clearDistanceCache()` → ~50 calls (96% reduction) | 156 |
| 167 | chatsProvider dispose/recreate στο startup (2×) | `prev is AsyncData` guard στο auth listener | 167 |
| 174 | Rebuild cascade από Firestore `.snapshots()` metadata changes | `chatDocProvider` cache + `DeepCollectionEquality` | 174 |
| 178 | participantUidsProvider identity comparison (`List.==`) | Cache `_participantUidCaches` + `DeepCollectionEquality` | 178 |
| 179 | Emoji picker rebuild storm (~20-30× ChatScreen) | `EmojiPickerPanel` leaf widget extraction | 179 |
| 188 | Exit animation storm — `GoRouterState.of(context)` στο `didChangeDependencies` | Remove `didChangeDependencies`, fallback `otherNickname ?? widget.chatId` | 188 |
| 188 | Idle rebuilds — ListView.builder χωρίς ValueKey | `ValueKey(msg['id'])` + `ValueKey('ds_\$date')` | 188 |
| 189 | MainShell LayoutBuilder cascade → Scaffold recreate | StatefulWidget + `MediaQuery` + cached `isWide` | 189 |
| 192 | chatDocProvider.select() returning AsyncValue → always notify | Return `Map<String, dynamic>?` (Dart deep comparison) | 192 |
| 193 | participantUidsProvider dispose/recreate cascade (autoDispose) | Remove `autoDispose` from `participantUidsProvider` | 193 |
| 195 | decrypt lastMessage failed for media messages (FormatException) | Skip decrypt when `lastMessageType` is gif/image/video | 196 |
| 195 | Rebuild cascade 17-53× από pending=true→false (serverTimestamp) | Suppress pending=true emits in chatDocProvider | 199 |
| 196 | LayoutBuilder per-bubble → constraint cascade rebuild | Pre-computed `bubbleMaxWidth` at ChatMessagesList level | 196 |
| 197 | markAsRead σε build path → Firestore write → cascade | Move markAsRead to `initState` via `addPostFrameCallback` | 197 |
| 198 | Keyboard animation cascade (26× από MediaQuery dependency) | `_SafeInputArea` leaf widget extraction | 198 |
| 199 | messagesStream always emitted new list instances after decrypt — unnecessary ChatMessagesList rebuilds | `DeepCollectionEquality` cache: return same list reference if content unchanged | 200 |
| 200 | _obtainBubble cache cascade — every signature miss recreates all MessageBubble widgets | `_MessageBubbleSignature` + `_obtainBubble` cache with `DeepCollectionEquality` on message map + all params | 200 |
| 201 | EmojiOnlyBubble static `_buildCounts` memory leak — global Map<String,int> never cleared, misleading debug output | Remove static debug map (emoji_only_bubble.dart) | 201 |
| 202 | markAsRead serverTimestamp write cascade — group chat signature miss from every navigation | Guard: skip `FieldValue.serverTimestamp()` write when `unreadCount==0` (read from local Drift cache) | 201 |
| 203 | Bubble width = bubbleMaxWidth (264) on initial load — Column(mainAxisSize: min, crossAxisAlignment: end) fails intrinsic sizing on first layout pass inside Container(maxWidth) | `IntrinsicWidth` wrapper around inner Column in TextMessageBubble | 203 |
  
### Profile & Privacy
| # | Bug | Fix | Session |
|---|---|---|---|
| 14 | `isPublished: false` hardcoded στο save | Preserve `_loadedProfile.isPublished` | — |
| 80 | Null-overwrite fix (`removeWhere`) | Unit tests (13), widget test fix | 80 |
| 92 | SettingsScreen cascade rebuild fix | ConsumerStatefulWidget + `ref.listen` | 92 |
| 142 | Riverpod autoDispose race στο `_save()` | Try-catch γύρω από `ref.invalidate` | 142 |
| 162 | Role-based visibility: Invites gate + isAdmin from groupPermissionsProvider | `hasPermission(uid, GroupPermission.inviteMembers)` | 162 |
| 161 | UID αντί nickname σε 4 screens (CreateGroup, GroupInfo, AuditLog, PermissionsEditor) | Resolve from participantNicknames map | 161 |
| 165 | maxParticipants display bug — UI reads from cache snapshot (10) ignores server (30) | Fix guards: `maxP != _currentMax && maxP > 0` | 165 |

## ΚΕΦΑΛΑΙΟ 5 — SESSION PROGRESSION (ΣΥΝΟΠΤΙΚΟ)

### Foundation (Sessions 1-68)
Project init, Blueprint, Isar→Drift migration, Firebase, Auth, Profile CRUD, GPS, Search prototype, Chat init, FCM, Online Presence. Riverpod 2→3, deriveKey fix, `notBanned()` rewrite. Server-side filters + cursor pagination + 300 cap.

### Communication & Profile (Sessions 69-100)
Comm settings cleanup, Chat rebuild loop fix, Auto-publish, Request validation (4-layer), Feature Flags (8), Biometric Lock, Typesense stub, GoRouter errorBuilder, PresenceService race fix, `showPhotos` privacy toggle, Schema v3→v6, Country field, Null-overwrite fix, Unit tests (30), Phone verification, SettingsScreen cascade fix, Unlink phone, `isOnline` preserve, Country filter + GPS-first + auto-publish + Nominatim + `isManualLocation`.

### Search Overhaul (Sessions 100-131)
`hasLocationFilter` flag, `WHERE country` server-side, parallel geo queries per cell, Haversine distance, cell BOUNDS fix, stale lat/lng refresh, distance display, Adaptive search precision, `getNeighbours` `*2` bug, default radius selector. Auth fixes: registration UX redirect, stale `emailVerified`, canUserCommunicate 5-layer guard.

### Sessions 132-150 (Polish & Bugfixes)
| Sess | Key Fix |
|:----:|---------|
| 132 | `userChanges()` αντί `authStateChanges()` για reload() emit |
| 133 | `_safePublicProfileFromJson()` null check για legacy docs |
| 134 | GoRouterState moved to `didChangeDependencies()` + raw AlertDialog→AppMessenger |
| 135-136 | FCM biometric lock bypass — `FcmService.isLocked` flag + pending nav guard |
| 137 | ProfileCards ~20× rebuilds — `ValueKey` + `select()` + SearchResultsGrid extraction |
| 138 | FCM retry — exponential backoff 1s→2s→4s, 3 retries |
| 139 | Unread tracking requests (readAt, blue dot, badge, FCM deep link `/requests/:id`) |
| 140 | RenderFlex overflow fixes (discovery + delete account: LayoutBuilder + SingleChildScrollView) |
| 141 | Image Cropper (1:1 avatar, free ratio photos) |
| 142 | Riverpod autoDispose race — try-catch γύρω από invalidate |
| 143 | L2 badge iOS + L4 locale `?? 'en'` + **P0 city-filter Firestore crash** |
| 144 | Saved search bool DB fix (3 columns, schema v7→v8) |
| 145-146 | Breakpoint spam fix (cache) + 16/16 files constraint-based responsive |
| 147 | `_saveSearch()` stale state + 147b: Duplicate Encrypt/Decrypt (3 fixes) |
| 148a | RenderFlex overflow (request_card_widgets: Row→Wrap) |
| 148β | Auto-scroll to last message on chat open |
| 149 | Auto-search after reset filters (preserve GPS) |
| 150 | Saved search apply async + city+radius→`_geoSearch` + GPS refresh |

### Sessions 151-170 (Critical Bugfixes + MultiChat)
| Sess | Key Fix |
|:----:|---------|
| 151 | **6× PERMISSION_DENIED after signOut** — isSigningOut flag + autoDispose + provider invalidation |
| 152 | **Biometric idle timer `inactive` + sign-out** — stop timer, reset `_isLocked` |
| 153 | **ChatCache duplicate bug** — remove `_saveChatCache` from createChat, `var rows`/`rows=[]` |
| 154 | P1.1/P2.1/P2.2 verification audit — all already fixed |
| 155 | **Online Status Flicker** — `streamOnline ?? profile.isOnline` null-coalescing |
| 156 | **Haversine Memoization** — `_distanceCache` → 96% reduction |
| 157 | **ConsentLog Pagination** — `LIMIT 50 OFFSET ?` + loadMore button |
| 158 | **MultiChat Phase 1-7** — Group chat foundation (22/31 steps) |
| 159 | **MultiChat Phase 9** — 3× P0 fixes (deleteKey isSelf, memberCount, block check groups) + deploy rules/indexes/functions |
| 160 | **CRITICAL** — `addParticipant` PERMISSION_DENIED (callable CF) + `markAsRead` PERMISSION_DENIED (rules CEL fix) + arrayUnion crash |
| 161 | UID→Nickname fixes + avatar εμφάνιση (4 screens) |
| 162 | Role-based visibility: Invites gate + isAdmin from groupPermissionsProvider |
| 163 | Bilingual system messages SPoT (`SystemMessageFormatter`) + 5 νέες actions + FCM group add |
| 164 | Split photo privacy: `showAvatar` + `showPhotos` ξεχωριστά (schema v11→v12) |
| 165 | **Delete chat 1-to-1 flow** (request + approve/reject) — ChatDeleteMixin |
| 166 | 9 delete chat fixes + maxParticipants display bug (2-tier) |
| 167 | chatsProvider dispose/recreate στο startup — `prev is AsyncData` guard |
| 168 | **Firestore Cost Phase B**: unreadCount map (zero count queries) + parallel reads + conditional verify |
| 169 | **P0 joinPublicGroup crash** (rules read/update fix + nickname refactor) + member status UI |
| 170 | **notBanned() σε 17 chat/request rules** + `isGroupMember` helper + memberCount fix |

### Sessions 171-183 (Group Chat Polish + Media Input)
| Sess | Key Fix |
|:----:|---------|
| 171 | **leaveGroup callable CF** (Admin SDK bypass for self-removal) + GoError navigation race fix |
| 172 | GroupInfo Add Member search bug — stale participantRoles keys (priority fix) |
| 173 | Blocked user add bilingual error + existing members UI (disabled Chip) + auto-localize AppMessenger |
| 174 | **Rebuild loop fix**: chatDocProvider cache + `DeepCollectionEquality` |
| 175 | Media Input Plan (`media_input.md`) + Phase 1 proposal |
| 176 | **Phase 1: Emoji Picker** — `ChatInputBar` extraction + `emoji_picker_flutter v4.4.0` |
| 177 | **Theme-aware EmojiPicker** — `EmojiPickerConfig` SPoT + responsive height |
| 178 | **ChatScreen rebuild storm** — participantUidsProvider cache + `select()` αντί direct watch |
| 179 | **EmojiPickerPanel extraction** — rebuild storm isolation (leaf widget) |
| 180 | **Instance cache** — StatefulWidget + SPoT restoration + decrypt log summary |
| 181 | **Phase 2: GIF Support** — GIPHY API (Tenor discontinued) + `GifPickerSheet` + `_GifBubble` |
| 182 | **Phase 3: Large Emoji-Only** — `EmojiOnlyBubble` (font size 64/48/36/28px) |
| 183 | **Profile Sync Across Chats** — nickname+avatar auto-sync σε όλα τα chat docs + avatar UI |

### Sessions 184-199 (Chat Features + Rebuild Cascade Elimination)
| Sess | Key Fix |
|:----:|---------|
| 184 | **Reaction System** — emoji reactions (Map<UID, emoji>), toggle, preset + custom |
| 185 | **Reply to Message** — long-press → reply banner → send (12 steps, 11 files) |
| 186 | Reply flag enable + dispose crash fix + ReplyPreview dark theme colors |
| 187 | **Viber-like Chat Redesign** — bubble tails (CustomPainter), date separators, message grouping |
| 188 | **Chat rebuild storm** — remove GoRouterState + ValueKey(msg['id']) + memoization |
| 189 | MainShell rebuild fix (StatefulWidget + cached isWide) + reply delete fix |
| 190 | **Phase 3: Image Messages** — gallery/camera, Storage upload, full-screen, storage cleanup |
| 191 | **Media "+" Popup** + multiline TextField (maxLines:5) |
| 192 | ChatMessagesList rebuild fix — `select()` return Map (deep comparison) |
| 193 | participantUidsProvider dispose/recreate cascade — remove autoDispose |
| 194 | ReadReceiptIndicator shared widget + emoji card removal + text alignment end |
| 195 | Log Analysis: `resizeToAvoidBottomInset: false` + 5 remaining issues found |
| 196 | **LayoutBuilder removal** — pre-computed `bubbleMaxWidth` (cascade eliminated) |
| 197 | **markAsRead cascade fix** — move to `initState` postFrameCallback + _MessageReadProps precompute |
| 198 | **Keyboard cascade eliminated** — `_SafeInputArea` leaf widget (26→0 rebuilds) |
| 199 | **pending=true suppression** — chatDocProvider double-emit fixed |
| 200 | **messagesStream equality caching** — `DeepCollectionEquality` σε decrypted messages list (chat_repository_impl.dart) |
| 200 | **_MessageBubbleSignature + _obtainBubble cache** — MessageBubble instances cached by signature (chat_messages_list.dart) |
| 201 | **EmojiOnlyBubble _buildCounts cleanup** — remove static debug map (memory leak, misleading cascade counters) |
| 201 | **markAsRead guard** — skip serverTimestamp write when unreadCount==0 via local Drift cache (prevents group chat cascade) |
| **206** | **Server-side authoritative geoHash** — computeGeoHash CF (πιστό GeoHashUtils port), Firestore SPoT geoPrecision, update rule blocks client geoHash write, auto-publish σε κάθε save, live distance από geoHash αντί searchState.distances, 5 files changed |
| **207** | **Mock-location detection** — `position.isMocked` check σε GPS + lastKnown, LocationFailure.mockLocationDetected, discovery_screen μήνυμα fake GPS, 2 files changed |
| **208** | **Client-side search rate limiting** — `_checkRateLimit()` στο SearchNotifier (search_provider.dart:118), fixed-window 30 queries/5min, CF `checkSearchRateLimit` με transaction, firestore.rules rateLimits write:false, fail-open σε network/CF failure |
| **209** | **deleteUserData orphaned subcollections fix** — +3 subcollection deletes (privacy/settings, blocked/, rateLimits/search) σε CF `deleteUserData` (index.ts) + client-side defense-in-depth (`auth_repository_impl.dart:76-89`) + UI list update (`delete_account_screen.dart:213-221`). backup: `backups/deleteUserData_fix_20260728_*` |
| **235** | **EU migration (eur3) ολοκλήρωση + δικτυακή διάγνωση IPv6 + αμυντικά fixes** — project nearme-gr→nearme-eu (nam5→eur3), `REGION=europe-west1` στις 12 CFs, `instanceFor` ×3 client calls · διάγνωση IPv6 blackhole router halohalo (fix στη πηγή, search TOTAL 7931→1149ms) · offline gate στην `_checkRateLimit` · auth timeouts 6s (`_withAuthTimeout`, 5 μέθοδοι) · SEARCH-PERF cleanup (−67 γρ.) · minInstances → Plan B deferred με triggers |

## ΚΕΦΑΛΑΙΟ 6 — CURRENT STATE

| Μέτρο | Τιμή |
|---|---|
| Completion | ~99.9% (Phases 1-3 100%, MultiChat 100%, Media 100%, Chat Redesign 100%, Audio Messages 100%) |
| `.dart` files | ~123 (non-generated, +`vision_moderation_service.dart`) |
| Firestore indexes | 21 composite deployed |
| Cloud Functions | 13 (12 deployed + `moderateImage` scaffolding `europe-west1`, gen1, Node 22) + `fcm-utils.ts` + computeGeoHash + checkSearchRateLimit + expireStaleMessages |
| Build | `flutter analyze` clean ✅, release APK ~20.8MB (R8), signed `gr.nearme.app` (CN=NearMe) |
| Tests | 30/30 passed |
| Schema | Drift v15, 7 tables (+crashReportsEnabled σε AppSettings) |
| Moderation | `contentModerationEnabled=false` (Session 243) — 0 Vision calls/$0, stub + CF kill-switch `config/moderation` |
| Photo Fix | `EqualUnmodifiableListView` → `List.from` `profile_editor_screen.dart:153,161` (Session 244) |
| P0 Fixes | `unawaited` `then<void> onError` + `await close()` + `chatId` null check (Session 245) |
| Feature Flags | ~24 (core 21: typesense, videoCall, groupChat, gifSupport, mediaMessages, audioMessages, videoMessages, messageExpiry, messageReactions, replyToMessage, **replyPrivately**, editMessage, deleteMessage, messageInfo, messageEmail, messageShare, groupEvents, webVersion, aiMatching, verifiedBadge, premiumTier + moderation: contentModerationEnabled, autoModerateProfilePhotos, autoModerateChatMedia, blurExplicitByDefault) |

## ΚΕΦΑΛΑΙΟ 7 — KEY CONVENTIONS
- File size ≤ 500 lines (exceptions: profile_repository_impl ~570, chat_repository_impl ~590 with user permission)
- `DebugConfig.log(flag, msg)` σε κάθε operational action (33 flags, 3 levels)
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): `L10n.isGreek()` + `L10n.localizedMessage()`
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
- GPS-first → session cache (5min) → last known → failure
- Network timeouts: auth 6s (`_withAuthTimeout`) · search CF 4s fail-open · zombie futures consumed με `unawaited(f.then<void>((_) {}, onError))` — ποτέ bare `.catchError` (runtime TypeError σε non-nullable T)
- Offline gate: fresh connectivity check ΠΡΙΝ από κάθε CF κλήση → offline = άμεσο error state, μηδενική κλήση/αναμονή
- Client CF κλήσεις: πάντα `FirebaseFunctions.instanceFor(region: 'europe-west1')`, ποτέ default instance
- Firebase project: **nearme-eu / eur3** (migration 22 Αυγ 2026 από nearme-gr/nam5 — παλιό alias `old-nam5`)

---

## ΚΕΦΑΛΑΙΟ 8 — FEATURE DOCUMENTATIONS (Audio, Video, Bubble Width, SPoT, Offline, Expiry, Session 208-213)

### Audio Messages (Voice Messages) — 100% (Session 204-205)
**Αρχείο πρότασης:** `sound_message.md` (v2.0, 24 Ιουλ 2026)

22 SPoTs υλοποιήθηκαν:
- **Packages:** `record ^7.1.1`, `audioplayers ^6.8.1`
- **Permissions:** `RECORD_AUDIO` (Android), `NSMicrophoneUsageDescription` (iOS)
- **Config:** `audioMessagesEnabled` flag, `chatAudio` debug flag, 4 νέα error codes
- **Repository:** `audioBytes` + `duration` params σε `sendMediaMessage()` (interface/impl/provider)
- **Upload:** Audio `.m4a` → `chat_media/{chatId}/{msgId}.m4a` (Storage)
- **Decode:** `'audio'` σε skip-decrypt list (3 σημεία: `_decodeMessageDoc`, `_syncChatFromFirestore`, `_syncGroupChatToCache`)
- **Duration:** `duration` field σε Firestore msgData + return map
- **AudioRecorderSheet** (νέο): Record UI (60s max, ≥1s min, AAC 44kHz, play/pause, progress bar, temp file via path_provider)
- **AudioMessageBubble** (νέο): Playback bubble (shared AudioPlayer από ChatScreen, progress indicator, E2E lock icon)
- **Edit guard:** 3-layer (`MessageActionBar.showEdit=false`, `BubbleLongPressWrapper.canEdit=false`, `ChatMessagesList._onEdit` type guard)
- **Media Picker:** `MediaAction.record` με `kIsWeb` guard
- **Chat preview:** `'🎵 Φωνητικό μήνυμα / Voice message'`

**Backup:** `backups/sound_message_20260724_130843/`
**`flutter analyze`:** clean ✅ (0 issues)

---

### Video Messages (v2.1) — 100% (Session 200)
**Αρχείο πρότασης:** `video_message.md` (v2.2, 24 Ιουλ 2026)

21 SPoTs υλοποιήθηκαν:
- **Package:** `video_player: ^2.9.0`
- **Config:** `videoMessagesEnabled` flag, `chatVideo` debug flag (bool), 4 error codes
- **Repository:** `videoPath` + `duration` params σε `sendMediaMessage()` (interface/impl/provider)
- **Upload:** Video `.mp4` → `chat_media/{chatId}/{msgId}.mp4` (Storage, **putFile** αντί putData — streaming)
- **Decode:** `'video'` σε skip-decrypt list (3 σημεία)
- **ChatInputBar:** `_pickAndSendVideoGallery/Camera` → `_pickVideo` (30s max, ≥1s min, 15MB→50MB limit)
- **VideoMessageBubble** (νέο): Playback bubble (shared VideoPlayerController από ChatScreen, play/pause/mute, duration badge, E2E lock icon)
- **Storage Rules Fix:** participant check στο **read** (chat_media + group_avatars), 15MB→50MB size limit
- **EXIF stripping:** `flutter_image_compress` + `ImageUtils.stripExif` σε chat photos, avatar, profile photos
- **Aspect Ratio Fix:** `AspectRatio` με `controller.value.aspectRatio` αντί fixed 16:9 — διόρθωση portrait video distortion
- **Repeated switch→helper:** `_mediaPreview()` αντί τριπλής επανάληψης σε `_buildReplyData`/`_buildReplyBanner`/`_buildEditBanner`

**Backup:** — (in-place edits, `git` pending)
**`flutter analyze`:** clean ✅ (0 issues)

### Video Thumbnails (v2.2) — **100%** (ενσωματώθηκε στο Video Messages v2.1)
**Αρχείο πρότασης:** `video_message.md` §35

7 SPoTs, 1 new package (`get_thumbnail_video ^0.7.3`), 0 new files, 12 edge cases, 3-layer equality cache ✅
- Thumbnail generation: `chat_input_bar.dart:307` (VideoThumbnail.thumbnailData)
- Upload: `chat_repository_impl.dart:861-867` (Storage chat_media)
- Display: `video_message_bubble.dart:275-281` (thumbnailUrl preview)

---

## 🐞 Session 201+ — Bubble Width Bug (RESOLVED)

Text bubbles εμφανίζονταν στο `bubbleMaxWidth=264.0` αντί στο content width. Αιτία: `Column(mainAxisSize:min)` μέσα σε `Container(maxWidth:264)` απέτυχε το intrinsic-width pass στο πρώτο layout (νέο μήνυμα: 1ο frame 55.9 → 2ο 264.0 όταν `ts=null→Timestamp`).

**Fix:** `text_message_bubble.dart:236` — `IntrinsicWidth` γύρω από το inner `Column(text+time)` → επιπλέον intrinsic pass → σωστό sizing (verified `w=55.9/83.9/103.4`). Δοκιμάστηκε & απέτυχε το `SizedBox.shrink` (μεταβλητό child count δεν ήταν η αιτία). Όλα τα `BUBBLE_W`/`BUILD` debug logs + statics αφαιρέθηκαν μετά (βλ. και Reply-after-quote unification Session 227 §3.8).

---

## Session 202+ — SPoT Error Messages Fix (100%) — 26 Ιουλ 2026

### Σκοπός
Αντικατάσταση όλων των inline bilingual strings σε `AppMessenger.showSuccess/Error/Info` calls με `ErrorMessages.get(code, isGreek)` — Ενιαίο SPoT για error/status/success messages.

### Τι έγινε
- **Backup:** `backups/spot_fix_20260726_120756/` (error_messages.dart + chat_messages_list.dart)
- **error_messages.dart:** ~85 static codes (52 original + 33 νέα) organized by feature
- **19 αρχεία** edited:
  - `error_messages.dart` — όλα τα codes
  - `chat_messages_list.dart` (6 fixes)
  - `chat_screen.dart` (2 fixes)
  - `group_settings_screen.dart` (7 fixes)
  - `group_info_screen.dart` (5 fixes)
  - `create_group_screen.dart` (3 fixes)
  - `profile_editor_screen.dart` (8 fixes)
  - `privacy_editor_screen.dart` (3 fixes + scope fix)
  - `settings_screen.dart` (6 fixes)
  - `profile_screen.dart` (2 fixes)
  - `add_participant_screen.dart` (2 fixes)
  - `permissions_editor_screen.dart` (8 fixes)
  - `group_invite_screen.dart` (4 fixes)
  - `join_confirmation_screen.dart` (3 fixes)
  - `public_profile_view_screen.dart` (7 fixes)
  - `delete_account_screen.dart` (1 fix)
  - `saved_searches_screen.dart` (1 fix)
  - `search_filters_screen.dart` (1 fix)
  - `blocked_users_screen.dart` (1 fix)
  - `verify_account_screen.dart` (2 fixes)
  - `requests_dashboard_screen.dart` (1 fix)
  - `send_request_screen.dart` (1 fix)
  - `request_card_widgets.dart` (3 fixes)
  - `phone_verify_screen.dart` (1 fix)

**Σύνολο:** ~90 static violations fixed, 63/63 AppMessenger calls → `ErrorMessages.get()`

### Δεν πειράχθηκαν
- **Dynamic messages** (με `$nickname`, `$count`, `$label`, `$_maxParticipants`, `$_accuracyMeters`) — deferred για template `%s` pattern
- **UI labels** σε dialogs (`confirmLabel`/`cancelLabel`), titles, menu items, Text widgets — παραμένουν inline bilingual

> **Σημείωση:** Το **clickable-links feature** αναφερόταν ως deferred στο Session 202, αλλά έχει έκτοτε υλοποιηθεί: `_linkDetector` regex (`text_message_bubble.dart:76`) + `url_launcher` (`chat_messages_list.dart:23`). Αφαιρέθηκε από εκκρεμότητες.

### `flutter analyze`: clean ✅ (0 issues)

---

## Session 203+ — Offline Handling System (100%) — 27 Ιουλ 2026

### Σκοπός
Προσθήκη offline handling: global banner + active connectivity guard σε όλες τις network κλήσεις, χωρίς νέα dependencies (υπάρχον `connectivity_plus`).

### Τι έγινε
- **Backup:** `backups/offline_guard_20260727_224951/` (17 αρχεία)
- **Νέα αρχεία (2):**
  - `lib/providers/connectivity_provider.dart` — StreamProvider<bool> από connectivity_plus
  - `lib/core/utils/connectivity_guard.dart` — `isOnline()` (no context) + `ensure(context)` (showError + return false)
- **Τροποποιημένα (16):**
  - `error_messages.dart` — +case `'network/no-connectivity'`
  - `main_shell.dart` — +`_ConnectivityBanner` ConsumerWidget
  - `auth_provider.dart` — +6 guards (verify, checkVerification, sendPasswordReset, signIn, signUp, browseAnonymously)
  - `phone_verify_provider.dart` — +2 guards (sendOtp, verifyOtp)
  - `chat_provider.dart` — +`_checkOnline()` helper + ~25 guards (όλες οι network methods)
  - `delete_account_provider.dart` — +2 guards (delete, deleteWithPassword)
  - `profile_editor_screen.dart` — +guard σε `_save()`
  - `privacy_editor_screen.dart` — +guard σε `_save()`
  - `profile_screen.dart` — +guard σε `_togglePublish()`
  - `send_request_screen.dart` — +guard σε `_sendRequest()`
  - `create_group_screen.dart` — +2 guards (`_search`, `_createGroup`)
  - `group_info_screen.dart` — +4 guards (`_saveGroupName`, `_changeRole`, `_removeParticipant`, `_deleteGroup`)
  - `group_settings_screen.dart` — +3 guards (`_pickAndUploadAvatar`, `_removeAvatar`, `_saveMaxParticipants`)
  - `permissions_editor_screen.dart` — +4 guards (`_togglePermission`, `_resetOverrides`, `_changeRole`, `_removeMember`)
  - `add_participant_screen.dart` — +2 guards (`_search`, `_addUser`)
- **Δεν πειράχθηκαν:** background services (PresenceService, FcmService, LocationService), report_provider, block_provider (οι κλήσεις γίνονται από screens που ήδη ελέγχθηκαν)

### Μηχανισμός
- **Passive banner:** `_ConnectivityBanner` στην MainShell — `connectivityProvider.asData?.value ?? true`
- **Active guard (screens):** `ConnectivityGuard.ensure(context)` — showError snackbar + return false
- **Active guard (providers):** `ConnectivityGuard.isOnline()` / `_checkOnline()` — set error state + return false
- **Layer:** 2-layer (global passive + active πριν κάθε network call)
- **Background services:** Χωρίς guard (σχεδιασμένο)

### Fixes
- `main_shell.dart` — `valueOrNull` → `asData?.value` (Riverpod API)
- `privacy_editor_screen.dart` — `greek` μεταφορά πριν το await (use_build_context_synchronously)
- `group_info_screen.dart` — `context.mounted` → `mounted` (use_build_context_synchronously)

### `flutter analyze`: clean ✅ (0 issues)

---

## Session P3.2 — Message Expiry Feature (100%) — 28 Ιουλ 2026

### Σκοπός
Αυτόματη διαγραφή μηνυμάτων σε group chats μετά από configurable χρονικό διάστημα (1min, 5min, 30min, 6h, 12h, 24h). Feature flag: `FeatureFlags.messageExpiryEnabled`.

### Τι έγινε
- **Πρόταση/Ανάλυση:** `message_expiry.md` — 17 SPoTs (schema, UI, Cloud Function, permissions, indexes)
- **Νέο config field:** `chats/{chatId}.messageExpiry` (string, default `'off'`)
- **group_chat_mixin.dart:** `updateMessageExpiry(chatId, value)` με creator-only guard + validation
- **Cloud Function:** `expireStaleMessages` — every 5min, `collectionGroup('messages').where('expiresAt', '<', now).get()` → batch delete
- **SystemMessageFormatter:** +`'message_expiry_changed'` case
- **GroupSettingsScreen:** +Message Auto-Delete section (DropdownButtonFormField), creator-only
- **ChatScreen:** `_ExpiryBanner` widget — animated banner "Messages auto-delete after X" (5sec auto-dismiss)
- **indexes:** `fieldOverrides` για `expiresAt` (ASC + DESC, COLLECTION_GROUP) στο `firestore.indexes.json`

### Bugs Found & Fixed

| # | Issue | Fix |
|---|---|---|
| 1 | GroupSettingsScreen: `groupPermissionsProvider` with `autoDispose` — Permissions section invisible on navigation | Remove `autoDispose` from `groupPermissionsProvider` |
| 2 | `updateMessageExpiry` in ChatActionsNotifier returned `Future<void>` (inconsistent with all other methods) | Changed to `Future<bool>`, `return false;` on offline, `return true;` on success |
| 3 | `_ExpiryBanner` placed inside `chat_messages_list.dart` (wrong architectural layer) | Moved to `chat_screen.dart` as independent widget between Expanded list and SafeInputArea |


### `flutter analyze`: clean ✅ (0 issues)

---

## Εκκρεμότητες

| # | Θέμα | Προτεινόμενη Λύση |
|---|---|---|
| 1 | **collectionGroup scraping** — οποιοσδήποτε authenticated χρήστης (ακόμα και anonymous) μπορεί να κάνει bulk collectionGroup queries σε όλα τα ορατά προφίλ, χωρίς server-side rate limit | App Check + server-side rate limit (π.χ. Firestore rules στο `rateLimits/{uid}` ή quota μέσω CF, όχι μόνο client-side) |

---

## Session 208 — EditorScaffold shared widget (100%) — 29 Ιουλίου 2026

### Σκοπός
Εξαγωγή του duplicated unsaved-changes PopScope pattern από ProfileEditorScreen και PrivacyEditorScreen σε shared widget `EditorScaffold`, εξαλείφοντας ~90 γραμμές πανομοιότυπου κώδικα.

### Τι έγινε
- **Νέο αρχείο:** `lib/shared/widgets/editor_scaffold.dart` — StatelessWidget με PopScope + AppBar(close) + unsaved-changes dialog + responsive body wrapper + loading state
- **profile_editor_screen.dart:** -47 γραμμές (αφαίρεση `_onBack()` + PopScope/Scaffold/LayoutBuilder → EditorScaffold)
- **privacy_editor_screen.dart:** -48 γραμμές (αφαίρεση `_onBack()` + PopScope×2 → EditorScaffold με `isLoading` flag)
- **Unused imports:** `responsive_utils.dart` + `app_state_widget.dart` αφαιρέθηκαν

### Key Design Decisions
- **`ValueGetter<bool>`** για `isDirty` και `isSaving` (όχι `bool`) — ώστε να διαβάζονται την ώρα του callback, όχι του build. Κρίσιμο για TextFormField που αλλάζει controller.text χωρίς setState.
- **`onSave` required** — και τα 2 editors έχουν `_save()`
- **`screenName` prop** — για DebugConfig.log με σωστό prefix
- **StatelessWidget** — καμία internal state, const constructor, καμία νέα reactive dependency (χωρίς rebuild storm risk)

### Bug found
| # | Issue | Fix |
|---|---|---|
| 1 | `isDirty`/`isSaving` ως `bool` — σταθερά values από build(), όχι live από State. Όταν ο χρήστης πληκτρολογούσε (controller.text χωρίς setState), το × δεν εμφάνιζε dialog. | `bool` → `ValueGetter<bool>` |


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 210 — 1-to-1 Delete Chat State Machine (100%) — 30 Ιουλ 2026

### Σκοπός
Ολοκλήρωση του 1-to-1 delete chat flow με state machine (pendingDelete + deleteResponseNeeded) — τα action buttons εμφανίζονται/εξαφανίζονται σωστά βάσει role και state.

### Τι έγινε
- **chat_repository_delete.dart** — `_sendDeleteSystemMessage`: γράφει `pendingDelete` (true/delete()) + `deleteResponseNeeded` (true/delete()) βάσει action
- **firestore.rules (line 155)** — `pendingDelete` + `deleteResponseNeeded` στο `hasOnly` list. Deployed.
- **system_message_bubble.dart** — `hasPendingDelete` + `hasDeleteResponseNeeded` props (default true). `showActions` gated: delete_request → `hasPendingDelete && !isRequester`, delete_rejected → `hasDeleteResponseNeeded && !isRequester`
- **message_bubble.dart** — pass-through props
- **chat_messages_list.dart** — `.select()` watch σε `pendingDelete` + `deleteResponseNeeded` από `chatDocProvider`, πέρασμα σε MessageBubble

### Device test (2 devices, real-time)
- State machine verified: `pendingDelete=false/true`, `deleteResponseNeeded` transitions → delete_request/reject/keepChat buttons εμφανίζονται/εξαφανίζονται σωστά ✅
- `chatDocProvider suppressed (pending)` observed during batch writes (rebuild storm prevention works)


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 211 — Reply Privately (100%) — 3 Αυγ 2026

### Σκοπός
Επιλογή **"Απάντηση ιδιωτικά"** σε long-press ομαδικού chat: ανοίγει/δημιουργεί 1-to-1 chat με τον αποστολέα και φορτώνει αυτόματα το quoted μήνυμα ως quote banner στο ChatInputBar.

### Τι έγινε
- **`message_action_bar.dart`** — νέο menu item `reply_private` (bilingual "Απάντηση ιδιωτικά / Reply privately"), gated με `FeatureFlags.replyPrivatelyEnabled`
- **`bubble_long_press_wrapper.dart`** — `showReplyPrivately: isGroupChat && !isMe && !isSenderBlockedByMe`, νέο callback `onReplyPrivately`
- **`message_callbacks.dart` + `message_bubble.dart` + text/video/gif/audio bubbles** — pass-through `onReplyPrivately`
- **`chat_messages_list.dart`** — `_onReplyPrivately(msg)`: `createChat(senderId)` → `pendingPrivateReply.set(chatId, msg)` → `context.push('/chat/$chatId')` + `_isOpeningPrivateChat` double-tap guard
- **`chat_provider.dart`** — `PendingPrivateReply` model + `pendingPrivateReplyProvider` (global Notifier, self-safe `consumeFor` με `targetChatId` match)
- **`chat_input_bar.dart`** — `consumeFor(chatId)` στο `initState` → `setReply(chatId, pending)` → εμφάνιση quote banner
- **`feature_flags.dart`** — `replyPrivatelyEnabled = true`
- **`error_messages.dart`** — `chat/reply-privately-failed`

### Έλεγχος (4 Αυγ 2026)
- **Flow:** σωστό — long-press → menu → createChat → pending set → push → ChatInputBar initState consume → banner ✅
- **Rebuilds:** **0 από το feature** — κανείς δεν κάνει `watch` το `pendingPrivateReplyProvider` (μόνο `ref.read`). `setReply` rebuilds μόνο το ChatInputBar (επιθυμητό). `createChat` → `ref.invalidate(chatsProvider)` (αναμενόμενο)
- **Κανόνες:** feature flag ✅, bilingual ✅, `ErrorMessages.get('chat/reply-privately-failed')` ✅, `AppMessenger` ✅, connectivity guard `_checkOnline()` ✅, repository pattern ✅, `canUserCommunicate` + block check στο repository ✅
- **Παρατηρήσεις (μη-blocking):** duplicate σχόλιο `// Reply to Message` στο `feature_flags.dart:34-35` · file sizes > 500 (chat_messages_list 804, chat_input_bar 650, chat_provider 799 — προϋπήρχαν) · edge case: αν ακυρωθεί η πλοήγηση, το pending μένει στον global provider (self-safe μέσω `targetChatId`)
- **`flutter analyze`:** clean ✅ (0 issues)

---

## Session 212 — Photo Gallery Viewer + Double-tap Zoom (100%) — 4 Αυγ 2026

### Σκοπός
Full-screen gallery viewer με swipe ανάμεσα στις φωτογραφίες ενός chat (type='image') + smooth double-tap zoom. Αντικατέστησε το single-image preview του `_showImageFullScreen`.

### Τι έγινε
- **Μόνο `gif_image_bubble.dart`** άλλαξε (κανένα άλλο αρχείο, κανένα νέο αρχείο)
- **`GifImageBubble`** → `extends ConsumerWidget` — στο tap χρησιμοποιεί **`ref.read(combinedMessagesProvider(chatId))`** (SPoT, όχι watch → zero rebuild cascade)
- **`_PhotoGalleryViewer`** (νέο StatefulWidget):
  - `PageView.builder` με `TransformationController` + counter AppBar «${_current+1} / ${urls.length}»
  - `NeverScrollableScrollPhysics` όταν scale > 1 (zoom/swipe conflict protection)
  - `onPageChanged` → reset zoom
  - **Double-tap zoom:** `GestureDetector(onDoubleTap)` + `AnimationController` (250ms easeOut) μέσω `Matrix4Tween` — 2.5x στο κέντρο ↔ identity. `SingleTickerProviderStateMixin`
  - vector_math deprecations → `translateByDouble`/`scaleByDouble`
  - Debug logs: `image tap idx=... of ...`, `open idx=... of ...`, `page -> N`, `double-tap zoom -> in/out`

### Έλεγχος (device logs, 4 Αυγ 2026)
- Swipe pagination OK (50→100 messages, page 0↔1), zoom in/out OK, dispose clean ✅
- **0 rebuilds κατά τη διάρκεια gallery** — κανένα `MSG_LIST BUILD` μετά το init (4 builds μόνο στο άνοιγμα) ✅
- GIF χωρίς image tap logs (δεν ανοίγει gallery) ✅
- `double-tap zoom -> in/out` με ίδιο timestamp σε γρήγορα back-to-back double-taps = φυσιολογικό (ο animation σε εξέλιξη)


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 212β — Auto-scroll Fix (100%) — 4 Αυγ 2026

### Το πρόβλημα (πραγματική αιτία — 2 σημεία)
Στο `chat_messages_list.dart` `_onMessagesChanged`: όταν ο χρήστης έστελνε δικό του μήνυμα ενώ ήταν scrolled στη μέση/πάνω της λίστας:
1. **Το suppression** `currentScroll > 50.0` κρατούσε τη θέση (δεν κατέβαινε στο νέο του μήνυμα).
2. **ΚΡΙΣΙΜΟ (αρχική διάγνωση λάθος):** ο εντοπισμός "νέου μηνύματος" βασιζόταν στο count (`messages.length > _lastMessageCount`). Με **γεμάτο live window** (`limitToLast(50)`) το snapshot έβγαινε πάλι 50 docs → `50 == 50` → **καμία ενέργεια ΠΟΤΕ** (ούτε για δικά του, ούτε για εισερχόμενα).

### Η λύση — εντοπισμός με ID, όχι count
- **Μόνο `chat_messages_list.dart`** (3 σημεία: state field + `_onMessagesChanged` + κλήση με uid)
- **Νέο state:** `String? _lastMessageId` — το id του νεότερου μηνύματος που είδαμε
- **Νέος εντοπισμός:** `hasNewLast = newLastId != null && newLastId != _lastMessageId` · `isNewMessage = hasNewLast && length >= _lastMessageCount` (guard για delete) · `isOwnNewMessage = isNewMessage && senderId == currentUid`
- **`isOwnNewMessage`** → **πάντα scroll κάτω** · εισερχόμενα → παραμένει η suppression ως είχε
- **`currentUid`** από το build (ήδη υπάρχει, χωρίς νέο watch)
- Debug logs: `ChatMessagesList: own message -> scroll-to-bottom (from Npx)` + υπάρχον `auto-scroll: suppressed`
- **Rebuild storm:** 0 νέο watch, 0 νέο setState, `_lastMessageId` ενημερώνεται πριν το postFrameCallback → κανένα cascade

### Έλεγχος (device logs, 4 Αυγ 2026)
- **Δικό σου send στη μέση:** `own message -> scroll-to-bottom (from 9480px)` και `(from 19499px)` → scroll κάτω ✅
- **Εισερχόμενο ενώ πάνω:** `auto-scroll: suppressed (user 11033px / 6993px)` → δεν κουνιέται ✅
- **Window γεμάτο (50):** `messagesProvider emitted 50` σε κάθε νέο μήνυμα, παρόλα αυτά ο εντοπισμός με ID δουλεύει (το παλιό count-based θα έκανε no-op) ✅
- **Rebuilds:** 1 μόνο `MSG_LIST BUILD` ανά νέο μήνυμα, κανένα cascade · Pagination (50→100→181) δεν σκανδάλει scroll ✅
- `ChatMessagesList dispose` clean ✅


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 213 — Reply Thumbnails για Media (100%) — 4 Αυγ 2026

### Σκοπός
Μικρογραφία (thumbnail) στις απαντήσεις (replies) σε media μηνύματα — τόσο στο quote banner του ChatInputBar όσο και στο quote preview μέσα στο chat.

### Το πρόβλημα (πραγματική αιτία)
Το `_onReply(msg)` (`chat_messages_list.dart:413`) κρατάει **ολόκληρο** το μήνυμα στο `replyToMessageProvider`, αλλά το `_buildReplyData` στο `chat_input_bar.dart` κρατούσε μόνο κείμενο (`msg`, `type=text`) → στο Firestore το `replyTo` έχανε το media URL → ο παραλήπτης έβλεπε quote χωρίς thumbnail.

### Τι έγινε
- **Μόνο 2 αρχεία** (κανένα νέο):
- **`reply_preview.dart`** — νέο shared widget **`ReplyMediaThumbnail`** (44×44, `CachedNetworkImage`, ClipRRect, placeholder/errorWidget) με SPoT helper `ReplyMediaThumbnail.urlFor(replyTo)` (image/gif → `content`, video → `thumbnailUrl`, μόνο για media types με non-empty URL). `ReplyPreview` δείχνει Row(thumbnail + κείμενο) όταν `isMedia`· αλλιώς κείμενο (graceful για παλιά μηνύματα).
- **`chat_input_bar.dart`** — `_buildReplyData` προσθέτει `'type'` + `'content'` (image/gif) ή `'thumbnailUrl'` (video) στο replyTo map· `_buildReplyBanner` εμφανίζει `ReplyMediaThumbnail` (reuse)· import `message_bubble/reply_preview.dart` προστέθηκε.

### Έλεγχος (device logs, 4 Αυγ 2026)
- **GIF:** `reply data type=gif hasMediaUrl=true` + `ReplyPreview: thumbnail=yes` ✅
- **Φωτογραφία:** `reply data type=image hasMediaUrl=true` + `ReplyPreview: thumbnail=yes` ✅
- **Βίντεο:** `reply data type=video hasMediaUrl=true` + `ReplyPreview: thumbnail=yes` ✅
- **Group chat (My Team):** GIF → `thumbnail=yes` ✅
- Banner στο input: `reply banner for @Yahooman: 🎞️ GIF / 📷 Photo / 🎬 Video (thumb)` ✅
- **Rebuild storm:** 1-3 `MSG_LIST BUILD` ανά send (καθαρό) — τα `(×N)` στα logs είναι το DebugConfig 1-sec buffer (όχι rebuilds) ✅
- **Graceful:** παλιά replies → `thumbnail=no` (ως είχε) ✅
- **Παρατήρηση (unrelated):** 1ο GIF send απέτυχε με `blocked by scIChf...` — ο Yahooman έχει κάνει block στο 1-to-1 (δεν αφορά το fix)· 2ο send πέρασε ✅


### `flutter analyze`: clean ✅ (0 issues)

---

## ΚΕΦΑΛΑΙΟ 9 — RECENT SESSIONS (214-226)

## Session 214 — GeoHash Adaptive Precision Fix + Radius 500km (100%) — 5 Αυγ 2026

### Το πρόβλημα (silent data loss)
Στο `searchPrecision()` του `geohash_utils.dart`: ο βρόχος εύρεσης precision είχε κάτω όριο `p >= 3` → για radius > ~120-150km (Ελλάδα) κανένα κελί δεν ήταν αρκετά μεγάλο → **fallback=3** (κελί ~123km) ΑΝΕΞΑΡΤΗΤΑ από την πραγματική ακτίνα. Το 9-cell (3×3) grid ~470km δεν κάλυπτε κύκλο radius 500km → profiles στα άκρα ποτέ δεν έμπαιναν στο query. Όχι σφάλμα — σιωπηλή απώλεια.

### Η λύση (μόνο `geohash_utils.dart` `searchPrecision` + `discovery_screen.dart`)
- **Loop bound**: `p >= 3` → `p >= 1` (το `_cellDimensions` δίνει p=2 → min 626km, p=1 → min 5009km)
- **Fallback**: `return 3` → `return 1` + `DebugConfig.error` (ΑΚΡΑΙΟ σενάριο, ορατό) αντί σιωπηλό
- **`discovery_screen.dart`**: radius selector `[1..100]` → `[1..500]` +250, +500km · clamp 100→500 (2 γραμμές)
- **Χωρίς επιπλέον Firestore reads**: ίδιο 9-cell pattern, ίδιος αριθμός queries

### Επαλήθευση (πριν την εφαρμογή)
- `_cellDimensions`: p=3 min 156km/123km (lat0/38°) · p=2 min 626km (lat-independent h, w=1252×cos) · p=1 min 5009/3947 (lat0/38°)
- radius=500km → p=2 ✅ · radius=1000km → p=1 ✅ · radius=6000km → error fallback p=1 ✅
- **Side effects**: callers μόνο `_geoSearch:69` + `searchNearby:255` (περνάνε sp στο `encode()` clamp 1-12, γραμμή 19) ✅ · `basePrecision > 3` block δεν τρέχει για p=1-2 (1-char/2-char cell καλύπτει ήδη τα city 3-char) ✅ · `getNeighbours` length 1-2 OK ✅ · haversine post-filter αμετάβλητο ✅ · κανένα test ✅
- **SPoT/γλώσσα/resize**: static pure function, μηδέν rebuilds · το μόνο string είναι `DebugConfig.error` (developer-facing, όχι L10n) · δεν αφορά media/resize

### Έλεγχος εφαρμογής
- `searchPrecision` loop `p >= 1` + fallback `return 1` + `DebugConfig.error` ✅
- discovery_screen values +250/500 + clamp 500 ✅
- search_filters_screen slider **ήδη** max 500 (δεν χρειαζόταν αλλαγή) ✅
- **`flutter analyze`: clean ✅ (0 issues)**


---

## Session 215 — ProfileCard Redesign (Horizontal/Μinimal) (100%) — 5 Αυγ 2026

### Σκοπός
Minimal οριζόντια κάρτα στη Discovery: κυκλικό avatar αριστερά (64px, ClipOval) + πληροφορίες δεξιά, με SPoT στα strings και πλήρη συμμόρφωση στους κανόνες (resize, debug flags, όχι rebuild storm).

### Τι έγινε (3 αρχεία, backup: `backups/profile_card_redesign_20260805_105116/`)
- **`l10n.dart`** — 3 νέες SPoT μέθοδοι:
  - `L10n.ageLabel(int age, {required bool isGreek})` — «{age} ετών» / «{age} years»
  - `L10n.unknownName({required bool isGreek})` — «Άγνωστο» / «Unknown»
  - `L10n.distanceLabel(double km, String? geoHash, {required bool isGreek})` — «Συνοικία»/«Neighborhood» όταν `geoHash.length >= 5`, αλλιώς «{km} χλμ»/«{km} km»
  - Εξάλειψε το duplicated `_distanceLabel` από profile_card.dart + public_profile_header.dart και τα inline `'${age} years'`/`'Unknown'`
- **`profile_card.dart`** — διάταξη `Padding(10) > Row > [avatar 64px ClipOval + SizedBox(12) + Expanded(Column)]`:
  - nickname + online dot, city/country (ellipsis), `Wrap` για distance·age (με `·` separator), chip lookingFor
  - guards, debug logs (`presence` + `uiRebuild` `layout=horizontal`) και placeholder avatar διατηρήθηκαν
  - `_distanceLabel` local αφαιρέθηκε → `L10n.distanceLabel` (SPoT)
- **`public_profile_header.dart`** — `_distanceLabel` αντικαταστάθηκε με `L10n.distanceLabel(...)`, duplication εξαλείφθηκε, διάταξη αμετάβλητη

### Rebuild analysis (device logs, 5 Αυγ 2026)
- `ProfileCard build ... layout=horizontal width=Infinity` — νέο layout ενεργό (mobile → `double.infinity`, σωστό)
- **`(×2)` ανά κάρτα = σχεδιασμένο #155**: build #1 `stream=null` (fallback `profile.isOnline`) + build #2 όταν φτάνει status stream. Όχι bug — ο μηχανισμός του online-status flicker fix
- **ΔΕΝ εφαρμόστηκε `select()` στο grid**: θα εισήγαγε risk στο loadMore spinner (`_isLoadingMore || state.hasMore`) και δεν θα έλυνε το `(×2)` (προέρχεται από `userStatusProvider`, όχι από grid) — αναλύθηκε και απορρίφθηκε
- `SearchResultsGrid built` 1× ανά search · `userStatusProvider` created/disposed σωστά (autoDispose, clean lifecycle) · placeholder avatar για `avatarUrl=null` ✅ · κανένα overflow error


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 216 — chatsProvider redundant emits elimination (100%) — 5 Αυγ 2026

### Σκοπός
Εξάλειψη των redundant `chatsProvider` emits στο startup: N sync writes → N Drift `.watch()` `controller.add` → N UI rebuilds + N native `setBadge` calls. Στόχος: 1 emit που αντανακλά πραγματική αλλαγή.

### Root cause
Στο startup ο Firestore listener φέρνει όλα τα chat docs ως `added` → `_syncChatFromFirestore`/`_syncGroupChatToCache` γράφουν πάντα (χωρίς σύγκριση) → `streamChats` `.watch()` κάνει `controller.add` σε κάθε write → redundancy (π.χ. `prev=5 next=5 ×5`).

### Η λύση (μόνο `chat_repository_impl.dart`, 3 σημεία)
- **New fields** `_lastChatsListCache` + `_lastChatsStreamUid` (δίπλα στα υπάρχοντα caches).
- **Reset cache** στο `streamChats` start όταν αλλάζει `uid` (αποτρέπει stale equality ανάμεσα σε accounts).
- **Equality-check** στο `.watch()` listen: αν `previous != null && DeepCollectionEquality.equals(previous, rows)` → `streamChats: suppressed (content unchanged)` (χωρίς emit)· αλλιώς cache + `controller.add(rows)`.

Ίδιο pattern με `messagesStream`/`chatDocProvider`. Το `ChatCacheTableData` έχει ήδη generated `operator ==` (18 πεδία, `database.g.dart`), `package:collection` ήδη imported. **Απορρίφθηκαν:** A (skip-write — invasive, 4 σημεία, false-negative risk σε timestamps) και C (debounce — add latency στο live chat).

### Επαλήθευση (device logs, 5 Αυγ, release)
- Πριν: `chatsProvider emitted prev=5 next=5 (×5)` + `Badge set to 79 (×5)` + `unreadBadgeProvider (×5)`
- Μετά: `chatsProvider emitted prev=null next=7` (ΜΟΝΟ το αρχικό) + `streamChats: suppressed (content unchanged) rows=7 (×7)` → ΚΑΝΕΝΑ redundant emit, ΚΑΝΕΝΑ redundant Badge set
- Server-sync (Firestore→Drift) **δεν επηρεάστηκε**: το equality convergence το επιτρέπει όταν το content αλλάζει πραγματικά
- **Bonus:** `(×7)` suppressed = τα 7 writes του sync μπλοκαρίστηκαν από το equality — απόδειξη ότι το cache ήταν ήδη σωστό


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 217 — AppMessenger Snackbar Keyboard Fix (100%) — 5 Αυγ 2026

### Σκοπός
Τα error/success snackbars εμφανίζονταν κρυμμένα πίσω από το πληκτρολόγιο στα screens που κρατάνε `resizeToAvoidBottomInset: false` (main_shell:32, chat_screen:278, chat_list_screen:32, discovery_screen:269) — το Scaffold δεν υπολογίζει viewInsets → το floating snackbar έμενε κάτω από το keyboard.

### Διάγνωση
- Όλα τα snackbars περνούν **SPoT** από `AppMessenger` (grep: κανένα raw `SnackBar` στο project).
- Σε screens με `resize:false` τα viewInsets διατίθενται μόνο μέσα από το body → εφαρμόζονται ως dynamic margin.

### Η λύση (μόνο `lib/core/utils/app_messenger.dart`)
- Snackbar `margin`: `EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16)` → όταν το keyboard είναι ανοιχτό το snackbar ανεβαίνει πάνω του· όταν κλειστό margin=16 (όπως πριν, zero UI change).
- `import 'core/theme/responsive_utils.dart'` + `DebugConfig.log(DebugConfig.uiInteraction, 'AppMessenger: showing ... margin-bottom=${...}')`.
- **SPoT**: helper `ResponsiveUtils.isKeyboardVisible(context)` (responsive_utils:100-102) ήδη υπήρχε — δεν προστέθηκε νέο duplicated logic.

### Επαλήθευση
- `flutter analyze`: clean ✅ (0 issues)
- `test/widget_test.dart:17-49` (AppMessenger tests) unaffected — viewInsets=0 σε test environment.
- Όχι rebuild storm: event-driven, non-interceptive.
- Backup: `backups/app_messenger_20260805_143321.dart`


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 218 — Router `/groups` placeholders → real ChatScreen (100%) — 5 Αυγ 2026

### Σκοπός
Αντικατάσταση των placeholder routes `/groups` (→ `/chats` redirect) και `/groups/:chatId` (→ πραγματικό ChatScreen με `ChatNavExtra(isGroupChat: true)`) στο `app_router.dart`.

### Διάγνωση
- Όλα τα pushes του app περνούν `ChatNavExtra(isGroupChat, groupName)` (chat_list_screen:261-263, group_search_screen:279-283, create_group_screen:150-151) — κρίσιμο γιατί το `ChatScreen.initState` (γρ. 81-97) χρειάζεται το `isGroupChat` ΠΡΙΝ φορτώσει ο `chatDocProvider`.
- Το πειραματικό `/groups/:chatId` με κενό Drift cache χωρίς `navExtra` → `isGroup=false` σε group → λάθος `markAsRead`/initial-state.

### Η λύση (μόνο `lib/core/router/app_router.dart`, 2 routes)
- `/groups` → `redirect: (_, _) => '/chats'` (lint: `(_, _)` not `(_, __)`).
- `/groups/:chatId` → `_slideUp(ChatScreen(chatId, navExtra: ChatNavExtra(isGroupChat: true)))` (groupName έρχεται μόνο από το chatDocProvider) + `DebugConfig.log(DebugConfig.navigationRoute, ...)`.
- Backup: `backups/app_router_20260805_184037.dart`

### Επαλήθευση (device logs, 5 Αυγ 2026)
- 1-1 chat `Sfh...KuY`: `isGroup=false`, `markAsRead isGroup=false`, BUILD #1+#2 ✅
- Group "My Team" `Yz...J3`: `isGroup=true`, `markAsRead isGroupChat=true src=drift`, `canInvite` false→true load, BUILD #1-#3 ✅ (καθόλα φυσιολογικά, μακριά από cascade)
- `chatsProvider emitted prev=null next=7` μία φορά → fix Session 216 ενεργό ✅ · `prev=7 next=7` once = νόμιμο (πραγματική content αλλαγή, πέρασε equality-check) ✅
- `Redirect: location=/chat/...` σε όλα τα opens — το UI πάει πάντα `/chat/`, άρα το `/groups` route δεν δοκιμάστηκε άμεσα σήμερα (out-of-scope, προτείνεται widget test)

### Γνωστά out-of-scope gaps (προτείνονται ως ξεχωριστό βήμα)
- `join_confirmation_screen.dart:72` → `context.go('/chat/$chatId')` χωρίς `extra` (group-capable)
- `fcm_service.dart:89,166` → deep links χωρίς `extra` (group-capable)


### `flutter analyze`: clean ✅ (0 issues)

## Session 220 — Crash L10n fix + Incoming Share v1 + Media Forward fix (100%) — 6 Αυγ 2026

### Σκοπός (3 ανεξάρτητα, σε ροή)
1. **Fix crash** — `L10n.appName(context)`/`L10n.isGreek(context)` πάνω από το MaterialApp (χωρίς Localizations): title στο `main.dart:471` + biometric unlock reasons (`:237,:295`).
2. **Incoming Share v1** — "Κοινόχρηστο σε NearMe" από άλλες εφαρμογές (text/url/image/video/audio).
3. **Media Forward fix** — η προώθηση media σε chat έστελνε το URL ως text· τώρα `sendMediaMessage` (image/audio/video/gif) χωρίς re-upload.

### 1) Crash fix (`l10n.dart` + `main.dart`)
- **SPoT**: νέα context-free helpers `L10n.appNameFromLocale(Locale)` / `L10n.isGreekLocale(Locale)` + `_deviceLocale` στο main (χωρίς MediaQuery) — τα 3 σημεία χρησιμοποιούν locale, όχι context.
- Backups: `backups/*_20260806_112344.bak` (l10n/main/chat_messages_list/AndroidManifest/debug_config/feature_flags/MainActivity).

### 2) Incoming Share v1 (νέα λειτουργία)
- **`lib/core/services/incoming_share_service.dart`** (νέο) — consume-once, event-driven, static: `init()`/`pollPending()`/`tryExecutePending()`/`onPending`, truncation 4000 chars, guards `_isShowingSheet`, Android-safe (`MissingPluginException` graceful), getPendingShare single poll + type validation.
- **`lib/shared/widgets/incoming_share_sheet.dart`** (νέο) — leaf preview sheet (text/url μόνο· images/video/audio → info "δεν υποστηρίζεται"), χρησιμοποιεί shared `showChatRecipientPicker`.
- **`feature_flags.dart`** `incomingShareEnabled=true` · **`debug_config.dart`** `chatShare=true` · error keys `share/needs-verification`, `share/media-not-supported`.
- **`main.dart`** — `IncomingShareService.init()` (firebase-ok block), `onPending` σαν FcmService listener, `_executeIncomingShareSafely()` (app context + post-frame fallback), κλήσεις μετά startup-lock/biometric-unlock/resume + `pollPending` σε resumed.
- **`MainActivity.kt`** — 2ο MethodChannel `near_me/incoming_share` + `ACTION_SEND` (text/image/video/audio) + `onCreate`/`onNewIntent` handling.
- **`AndroidManifest.xml`** — 4 intent-filters (text, image, video, audio).
- Τεστ: τελευταίο v1 build → share δεν δοκιμάστηκε σε device εκείνη τη στιγμή.

### 3) Media Forward fix (5 αρχεία, backup `backups/*_20260806_121640.bak`)
**Root cause (verified με git):** ο `_forwardToChat` (`chat_messages_list.dart:334`) έκανε **πάντα** `sendMessage(content)` — το `content` για media είναι Storage/GIPHY URL → αποθηκευόταν ως text → εμφανιζόταν σύνδεσμος. `git log -S "sendMedia" -- chat_messages_list.dart` → **κανένα commit** → ΔΕΝ είναι regression, feature-gap που υπήρχε πάντα. Email (`_onEmail`: κατεβάζει+επισυνάπτει) και εξωτερικό share (`_onShare`: κατεβάζει+SharePlus file) δούλευαν — γι' αυτό "το email δουλεύει σωστά".
- **`giphy_service.dart`** — νέο `GiphyService.downloadBytes(String url)`: HTTP GET (HttpClient, 15s timeout), `storageDownload` logs, null σε αποτυχία/άκυρο URL. SPoT HTTP GET (ίδιο pattern με search/trending). `import 'dart:typed_data'`.
- **`chat_repository.dart`** (interface) — νέα παράμετρος `String? forwardThumbnailUrl` στο `sendMediaMessage`.
- **`chat_repository_impl.dart`** — video: `'thumbnailUrl': thumbnailUrl ?? forwardThumbnailUrl` (backward-compatible) + `DebugConfig.log(chatVideo, 'forward thumbnail passthrough')`.
- **`chat_provider.dart`** — passthrough `forwardThumbnailUrl`.
- **`chat_messages_list.dart`** — `_forwardToChat`: media (`image/audio/video/gif`) → `sendMediaMessage(content, type, duration?, forwardThumbnailUrl?)`· text → `sendMessage` (parity). `_downloadMediaAsFile` dispatcher: `gif` → `GiphyService.downloadBytes` (ext `gif→'gif'`), αλλιώς `refFromURL` (50MB). `_onEmail`/`_onShare` `isMedia` συμπεριλαμβάνει `gif`.
- **Ζero rebuild storm:** 0 νέο `watch`/MediaQuery/`setState`· `ref.read(chatActionsProvider.notifier)` (pattern υπάρχον text forward)· HTTP download χωρίς UI state. Checks verify/block τα ίδια σε send/sendMedia (:204,:244 vs :806,:836) → μηδέν regression.

### Παρατήρηση UX (δεν είναι bug)
Email με attachment: το Android email app (π.χ. Gmail, `launchMode=singleTask`) ανοίγει στο δικό του task — με "back" γυρίζει στο inbox του, όχι στην εφαρμογή. Ο plugin κάνει σωστά `startActivityForResult` (`flutter_email_sender_method_channel-1.0.1:...Plugin.kt`). Αναμενόμενη Android συμπεριφορά, όχι fixable από Flutter χωρίς vendor/hack. Επιστροφή με "Μετάβαση εφαρμογών". Προαιρετική βελτίωση: info snackbar οδηγίας (δεν εφαρμόστηκε).

### Έλεγχος
- Forward text σε ομαδική: `sendMessage chat=...` + `Προωθήθηκε` ✅
- **`flutter analyze`: clean ✅ (0 issues)** (μετά τα 3 fixes)
- `flutter test`: δεν τρέχτηκε σε αυτό το session


---

## Session 221 — ChatMessagesList rebuild storm (MediaQuery) + ReplyPreview media label (100%) — 6 Αυγ 2026

### Σκοπός
1. **ReplyPreview fix** — περιττό label («🎬 Βίντεο»/«📷 Φωτογραφία»/«🎞️ GIF») δίπλα στο thumbnail των media replies.
2. **ChatMessagesList rebuild storm** — 22-26 builds/sec στο πληκτρολόγιο (regression από Session 212 όπου το gallery είχε 0 rebuilds). **Root cause βρέθηκε & fixed.**

### 1) ReplyPreview fix (`reply_preview.dart`, backup `backups/reply_preview_20260806_1600.bak`)
- Για media reply, το `contentPreview` παίρνει label από το `_mediaPreview` (chat_input_bar.dart:169-176, π.χ. image→"📷 Photo"). Το `ReplyPreview` το έδειχνε **δίπλα** στο thumbnail → πλεονασμός.
- **Fix:** όταν υπάρχει thumbnail (`isMedia`), το κείμενο δίπλα δείχνει **μόνο** `@senderNickname` (σε group) ή τίποτα. Στο **audio** (χωρίς thumbnail, `urlFor`→null) και στα **text** το κείμενο μένει κανονικά.
- `flutter analyze` clean ✅

### 2) Rebuild storm — Διάγνωση (revert-ready diagnostics, όλα αποκλείστηκαν ένα-ένα)
Με `MSG_LIST SIG` diagnostic στο `build()` (ποιο `ref.watch` αλλάζει / identity-check στο AsyncValue):
- **nicknames/avatars fix (προηγούμενο, κρατείται):** οι selectors `participantNicknames`/`participantAvatarUrls` έφτιαχναν νέο Map σε κάθε build → Riverpod identity-compare = πάντα "άλλαξε" → rebuild. Fix: cached-instance (όπως το υπάρχον `lastReadTimestamps`), κρατείται στο `chat_messages_list.dart` ~581-616.
- **Αποκλείστηκαν:** parent rebuild (καμία γραμμή `ChatScreen BUILD`, flag `uiRebuild=true`), provider emits (κανένα `chatDocProvider`/`messagesProvider` log στα bursts), `setState` (κανένα στο widget), ReplyPreview (StatelessWidget), screenH (853.3 σταθερό).
- **`SIG -> EXTERNAL(no-watch-changed)`** σε όλα τα bursts → τίποτα από τα watches δεν άλλαξε, το build τρέχει 22-26× **στο ίδιο ms**.

### ROOT CAUSE (επιβεβαιώθηκε με `SIG -> viewInsets` σε κάθε burst)
- Το `ChatMessagesList.build()` έκανε `MediaQuery.sizeOf(context)` (για diagnostic screenH) + `MediaQuery.sizeOf(context).width` (γραμμή 750, responsive padding).
- Όταν ανοίγει/κλείνει το πληκτρολόγιο, το **`viewInsets` αλλάζει σε κάθε frame του animation** → όποιος κάνει `MediaQuery.of`/`sizeOf` στη build του γίνεται dirty → **ολόκληρο το list ξαναχτίζεται 22-26 φορές** (όσα τα frames του keyboard animation). Το `screenH` δεν αλλάζει — το `viewInsets` είναι άλλο field του MediaQueryData.

### Η λύση (μόνο `chat_messages_list.dart` — 2 προσπάθειες)

**fix2 (απέτυχε — βλ. REJECTED πίνακα Κεφ.10):** cached width μέσω `didChangeDependencies` δήλωνε MediaQuery dependency → keyboard εξακολουθούσε να ξαναχτίζει.

**fix3 (ΤΕΛΙΚΟ, backup `backups/chat_messages_list_20260806_1715.fix3.bak`):**
- **LayoutBuilder** αντί MediaQuery: wrapped το ListView σε `LayoutBuilder` και πλάτος μέσω `ResponsiveUtils.resolveWidth(context, constraints)` (chat_messages_list.dart:923-925) — **μηδέν MediaQuery σε ολόκληρο το αρχείο** (grep-verified).
- **Revert όλων των test codes:** αφαιρέθηκαν `REVERT-DIAG-H`, `REVERT-DIAG-T`, fields `_diagSig`/`_diagPrevAsync`, `_screenWidth`/`didChangeDependencies`, `viewInsets`/`viewPadding` diagnostics. Κρατείται μόνο το απλό `MSG_LIST BUILD #N` log (flag `chatBubbleDesign`).
- Κρατήθηκαν: fix nicknames/avatars (cached-instance) + λειτουργικό `MSG_LIST: N items...` log.

### Επαλήθευση (device logs, 6 Αυγ)
- **Πριν:** κάθε άνοιγμα/κλείσιμο πληκτρολογίου → `MSG_LIST BUILD #4..#29` (22-26×, όλα `SIG -> viewInsets`).
- **Μετά fix3:** σε πλήρες run (άνοιγμα chats, send/reply/forward με πληκτρολόγιο) → **καμία** γραμμή `MSG_LIST BUILD` από keyboard/scroll. Μόνο: BUILD #1-#4 στο άνοιγμα chat (initial → chatDoc emit → messagesProvider emit) και +1-#2 σε κάθε πραγματικό send. ✅
- **Υπόλοιπο:** τα `ReplyPreview ×N` (26-47) είναι rebuilds **μεμονωμένων ListView items** (bubbles), ΟΧΙ ολόκληρου του list (δεν υπάρχει ταυτόχρονο `MSG_LIST BUILD`) — πιθανόν από scroll/keyboard frames. Ξεχωριστό, πιο ελαφρύ ζήτημα, ακόμα προς διερεύνηση.

### Μάθημα για μελλοντική χρήση (σημαντικό)
- **ΠΟΤΕ** `MediaQuery.sizeOf/viewInsetsOf/viewPaddingOf` μέσα σε `build()` αν το widget πρέπει να είναι σταθερό: η εξάρτηση είναι σε **ολόκληρο το MediaQueryData** — το keyboard (viewInsets) ξαναχτίζει όλους τους dependents, ακόμα κι αν το μέγεθος δεν αλλάζει.
- Το codebase έχει ήδη το σωστό pattern: `ResponsiveUtils` "PURE WIDTH-BASED (no MediaQuery dependency)" + `ResponsiveBuilder`/`ResponsivePadding` με `LayoutBuilder` (constraints) — «no MediaQuery rebuild cascade».
- Διάγνωση rebuild storms: SIG-diagnostic (hash/identity των watches ανά build) πριν οτιδήποτε speculative. Αποκλεισμοί: parent build log, provider emits, setState, MediaQuery.

> **Σημείωση:** fix4 (memoization ListView) + `didChangeDependencies` width απορρίφθηκαν/REVERTED — μάθημα στον πίνακα REJECTED Κεφ.10 (διάγνωση με διακριτικά logs, ποτέ speculative). Η διερεύνηση `ReplyPreview ×N` έκλεισε στο Session 231.

### `flutter analyze`: clean ✅ (0 issues)

---

## Session 222 — SPoT bubbleMaxWidth + ReplyPreview cap + rebuild diagnosis (100%) — 10 Αυγ 2026

### Σκοπός (3 μέρη, σε ροή)
1. **SPoT bubbleMaxWidth** — το `bubbleMaxWidth = πλάτος × 0.75` υπολογιζόταν σε **4 διαφορετικά** bubble αρχεία (text/gif/audio/video, καθένα με δικό του `LayoutBuilder`· το `emoji_only_bubble` δεν είχε καθόλου). Σήμερα έγινε **Single Point of Truth** (Option A εγκρίθηκε).
2. **ReplyPreview (quotes) καπέλωμα** — τα quotes (ReplyPreview) άφηναν το πλάτος τους ελεύθερο· τώρα καπελώνονται στο `bubbleMaxWidth` με `ConstrainedBox`.
3. **Rebuild diagnosis** — κλείσιμο του ανοικτού θέματος του Session 221 (τα `ReplyPreview ×N` στα bursts): γιατί ξαναχτίζονται, ποια items, είναι φυσιολογικό;

### 1) SPoT (8 αρχεία, backup `backups/*_20260810_pre_bubbleMaxWidth_spot.bak.dart`)
- **`chat_messages_list.dart:943-944`** — SPoT: `w = ResponsiveUtils.resolveWidth(...)`, `bubbleMaxWidth = w * 0.75`. Υπολογισμός ΕΝΑΣ φορά ανά (re)BUILD, περνάει ως παράμετρος στο `MessageBubble`.
- **`message_bubble.dart`** — νέα **required** παράμετρος `bubbleMaxWidth`, περνιέται και στα 5 bubble types.
- **`text_message_bubble.dart`** — αφαιρέθηκε το LayoutBuilder (κρατήθηκε το `IntrinsicWidth` από Session 203).
- **`gif_image_bubble.dart`** — αφαιρέθηκε το LayoutBuilder (κρατήθηκε το `maxHeight: 200`). Ο full-screen viewer (:383) **έμεινε άθικτος**.
- **`audio_message_bubble.dart`** — αφαιρέθηκε το LayoutBuilder.
- **`video_message_bubble.dart`** — αφαιρέθηκαν **και οι 2** χρήσεις (maxWidth + SizedBox width).
- **`emoji_only_bubble.dart`** — νέα required παράμετρος + build-log με το value.
- **`reply_preview.dart`** — νέα optional `maxWidth` + `ConstrainedBox`· τα 5 bubble αρχεία περνούν `maxWidth: bubbleMaxWidth`.

### 2) Επαλήθευση SPoT (device: Xiaomi 24094RAD4G / NFT8KF4LD6XWOF7D)
- `MSG_LIST: ListView (re)BUILT (w=384.0, bubbleMaxWidth=288.0, ...)` → **μία** φορά ανά πραγματικό build ✅
- `MSG_LIST: ListView REUSED (w=384.0 ...) — height-only relayout, itemBuilder NOT re-invoked (×25)` → **fix5 (SPoT width-cache) δουλεύει**: σε αλλαγή μόνο ύψους το ListView instance επιστρέφεται identical → το Flutter κάνει shortcut → **δεν** ξανακαλεί itemBuilder για κανένα index ✅ (backups/λογική: 926-937, τοπικές μεταβλητές, όχι State field).
- Idle: **4+ λεπτά καθαρά** (0 bursts) ✅
- Ξεχωριστή παρατήρηση (δεν απενεργοποιήθηκε): το `ChatScreen` ξαναφτιάχνει `_messagesList` σε video play/fail (chat_screen.dart:134,150,161) — σκοτώνει το fix5 cache, μελλοντική δουλειά.

### 3) Rebuild diagnosis — ΑΠΑΝΤΗΣΗ (probe `MB:` στο `MessageBubble.build`, flag `chatBubbleDesign`)
- **Probe:** `MB: msgId=... type=... REPLY=... isMe=...` στο build του MessageBubble (προσωρινό) έδειξε ξεκάθαρα ότι στα bursts ξαναχτίζονται **ΟΛΑ τα visible bubbles** (image×26, gif×26, video×26, text×9, emoji×5 σε ~25 frames), ΟΧΙ μόνο τα quotes.
- **Γιατί «τα`ReplyPreview` ήταν τόσα»:** το `ReplyPreview` ήταν το **μόνο** αρχείο με build-log. Καμία γραμμή `MSG_LIST: ListView REUSED` δεν συνέπεσε με itemBuilder — τα `MB ×N` είναι rebuilds των **ίδιων Elements** (Sliver-layer relayout), όχι νέα ListView/items.
- **Συμπέρασμα: ΦΥΣΙΟΛΟΓΙΚΟ.** Τυπική συμπεριφορά `ListView` όταν αλλάζει η διάσταση viewport (πληκτρολόγιο/insets): τα **ορατά** παιδιά ξανα-γίνονται build κάθε frame του animation. Bounded (ανάλογο των ~5 ορατών, όχι των 50), μόνο κατά αλληλεπίδραση, ιδle=0. Όχι leak, όχι loop. Δεν χρειάζεται επεμβατική βελτιστοποίηση (ρίσκο > όφελος).

### `flutter analyze`: clean ✅ (0 issues)


---

## Session 223 — SIG-PROBE: το storm αναπαράγεται και διαγιγνώσκεται 100% — 10 Αυγ 2026

### Σκοπός
Το Session 222 έκλεισε το «φυσιολογικό» κομμάτι (sliver relayout), αλλά παρέμενε ανοιχτό το storm του Session 221: 24-26 πλήρη `MSG_LIST BUILD` ανά δευτερόλεπτο με πανομοιότυπα δεδομένα. Βάλαμε instrumentation για οριστική διάγνωση.

### Instrumentation (TEMP, αναστρέψιμο, backup `chat_messages_list_20260810_sigprobe.bak` / `..._sigprobe2.bak`)
- Fields: `_sigLastWidget` (parent-change ανίχνευση), `selectCalls` counter στον lastReadTimestamps selector, `_sigLastMsgsHash`/`_sigLastCombinedHash` (content-change ανίχνευση).
- Probe-log ανά build με `WidgetsBinding.instance.platformDispatcher.views.first.viewInsets` — **platformDispatcher, ΟΧΙ MediaQuery.of** → η ίδια η μέτρηση δεν αλλάζει τα rebuilds.
- `SIG-PROBE-2`: hashes όλων των υπόλοιπων ref.watch (lastRead/nicknames/avatars/blocked/participantUids).

### Ευρήματα (από run 20:45-46: media/GIF/emoji/photo pickers + keyboard)
- **Κάθε animation πληκτρολογίου = 1 build ανά καρέ** (viewInsets σε τέλεια animation curve: κλείσιμο `804→699→580→…→0`, άνοιγμα `40→135→246→…→850`· 24-26 builds ανά animation).
- `parentChanged=false` **πάντα** → parent αθώος.
- `msgsHash`/`combinedHash` **πανομοιότυπα σε όλο το storm** → providers/content αθώα.
- `selectCalls` +1/build (cache hits, equal) → selectors αθώα.
- `flutter grep`: κανένα `MediaQuery` στο chat_messages_list.dart, ούτε στο `ResponsiveUtils.resolveWidth` (constraints+L10n μόνο), ούτε στο `L10n.isGreek` (Localizations.localeOf) → το dirty ανά καρέ έρχεται από το **Localizations InheritedWidget μέσω `L10n.isGreek(context)` στο build()** (μόνη `dependOnInheritedWidgetOfExactType` στο build path).

---

## Session 224 — ROOT CAUSE: Localizations + fix6 locale-cache (100%) — 10 Αυγ 2026

### Απόδειξη (isolation test)
Με το `L10n.isGreek(context)` προσωρινά αντικατεστημένο (`const greek = true`), **μηδέν storms** σε test με πολλαπλά ανοίγματα/κλεισίματα πληκτρολογίου (21:44:15/19/34/38) — μόνο τα bounded `ReplyPreview ×N` (φυσιολογικό sliver relayout). **Root cause 100% επιβεβαιωμένο:** το `Localizations.localeOf(context)` στο build ειδοποιεί τους dependents σε κάθε frame keyboard animation (το Localizations rebuilds ανάντη από MediaQuery viewInsets), ακόμα κι αν το locale δεν αλλάζει ποτέ.

### Fix6 (SPoT locale-cache, 1 αρχείο) — ίδιο pattern με τα υπόλοιπα equality-caches του αρχείου
- **Field:** `bool _cachedGreek = true;` (με σχόλιο root cause).
- **`didChangeDependencies()`:** μοναδικό σημείο ανάγνωσης `_cachedGreek = L10n.isGreek(context);` — καλείται μόνο όταν το Localizations **πραγματικά** αλλάζει (αλλαγή γλώσσας εφαρμογής) → δίγλωσση λειτουργικότητα 100% διατηρημένη.
- **Build:** `final greek = _cachedGreek;` — μηδέν InheritedWidget dependency στο build(). Το greek χρησιμοποιείται μόνο σε EmptyView/ErrorView μηνύματα → μηδενική επίδραση σε bubbles/ListView.

### Επαλήθευση (device, run 22:00 — group chat, media+fwd+emoji+gif+photo+reply)
- ΟΛΑ τα σενάρια που προκαλούσαν storm (MediaPickerSheet, emoji, GifPicker, photo picker + keyboard animations): **μηδέν `MSG_LIST BUILD` storms**.
- Κάθε `MSG_LIST BUILD` (#1→#12) είχε **πραγματική αλλαγή** (msgsHash/combinedHash άλλαζαν — νέο μήνυμα/pending state).
- Τα `ReplyPreview ×N` (bounded bursts) παραμένουν μόνα τους — φυσιολογικά (Session 222).
- Σύγκριση: 20:45 (πριν) → 24-26 builds/storm με πανομοιότυπα hashes· 22:00 (μετά) → μηδέν.

### Καθαρισμός (revert TEMP probes)
- Αφαιρέθηκαν όλα τα SIG-PROBE (Session 223/224): fields (71-80), selectCalls counter (selector), SIG-PROBE + SIG-PROBE-2 blocks στο build().
- Κρατήθηκε το permanent logging (MSG_LIST BUILD, ListView (re)BUILT/REUSED, item, precomputed).

### `flutter analyze`: clean ✅ (0 issues)


## Session 225 — Incoming Share Media (image/video/audio/GIF) + Upload progress UX (100%) — 10 Αυγ 2026

### Στόχος
Το incoming share υπήρχε μόνο για text/url (`share/media-not-supported`). Φάση 2: πλήρες media sharing με πραγματικό GIF, video thumbnails και οπτική πρόοδο upload μέσα στη συνομιλία.

### Native (`MainActivity.kt`)
- `copySharedMedia(uri, type)`: αντιγράφει το `content:// → cacheDir/near_me_share_cache/incoming/<ts>.<ext>` (ext mapping ίδιο με Dart: gif→gif, image→jpg, video→mp4, audio→m4a). `clipData` fallback για EXTRA_STREAM null. Όποιο copy fail → null.
- Media branch πλέον στέλνει στο Dart `content = απόλυτο path` (όχι το απρόσιτο για File `content://`).

### Dart — flow
- **`incoming_share_service.dart`**: το `share/media-not-supported` αντικαθίσταται από πλήρες media flow: file-check → preview sheet (`filePath` + `thumbnailBytes`) → `showChatRecipientPicker` → `_sendMedia`. Dispatch: `image` → `ImageUtils.stripExif` + bytes· `image/.gif` → **raw bytes** ως πραγματικό animated GIF (χωρίς stripExif· εσκεμμένα)· `video` → `videoPath` + thumbnail (fail-open)· `audio` → bytes. Temp cleanup best-effort `_deleteTmp()` σε **όλους** τους δρόμους (dismiss/απόρριψη/send ok-fail). Ο `MediaShareCache.sweep()` σβήνει μόνο root files → το `incoming/` δεν αγγίζεται (κανένα race).
- **Video thumbnail reuse**: το thumbnail δημιουργείται **πριν** το preview sheet (`_generateVideoThumb`, ίδιο `VideoThumbnail`/get_thumbnail_video που ήδη χρησιμοποιεί το ChatInputBar) → εμφανίζεται στο sheet (`Image.memory`) και ξαναχρησιμοποιείται στο send (μία κλήση, όχι δύο).
- **Upload progress UX**: μετά την επιλογή συνομιλίας `begin(chatId)` → `context.go('/chat/$chatId')` → `_sendMedia` → `end()` (πάντα). Ο `ChatInputBar` κάνει `ref.watch(incomingShareUploadProvider) == chatId` → ίδιο spinner pattern με το `_isLoading` (send disabled + «+» κρυφό) — **ίδια συμπεριφορά για ΟΛΑ τα media** (image/gif/video/audio). Success χωρίς toast (το μήνυμα φαίνεται)· error → υπάρχοντα snackbar/failed.
- **`incoming_share_sheet.dart`**: media preview (Image.file / Image.memory thumb / icon) — leaf, χωρίς MediaQuery/watch. Νέο SPoT `L10n.mediaTypeLabel` (3 labels). `error_messages.dart`: `share/media-not-supported` → `share/media-load-failed`.
- **`chat_repository_impl.dart`**: `imageBytes` branch δέχεται και `type=='gif'` → upload `.gif` με `contentType: image/gif` (interface αμετάβλητο).

### Σημαντικά ευρήματα
- **Υπάρχον pattern του app**: το app δεν χρησιμοποιεί modal loading — τα media sends χρησιμοποιούν `_isLoading` → spinner στο send button. Το `AppMessenger.showLoading/hideLoading` ήταν **dead code** (δεν καλούνται πουθενά). Γι' αυτό επιλέχθηκε το spinner στο InputBar αντί modal — συνεπές παντού.
- `stripExif` με αρνητικό "saved bytes" (π.χ. `-90068`) είναι φυσιολογικό (JPEG re-encode μπορεί να επεκταθεί) — χωρίς σφάλμα.

### Verification
- `flutter analyze`: clean ✅ · `flutter test`: 30/30 ✅
- Device (release build, cold start): image share ✓ (stripExif → sendMediaMessage image → success), video share ✓ (upload → success, Storage URL `.mp4` σωστό)
- Παρατήρηση που διορθώθηκε: **video χωρίς thumbnail στο preview** → λύθηκε με δημιουργία thumbnail πριν το sheet
- `SqliteException(database is locked)` στα `_syncChatFromFirestore` **προϋπάρχον** drift issue (retry πέτυχε μετά), όχι σχετικό με το share


### Χρόνος/Flags
- Κάθε αλλαγή ενεργοποιείται με το υπάρχον `FeatureFlags.incomingShareEnabled` · native copy logs `chatShare` flag. Απαιτεί **πλήρες rebuild** όταν αλλάζει το Kotlin (το video thumb + progress είναι Dart-only — αρκεί hot restart).

### Εκκρεμούν (device tests) — ✅ ΟΛΑ ΕΛΗΞΑΝ (13 Αυγ, Session 231)
- ~~GIF share → **animated** στην οθόνη παραλήπτη~~ → ✅
- ~~Audio share · Warm share (app ανοιχτό → share) · Regression text share~~ → ✅

---

## Session 226 — Debug logs cleanup: search/discovery + startup (100%) — 11 Αυγ 2026

### Σκοπός
Απομάκρυνση/ομαδοποίηση verbose debug logs. Δύο φάσεις: **(1)** search/discovery hot path (per-candidate → summary) και **(2)** startup logs (περιορισμένο σετ high-value). Αρχή: «keep summaries / remove per-item lines». Καμία αλλαγή λογικής — μόνο `DebugConfig.log` calls (flags unchanged).

### Φάση 1 — Search/discovery (6 αρχεία)

- **`geohash_utils.dart`** — αφαιρέθηκαν: `encode:` / `decode:`, `_cellDimensions:`, `haversine:` (per-pair), και τα 2 `distanceToNearestEdge:`, `distanceToPoint:` (result + `[CACHE HIT]`), `isWithinRadius:`, και τα searchPrecision intermediates (`radius≤0`, «try coarser»). **Κρατήθηκαν:** `searchPrecision` final summary (1 γραμμή/αναζήτηση — τεκμήριο Session 214), ακραίο `DebugConfig.error` (safety net), `getNeighbours`, `getBounds`, `precisionFromSetting`, `precisionLabel`, `clearDistanceCache`.
- **`firestore_search_repository.dart`** — `_passesFilters` → `(bool, reason)` χωρίς header + 12 ❌/✅ per-user γραμμές. Νέο helper `_filterAndLog`: **1 summary γραμμή ανά query** — `_geoSearch/_generalSearch: X/Y candidates passed filters (rejected: gender=N, age=M, radius=K...)`. Reasons ομαδοποιημένα: city/country/age/videoCall/directChat/online/lookingFor/interests/gender/radius.
- **`search_provider.dart`** — per-candidate `_computeDistances: uid=...` αφαιρέθηκε · κρατείται το summary `N computed, M skipped`.
- **`profile_card.dart`** — −3 logs (`presence` isOnline, `uiRebuild` build, `_buildAvatar`) + unused import αφαίρεση.
- **`status_provider.dart`** — −2 logs (create/dispose) + unused import αφαίρεση.
- **`profile_repository_impl.dart`** — −1 log (`streamUserStatus` start line · κρατείται η result line με `isOnline/effective`).

### Φάση 2 — Startup (περιορισμένο σετ — ο χρήστης ρώτησε ρητά «τι κερδίζουμε», αποφασίστηκε optional-polish μόνο στα high-value)

- **`main.dart`** — `AppBootstrap.didChangeAppLifecycleState` «ignored» branch → `if (!_firebaseInitDone) return;` (behavior-identical).
- **`app_router.dart`** — 6→2 auth γραμμές: `AppRouter: user.reload() completed in Xms` + `Auth state changed: uid=..., anon=..., emailVerified=...` (με `verifyDismissed reset` ενσωματωμένο· `uidChanged` κρατιέται πριν το `_lastUid`). Αφαιρέθηκαν: `init callback fired`, `reload starting`, `user changed to`, `calling _authNotifier.notify()`.
- **`auth_provider.dart`** — `userChanges:` duplicate αφαιρέθηκε — το `.map()` υπήρχε μόνο για το log, απλοποιήθηκε σε direct `userChanges()`.

### Απορρίφθηκαν / κρατήθηκαν συνειδητά
- **Init redundancy**: `Firebase initialized`, `Opening/Drift database opened`, `start` markers, `PresenceService.init`, `IncomingShare: init` — κρίθηκαν χαμηλής αξίας (μία φορά/εκκίνηση vs per-search noise), ο χρήστης πήρε απόφαση με κόστος-όφελος και τα άφησε.
- **Guardrails** (ούτε έγγραφα στους candidates): ΟΛΑ τα `DebugConfig.warn`/`error` paths (`searchPrecision` extreme error, `getNeighbours failed`, `SearchNotifier.search failed`) — safety net ενάντια σε silent regressions.

### Verification
- `flutter analyze`: clean ✅ (0 issues, όλο το project) · `flutter test`: **30/30 passed** ✅ (το `[ERROR] AppSettings load failed` στο widget_test είναι γνωστό test-environment artifact, προϋπάρχον και άσχετο).
- Net κέρδος: search/discovery ~50-80 → **~4-5 γραμμές/αναζήτηση** · startup **−6 γραμμές/εκκίνηση**.


### Σημείωση για το μέλλον
- Το πλήρες startup cleanup (init redundancy κ.λπ.) παραμένει **προαιρετικό polish**, όχι ανάγκη — εκτιμημένο κέρδος ~8-10 γραμμές/εκκίνηση με μηδενικό ρίσκο αν ποτέ αποφασιστεί.
- Τα κρατημένα `[TIMING]`, `Redirect`, search εισόδου/εξόδου, `publish`/`saveProfile` είναι σκόπιμα — αποτελούν την «καρδιά» της διαγνωστικής ικανότητας.

---

## ΚΕΦΑΛΑΙΟ 10 — REBUILD STORMS: SETTLED / PENDING / REJECTED

> Το μεγαλύτερο διαρκές θέμα του project. Συγκεντρωτική κατάταξη όλων των rebuild-related fixes με την τελική τους κατάσταση.

### SETTLED ✅ (λύθηκαν & verified — ο κώδικας είναι ο ενεργός fix)

#### Root cause — Localizations (Session 224, fix6 · ΣΤΑΘΕΡΟ)
- **Σύμπτωμα:** 24-26 πλήρη `MSG_LIST BUILD`/sec με πανομοιότυπα hashes σε κάθε keyboard animation.
- **Αιτία:** `Localizations.localeOf(context)` μέσω `L10n.isGreek(context)` στο `build()` — ακόμα κι αν το locale δεν αλλάζει, τα rebuilds αλλάζουν ανά frame.
- **Fix:** `bool _cachedGreek` + ανάγνωση ΜΟΝΟ σε `didChangeDependencies()`. Zero InheritedWidget dependency στο build(). Verified: μηδέν storms, locale-switch 100% λειτουργικό.

#### Root cause — MediaQuery στο ChatMessagesList.build() (Session 221, fix3 · ΣΤΑΘΕΡΟ)
- **Σύμπτωμα:** 22-26 rebuilds σε κάθε keyboard open/close.
- **Αιτία:** `MediaQuery.sizeOf(context)` (screenH diagnostic + `width` για responsive padding) — viewInsets αλλάζει ανά frame.
- **Fix:** `LayoutBuilder` + `ResponsiveUtils.resolveWidth(context, constraints)` — **ZERO MediaQuery στο αρχείό** (grep-verified). Verified: μηδέν `MSG_LIST BUILD` από keyboard/scroll.

#### fix5 — SPoT width-cache (Session 222 · ΣΤΑΘΕΡΟ)
- ListView instance επιστρέφεται **identical** σε αλλαγή μόνο ύψους → `ListView REUSED ... itemBuilder NOT re-invoked (×25)`. Idle: 4+ λεπτά με 0 bursts.

#### Selectors rebuild (Session 221 · ΣΤΑΘΕΡΟ)
- `participantNicknames`/`participantAvatarUrls` έφτιαχναν νέο Map ανά build → Riverpod identity νόμιζε «άλλαξε». Fix: **cached-instance** (όπως `lastReadTimestamps`).

#### bubbleMaxWidth SPoT (Session 222 · ΣΤΑΘΕΡΟ)
- Υπολογιζόταν σε 4 αρχεία με ξεχωριστό LayoutBuilder καθένα. Fix: **ένας υπολογισμός** στο ChatMessagesList (`w * 0.75`), πέρασμα ως required param σε όλα τα 5 bubble types. Αφαιρέθηκαν όλα τα βubble-level LayoutBuilder.

#### Ιστορικά fixes (Sessions 70-203 · ΟΛΑ STABLE)
| Session | Fix |
|---|---|
| 70 | ChatScreen rebuild loop (5x/4s) — page keys + smart auth notifier + batch pagination |
| 137 | ProfileCards ~20× rebuilds — `ValueKey` + `select()` + `SearchResultsGrid` extraction |
| 174 | chatDocProvider cascade — cache + `DeepCollectionEquality` |
| 178 | ChatScreen storm — participantUidsProvider cache + `select()` |
| 179 | EmojiPicker storm — `EmojiPickerPanel` leaf widget |
| 188 | Exit animation storm + idle rebuilds — remove GoRouterState·from build, `ValueKey(msg['id'])` + `ValueKey('ds_$date')` |
| 189 | MainShell LayoutBuilder cascade — StatefulWidget + cached `isWide` |
| 192 | chatDocProvider.select() AsyncValue → return `Map` (deep comparison) |
| 193 | participantUidsProvider autoDispose cascade — remove autoDispose |
| 195 | decrypt lastMessage media FormatException — skip-decrypt gif/image/video |
| 196 | LayoutBuilder per-bubble → pre-computed `bubbleMaxWidth` |
| 197 | markAsRead σε build path → `initState` `addPostFrameCallback` |
| 198 | Keyboard cascade 26× — `_SafeInputArea` leaf widget |
| 199 | pending=true→false cascade — suppression σε chatDocProvider |
| 200 | messagesStream νέα list instances — `DeepCollectionEquality` cache (same reference) |
| 200 | `_obtainBubble` cascade — `_MessageBubbleSignature` + instance cache |
| 201 | EmojiOnlyBubble `_buildCounts` static leak — removed |
| 201 | markAsRead serverTimestamp όταν `unreadCount==0` — guard (skip write) |
| 203 | Bubble width = max στην αρχή — `IntrinsicWidth` wrapper |
| 216 | chatsProvider redundant emits — equality-check στο `.watch()` |

#### «Φυσιολογικό» (δεν χρειαζόταν fix — Session 222 · ΚΛΕΙΣΙΜΟ ΘΕΜΑΤΟΣ)
- Τα `ReplyPreview ×N` στα bursts = **sliver-level relayout των ορατών bubbles** (τα ίδια Elements, όχι νέα ListView/items). Bounded, μόνο σε αλληλεπίδραση, idle=0, όχι leak/loop. **Δεν εφαρμόστηκε επεμβατική βελτιστοποίηση** (ρίσκο > όφελος).

---

### PENDING ⏳ (εκκρεμούν — όχι ενεργά σφάλματα)

| Θέμα | Πηγή |
|---|---|
| ~~`ChatScreen` ξαναφτιάχνει `_messagesList` σε video play/fail (chat_screen.dart:134,150,161) — σκοτώνει το fix5 width-cache~~ → **✅ ΚΛΕΙΣΕ (Session 232: videoPlaybackProvider)** | Session 222 |
| ~~Device test νέων διακριτικών logs (Log A/B/C: item, ReplyPreview id/h, inst) + ανάλυση — ζητήθηκε από χρήστη~~ → **✅ ΕΛΗΞΕ (13 Αυγ)** | Session 221 |
| ~~`join_confirmation_screen.dart:72` + `fcm_service.dart:89,166` — deep links χωρίς `extra` (group-capable)~~ → **✅ ΚΛΕΙΣΕ (Session 232: ChatScreen cold-path chatDoc lookup με `!mounted` re-check)** | Session 218 |
| ~~`AppMessenger.showLoading/hideLoading` — dead code (δεν καλούνται πουθενά· τα media sends χρησιμοποιούν `_isLoading` spinner)~~ → **✅ ΚΛΕΙΣΕ (Session 232)** | Session 225 |

---

### REJECTED / REVERTED ❌ (δοκιμάστηκαν & απορρίφθηκαν — παραμένουν μόνο ως ιστορικό)

| # | Προσέγγιση | Αιτία απόρριψης |
|---|---|---|
| 1 | **fix4 — memoization ολόκληρου ListView** (Session 221, backup `..._memo.bak`) | REVERTED: στο relayout ο `itemBuilder` ξανακαλείται ούτως ή άλλως για τα ορατά items (sliver child cycle) — το memoized ListView δεν σταματάει τα bubble rebuilds. Plus: τα `ReplyPreview ×26` ήταν **aggregate** χωρίς msgId/instance — δεν μας έλεγαν ποια εστία. |
| 2 | **fix2 — cached width μέσω `didChangeDependencies()`** (Session 221, backup `..._fix2.bak`) | Απέτυχε: η κλήση `MediaQuery.sizeOf()` στη `didChangeDependencies` δηλώνει κι αυτή MediaQuery dependency → το keyboard συνέχισε να ξαναχτίζει. |
| 3 | **Option A (skip-write) & C (debounce)** για chatsProvider redundant emits (Session 216) | A = invasive (4 σημεία, false-negative risk σε timestamps)· C = προσθέτει latency στο live chat. Επιλέχθηκε ο equality-check. |
| 4 | **`select()`/grid-level fixes για ProfileCard (×2)** (Session 215) | Αναλύθηκε & απορρίφθηκε: το `(×2)` προέρχεται από `userStatusProvider` (design του online-flicker fix #155), όχι από το grid — το `select()` θα εισήγαγε risk στο loadMore spinner. |
| 5 | **Firebase init retry screen** (Session 219, full REVERT) | Πλήρες revert: το init **δεν** απαιτεί δίκτυο (bundled `google-services.json`)· το «Retry» που έβλεπε ο χρήστης ήταν το υπάρχον offline UX του Discovery. Ο κώδικας δεν άφησε κανένα ίχνος. |

### Μάθημα (Session 221-224, κρατάμε για το μέλλον)
1. **ΠΟΤΕ** `MediaQuery.sizeOf/viewInsetsOf/viewPaddingOf` σε `build()` αν το widget πρέπει να είναι σταθερό — η dependency είναι σε ΟΛΟ το MediaQueryData.
2. Διάγνωση πριν από fix: **SIG-diagnostic** (hash/identity των watches) + αποκλεισμοί (parent rebuild, provider emits, setState, MediaQuery) πριν οτιδήποτε speculative.
3. **Ποτέ speculative fix σε aggregate logs** — πρώτα διακριτικά (msgId/instance/identityHashCode).
4. Το σωστό pattern του codebase: επιμέρους equality-caches (identical reference) + `LayoutBuilder`· «no MediaQuery rebuild cascade».

---

## Session 227 — Quote-in-Bubble unification (Φάσεις 1-6) + instrumentation removal (100%) — 12 Αυγ 2026

### Σκοπός
1. **Quote ενσωματωμένο ΜΕΣΑ στο bubble** (WhatsApp/Telegram style) σε ΟΛΟΥΣ τους τύπους μηνύματος — όχι ξεχωριστό `ReplyPreview` πάνω-έξω. Quote = ίδιο background, ίδιο πλάτος, εσωτερικός divider.
2. Μετά το device verification, **αφαίρεση όλων των BUBBLE_W instrumentation blocks** (προσωρινό debug).

Οδηγός υλοποίησης: **`reply_card.md`** (v1.0, authoritative).

### βασική λύση (σε όλα τα bubble types)
- **Quote κορυφή μέσα στο Container**: `Column(mainAxisSize.min, crossAxisAlignment.stretch) → [BubbleQuoteSection?, content..., time]`, αντί για `ReplyPreview` + μετά Container.
- **§3.8 hug/fixed:** `IntrinsicWidth` (για να σφίγγει το πλάτος στο περιεχόμενο) ΜΟΝΟ για text & emoji. Media (gif/image, audio, video) = stretch χωρίς IntrinsicWidth (fixed width).
- **Divider insider:** `SizedBox(height: 12, child: Center(child: SizedBox(height: 1, ColoredBox)))` μέσα στο `BubbleQuoteSection` (learned: ποτέ Material `Divider`/`Container(height:)` — intrinsic height ≠ 0).
- **GlobalObjectKey:** ένα instance ανά μετρητή (δύο keys με ίδια τιμή ΔΕΝ είναι ίσα — bug source).
- **Divider width verified (device logs):** text `w−28` (padding 14×2) · gif/image `=w` · audio `w−24` (padding 12×2) · video `=w` · emoji `w−28`.
- **Emoji ειδικό:** `hasQuote ? _buildQuoteCard : _buildBare` — bare = ακριβώς η παλιά δομή (χωρίς card), quote card = Container(stretch)[Quote, emoji, time]. Sent → `AppColors.chatBubbleSent` (#075E54), received → `surfaceContainerHighest`, textColor contrast-aware, tail στο `isLastInGroup`.
- **Κανόνες:** μόνο `Theme.of` σε build (audio/video ήταν ήδη Stateful για player), υπογραφές `MessageBubble`/`chat_messages_list` αμετάβλητες, `ChatInputBar` reply banner (:416) δεν αγγίστηκε.

### Φάσεις (όλες merged & device-verified πριν το cleanup)
- **Φάση 1:** `_replyPreviewText` helper + `BubbleQuoteSection` (flattened, accent 3px, contrast-aware) + `ReplyMediaThumbnail.surfaceColor` param → `reply_preview.dart`.
- **Φάση 2 (text):** quote μέσα στο Container + test πλάτους· device verdict: divider πάντα `w−28`, hug σωστό, idle rebuild test 1′42″ καθαρό.
- **Φάση 3 (gif/image):** αφαίρεση `ReplyPreview`, `Column(stretch)[Quote?, CachedNetworkImage]`· logs: `w=288.0 divider=288.0` ✓.
- **Φάση 4 (audio):** `Column(stretch)[Quote?, Row]` (padding h12/v8)· logs: `divider=264.0` (w−24) ✓.
- **Φάση 5 (video):** `Column(stretch)[Quote?, ClipRRect]`· logs: `divider=288.0` (=w) ✓.
- **Φάση 6 (emoji):** `_buildBare`/`_buildQuoteCard`· logs: divider `w−28` (96.7→68.7, 96.2→68.2, 107.2→79.2, 125.3→97.3, 140.9→112.9), μικρά w → IntrinsicWidth OK, μηδέν `quote=false` μετρήσεις (bare).

### Device regression (12 Αυγ, πριν το cleanup)
- 1-to-1 + group + sent/received, replies σε text/gif/image/audio/video/emoji, πολλαπλά διαδοχικά reply→send→clear loop, emoji picker open/close.
- **0 exceptions/overflows.** Όλα τα dividers συνεπή. Ένα burst ×48 στο dismiss emoji picker = γνωστό keyboard/scroll relayout, όχι regression του merge.

### Αφαίρεση instrumentation (αυτό το session)
- **5 αρχεία**, κάθε ένα: αφαίρεση `GlobalObjectKey` keys (`bubbleKey`/`dividerMeasureKey` + prefixes `bubble_/gif_/aud_/vid_/emo_`)**, `if (DebugConfig.debugMode) { addPostFrameCallback ... }` block, `key:` στο Container, `dividerKey:` param στο `BubbleQuoteSection`.
- **Αφαιρέθηκαν και αχρησιμοποίητα imports `debug_config.dart`:** `text_message_bubble.dart`, `emoji_only_bubble.dart` (μόνο το instrumentation τα χρησιμοποιούσε). Σε `gif/audio/video` το import ΜΕΝΕΙ (χρησιμοποιείται για chatAudio/uiInteraction κ.λπ.).
- **Κρατήθηκαν** τα προϋπάρχοντα `DebugConfig.chatBubbleDesign` logs: `chat_messages_list.dart:921` (MSG_LIST) & `chat_ui_utils.dart:68` (ChatGroupingCalculator).
- Το flag `chatBubbleDesign` παραμένει στο `debug_config.dart` (χρησιμοποιείται από τα δύο κρατημένα logs).

### Έλεγχος
- `grep` verification: μηδέν `BUBBLE_W*` / bubble keys σε όλο το `lib/`.
- **`flutter analyze`: clean ✅ (0 issues)**
- `flutter test`: δεν τρέχτηκε σε αυτό το session.


---

## Session 228 — Reactions side-trigger + summaries + cancel (100%) — 12 Αυγ 2026

### Σκοπός
Μετακίνηση του reaction trigger από τη στήλη κάτω από το μήνυμα σε **εικονίδιο δίπλα** στο bubble (αριστερά στα δικά μας, δεξιά στου άλλου), με: εμφάνιση του δικού μου emoji στο icon, σύνολα (emoji+πλήθος) δίπλα στου άλλου, και δυνατότητα **ακύρωσης**. Τίποτα δεν εμφανίζεται κάτω από το μήνυμα πια.

### Φάση 1 — Πλάγιο trigger icon (+1 API)
- **`message_reactions.dart`** — νέο public `ReactionTriggerIcon` (Stateless, μόνο `Theme.of` — μηδέν rebuild cascade, συνεπές με Sessions 196/200/222/224): ημιδιαφανές `Icons.add_reaction_outlined` σε κυκλικό border, `GestureDetector.onLongPress` → picker. Εξήχθη `showReactionPicker` (η picker λογική που ήταν μέσα στο `MessageReactions`) ως public.
- **5 bubble files** (`text_message_bubble`, `gif_image_bubble`, `audio_message_bubble`, `video_message_bubble`, `emoji_only_bubble`): ο long-press wrapper (text/emoji) ή ο Stack (gif/audio/video) τυλίχτηκε σε `Row(center)` με το icon — `if (isMe)` αριστερά, `if (!isMe)` δεξιά.

### Φάση 2 — Revert (ζητήθηκε από χρήστη)
- Ο χρήστης δεν κατάλαβε τον συνδυασμό icon-emoji + chips κάτω → ζήτησε πλήρες revert. Επιστροφή στο «trigger-side» backup (`*_emoji_show_20260812_151503.bak`). Μάθημα επικοινωνίας: εξηγώ πάντα τι δείχνει το icon σε κάθε περίπτωση πριν εφαρμόσω.

### Φάση 3 — Τελικό design (κατόπιν ξεκάθαρου UX με τον χρήστη, backup `*_side_summary_20260812_154038.bak`)
- **Κάτω από το μήνυμα: ΤΙΠΟΤΑ** — αφαιρέθηκαν πλήρως τα `MessageReactionsRow(...)` από τα 5 bubbles (και τα 5 unused `import message_reactions_row.dart`).
- **`ReactionTriggerIcon` (νέα signature: `reactions`, `currentUid`, `isMe`, `onRemove`):**
  - Χωρίς δική μου reaction → `add_reaction_outlined` ημιδιαφανές, long-press → picker.
  - Με δική μου reaction → δείχνει **το δικό μου emoji** σε κύκλο με border `primary`.
  - **Tap** στο icon όταν έχω reaction → **αφαίρεση** (`onRemove?.call`).
  - **Σύνολα δίπλα μόνο σε `!isMe`**: badge ανά emoji με πλήθος όταν >1 (νέο `_ReactionCountBadge`, π.χ. `❤️ 2 😂 1`). Στα δικά μου ΔΕΝ δείχνονται (το icon ήδη δείχνει το emoji μου — αποφυγή διπλής εμφάνισης, ζητήθηκε).
- **`showReactionPicker` (νέα: `currentEmoji`, `onRemove`) — toggle:** ξανά-επιλογή του **ίδιου** emoji στο bottom-sheet ή στο full EmojiPicker → `onRemove` (ακύρωση) αντί re-set.
- Όλα τα bubbles περνούν `reactions`, `currentUid`, `isMe`, `onRemove` (audio/video: `widget.`). `FeatureFlags.messageReactionsEnabled` κρατείται σε όλα τα paths.

### Σημείωση / open θέμα
- ~~**`MessageReactions`** (message_reactions.dart) και **`MessageReactionsRow`** (message_reactions_row.dart) παραμένουν ορισμένα ως **dead code**~~ → **ΚΛΕΙΣΙΜΟ (Session 231):** και τα δύο διαγράφηκαν (verified 100% ασφαλές).

### Έλεγχος
- **`flutter analyze`: clean ✅ (0 issues)** σε κάθε φάση (και μετά την αφαίρεση των unused imports).
- `flutter test`: δεν τρέχτηκε σε αυτό το session.
- ~~**Εκκρεμεί**: device test τελικού design~~ → **✅ ΟΛΟΚΛΗΡΩΘΗΚΕ (13 Αυγ, Session 231):** δικό μου μήνυμα με ❤️ στο icon χωρίς σύνολα · του άλλου με badges · tap-remove · picker-toggle — όλα OK.


---

## Session 229 — ImageCacheGuard: disk cache pruning fix (100%) — 13 Αυγ 2026

### Το πρόβλημα
Η disk cache του CachedNetworkImage δεν μειωνόταν στα 300MB παρά το log `pruned (was 774MB > 300MB limit)` — μεγάλωνε ανεξέλεγκτα (774→776→777MB).

### Root cause (επιβεβαιωμένο, 2 μέρη)
1. **Bug στο flutter_cache_manager 3.4.1 (`cache_store.dart`):** το `emptyCache()` διαγράφει τα entries από το DB αλλά **ΟΧΙ τα αρχεία** — το delete γίνεται με `io.File(cacheObject.relativePath)` (σχετικό path, π.χ. `uuid.jpg`, χωρίς base dir) → `existsSync()` = false πάντα, γιατί το πραγματικό cache είναι στο `getTemporaryDirectory()/libCachedImageData/`.
2. **Λάθος μέτρηση στο πρώτο DIAG:** στο Android το DB του cache manager είναι **sqflite** (`libCachedImageData.db`) — το temporary DIAG που διάβαζε το `libCachedImageData.json` έδειχνε `registered=0`, που ήταν απλά λάθος μέτρηση (δεν υπάρχει json στο Android).

- Το bug είναι **platform-agnostic** (Android/iOS/macOS/Windows/Linux) — μόνο το Web εξαιρείται.
- **Κύκλος:** entries σβήνονται → files ξανακατεβαίνουν πάνω στα παλιά (χωρίς entry) → cache μεγαλώνει συνεχώς.

### Fix (`image_cache_guard.dart`, 1 αρχείο)
- Αντικατάσταση του σκέτου `DefaultCacheManager().emptyCache()` με: **απευθείας διαγραφή όλων των files** του φακέλου `getTemporaryDirectory()/libCachedImageData/` (loop `cacheDir.list(recursive: true)` → `File.delete()` με per-file try/catch) **και μετά** `emptyCache()` για καθαρισμό των entries του DB.
- Αφαίρεση όλων των temporary DIAG diagnostics (import `dart:convert`, μετρητής `fileCount`, DIAG json block).
- Logs: `current size=X.XMB` (πάντα) + `pruned N file(s) (was XMB > 300MB limit)` (μόνο όταν ξεπεράσει το όριο).

### Verification (device, release build, 13 Αυγ)
| Run | `current size` | Αποτέλεσμα |
|---|---|---|
| Πριν το fix | 777.3MB | — |
| Run 1 | 777.3MB | `pruned 1202 file(s) (was 777MB > 300MB limit)` ✅ |
| Run 2 | **0.8MB** | κάτω από 300MB, κανένα prune ✅ |

- `flutter analyze lib\core\utils\image_cache_guard.dart`: clean ✅
- Κανένα side-effect (όλα τα startup logs φυσιολογικά)


---

## Session 230 — Phone verification UI removal (feature flag OFF) (100%) — 13 Αυγ 2026

### Σκοπός
Αφαίρεση του phone verification από το UI (Settings), ύστερα από ανάλυση ότι είναι **πλεονασμός**: το `canUserCommunicate` καλύπτεται ήδη με verified **email Ή** τηλέφωνο — το τηλέφωνο πρόσθετε μόνο κόστος (SMS), fragile flow (reCAPTCHA + browser dependency, π.χ. Brave sessionStorage partitioning → «missing initial state») και UX friction. Η λογική παραμένει στον κώδικα, απλώς **feature flag OFF**.

### Τι έγινε (2 αρχεία, backups `*_20260813_121012.dart`)
- **`core/config/feature_flags.dart`** — νέο flag `static const bool phoneVerificationEnabled = false;` (στο Communication section).
- **`features/settings/screens/settings_screen.dart`** — το section «Επαλήθευση Τηλεφώνου» + «Αφαίρεση Τηλεφώνου» + Divider (γρ. 133-161) τυλίχτηκε σε `if (FeatureFlags.phoneVerificationEnabled && !isAnonymous && emailVerified) ...[...]` + import `feature_flags.dart`. Κρύβονται και τα δύο entries (τηλέφωνο + ακύρωση/unlink).

### Τι ΔΕΝ άλλαξε
- `phone_verify_screen.dart`, `phone_verify_provider.dart`, `auth_repository.dart`/`impl` — λογική 100% άθικτη.
- Route `/settings/phone-verify` στο `app_router.dart` — παραμένει (κανείς δεν το καλεί με flag OFF).
- `public_profile_view_screen.dart` — το δημόσιο τηλέφωνο (profile field) δεν αγγίχτηκε (διαφορετικό από auth verification).

### Διαδικασία απόφασης
- Διαπιστώθηκε ότι τα SHA-1/SHA-256 fingerprints στο Firebase Console **ταιριάζουν** με το debug keystore (το release χρησιμοποιεί debug signing, `build.gradle.kts:33`) — άρα δεν ήταν θέμα κλειδιών.
- Το «verify you're not a robot» + «missing initial state» είναι το **reCAPTCHA fallback** του Firebase (όταν δεν γίνεται SMS auto-verify) που ανοίγει τον **default browser** — ο Brave με storage partitioning σπάει το flow. Λύσεις (για μελλοντική χρήση αν ξαναενεργοποιηθεί): default browser → Chrome, Play Services ενημερωμένα, Shields OFF.

### `flutter analyze`: clean ✅ (0 issues)


---

## Session 231 — Reactions dead code removal + device test OK (100%) — 13 Αυγ 2026

### Σκοπός
Κλείσιμο των 2 open θεμάτων του Session 228: **(1)** διαγραφή του dead code (`MessageReactions` + `MessageReactionsRow`) και **(2)** επιβεβαίωση του device test του τελικού design reactions.

### 1) Dead code removal
**Έλεγχος πριν (διεξοδικός, verified 100% ασφαλές):**
- `MessageReactionsRow` — κανένα `.dart` import (ούτε `lib/`, ούτε `test/`). Μόνο αναφορές σε `.md` (oldsessions/sound_message/video_message) = τεκμηρίωση, όχι κώδικας.
- `MessageReactions` (κλάση) — μοναδική χρήση από `MessageReactionsRow` (διαγράφεται κι αυτό).
- `_ReactionChip` — private, ζει μόνο μέσα στην `MessageReactions`.
- LIVE μέρη που ΜΕΝΟΥΝ: `ReactionTriggerIcon` (11 κλήσεις σε 5 bubbles), `showReactionPicker`, `_ReactionCountBadge`, `_reactionEmojiButton`, `_reactionFullPicker`.

**Διαγραφές:**
- `message_reactions_row.dart` — **ολόκληρο το αρχείο** (43 γρ., 1 αρχείο deleted).
- `message_reactions.dart` — κλάση `MessageReactions` (74 γρ.) + `_ReactionChip` (47 γρ.). Το υπόλοιπο αρχείο μένει άθικτο.

### 2) Device test τελικού design (13 Αυγ) — ✅ ΟΛΑ ΚΑΛΑ
- Δικό μου μήνυμα με ❤️ στο icon **χωρίς σύνολα** ✓
- Του άλλου με **badges** (emoji + πλήθος όταν >1) ✓
- **Tap-remove** (tap στο icon με reaction → αφαίρεση) ✓
- **Picker-toggle** (ξανά-επιλογή ίδιου emoji → remove αντί re-set) ✓

### `flutter analyze`: clean ✅ (0 issues, full project — δεν έμεινε κανένα orphan import)


---

## Session 232 — PENDING 1: Video `_messagesList` rebuild → videoPlaybackProvider (100%) — 13 Αυγ 2026

### Το πρόβλημα (κλείσιμο PENDING 1)
Το `ChatScreen` ξαναδημιουργούσε ολόκληρο το `ChatMessagesList` **3 φορές** σε video play/fail (chat_screen.dart:134,150,161) — σκότωνε το fix5 width-cache (Session 222). Ο κανόνας `reply_card.md` §7.3 («ΠΟΤΕ αλλαγή υπογραφής MessageBubble / itemBuilder») και το «κλειδωμένο» fix5 αποκλείουν την περνάδα props.

### Επανέλεγχος (πριν την υλοποίηση)
- **Υπάρχουσα υποδομή:** το `chat_provider.dart` έχει ήδη το pattern `Notifier<Map<String, …>>` keyed by chatId (`ReplyToMessageNotifier`, `EditingMessageNotifier`, `PendingPrivateReplyNotifier`) για state που διαβάζουν τα bubbles χωρίς αλλαγή υπογραφής — το video ακολούθησε ακριβώς αυτό.
- **Το `VideoMessageBubble` ήδη αυτο-φιλτράρει** μέσω `_isMyController()` (`controller.dataSource == widget.content`) — δεν χρειάζεται να ξέρει «ποιο μήνυμα παίζει» από props.
- **Κριτικό κενό (σημείωση χρήστη, επιβεβαιωμένο):** το `_initPlayerListeners()` ενεργοποιούνταν μέσω `didUpdateWidget` (αλλαγή props). Με `ref.watch` μόνο, το side-effect (attach/detach listener) δεν θα ξαναέτρεχε — stale listener σε παλιό controller. Λύση: `ref.listen` στο build (Riverpod-ισοδύναμο του didUpdateWidget) + `_attachedController` State field ως single source of truth (όχι re-derive από provider στα cleanup — η σειρά dispose ChatScreen vs bubble δεν είναι εγγυημένη).

### Αλλαγές (3 αρχεία, backups `*_20260813_131456.dart`)
- **`chat_provider.dart`** — νέο `VideoPlaybackInfo {controller, loadingUrl}` + `VideoPlaybackNotifier` (`play(chatId, url)`: dispose παλιού → loadingUrl → init → controller· `stop(chatId)`: dispose+clear) + `videoPlaybackProvider`. Import `video_player`. Logs `DebugConfig.chatVideo` σε loading/ready/fail/stop/dispose.
- **`chat_screen.dart`** — `_playVideo` → 1 γραμμή `ref.read(videoPlaybackProvider.notifier).play(widget.chatId, url)`· αφαίρεση `_videoController` field + `dispose()` → `stop(chatId)`· αφαίρεση unused import `video_player`· `_messagesList` μένει fixed (χωρίς ξαναδημιουργίες).
- **`video_message_bubble.dart`** — `StatefulWidget` → `ConsumerStatefulWidget` (υπογραφή **ίδια**): `_attachedController` field· `_attachListener(controller)` (remove-old → attach-new)· `_removeListener()` βάσει `_attachedController`· `initState` = `ref.read`· `didUpdateWidget` μόνο σε content change· build: `ref.watch` (rendering value) + `ref.listen` (side-effect: `prev?.controller != next?.controller` → `_attachListener`)· `_togglePlayPause` → notifier.play (null-guard chatId)· `isLoading` από `playback?.loadingUrl`· TODO σχόλιο στα νεκρά πεδία (`videoPlayer`/`onPlayVideo`/`isLoadingUrl`) — επιλογή **Α** (dead props ως fallback, πλήρης τήρηση §7.3).

### Τι ΔΕΝ άλλαξε
- `chat_messages_list.dart` — **ακέραιο** (fix5 άθικτο) · `message_bubble.dart` υπογραφή/`itemBuilder` — **ακέραια** · audio/gif/text/emoji/system bubbles — **ακέραια** · `ChatInputBar` (δικό του local controller για preview) — **ακέραιο**.

### Rebuild-scope (επιβεβαίωση)
`ref.watch`/`ref.listen` σε ConsumerState rebuild-άρουν μόνο το συγκεκριμένο bubble Element — όχι cascade στο ListView. Αφού `_messagesList` δεν αλλάζει πια, το `_buildMessagesList()`/fix5-cache δεν ξανατρέχει λόγω video.

### `flutter analyze`: clean ✅ (0 issues)

### Εκκρεμεί device test (release build)
1. Play 2ο βίντεο ενώ παίζει το 1ο → το 1ο σταματά, χωρίς «αναβοσβήσιμο» όλης της λίστας.
2. Loading spinner μόνο στο πατημένο βίντεο· mute/pause toggle OK· play/fail επιστροφή σε thumbnail χωρίς stuck spinner.
3. Κλείσιμο/άνοιγμα chat → κανένα crash/zombie player.
4. Logs `MSG_LIST`: σε play/fail **όχι** πλήρες `MSG_LIST BUILD`.


### 🔴 Bug που βρέθηκε στο device test + fix (13 Αυγ)
- **Σύμπτωμα:** `Bad state: Using "ref" when a widget is about to or has been unmounted is unsafe.` στο `_ChatScreenState.dispose` (chat_screen.dart:100) — το `ref.read(...).stop()` μέσα στο dispose.
- **Αιτία:** το Riverpod απαγορεύει `ref` στο `dispose()`. Το `stop()` δεν εκτελούνταν → ο controller έμενε στο provider (zombie).
- **Fix (canonical pattern):** field `late final VideoPlaybackNotifier _videoPlayback;` → αποθήκευση στο `initState` (`ref.read(videoPlaybackProvider.notifier)`) → `dispose()` καλεί `_videoPlayback.stop(chatId)` χωρίς `ref`. Backup `backups/chat_screen_20260813_133117.dart`.
- **Επαλήθευση ότι το notifier είναι ασφαλές:** `stop()`/`_disposeController()`/`play()` χρησιμοποιούν ΜΟΝΟ το δικό τους `state` — κανένα `ref.read/watch` άλλου provider → ασφαλές να τρέξει σε οποιοδήποτε σημείο (ο notifier είναι global non-autoDispose).
- `flutter analyze`: clean ✅ · εκκρεμεί re-test (καμία `Bad state` γραμμή).

### ✅ Device re-test PASS (13 Αυγ 13:34-35)
- **Καμία** `Bad state: Using "ref"` γραμμή (το fix του dispose δουλεύει).
- `VideoPlayback: disposed controller` → `stop` → `ChatScreen dispose` στο κλείσιμο (13:34:54, 13:35:45).
- Play 1ο/2ο/3ο βίντεο διαδοχικά: `disposed` → `loading` → `ready`, **0 `MSG_LIST BUILD`** σε όλα (fix5 cache σώζεται).
- `ChatMessagesList init` 1 φορά/άνοιγμα. Μόνο `MSG_LIST ×2` = νέο μήνυμα (own message scroll) — φυσιολογικό.
- **PENDING 1 ΚΛΕΙΣΕ:** Session 222 πρόβλημα (ChatScreen ξαναδημιουργούσε `_messagesList`) λύθηκε οριστικά.

### ✅ PENDING 3 ΚΛΕΙΣΕ — deep links χωρίς `extra` (13 Αυγ)
- **Πρόβλημα:** `join_confirmation_screen.dart:72` + `fcm_service.dart:89,166` πηγαίνουν στο `/chat/$chatId` χωρίς `navExtra`. Σε cold path (cache miss) το `ChatScreen.initState` πήγαινε `isGroup=false` σε group → λάθος batch `isRead:true` σε group μηνύματα (`chat_repository_impl.dart:499`).
- **Fix (Επιλογή Α, μόνο `chat_screen.dart`):** ο postFrameCallback έγινε `async`· `knownGroup = cached ?? navExtra`· αν null → `await ref.read(chatDocProvider(...).future)` για το πραγματικό `isGroupChat` doc, **με `!mounted` re-check ΜΕΤΑ το await** (same lesson με dispose/ref bug — χρήστης το απαίτησε) · `src='firestore-cold'` στα logs.
- **Λύει ΚΑΙ τα 2 σημεία με 1 αλλαγή** (fcm_service/join_confirmation δεν αγγίχτηκαν). Zero impact στο normal flow (cached/navExtra υπάρχουν πάντα· chatDocProvider είναι ήδη watched από build → ζωντανός, autoDispose δεν το σκοτώνει).
- Backup: `backups/chat_screen_20260813_134449.dart` · `flutter analyze`: clean ✅

### ✅ PENDING 3 device test PASS (13 Αυγ 13:49-50)
- **Regression:** 1-1 `fUt4...ZQ` → `src=drift isGroupChat=false` · group `MJtzpl...` → `src=drift isGroupChat=true` · dispos χωρίς exceptions ✅
- **Cold path:** cold start → `FCM executing pending nav=/chat/Sfh...KuY` (χωρίς extra) → `ChatScreen init #0` → **`src=firestore-cold isGroupChat=false`** → `chatDocProvider emit` ΠΡΙΝ το `markAsRead` (σωστή σειρά) · `Sfh...KuY` είναι όντως 1-1 (Session 218) ✅
- Μηδέν `Bad state`/flutter exceptions · όλα τα E/ system-level (MIUI/Finsky/ads).
- Σημείωση: cold-path group chat δεν δοκιμάστηκε (δεν υπήρχε FCM group push) — αλλά το flag έρχεται από το doc (truth), άρα εξ ορισμού σωστό.

### ✅ PENDING 4 ΚΛΕΙΣΕ — AppMessenger dead code (13 Αυγ)
- **Πρόβλημα:** `AppMessenger.showLoading/hideLoading` ήταν dead code από το Session 225 (κανένα call σε όλο το lib) — το app χρησιμοποιεί `_isLoading` spinner, όχι modal loading.
- **Fix:** αφαίρεση και των δύο μεθόδων από το `app_messenger.dart` (γρ. 144-176). Τα `showSuccess/showError/showInfo/showConfirmDialog` έμειναν ως έχουν.
- Backup: `backups/app_messenger_20260813_135235.dart` · `flutter analyze`: clean ✅

---

## Session 233 — ID token claims-check (cold start) + Sign Out στο Settings (100%) — 14 Αυγ 2026

### 1) Stale ID token claims-check — πλήρες restart-scenario coverage

**Το πρόβλημα (restart gap):** Το `main.dart` auth listener είχε `if ((uidChanged || emailVerifiedChanged) && prev is AsyncData)` — το `prev is AsyncData` guard έκανε SKIP **όλο** το block σε καθαρό cold start (πρώτο emit = `AsyncLoading`, όχι `AsyncData`). Έτσι, στο σενάριο «register unverified → kill app → επαλήθευση εξωτερικά (κλικ στο link) → cold start», το claims-check **δεν έτρεχε ποτέ** → το cached ID token έμενε με claim `email_verified: false` έως ~1h → το Firestore rule `isVerified()` (firestore.rules:60-63, `request.auth.token.email_verified`) μπλόκαρε writes (chat/requests) server-side ενώ το UI έδειχνε `canComm=true`.

**Διάγνωση (device logs, 14 Αυγ):**
- Live verification (ίδιο session): claims-check έτρεχε κανονικά (`cached ID token stale … force refreshing` → `force-refreshed`) ✅
- Restart μετά από εξωτερική επαλήθευση (11:32:43): `listener fired … nextVerified=true` αλλά **ΚΑΝΕΝΑ** claims-check log — block skipped (`prev=AsyncLoading`) → stale token μη φρεσαρισμένο ❌

**Fix (μόνο `main.dart`, backup `backups/main_claimscheck_20260814_113558.dart`):**
- Το claims-check μετακινήθηκε **ΕΚΤΟΣ** του `prev is AsyncData` guard (main.dart:450-473) — τρέχει σε κάθε emission όταν `nextUser != null && nextUser.emailVerified`:
  - `getIdTokenResult(false)` (local, 0 δίκτυο) → αν claim `email_verified == true` → `skip refresh` (return)
  - Αλλιώς `getIdToken(true).timeout(6s)` → `force-refreshed`
  - `.catchError` για check/refresh failures
- Καλύπτει: live verification, cold-start μετά από εξωτερική επαλήθευση, login verified account. 0 δίκτυο όταν το token είναι ήδη σωστό.
- Αφαιρέθηκε το stale σχόλιο (π.χ. `prevUser != null` προσέγγιση) + typo fix.

**Πλήρες test (14 Αυγ, release):** register `soc.near.app@gmail.com` → sign out → kill → external verify → cold start:
```
11:49:03.688  listener fired prevUid=null … nextVerified=true
11:49:03.688  cached ID token stale (claims say unverified) — force refreshing uid=kEs5O…
11:49:04.841  ID token force-refreshed uid=kEs5O…           ← ακριβώς 1×
11:49:04.841  listener fired prevVerified=true nextVerified=true
11:49:04.841  cached ID token already reflects emailVerified, skip refresh   ← 2ο fire: skip
```
- Register (unverified): claims-check skip ✅ · `reload()` χωρίς timeout ✅ · 0 errors ✅
- **Sign Out από Settings** (νέο): πλήρες cleanup + redirect `/welcome` ✅
- `flutter analyze lib/main.dart`: clean ✅

### 2) Sign Out στο Settings (για χρήστες χωρίς προφίλ)

**Σκοπός:** Ο χρήστης που δεν έχει δημιουργήσει προφίλ δεν βλέπει το ProfileScreen (που είχε το μοναδικό Sign Out) → δεν μπορούσε να αποσυνδεθεί. Προστέθηκε Sign Out στο Settings πάνω από τη Διαγραφή Λογαριασμού.

**Fix (μόνο `lib/features/settings/screens/settings_screen.dart`, backup `backups/settings_screen_signout_20260814_114543.dart`):**
- **Imports:** `../../../providers/unread_badge_provider.dart` + `../../requests/providers/requests_provider.dart`
- **Μέθοδος `_signOut()`:** ίδιο pattern με profile_screen (confirm dialog → invalidate `incomingRequestsProvider`/`outgoingRequestsProvider`/`unreadBadgeProvider` → `authRepositoryProvider.signOut()` → error handling `auth/sign-out-failed`)
- **ListTile "Αποσύνδεση / Sign Out"** στο block `if (!isAnonymous)`, πάνω από το "Διαγραφή Λογαριασμού" + Divider
- Device-verified: confirm dialog → `SettingsScreen: sign out` → cleanup (`Cleared 2 tokens`, `Presence setOffline`, chat cache) → `SettingsScreen: signed out` → redirect `/welcome` ✅


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 234 — SPoT μεταφορά allowVideoCall/allowDirectChat στο Privacy Editor (100%) — 22 Αυγ 2026

### Σκοπός
Τα toggles «Βιντεοκλήση» / «Άμεσο Chat» υπήρχαν μόνο στο Profile Editor και έγραφαν στο `UserProfileTable`. Το `PrivacySettingsTable` είχε ήδη τα ίδια columns (ορφανά — κανείς δεν τα διάβαζε). Η ρύθμιση «ποιος μπορεί να μου στείλει αίτημα video/chat» είναι θέμα απορρήτου → μεταφορά SPoT στο Privacy Editor.

### Κρίσιμο εύρημα πριν την υλοποίηση
Το `publish()` διάβαζε `profile.allowVideoCall/allowDirectChat` από UserProfileTable — απλή προσθήκη toggles δεμένων στο PrivacySettings θα δημιουργούσε dead UI (αποθηκευόταν τοπικά, δεν έφτανε ποτέ στο public snapshot). Γι' αυτό χρειάστηκε πλήρης μεταφορά SPoT, όχι απλό UI toggle.

### Υλοποίηση (4 αρχεία, υλοποίηση από τον χρήστη, review από AI)

1. **`lib/data/local/database.dart`** — schema v13→**v14**:
   - Migration `from < 14`: `customStatement` UPDATE που αντιγράφει `allow_video_call`/`allow_direct_chat` από `user_profile_table` → `privacy_settings_table` per-uid (scalar subqueries + `WHERE EXISTS` guard). Προστατεύει υπάρχοντες χρήστες από silent reset σε false/false.
   - **try/catch non-fatal**: DML πάνω σε δεδομένα χρήστη· αν αποτύχει δεν πρέπει να μπλοκάρει το άνοιγμα βάσης/εκκίνηση app (το onUpgrade τρέχει σε transaction). Ίδιο best-effort pattern με το geoPrecision Firestore sync.
   - Trade-off: αν αποτύχει μία φορά ΔΕΝ ξανατρέχει (v14 καταγράφεται) → ο συγκεκριμένος χρήστης χάνει τη ρύθμιση. Mitigation: `DebugConfig.error` (πάντα ορατό).

2. **`lib/repositories/profile_repository_impl.dart`**:
   - `_ensurePrivacySettings(uid, {UserProfileTableData? sourceProfile})` — seeding: νέο row παίρνει τις τιμές του profile αντί για defaults (καλύπτει restore path σε νέα συσκευή).
   - 3 call sites ενημερώθηκαν με `sourceProfile:` (getProfile restore γρ. 137, saveProfile γρ. 181, publish γρ. 327).
   - **SPoT switch στο publish()** (γρ. 354-355): `allowVideoCall: privacy?.allowVideoCall ?? false`, `allowDirectChat: privacy?.allowDirectChat ?? false`.

3. **`lib/features/profile/screens/profile_editor_screen.dart`** — αφαίρεση των 2 FormToggles + state fields (`_allowVideoCall`/`_allowDirectChat`) + dirty checks + import form_toggle. Στο `_save()` pass-through διατήρησης τιμών: `allowVideoCall: _loadedProfile?.allowVideoCall ?? false` (δεν μηδενίζει — το UserProfileTable column μένει ως legacy).

4. **`lib/features/profile/screens/privacy_editor_screen.dart`**:
   - Νέο FormSection «Αιτήματα Επικοινωνίας / Communication Requests» με 2 FormToggles δεμένα στα `_settings.allowVideoCall/allowDirectChat` + DebugConfig.logs.
   - initState fallback defaults: `true/true` → **`false/false`** — ευθυγραμμισμένα με table defaults. Έτσι όλοι οι δρόμοι δημιουργίας row συγκλίνουν (table default = initState fallback = seeding) και δεν εξαρτάται από σειρά πλοήγησης (πρώτα Privacy Editor vs πρώτα publish).

5. **`lib/features/requests/screens/send_request_screen.dart`** — deny-by-default στο UI: `profile?.allowDirectChat ?? true` → `?? false` (και για video). Χωρίς UX flicker: το FutureBuilder δείχνει LoadingView κατά το waiting, άρα το selector αποδίδει ΜΟΝΟ μετά την ολοκλήρωση — το fallback ενεργοποιείται μόνο όταν το public doc είναι πραγματικά null. Πλέον UI = client pre-check (request_repository_impl:62-67) = server rules (firestore.rules:68-69), όλα deny-by-default.

### Συμπεριφορά
- **Νέοι χρήστες**: αιτήματα επικοινωνίας κλειστά by default (privacy-first) — ενεργοποίηση ρητά από Privacy Editor.
- **Υπάρχοντες χρήστες**: migration διατηρεί τις τιμές τους (σχεδόν όλοι έχουν `allowDirectChat=true` από το παλιό ProfileEditor default).
- Ανεπηρέαστα: firestore.rules, search filters, saved searches, help_request_config (όλα διαβάζουν το public snapshot που πλέον γεμίζει από το σωστό SPoT).
- **ΔΕΝ χρειάστηκε build_runner** (καμία αλλαγή σε columns — μόνο data migration).

### Παραλείψεις / εκκρεμότητες
- ❌ Δεν έγιναν backups για τα 4 edited αρχεία πριν τις αλλαγές (παραβίαση κανόνα — επισημάνθηκε).
- ⏳ Device tests: (1) migration log `Migration v13->v14` σε update υπάρχοντος account, (2) toggle off → Apply → άλλη συσκευή δεν μπορεί να στείλει αίτημα, (3) restore path → log `seeded allowVideoCall=...`.

### Έλεγχος
- `flutter analyze`: clean ✅ (full project + targeted σε database.dart, privacy_editor_screen.dart, send_request_screen.dart)


---

## Session 235 — Μετάβαση nearme-eu/eur3 (ολοκλήρωση) + δικτυακή διάγνωση IPv6 + αμυντικά fixes (100%) — 23 Αυγ 2026

### Μέρος 1: Ολοκλήρωση μεταβάσης Firebase project (22-23 Αυγ)
nearme-gr (nam5, US multi-region) → **nearme-eu** (**eur3**, EU multi-region). Αλλαγές:
- `.firebaserc`: `default: nearme-eu`, παλιό project ως alias `old-nam5`
- `android/app/google-services.json`: νέο project (`project_id: nearme-eu`)
- `functions/src/index.ts`: +`const REGION = 'europe-west1'` + `.region(REGION)` και στις **12 functions**
- Client `httpsCallable` κλήσεις: `FirebaseFunctions.instanceFor(region: 'europe-west1')` ×3 — search_provider.dart:164 (checkSearchRateLimit), auth_repository_impl.dart:65 (deleteUserData), profile_repository_impl.dart (computeGeoHash). Κανόνας: ποτέ default instance
- Νέα UIDs (νέα accounts στο νέο project), δεδομένα ξαναφορτώθηκαν
- Επαλήθευση με device tests: login/search/publish OK. Backups `*_pre_eu_migration_20260822_210025` ×7

### Μέρος 2: Δικτυακή διάγνωση — IPv6 blackhole (23 Αυγ)
**Σύμπτωμα:** Ένα WiFi δίκτυο (halohalo) έδειχνε timeouts σε reload/CF (~2s) ενώ τα υπόλοιπα δίκτυα ήταν γρήγορα (TOTAL 854-2590ms).
**Διάγνωση μέσω adb:** ο router διαφημίζει SLAAC IPv6 (prefix `2a02:2149`, Vodafone GR) χωρίς δρομολόγηση → Android προτιμά IPv6 → SYN blackhole (~1-4s) → fallback IPv4. ping IPv4 22ms OK, ping6 100% packet loss.
**Fix στη πηγή:** απενεργοποίηση IPv6 στον router (χρήστης). Re-test: CF 819ms, TOTAL **1149ms** (από 7931ms, **×7 βελτίωση**). Transient CF fail κατά το settling του router = σωστή OFFLINE banner συμπερίφορα (12s auto-recovery).

### Μέρος 3: Αμυντικά fixes δικτύου (3 βήματα, ένα τη φορά)
1. **Offline gate** (`search_provider.dart` `_checkRateLimit()`): fresh `Connectivity().checkConnectivity()` πριν την CF κλήση → offline: error state `'search/no-connectivity'`, μηδενική κλήση/αναμονή. Backup `search_provider_pre_offline_gate_20260823_123122.dart`
2. **Auth timeouts**: helper `_withAuthTimeout<T>` (6s → `AppException('auth/network-error')`) σε 5 μεθόδους auth_repository_impl: signInWithEmailAndPassword, createUserWithEmailAndPassword, signInAnonymously, linkWithEmailAndPassword (κύριο μονοπάτι verify!), sendEmailVerification. Zombie futures consumed: `unawaited(f.then<void>((_) {}, onError: warn))` — ΠΟΤΕ bare `.catchError` (runtime TypeError σε non-nullable T). Επικυρώθηκε με πραγματικό login npit79@gmail.com: 1.82s success, μηδέν regressions (reload 274ms, TOTAL 854ms). Backup `auth_repository_impl_pre_auth_timeout_20260823_131300.dart`
3. **SEARCH-PERF cleanup**: διαγραφή TEMP diagnostics (watchdogs 5s/20s+cfDone, perfSw/perfLog/fetchSw/repoSw) από search_provider.dart / discovery_screen.dart / firestore_search_repository.dart. Διατηρήθηκαν: offline gate, zombie-consumption pattern, timeout+fail-open, operational logs. Διαφορά **−67 γραμμές** (+9/−76). flutter analyze clean. Backups `*_pre_perf_cleanup_20260823_132418` ×3

### Μέρος 4: minInstances απόφαση (Plan B)
Cold start ~2s μία φορά ανά idle window στο checkSearchRateLimit — το fail-open καλύπτει ήδη το χειρότερο (UX polish, όχι correctness fix). **Απόφαση:** καμία αλλαγή τώρα · scale-up item με triggers επανεξέτασης (>30-50 DAU ή συχνοί cold starts στα logs) → τότε `runWith({ minInstances: 1 })` (~$10-14/μήνα gen1 256MB @eur pricing· targeted deploy `--only functions:checkSearchRateLimit`). Σημειώθηκε και στο firestore_cost_optimization.md §9.

### Έλεγχος
- `flutter analyze`: clean ✅ (και στα 3 fixes)
- Device tests: login/search/publish στο halohalo post-fix — TOTAL 854-1149ms, μηδέν σφάλματα

### Παραλείψεις / εκκρεμότητες
- ~~⏳ Git commit των αλλαγών #2/#3 (working tree)~~ → **✅ ΚΛΕΙΣΕ (23 Αυγ):** commits d655e84 / 8056af7 / bd5e9aa
- ~~⏳ Follow-ups: timeout για `sendPasswordResetEmail` & `reloadUser`~~ → **✅ ΚΛΕΙΣΕ (Session 236)**
- Σημείωση: audit_report.md «8 deployed» παραμένει ως ιστορικό snapshot (δεν διορθώθηκε εσκεμμένα)


---

## Session 236 — Auth timeouts ολοκλήρωση (reloadUser/sendPasswordResetEmail) + «Ξέχασες τον κωδικό» στη σελίδα Login + 2 polish fixes (100%) — 23 Αυγ 2026

### 1) Auth timeouts: reloadUser() + sendPasswordResetEmail (κλείσιμο εκκρεμότητας του Session 235)

**Αλλαγή (μόνο `auth_repository_impl.dart`, backup `backups/auth_repository_impl_pre_reload_timeout_20260823_193916.dart`):**
- `reloadUser()`: τοπική μεταβλητή `user` + null check (**διατήρηση σκόπιμης συμπεριφοράς «null user = σιωπηλό no-op»** — όχι throw, minimal change) + wrap με το υπάρχον `_withAuthTimeout` (6s → `AppException('auth/network-error')`)
- `sendPasswordResetEmail()`: απευθείας wrap με `_withAuthTimeout`
- Callers verified **read-only** πριν το edit: `checkVerification` (auth_provider.dart:98/:106 catch→emailSent), `sendPasswordReset` (:121/:124 catch→φιλικό μήνυμα), `checkVerificationSilent` (:132/:137 catch→warn) — όλα graceful ✅
- Εκτός scope `.reload()` κλήσεις που αφέθηκαν συνειδητά: app_router.dart:298 (δικός του `.timeout(6s)`), auth_repository_impl.dart:301/:335 (phone flow — flag OFF από Session 230 / δικό του try-catch)

**Device validation (release + `ENABLE_RELEASE_DEBUG=true`, logs 19:46-19:57):**
| Σενάριο | Αποτέλεσμα |
|---|---|
| Α — reloadUser happy path | ×20+ κύκλοι auto-verify timer (~3s), όλα <1s, μηδέν timeout/warn ✅ |
| Β — sendPasswordResetEmail | άμεση αποστολή + «Στάλθηκε email επαναφοράς», καθαρά logs ✅ |
| Γ — blackhole πραγματικό 6s timeout | παραλείφθηκε ως προαιρετικό (ίδιος μηχανισμός με τις 7 ήδη επικυρωμένες μεθόδους) |
| Δ — offline gate / cold start / sign-out ×3 / login | όλα καθαρά· offline gate μπλοκάρει πριν την κλήση repository ✅ |

**Bonus — πραγματικό σφάλμα δοκίμασε αυθόρμητα το error path (19:55:53):** η επιβεβαίωση του reset link από τον χρήστη ακύρωσε τα tokens (`user-token-expired`, standard Firebase ασφάλεια) → το σφάλμα πέρασε σωστά μέσω του wrapper στον caller (`checkVerificationSilent: failed`) → καθαρό auto sign-out, redirect /welcome, μηδέν crash ✅

### 2) «Ξέχασες τον κωδικό;» — μεταφορά από VerifyAccountScreen στο WelcomeScreen (Login)

**Αιτία:** Το feature ζούσε ΜΟΝΟ στη σελίδα επαλήθευσης (εμφανίζεται μόνο post-registration) → χρήστης που ξέχασε τον κωδικό του δεν είχε κανένα σημείο ανάκτησης από τη σελίδα εισόδου (design gap).

**Αλλαγές (2 αρχεία — κανένα νέο import, καμία νέα λογική):**
- `welcome_screen.dart` (330→388 γρ.): κουμπί «Ξέχασες τον κωδικό;» κάτω από την Είσοδο, ορατό **ΜΟΝΟ σε login mode** · ίδιο dialog με **prefill το email από το πεδίο εισόδου** (`_emailCtrl`) · κλήση της υπάρχουσας `verifyAccountProvider.sendPasswordReset(email)` → connectivity gate + φιλικά σφάλματα + το timeout fix καλύπτονται αυτόματα (μηδέν duplication)
- `verify_account_screen.dart` (345→287 γρ.): αφαίρεση `_showForgotPassword()` dialog (γρ. 88-136) + κουμπιού (γρ. 299-306)· `isLinked` και όλα τα υπόλοιπα ανέπαφα
- `auth_provider.dart`: **ΔΕΝ άλλαξε** — η υπάρχουσα μέθοδος χρησιμοποιείται ως έχει

**Side-effect έλεγχοι πριν το edit:** κανένα import δεν έμενε αχρησιμοποίητο στο verify screen (`DebugConfig`/`AppMessenger`/`ErrorMessages` χρησιμοποιούνται και αλλού) · `sendPasswordResetEmail` δεν εξαρτάται από currentUser (σωστό για logged-out forgot-password) · welcome screen είχε ήδη όλα τα imports ✅

**Έλεγχος:** `flutter analyze` clean ✅ · `flutter test` **30/30** ✅ (γνωστά test-environment artifacts στα encryption tests) · device test χρήστη: **όλα καλά** ✅

### Νέα προαιρετικά polish items → ✅ ΔΙΟΡΘΩΘΗΚΑΝ αμέσως μετά (ίδιο session)

1. **Παραπλανητικό log μήνυμα:** το «late completion after timeout» του `_withAuthTimeout` τυπώνεται και όταν ΔΕΝ έγινε timeout — είναι ο γενικός error-consumer branch που δεν ξέρει αν χτύπησε timeout. Συμπεριφορά σωστή, μήνυμα μόνο παραπλανητικό (cosmetic).
2. **Auto-verify timer μετά sign-out:** σε token-expiry/auto sign-out ο timer της οθόνης επαλήθευσης συνεχίζει κάθε 3s («Reloading user … emailVerified: null») μέχρι να φύγει ο χρήστης από την οθόνη. Προϋπάρχον, no-op με null user, απλά θορυβώδη logs.

### Polish fixes των 2 ευρημάτων (✅ εφαρμογή + device validation)

**Ανάλυση πριν το edit (deep re-check):** Το Dart SDK `.timeout()` έχει εσωτερικό listener που ήδη καταναλώνει late completions (guard `if (timer.isActive)`) → ο error-consumer του `_withAuthTimeout` είναι belt-and-braces telemetry, ΟΧΙ απαραίτητος για αποτροπή unhandled exception (διόρθωσε και το λάθος doc comment) · μηδενική απώλεια diagnostics από τη σιωπηλή κατανάλωση εντός 6s (όλοι οι callers έχουν τα δικά τους catches με `data: e`: auth_provider.dart:98/:121/:132) · το `checkVerificationSilent` καλείται ΜΟΝΟ από τον timer (verify_account_screen:57) · σκόπιμα ΔΕΝ αγγίχτηκαν τα logs μέσα στο `reloadUser()` (με τον guard δεν ξανατυπώνονται μετά sign-out).

1. **Fix 1 — flag `timedOut`** (`auth_repository_impl.dart:190-201`): τοπική μεταβλητή, γίνεται `true` ΜΟΝΟ στο `onTimeout` → ο onError-consumer τυπώνει «late completion after timeout» πλέον ΜΟΝΟ για πραγματικά late completions· σφάλματα εντός 6s καταναλώνονται σιωπηλά. Μηδενική συμπεριφορική αλλαγή — μόνο logging. + Διόρθωση doc comment :182-189 (SDK listener, belt-and-braces πρόθεση).
2. **Fix 2 — guard στον auto-verify timer** (`verify_account_screen.dart` `_startVerifyTimer` ~54-60): στην αρχή κάθε tick `currentUser == null || isAnonymous` → `_verifyTimer?.cancel()` + ένα log `auto-verify stopped (no linked user)` + return. Σκόπιμα ΧΩΡΙΣ `emailVerified` στο guard (stale τοπική τιμή μέχρι `reload()`· τον verified-εντοπισμό τον κάνουν `checkVerificationSilent` + υπάρχον `ref.listen`). Αποτέλεσμα: μετά sign-out/token-expiry το πολύ 1 tick (~3s) αντί για λεπτά θορύβου. `dispose()` παραμένει safety net (cancel idempotent)· `authRepositoryProvider` ήδη χρησιμοποιείται στο αρχείο — μηδέν νέα imports.

**Έλεγχοι:** `flutter analyze` clean ✅ · `flutter test` **30/30** ✅ · Device validation ×2 release runs (22:50 & 22:56): cold start (verified), login ×2, tabs, anonymous browse, sign-out ×2 — μηδέν regressions, μηδέν timeout/warn, μηδέν «Reloading user» spam μετά sign-out ✅. Σημείωση ειλικρίνειας: στα 2 runs ο timer δεν άναψε ποτέ (κανένα VerifyAccountScreen στη ροή) → ο guard ασκήθηκε έμμεσα μόνο· το φυσικό σενάριο token-expiry πάνω στη σελίδα επαλήθευσης (19:55 σήμερα) παραμένει η ρεαλιστική αναπαραγωγή και εκεί ο guard κόβει στο πρώτο tick.

### Εκκρεμότητες
- ⏳ Git commit όλων των αλλαγών αυτού του session (timeout wraps + forgot-password move + 2 polish fixes) — **τον κάνει ο ίδιος ο χρήστης** (απόφαση 23 Αυγ: ο assistant δεν ασχολείται ποτέ με commits)
- ⏳ collectionGroup scraping (εκκρεμότητα #1 — App Check + server-side rate limit)


---

## Session 237 — Crashlytics: διόρθωση σπασμένου setup + πλήρης ενεργοποίηση end-to-end (100%) — 24 Αυγ 2026

### Σκοπός
Βήμα-βήμα έλεγχος ολόκληρης της αλυσίδας Crashlytics (dependencies → Gradle → google-services.json → main.dart init → Console → test crash) με αρχή «ότι υπάρχει να ελεγχθεί ότι είναι σωστό, ότι είναι λάθος να διορθωθεί, ότι δεν υπάρχει να προστεθεί».

### 🔴 Κρίσιμο εύρημα: το Android build ήταν ΣΠΑΣΜΕΝΟ από το πρωί
Το commit `f6804d6` («Crashlytics ok», 24 Αυγ 15:48) πρόσθεσε το plugin στο app-level (`app/build.gradle.kts:6`) αλλά **ΞΕΧΑΣΕ** τη δήλωση version στο settings-level. Επιβεβαίωση με `.\gradlew.bat :app:help`: `Plugin [id: 'com.google.firebase.crashlytics'] was not found ... BUILD FAILED`.
**Γιατί δεν φάνηκε:** τελευταίο επιτυχές build = χθες 23/8 10:50 (πριν το commit) · κανένα build μετά τις αλλαγές. Το μήνυμα «ok» ήταν ελπιδοφόρο, όχι επαληθευμένο.

### Διορθώσεις / προσθήκες (ένα αρχείο τη φορά, backup πριν κάθε edit)

1. **`android/settings.gradle.kts`** (+1 γραμμή) — η κρίσιμη διόρθωση:
   - `id("com.google.firebase.crashlytics") version "3.0.7" apply false` (3.0.7 = τελευταία σταθερή, 9 Απρ 2026· απαιτεί Gradle ≥8, AGP ≥8.1, google-services ≥4.4.1 — όλα OK: Gradle 9.1 / AGP 9.0.1 / GS 4.4.2)
   - Επαλήθευση: `gradlew :app:help` → **BUILD SUCCESSFUL** (η πρώτη εκτέλεση θέλει online για download· με `--offline` αποτυγχάνει μέχρι να κατέβει μία φορά)
   - Backup: `backups/crashlytics_fix_20260824_160843/`
2. **`lib/main.dart`** (+1 import, +5 γραμμές) — το μοναδικό πραγματικό κενό του init:
   ```dart
   PlatformDispatcher.instance.onError = (error, stack) {
     DebugConfig.error('main: uncaught async error',data: error, exception: stack);
     FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
     return true;
   };
   ```
   Official FlutterFire pattern (Context7-verified) — χωρίς αυτό τα uncaught async errors δεν έφταναν ΠΟΤΕ στο Crashlytics (το `FlutterError.onError` πιάνει μόνο framework errors). Το `DebugConfig.error` ακολουθεί SPoT convention (αλλιώς τα errors «χανόντουσαν» σιωπηλά στο debug console). Import pattern `dart:ui show PlatformDispatcher` ίδιο με profile_repository_impl.dart.
   **Έλεγχοι που ζήτησε ο χρήστης:** μηδέν διπλές δουλειές — το δεύτερο `Firebase.initializeApp()` (στο `FirebaseInit.tryInitialize`) είναι cached/idempotent, μηδέν νέο άνοιγμα βάσης (το DatabaseService.tryInit ανέγγιχτο).
   - Backup: `backups/crashlytics_fix_20260824_162137/`
3. **`settings_screen.dart`** (προσωρινό) — debug-only test section (`if (DebugConfig.debugMode)`): non-fatal `recordError(StateError(...), StackTrace.current, reason:)` + fatal `.crash()`. Backup: `backups/crashlytics_fix_20260824_163613/`
4. **`main.dart`** (auth listener) — User ID + custom keys:
   - `setCustomKey('isAnonymous'/'emailVerified', ...)` σε ΚΑΘΕ auth emission (φρεσκάρισμα emailVerified)
   - `setUserIdentifier(nextUser?.uid ?? '')` ΜΟΝΟ σε uidChanged ('' στο sign-out καθαρίζει — ο επόμενος χρήστης δεν κληρονομεί ID)
   - Privacy: ΠΟΤΕ email/phone/nickname σε keys· UID επιτρέπεται (η Google το γνωρίζει ήδη από Auth — GDPR αναφορά στο privacy policy)
   - Backup: `backups/crashlytics_userid_20260824_170548/`
5. **Αφαίρεση test section** (μετά την επιβεβαίωση) — backup: `backups/crashlytics_cleanup_20260824_170424/`

### ✅ End-to-end επιβεβαίωση (device, release + ENABLE_RELEASE_DEBUG)
- Fatal: `FirebaseCrashlyticsTestCrash` έφτασε με αποκωδικοποιημένο trace (r8 mapping upload δούλεψε αυτόματα από το Gradle plugin)
- Non-fatal: `Bad state: Test non-fatal error (verification)` με file:line του onTap
- Crash-free sessions 33.33% = μαθηματικό των λίγων δοκιμαστικών sessions (φυσιολογικό)
- Σημείωση UX: το crash μοιάζει με «πήγε background» — process death χωρίς animation· επιβεβαίωση με cold start (splash ξανά)

### Τι υπήρχε ήδη σωστό (ελέγθηκε, καμία αλλαγή)
pubspec.yaml ^5.2.3 = lock 5.2.3 ✅ · Gradle plugin application line ✅ · native deps block ✅ (βλ. εκκρεμότητα) · google-services.json: project_id nearme-eu, package_name ταιριάζει με applicationId ✅ · `setCrashlyticsCollectionEnabled(true)` + `FlutterError.onError` ✅

### Έλεγχος
- `flutter analyze`: clean ✅ (μετά από ΚΑΘΕ edit)
- SPoT audit πριν την υλοποίηση: κανένας υπάρχον Crashlytics wrapper (καμία διπλοδουλιά)· ErrorMessages άσχετο (UI-only)· DebugConfig.error signature `error(msg, data:, exception:)` όπως main.dart:479

### Εκκρεμότητες
- ⏳ **Consent-gating**: το `setCrashlyticsCollectionEnabled(true)` είναι hardcoded (αγνοεί ConsentLog) — GDPR απόφαση όταν αποφασιστεί πολιτική consent
- ⏳ **Redundant native deps** στο `app/build.gradle.kts` (BOM 33.12.0 + firebase-analytics + firebase-crashlytics): FlutterFire docs ΔΕΝ τα απαιτούν (το plugin φέρνει τα native SDKs μόνο του) — αξιολόγηση/αφαίρεση σε επόμενο session
- ⏳ Git commit (τον κάνει ο χρήστης — απόφαση 23 Αυγ)


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 238 — Crashlytics consent-gating GDPR (toggle στις Ρυθμίσεις) — υλοποίηση 9 βημάτων + επαλήθευση πλήρης + ενισχύσεις 2ου γύρου (~95%) — 24 Αυγ 2026

### Σκοπός
GDPR consent-gating του Crashlytics: η συλλογή crash reports OFF by default, ενεργοποιείται ΜΟΝΟ με ρητό toggle του χρήστη στις Ρυθμίσεις (section «Διαγνωστικά»), με εγγραφή στο ConsentLog και πλήρη διαφάνεια.

### 🔍 Δύο γύροι επανέλεγχου πριν την υλοποίηση (απαίτηση χρήστη)
**Γύρος 1 — υπάρχουσες λειτουργίες προς επαναχρησιμοποίηση (4 ευρήματα):**
1. **`AppDatabase.logConsent()` helper ΥΠΑΡΧΕ** (database.dart:194-208: `logConsent(uid, action, dataType, {details})`) — η αρχική πρόταση έλεγε raw insert pattern από chat_repository_impl → ΔΙΟΡΘΩΣΗ: χρήση helper (SPoT). Παρατήρηση εκτός scope: request/chat repos παρακάμπτουν το helper· διπλά keys στο ConsentActionConfig (`published`/`publish`)
2. **Official opt-in pattern = NATIVE**: AndroidManifest meta-data `firebase_crashlytics_collection_enabled=false` + runtime enable (FlutterFire docs «Enable opt-in reporting») → συλλογή OFF από process start, κλείνει το παράθυρο μέχρι τη γραμμή 36 του main.dart
3. **Queued reports συμπεριφορά VERIFIED (docs, όχι υπόθεση)**: με collection OFF τα crashes αποθηκεύονται τοπικά και στέλνονται ΑΥΤΟΜΑΤΑ με την επόμενη ενεργοποίηση
4. **Re-enable θέλει identifier sync**: το auth listener δεν ξανατρέχει χωρίς auth αλλαγή

**Γύρος 2 — συνολική επαναξιολόγηση (9 έλεγχοι ✅ + 2 διορθώσεις):**
- ✅ Manifest tag όνομα/θέση · column style 1:1 · κανένα raw SQL στο app_settings_table · μηδέν tests σε Crashlytics/AppSettings · cross-import authStateProvider καθιερωμένο (settings_screen.dart:14) · router global redirect → στον /settings ο χρήστης ΠΑΝΤΑ logged-in · clearAllTables σβήνει settings+consent (συνεπές) · settings_screen <500 γραμμές · hook point main.dart:515 επιβεβαιωμένος
- **Δ1**: uid στο logConsent = `FirebaseAuth.instance.currentUser?.uid ?? ''` ΟΧΙ στατικό `''` — το consent_log_provider.dart:35 φιλτράρει `uid.equals(currentUser.uid)` → στατικό '' θα ήταν ΑΟΡΑΤΟ στο Consent History
- **Δ2**: revoke → `setUserIdentifier('')` άμεσα (defense-in-depth)
- **Ρίσκο #1**: διαγραφή migration chain + ξεχασμένο παλιό install → missing column → settings load error → cascade: ScreenProtector & startup lock μένουν σιωπηλά OFF. Χρήστης διάλεξε **3-γραμμη guard** `if (from < 15)` αντί για διαγραφή chain. Μηδενισμός έκδοσης σε 0/1 απορρίφθηκε (κανένα όφελος σε fresh install, ρίσκο σε stale installs)

### Υλοποίηση — 9 βήματα (ένα ανά φορά, backup πριν κάθε edit)
1. **AndroidManifest.xml** (+meta-data lines 61-63): `firebase_crashlytics_collection_enabled=false` μέσα στο `<application>` — native default OFF
2. **app_settings_table.dart** (+2 γραμμές): `BoolColumn crashReportsEnabled` default **false** (privacy-safe)
3. **database.dart**: schemaVersion 14→**15** + guard `if (from < 15) m.addColumn(appSettingsTable, appSettingsTable.crashReportsEnabled)` στο τέλος του chain (το chain ΚΡΑΤΗΘΗΚΕ ολόκληρο)
4. **build_runner**: 333 outputs, 55s
5. **app_settings_provider.dart**: `_createDefaults`+field · νέα `setCrashReports(bool)` στο ακριβές σχήμα setScreenshotPrevention: guards (no-state/unchanged — προλαβαίνει διπλά ConsentLog entries σε rapid taps) → DB write try/catch early-return (σε αποτυχία runtime flag ΔΕΝ αλλάζει) → side-effects: setCrashlyticsCollectionEnabled → logConsent(currentUser?.uid ?? '', 'crash_reports_enabled/disabled', 'diagnostics', δίγλωσσο details) → enable: setUserIdentifier+setCustomKey sync από authStateProvider / disable: setUserIdentifier(''). Imports: +firebase_auth +firebase_crashlytics +auth_provider (~250 γραμμές σύνολο)
6. **main.dart**: αφαίρεση hardcoded `setCrashlyticsCollectionEnabled(true)` (πρώην γραμμή 36, comment ενημερώθηκε) · auth listener gated πίσω από `crashConsent` read (uid-change log βγήκε ΕΞΩ από το gate ώστε να συνεχίζει πάντα) · νέο `_applyCrashConsent(bool)` try/catch (ΟΧΙ catchError — κανόνας AGENTS.md) · first-load block (`p==null && n!=null`) +κλήση — εφαρμόζει την τιμή και στα δύο directions (native flag επιμένει across launches, Drift μένει SPoT). ⚠️ main.dart τώρα 656 γραμμές (>500, ήδη exception area — refactoring μελλοντικά με έγκριση χρήστη)
7. **settings_screen.dart**: νέο `_SectionHeader 'Διαγνωστικά/Diagnostics'` + `_DiagnosticsSection` μετά την Ασφάλεια Συσκευής — **ορατό και σε anonymous** (consent ανά συσκευή) · ίδιο pattern με _DeviceSecuritySection (when/Padding/SwitchListTile, bug_report_outlined) · biometric variant (await + context.mounted) · subtitle GDPR: «Με επανενεργοποίηση στέλνονται και όσα αποθηκεύτηκαν τοπικά.» (468 γραμμές)
8. **error_messages.dart**: +`settings/crash-reports-on/-off` δίγλωσσα
9. **consent_action_config.dart**: +`crash_reports_enabled` (bug_report, primary) / `crash_reports_disabled` (bug_report_outlined, warning)

### ✅ Device επαλήθευση (release build, NFT8KF4LD6XWOF7D, PID 18808)
- **Migration guard πέτυχε σε ΠΑΛΙΟ install** (χωρίς clean install!): `Migration v14->v15: added crashReportsEnabled column to AppSettingsTable`
- Cold start: `main: Crashlytics collection=false (saved consent)` — default OFF σωστά
- Toggle ON: πλήρης ακολουθία uiInteraction→serviceCall→collection=true→consent logged→identifier synced→snackbar ✅
- Toggle OFF: collection=false→consent logged→**identifier cleared** ✅
- **Φάση Α** (`adb shell am crash`, consent OFF): reopen → Console ΚΑΜΙΑ νέα καταχώρηση ✅
- **Φάση Β** (toggle ON, am crash): Console **2→4** = +1 νέο crash +1 queued της Φάσης Α — η τεκμηριωμένη συμπεριφορά «local storage → auto-send on re-enable» επιβεβαιωμένη στην πράξη ✅
- **Φάση Γ** (ξανά OFF, am crash #3): Console **ΜΕΙΝΕ στο 4** — μετά από ανάκληση η προστασία ισχύει ξανά, τίποτα δεν φεύγει ✅ → **πλήρης κύκλος GDPR επαληθευμένος**

### Ενισχύσεις 2ου γύρου (μετά τις Φάσεις Α-Γ)
1. **Consent History ομαδοποίηση**: οι νέες εγγραφές εμφανίζονταν μόνο στο «Όλες» — το `_actionFilters` του consent_log_screen.dart:22 είναι hardcoded. Διόρθωση: ψευδο-φίλτρο ομάδας `'crash_reports'` + entry στο ConsentActionConfig (chip «Αναφορές Σφαλμάτων», primary, bug_report_outlined — label/χρώμα από τα ΙΔΙΑ unified paths με τα άλλα chips) · λογική: `startsWith('crash_reports')` ταιριάζει και τις δύο ενέργειες · +case `'diagnostics'` στο `_dataTypeLabel()` («Δεδομένα: Διαγνωστικά» αντί raw 'diagnostics'). Backups: `consenthist_screen_20260824_184801`, `consenthist_config_20260824_184801`
2. **GDPR cleanup με `deleteUnsentReports()`** (αίτημα χρήστη: «αν δεν θέλει να στέλνει, δεν πρέπει να καθαρίζονται τα τοπικά;» — σωστός): provider `setCrashReports(false)` → +deleteUnsentReports() μετά τον identifier clear · main.dart `_applyCrashConsent(false)` → +deleteUnsentReports() σε ΚΑΘΕ cold start χωρίς consent (crashes που γράφτηκαν ενώ ήταν κλειστό σβήνονται στο επόμενο άνοιγμα). **Νέος κανόνας:** χωρίς συγκατάθεση κανένα δεδομένο δεν επιβιώνει πέρα από την τρέχουσα συνεδρία. Συνέπεια: το παλιό subtitle («με επανενεργοποίηση στέλνονται και όσα αποθηκεύτηκαν») πάψει να ισχύει — νέο: «Όταν είναι ανενεργό, όποιες αναφορές έχουν αποθηκευτεί τοπικά διαγράφονται.» (queued crashes της Φάσης Γ ΘΑ ΣΒΗΣΤΟΥΝ, δεν θα σταλούν ποτέ). Backups: `crashdelete_*_20260824_185732`

### Έλεγχοι
- `flutter analyze`: clean ✅ μετά από ΚΑΘΕ βήμα (τα προσωρινά expected errors μεταξύ βημάτων 2-5 κανονικά)
- adb σημείωση: `$pid` είναι read-only στην PowerShell 5.1 (χρήση άλλου ονόματος μεταβλητής) · multi-device: target πάντα με `-s <serial>`

### Εκκρεμότητες
- ⏳ Device επαλήθευση 2ου γύρου ενισχύσεων (θέλει νέο build/reinstall): νέο subtitle · chip «Αναφορές Σφαλμάτων» στο Ιστορικό · log `Crashlytics unsent reports deleted (no consent)` στο cold start με OFF
- ⏳ Restart persistence check (ρύθμιση παραμένει) — μπορεί να συνδυαστεί με το παραπάνω rebuild
- 📌 iOS follow-up: Info.plist `FirebaseCrashlyticsCollectionEnabled=false` όταν πάμε iOS builds
- ⏳ Redundant native deps στο app/build.gradle.kts (από Session 237)
- ⏳ Git commit (τον κάνει ο χρήστης — απόφαση 23 Αυγ)
- 📌 Pre-existing WARN `streamPublicProfile: empty uid` (18:18:40, πρώτο creation με κενό uid) — εκτός θέματος, μελλοντικό cleanup


### `flutter analyze`: clean ✅ (0 issues, τελική κατάσταση)

---

## Session 239 — Crashlytics Selective Forwarding (DebugConfig.error → non-fatal) + FirebaseInit idempotency + Production Build Verification — 24-26 Αυγ 2026

### Μέρος Α — FirebaseInit idempotency (user edit, review + polish)
- User πρόσθεσε μόνος του guard `if (Firebase.apps.isNotEmpty) return true;` στο `tryInitialize()` (`firebase_init.dart:6-10`) μετά από εξωτερική ανάλυση περί `[core/duplicate-app]` → splash stuck
- **Διόρθωση premise:** σε Android/iOS το default-app init είναι ήδη idempotent (αποδείχθηκε από device logs της ίδιας μέρας: FcmService/AppRouter έτρεξαν κανονικά)· το duplicate-app exception αφορά **web builds** και named apps. Το guard είναι σωστό/πολύτιμο γιατί το project targetάρει web
- main.dart σχόλιο ενημερώθηκε ώστε να τεκμηριώνει τον μηχανισμό («καλείται και αλλού αλλά δεν πειράζει» → αναφορά στο guard + web-only κίνδυνο)
- Backup πραγματικού πρωτοτύπου από αρχικό commit `574b855` (το HEAD είχε ήδη τις αλλαγές του user): `backups/firebaseinit_pre_idempotent_20260824_192817/` · backup main.dart pre-commentfix ίδιο ts

### Μέρος Β — Design: επιλεκτική προώθηση caught errors στο Crashlytics (3 γύροι)
**Πρόβλημα:** η `DebugConfig.error()` (206 κλήσεις σε lib/) είχε `if (!debugMode) return;` → σε release κανένα caught error (repos/services = πλειοψηφία production issues) δεν έφτανε στο Crashlytics. Μόνο τα 2 handlers του main κάλυπταν fatal/uncaught.

**Ευρήματα που διαμόρφωσαν την τελική λύση (όλα επαληθευμένα στον κώδικα):**
1. **AppException υπάρχει ήδη** (`core/utils/app_exception.dart`, 24 αρχεία/~198 χρήσεις): δομημένο μοντέλο message/code/originalError/**stackTrace** με domain constructors — στα κρίσιμα catches το stack υπάρχει ήδη, απλά περνάμε στη νέα παράμετρο. ΔΕΝ έγινε type-detection μέσα στο DebugConfig → αποφυγή κυκλικού import (app_exception imports debug_config)
2. **Μικτές συμβάσεις params** στα 206 sites: `data: e` (κυρίαρχη στα repos), `exception: e` (objects), `exception: s/st` (stacks) → precedence rule: ex = (exception!=null && is!StackTrace) ? exception : (data ?? StateError(message)) · st = stack ?? (exception if StackTrace)
3. **rethrow pattern** (`catch(e){log; rethrow;}`) → κανόνας «ένα forward ανά αλυσίδα», μόνο κατώτατο επίπεδο
4. **ΚΡΙΣΙΜΟ platform support**: Crashlytics plugin = Android/iOS/macOS ΜΟΝΟ (επίσημα docs) — χωρίς guard, κάθε instrumented site σε web/Windows/Linux θα πετούσε MissingPluginException μέσα στα catch blocks
5. `printDetails ??= kDebugMode` επιβεβαιωμένο από πηγή εγκατεστημένου firebase_crashlytics-5.2.3 → release console καθαρό χωρίς extra param

**Αποφάσεις user:** παρτίδα 1 ΝΑΙ · `crashlyticsForwardInDebug` flag (default false) NAI · main.dart hardening NAI

### Υλοποίηση — 3 βήματα
1. **debug_config.dart**: import crashlytics ξανά (χάθηκε στο revert) + flag `crashlyticsForwardInDebug=false` + `error()` upgrade: νέες παράμετροι `stack`/`reportToCrashlytics` (default false = μηδενική αλλαγή στα υπάοντα sites), debug-flag gate, platform allow-list guard (kIsWeb + android/iOS/macOS — widget tests σε desktop host αποκλείονται αυτόματα), precedence mapping, `unawaited(recordError(..., reason:, fatal:false))`. Backup `debugconfig_step1_forward_20260824_200310`
2. **Enstrumentation 10 sites** (μόνο κατώτατο επίπεδο, `(e,s)` + `stack:`+flag):
   - auth_repository_impl: deleteAccount · sendPhoneOtp
   - chat_repository_impl: sendMessage · sendMediaMessage
   - chat_repository_message_actions: editMessage · deleteMessage
   - storage_service: uploadAvatar · uploadPhoto (legacy shape, precedence χειρίζεται)
   - fcm_service: save-token τελική αποτυχία (**νέο lastError/lastStack capture** στον retry loop) · clear tokens
   - Εξαιρέθηκαν τεκμηριωμένα: reads (getChats/fetchOlderMessages/search), markAsRead/reactions (εκτός scope), `_syncChatFromFirestore` (chatId PII στο μήνυμα + stream-repeat risk), consent-log best-effort, firestore_service (κανένα site — errors φτάνουν στα repos). Backups `step2_*_20260824_200730` ×6
3. **main.dart hardening (pre-existing latent bug)**: `crashlyticsSupported` bool (!kIsWeb && android/iOS/macOS) γύρω και από τα ΔΥΟ handlers (FlutterError.onError + recordError fatal) — μέχρι τώρα unconditional. +import foundation, −περιττό `dart:ui show PlatformDispatcher`. Backup `step2_main_20260824_200730`

### GDPR/Consent συμβατότητα (μηδέν νέος κώδικας)
Collection OFF → SDK τοπική αποθήκευση → purge στο επόμενο cold start από το υφιστάμενο `deleteUnsentReports()` (_applyCrashConsent false-path) · ON → κανονικό upload. Το collection flag παραμένει το ενιαίο consent gate (SPoT).

### ⚠️ ΚΡΙΣΙΜΟ BUG & FIX (26 Αυγ 2026) — forwarding νεκρό σε production
**Εύρημα (εξωτερικό review):** η `error()` είχε `if (!debugMode) return;` στην κορυφή — σε πραγματικό production release (χωρίς dart-define) το debugMode=false → early return ΠΡΙΝ τη λογική forward → **κανένα από τα 10 sites δεν θα προωθούσε ποτέ**, ό,τι consent κι αν έχει ο χρήστης. Το ίδιο bug που ήρθε να λύσει το feature, επανεμφανίστηκε επειδή η νέα λογική κρεμόταν από το ίδιο master switch.

**Γιατί διέφυγε:** όλες οι device επαληθεύσεις έγιναν με `--dart-define=ENABLE_RELEASE_DEBUG=true` → debugMode=true → μάσκαρε πλήρως το bug. Οι αναφερόμενες παραπάνω «επαληθεύσεις» ισχύουν ΜΟΝΟ για dev-flag builds, ΟΧΙ για production.

**Fix (26 Αυγ, έκδοση κώδικα του user):** διαχωρισμός ανησυχιών — το print τυλίχθηκε σε `if (debugMode) { ... }` (χωρίς early return), το forward πλέον gated ΜΟΝΟ από: reportToCrashlytics (ανά site) + crashlyticsForwardInDebug (kDebugMode builds μόνο) + platform allow-list. Doc-header διορθώθηκε. **Νέα matrix:** production release = σιωπηλό console + ενεργό forward ✅ · release+dev-flag = print+forward ✅ · debug build flag=false = print χωρίς forward ✅

**Observability (+1 γραμμή):** `DebugConfig.log(DebugConfig.serviceError, 'Crashlytics forward: $message')` μέσα στο forward block — **επανάχρηση του νεκρού serviceError flag** — κάνει κάθε forward ορατό στο logcat των test builds.

Backups: `backups/debugconfig_prefix_earlyreturn_20260826_110004/` · `backups/debugconfig_forwardlog_20260826_104523/`

### Device Verification — Release Build + Dev-Flag (26 Αυγ 2026)
Build: `flutter build apk --release --dart-define=ENABLE_RELEASE_DEBUG=true` (dev-flag = debugMode=true, print logs visible)
Device: NFT8KF4LD6XWOF7D · Χρόνος run: ~12:30-12:37

**Δύο cold starts, ορισμός consent ON (mid-session toggle)**

| Έλεγχος | Αποτέλεσμα |
|---|---|
| Cold start ×2 — baseline | ✅ Καθαρό, καμία νέα σφάλματος γραμμή, μηδέν MissingPluginException |
| GDPR purge ×2 | ✅ `Crashlytics unsent reports deleted (no consent)` |
| Consent gating OFF | ✅ `collection=false (saved consent)` |
| Toggle ON offline | ✅ `collection=true` → `consent logged crashReports=true` → **identifier synced uid=...** |
| Offline guards (provider level) | ✅ `_performSearch: no connectivity` · send attempts while OFFLINE **blocked at provider** — δεν έφτασαν ποτέ στα repos |
| Regression μετά επαναφορά δικτύου | ✅ text + photo send επιτυχείς, μηδέν `[ERROR]` σε ΟΛΟ το session |
| Mid-flight trigger | ❌ **ΑΠΕΤΥΧΕ** — οι αποστολές έγιναν ΟΛΕ online (post-recovery), δεν προληφθηκε network cut |

**Αποτέλεσμα:** zero side effects επιβεβαιωμένα · zero forwards triggered (λογικό: κανένα instrumented failure δεν συνέβη)

### Εκκρεμότητες
- ⏳ Phase Γ: consent OFF → trigger → τίποτα Console + cold start purge
- ⏳ Phase Ζ: true production build (χωρίς dart-define) → silent logcat + Console +1 non-fatal issue
- ⏳ Όλες οι εκκρεμότητες του Session 238 (iOS Info.plist, redundant deps, restart persistence, 2ου γύρου device check)


### `flutter analyze`: clean ✅ (0 issues, τελική κατάσταση)

---

## Session 240 — Firebase Storage Upload Timeout: Future.timeout() εγκατάλειψη + Timer+Completer λύση (100%) — 26 Αυγ 2026

### Σκοπός
Προσθήκη upload timeout στα Firebase Storage uploads για αποφυγή infinite spinner όταν χάνεται το δίκτυο μέσα σε upload.

### Το πρόβλημα
`storageRef.putFile()` / `putData()` δεν έχουν ενσωματωμένο timeout. Όταν κόβεται το δίκτυο μέσα σε upload, το `await` κολλάει επ' αόριστον (spinner stuck) μέχρι να επανέλθει το δίκτυο. Στη συνέχεια, το upload συνεχίζει και ολοκληρώνεται (native Firebase SDK κάνει auto-resume).

### Εύρημα: `Future.timeout()` ΔΕΝ δουλεύει σε `UploadTask`
Η πρώτη υλοποίηση χρησιμοποιούσε `task.timeout(Duration(seconds: X))` — η οποία δεν έπιασε ΠΟΤΕ. Αποδείχθηκε με device test: `StorageHelpers: upload TIMEOUT` log ΑΠΟΥΣΙΑΖΕ παρόλο που ο χρόνος είχε υπερβεί (120δεπ). Αντ' αυτού: ο spinner έκανε spin για 5+ λεπτά, και μόλις επέστρεψε το δίκτυο, το upload ολοκληρώθηκε.

**Αιτία:** Ο `UploadTask` του Firebase Storage υλοποιεί το `Future` interface μέσω internal stream-based mechanism. Το `Future.timeout()` δεν μπορεί να διακόψει τον υποκείμενο stream — ο Timer πυροδοτείται, αλλά ο Completer του `Future.timeout` δεν ολοκληρώνεται ποτέ γιατί η stream παραμένει ανοιχτή.

### Η λύση: `Timer` + `Completer` + `task.cancel()`

**Σχεδιασμός (2 γύροι review + τελικό correctness audit):**
- `Timer` ξεχωριστός + `Completer<TaskSnapshot>` — ο timer κάνει `task.cancel()` χειροκίνητα
- `task.then()` / `task.onError` για ολοκλήρωση του completer + ακύρωση timer
- Ασφάλεια: `completer.isCompleted` guard σε όλα τα paths (timer και task completion μπορούν να συγκρουστούν)
- `task.cancel().catchError((_) => false)` — cancel μπορεί να αποτύχει (ήδη ολοκληρωμένο upload)

**Υλοποίηση:**
- `lib/core/utils/storage_helpers.dart` (νέο αρχείο):
  - `uploadBytesWithTimeout()` — `putData()` + `Future.timeout()` (μεταφέρθηκε από προηγούμενο session)
  - `uploadFileWithTimeout()` — `UploadTask` + `Timer` + `Completer` (νέο pattern)
  - `_awaitTaskWithTimeout()` — shared helper (Timer+Completer+task.then)
  - `downloadUrlWithTimeout()` — `getDownloadURL()` + `Future.timeout()` (αυτό δουλεύει, κανονικό Future)
- `lib/data/remote/storage_service.dart` — uploadAvatar/uploadPhoto χρησιμοποιούν `StorageHelpers`
- `lib/repositories/chat_repository_impl.dart` — image+audio+thumbnail μέσω `StorageHelpers`, video μέσω `StorageHelpers.uploadFileWithTimeout`
- `lib/repositories/group_chat_mixin.dart` — updateGroupAvatar χρησιμοποιεί `StorageHelpers`

### ✅ Device επαλήθευση — Video upload + network cut (release build + dev-flag)
```
13:54:46.558  StorageHelpers: upload chat_media/.../<id>.mp4 timeout=120s  ← νέος κώδικας ενεργός
13:56:46.475  StorageHelpers: upload TIMEOUT ... after 120s              ← Timer πυροδοτήθηκε ✅
13:56:46.477  sendMediaMessage failed | data: TimeoutException
13:56:46.485  AppException(firestore_error): Firestore error during send_media
13:56:47.480  Crashlytics forward: sendMediaMessage failed               ← forwarding ενεργό ✅
```
- Timeout ακριβώς 120δεπ από το `task.cancel()` — **Timer+Completer δουλεύει** ✅
- Spinner σταμάτησε αμέσως (AppException → ChatActionState.error) ✅
- Error forwarding σε Crashlytics ✅
- Μικρό note: error code `firestore_error` αντί `storage_error` στο catch block (γρ. 946)

### Μείωση timeouts (με έγκριση user)
| Τι | Πριν | Τώρα |
|---|---|---|
| Image (`putData`) | 30s | **15s** |
| Audio (`putData`) | 30s | **15s** |
| Thumbnail (`putData`) | 15s | **10s** |
| Video (`putFile` Timer) | 120s | **30s** |
| Download URL | 10s | 10s (ίδιο) |

### `flutter analyze`: clean ✅ (0 issues)


---

## Session 241 — ApplicationId Migration `com.example.near_me` → `gr.nearme.app` (100%) — 26 Αυγ 2026

### Σκοπός
Διόρθωση B1 hard blocker: placeholder `com.example.*` απορρίπτεται από Play/App Store. Μόνιμο reverse-domain `gr.nearme.app` (GR signal, ταιριάζει `nearme-eu`). App σε ανάπτυξη, μόνο test users, καμία δημοσίευση — 0 production risk.

### Προετοιμασία (2 γύροι review + Windows constraint)
- **Επανέλεγχος SPoT:** 9 ανεξάρτητες πηγές για ίδιο ID (gradle, pbxproj, json, xcconfig, CMake, rc) — καμία single source (Flutter template). Συγχρονισμός όλων.
- **Τι ΔΕΝ επηρεάζεται:** `pubspec.yaml:1` `name: near_me` (Dart imports), `lib/**` 0 hits (MethodChannel `near_me/...` ≠ bundle), `.firebaserc`/`firebase.json`/`l10n.dart`/`debug_config.dart`/`error_messages.dart`.
- **Windows constraint:** iOS/macOS edits χωρίς `xcodebuild` compile — extra file-level verification via `Select-String`/`Get-Content`.

### Υλοποίηση — 12 αρχεία + 1 μετακίνηση (2 φάσεις, backups πριν κάθε edit)

**Φάση 1 — Android (επαληθεύσιμο σε Windows):**
- `android/app/build.gradle.kts:10` `namespace` → `gr.nearme.app`
- `android/app/build.gradle.kts:20-21` διαγραφή TODO + `applicationId` → `gr.nearme.app`
- `android/app/src/main/kotlin/gr/nearme/app/MainActivity.kt:1` `package gr.nearme.app` + μετακίνηση φακέλου `com/example/near_me` → `gr/nearme/app` (old deleted)
- `android/build.gradle.kts:57` template → `gr.nearme.app.${project.name...}`
- `android/app/google-services.json:12,31` — Firebase Console Add Android app `gr.nearme.app` → JSON με 2 clients (old `com.example` + new `gr.nearme.app`, `edf299...` vs `3e02c...`) — transition OK

**Φάση 2 — Apple/Linux/Windows (edits τώρα, compile deferred):**
- `ios/Runner.xcodeproj/project.pbxproj:385,564,586` Runner → `gr.nearme.app` + `401,418,433` RunnerTests → `gr.nearme.app.RunnerTests` (6 hits)
- `ios/Runner/GoogleService-Info.plist:12` `BUNDLE_ID` → `gr.nearme.app` (νέο `GOOGLE_APP_ID` `461e9...`)
- `macos/Runner/Configs/AppInfo.xcconfig:11` → `gr.nearme.app` + `14` copyright → `gr.nearme.app`
- `macos/Runner.xcodeproj/project.pbxproj:398,412,426` RunnerTests → `gr.nearme.app.RunnerTests` (3 hits)
- `linux/CMakeLists.txt:10` `APPLICATION_ID` → `gr.nearme.app`
- `windows/runner/Runner.rc:92,96` `CompanyName`/`LegalCopyright` → `gr.nearme.app`

### Επαλήθευση (Windows, 26 Αυγ)
- `flutter clean` → `flutter pub get` → `flutter analyze` → **clean ✅ (0 issues)**
- `MainActivity` new exists ✅, old gone ✅, `package gr.nearme.app` ✅
- `Select-String com.example` σε `android/ios/macos/linux/windows` → 0 hits (εκτός docs)
- `ios pbxproj` 6× `gr.nearme.app` ✅, `macos` 3× ✅, `google-services.json` 2 clients ✅, `GoogleService-Info.plist` `gr.nearme.app` ✅
- SHA: `phoneVerificationEnabled=false` → skip (debug SHA για αργότερα αν ενεργοποιηθεί)


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 242 — B2 Release Signing (`debug` → `upload-keystore.jks` + R8 minify) (100%) — 26 Αυγ 2026

### Σκοπός
Διόρθωση B2 hard blocker: `signingConfig = debug` `android/app/build.gradle.kts:33` — Play απορρίπτει debug key. Release signing με upload keystore + R8 minify/shrink για store.

### Προετοιμασία (επανέλεγχος what exists / what can be reused)
- **Υπάρχει:** `android/app/build.gradle.kts:10,20` ήδη `gr.nearme.app` (B1 done) — reuse · `google-services.json:27` 2ο client `gr.nearme.app` — reuse · `android/.gitignore:12-14` ήδη `key.properties`/`**/*.keystore`/`**/*.jks` — reuse · `launch.md:139-165` snippet ready
- **Λείπει:** `android/key.properties` MISSING · `*.jks` MISSING · `android/app/proguard-rules.pro` MISSING · `signingConfigs` block MISSING · `isMinifyEnabled`/`isShrinkResources` MISSING
- **Κανόνες:** resize 0 (Gradle only), l10n 0, SPoT (`key.properties` single source), error_messages 0 (Gradle error), debug_config 0

### Υλοποίηση — 4 αρχεία + 1 keystore (backups πριν κάθε edit)

1. **Keystore εκτός repo:** `C:\Users\Vaggelis\keys\upload-keystore.jks` — `keytool -genkeypair -alias upload -keyalg RSA -keysize 4096 -validity 9125 -storetype JKS` + `Kwdiko5keystore0)` (store+key same) + `CN=NearMe, OU=Mobile, O=NearMe, L=Athens, ST=Attica, C=GR` — verified `keytool -list` 1 entry
2. **`android/key.properties` (νέο, gitignored):** `storeFile=C:/Users/Vaggelis/keys/upload-keystore.jks` + `storePassword`/`keyAlias`/`keyPassword` — `android/.gitignore` ήδη καλύπτει
3. **`android/app/build.gradle.kts`:** `import java.util.Properties`/`java.io.FileInputStream` + `val keystoreProperties`/`keystorePropertiesFile` load + `signingConfigs { create("release") {...} }` + `buildTypes.release` → `signingConfig = if (exists) release else debug` + `isMinifyEnabled=true` + `isShrinkResources=true` + `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")` — TODO `L31-32` διαγράφηκε
4. **`android/app/proguard-rules.pro` (νέο):** Flutter/Drift/Firebase/Geolocator/encrypt/secure_storage keeps + `-dontwarn` Play Core 11 rules (generated `missing_rules.txt` → `com.google.android.play.core.**`)

### Επαλήθευση (Windows, 26 Αυγ)
- `flutter clean` → `flutter pub get` → `flutter analyze` → **clean ✅ (0 issues)**
- Initial `flutter build appbundle` → `Unresolved reference 'util'/'io'` → fix imports → `daemon disappeared` (Xmx8G OOM) → `flutter build apk --release` → **R8 missing Play Core** → add `-dontwarn` 11 rules → **`flutter build apk --release` → 41.6MB (136s) ✅**
- `apksigner verify --print-certs` → `CN=NearMe, OU=Mobile, O=NearMe, L=Athens, ST=Attica, C=GR` + `SHA-256: 5c1b9ca4...` + `SHA-1: 060656b4...` ✅
- `jarsigner -verify` → `signature was verified` ✅
- Dev impact 0: `flutter run` (debug) uses debug signing, no minify, hot reload OK · `flutter run --release` uses release signing only if `key.properties` exists (fallback debug)


### `flutter analyze`: clean ✅ (0 issues)

### Σημείωση
`flutter build apk --release --dart-define=ENABLE_RELEASE_DEBUG=true --dart-define=GIPHY_API_KEY=...` → apk με debug logs (dev) · `flutter build appbundle --release --dart-define=GIPHY_API_KEY=...` → aab **χωρίς** `ENABLE_RELEASE_DEBUG` για Play upload · APK 41.6MB (keep `androidx.**` broad — polish: στένεμα σε επόμενο session)

---

## Session 243 — Content Moderation Scaffolding (`contentModerationEnabled=false`, 0 behavior change) (100%) — 26 Αυγ 2026

### Σκοπός
CSAE / Play Child Safety — automated SafeSearch/Vision scaffolding με master kill-switch **OFF** (0 Vision calls, $0, 0 latency, 0 UX change) — έτοιμο για staged rollout.

### Προετοιμασία (reuse-first)
- **Υπάρχει:** `onReportCreated` `index.ts:208` ban pattern + `isVisible` `public_profile.dart:37` + `stripExif` `shared/utils/image_utils.dart:9` + `StorageHelpers` `storage_helpers.dart:9` timeout + `FeatureFlags` 21 + `DebugConfig` 34 flags + `ErrorMessages` 210+ — reuse
- **Λείπει:** `contentModerationEnabled` flag, `moderation` debug, `moderation/*` errors, `VisionModerationService`, CF `moderateImage` storage trigger — MUST CREATE

### Υλοποίηση — 7 αρχεία (backups `moderation_init_20260826_213000/`)

1. **`feature_flags.dart`** +`contentModerationEnabled=false` + `autoModerateProfilePhotos=false` + `autoModerateChatMedia=false` + `blurExplicitByDefault=true`
2. **`debug_config.dart`** +`moderation:true` + `moderationVerbose:false` (`SOS` section)
3. **`error_messages.dart`** +`moderation/blocked-explicit`, `/flagged-review`, `/upload-retry`, `/banned-explicit` (4 codes)
4. **`vision_moderation_service.dart` (νέο, 45 γραμμές):** SPoT, flag-gated fail-open `isSafe()` + `isProfilePhotoSafe()` + `isChatMediaSafe()` — `false` → return true, empty bytes → allow, TODO Vision όταν ON
5. **`storage_service.dart`** `uploadAvatar/Photo` + pre-check `if (contentModerationEnabled && autoModerateProfilePhotos) await VisionModerationService.isProfilePhotoSafe(bytes) → AppException('moderation/blocked-explicit')` — flag OFF → no-op
6. **`chat_repository_impl.dart`** `sendMediaMessage` image/gif + same pre-check `isChatMediaSafe` — flag OFF → no-op
7. **`functions/src/index.ts`** +`moderateImage` `storage.object().onFinalize` `europe-west1` — kill-switch `config/moderation {enabled:true}` Firestore doc (fail-open), path `avatars/`/`photos/`/`chat_media/` — TODO Vision `safeSearchDetection`

### Επαλήθευση
- `flutter analyze` → 6 errors `AppException('code','msg')` positional → fix `message:`/`code:` named → **clean ✅ (0 issues)**
- Device test `22:37:56-22:42:34` — signIn → Discovery → Profile Edit avatar/photo → chat image/GIF → search 25km → GlobalConnectivityBanner → 0 `moderation` logs, 0 `moderation/blocked` (flag OFF), `uploadAvatar/Photo OK`, `sendMediaMessage success` — 0 side effects ✅
- CF `moderateImage` not deployed yet (requires `npm i @google-cloud/vision` + Vision enable) — kill-switch OFF → no billing


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 244 — Photo `UnmodifiableListView` Fix (`_interests` + `_photoUrls`) (100%) — 26 Αυγ 2026

### Σκοπός
`_photoUrls = profile.photoUrls ?? []` `profile_editor_screen.dart:161` + `_interests` `153` παίρνουν `EqualUnmodifiableListView` από `PublicProfile` `freezed.dart:551` via `profile_repository_impl:78,125` → `345` `add` / `359` `removeAt` / `665` `FilterChip` πετούν → `setState` no `markNeedsBuild` → UI stale μέχρι re-enter.

### Η λύση (reuse `List<String>.from` — 3 precedents)
- `profile_storage_mixin.dart:92,126` `List<String>.from(profile.photoUrls ?? [])` + `search_filters_screen.dart:76` `_interests = List<String>.from(...)` — SPoT idiom
- Edit: `153` `_interests = List<String>.from(profile.interests ?? [])` + `161` `_photoUrls = List<String>.from(profile.photoUrls ?? [])` — `345`/`359`/`665` μένουν, δουλεύουν σε mutable

### Επαλήθευση
- `flutter analyze` → **clean ✅ (0 issues)**
- Backup `backups/photo_unmodifiable_20260826_225000/` — `flutter clean; flutter pub get; flutter analyze` OK
- Rebuild storm: 0 — `_loadProfile` async `addPostFrameCallback` `initState:124` → single `setState` `163` — pure alloc, 0 `MediaQuery`/`Localizations` in build (Chapter 10 fix6 `224` locale-cache, fix3 `221` LayoutBuilder)


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 245 — P0 Startup Fixes (main + database_service + app_router) (100%) — 27 Αυγ 2026

### Σκοπός
3 στοχευμένες P0 διορθώσεις εκκίνησης με 0 side effects (blast radius 1-2 γραμμές/αρχείο).

### Υλοποίηση — 3 αρχεία

1. **`lib/main.dart` `126,131` — bare `unawaited()` → `unawaited(future.then<void>((_) {}, onError: (e,s)=>DebugConfig.warn(...)))`:** `MediaShareCache.sweep()` `media_share_cache.dart:35` + `ImageCacheGuard.checkAndPrune()` `image_cache_guard.dart:19` ήδη `try/catch` + `warn` internal — προσθήκη outer `then<void> onError` per `AGENTS.md:111` — blast radius 2 γραμμές, 0 επίδραση στο startup flow.
2. **`lib/data/local/database_service.dart:53` — `await _instance!.close()`:** Πρόσθεση `await` πριν `_instance = null` `57` — fix race `close()` Future<void> vs `_instance=null` → `database is locked` σε hot restart. `init()`/`tryInit()` ανέγγιχτα.
3. **`lib/core/router/app_router.dart:148` — `chatId!` → null/empty check:** `final chatId = state.pathParameters['chatId']; if (chatId==null || chatId.isEmpty) return ErrorView(...)` + import `shared/widgets/app_state_widget.dart` — blast radius μόνο `/chat/:chatId` route, άλλα 29 routes ανέγγιχτα — graceful deep link αντί `StateError`.

### Επαλήθευση
- `flutter analyze` → **clean ✅ (0 issues)** → `flutter build apk --release` 20.8MB → install → `23:03:02` `Splash 800ms` `main.dart:172` → `Database init 21ms` → `NearMeApp transition 35ms` → `user.reload 1646ms` — 0 delays πέραν εσκεμμένου splash + network
- `git diff` → 3 αρχεία, 5 γραμμές — 0 MediaQuery/Localizations in build (Chapter 10)


### `flutter analyze`: clean ✅ (0 issues)

---

## Session 246 — Prune θορύβου (Phase 1) + Δομή: καθαρό ιστορικό vs "σήμερα" (100%) — 28 Αυγ 2026

### Σκοπός
Το `oldsessions.md` είναι **ιστορικό χρονολόγιο** — κάθε εγγραφή είναι σωστή για τότε. Σκοπός: σαφής εξέλιξη της εφαρμογής, ιστορικά στοιχεία να μην μπλέκονται με τα νέα, και καθαρή διαδικασία ενημέρωσης.

### Αφαίρεση θορύβου (Phase 1, 2068→1850 γραμμές, 0 απώλεια ιστορίας/debugging)
- **37 `### Backups` blocks** αφαιρέθηκαν → paths ανακτήσιμα από `git log`/`backups/` (AGENTS.md:7). Backup folder = source of truth για backups.
- **Session 219** (Firebase retry screen, πλήρες REVERT — «κανένα ίχνος στον κώδικα») → μάθημα στον πίνακα REJECTED Κεφ.10.
- **fix2/fix4 REVERTED** (Session 221: memoization + didChangeDependencies width) → 1 σημείωση + REJECTED πίνακας.
- **Bubble Width verbose** (28γρ.) → 4-γραμμο summary (fix `IntrinsicWidth` κρατήθηκβ).
- **Session 210 device dump** → 1 σύνοψη. Παλιό note `com.example` (fixed 241) + κενό `| | |` row αφαιρέθηκαν.

### Τι ΔΕΝ άλλαξε (αρχή)
- **Sessions 1-100** δεν διαγράφονται — τεκμηριώνουν τη δημιουργία (Isar→Drift, auth, profile).
- **Παλιά schema/flags σε παλιές εγγραφές** δεν διορθώνονται (π.χ. `schema v12` σε Κεφ.1/3 ενώ τρέχον v15) — τότε ήταν σωστά. Η "τρέχουσα" αλήθεια ζει μόνο στο Κεφ.6.
- **Sessions 202/227/228/238** δεν συμπιέστηκαν (πυκνές τεκμηριωμένες αποφάσεις, χρήσιμες για debugging).

### Δομή & διαδικασία ενημέρωσης (SPAT — αυτό ισχύει πλέον μόνιμα)

**Η δομή είναι ήδη ορθολογική:**
- Κεφάλαια 1-10 = **στατική αναφορά** (σημερινή αλήθεια).
- Sessions = **χρονολογικό ιστορικό** (ιστορική αλήθεια, κάθε εγγραφή σωστή για τότε).
- Αυτά ΔΕΝ μπλέκονται: Κεφ.6 δείχνει το σήμερα, Sessions το πώς φτάσαμε.

**Κανόνες προσθήκης νέου session (υποχρεωτικοί):**
1. **Πάντα στο ΤΕΛΟΣ** του αρχείου (χρονολογικά), μετά το τελευταίο session που έχει το μπλοκ «ΔΙΑΔΙΚΑΣΙΑ ΕΝΗΜΕΡΩΣΗΣ».
2. **Μετά από κάθε session**, refresh των **στατικών Κεφαλαίων που γερνάνε**:
   - Κεφ.6 Current State → αριθμοί (flags, CFs, MB, schema, completion, `.dart` files, tests).
   - Κεφ.7 Conventions → αν προστέθηκε νέος κανόνας.
   - Κεφ.3 Φάσεις → αν ολοκληρώθηκε νέα.
   - Κεφ.1 Tech → αν άλλαξε επιλογή (σπάνιο).
3. **ΠΟΤΕ μη σβήνεις/τροποποιείς παλιό session** όταν αλλάζει η αλήθεια — γράψε το νέο στο τέλος + διόρθωσε μόνο το Κεφ.6.
4. **Backup** του αρχείου πριν κάθε edit (`backups/oldsessions_pre_<session>_<ts>.md`).
5. Κράτησε το τρέχον αυτό μπλοκ «ΔΙΑΔΙΚΑΣΙΑ ΕΝΗΜΕΡΩΣΗΣ» (μεταφέρεται μαζί με κάθε νέα εγγραφή) ώστε η επόμενη ενημέρωση να ακολουθεί την ίδια δομή.

> Αυτό το μπλοκ πρέπει να «κληρονομείται» σε κάθε επόμενο session στο τέλος του αρχείου.

### `flutter analyze`: clean ✅ (0 issues — μόνο .md αλλαγές)
