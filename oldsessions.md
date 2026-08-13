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
| | |
| **206** | **Server-side authoritative geoHash** — computeGeoHash CF (πιστό GeoHashUtils port), Firestore SPoT geoPrecision, update rule blocks client geoHash write, auto-publish σε κάθε save, live distance από geoHash αντί searchState.distances, 5 files changed |
| **207** | **Mock-location detection** — `position.isMocked` check σε GPS + lastKnown, LocationFailure.mockLocationDetected, discovery_screen μήνυμα fake GPS, 2 files changed |
| **208** | **Client-side search rate limiting** — `_checkRateLimit()` στο SearchNotifier (search_provider.dart:118), fixed-window 30 queries/5min, CF `checkSearchRateLimit` με transaction, firestore.rules rateLimits write:false, fail-open σε network/CF failure |
| **209** | **deleteUserData orphaned subcollections fix** — +3 subcollection deletes (privacy/settings, blocked/, rateLimits/search) σε CF `deleteUserData` (index.ts) + client-side defense-in-depth (`auth_repository_impl.dart:76-89`) + UI list update (`delete_account_screen.dart:213-221`). backup: `backups/deleteUserData_fix_20260728_*` |

## ΚΕΦΑΛΑΙΟ 6 — CURRENT STATE

| Μέτρο | Τιμή |
|---|---|
| Completion | ~99.9% (Phases 1-3 100%, MultiChat 100%, Media 100%, Chat Redesign 100%, Audio Messages 100%) |
| `.dart` files | ~122 (non-generated) |
| Firestore indexes | 21 composite deployed |
| Cloud Functions | 8 deployed (+ computeGeoHash, + checkSearchRateLimit) + `fcm-utils.ts` helper |
| Build | `flutter analyze` clean, release APK ~15.8MB |
| Tests | 30/30 passed |
| Schema | Drift v12, 7 tables |
| Feature Flags | 21 (typesense, videoCall, groupChat, gifSupport, mediaMessages, audioMessages, videoMessages, messageExpiry, messageReactions, replyToMessage, **replyPrivately**, editMessage, deleteMessage, messageInfo, messageEmail, messageShare, groupEvents, webVersion, aiMatching, verifiedBadge, premiumTier) |

## ΚΕΦΑΛΑΙΟ 7 — KEY CONVENTIONS
- File size ≤ 500 lines (exceptions: profile_repository_impl ~570, chat_repository_impl ~590 with user permission)
- `DebugConfig.log(flag, msg)` σε κάθε operational action (33 flags, 3 levels)
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): `L10n.isGreek()` + `L10n.localizedMessage()`
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
- GPS-first → session cache (5min) → last known → failure

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

### Το πρόβλημα
Όλα τα text message bubbles εμφανίζονταν στο `bubbleMaxWidth=264.0` (max) αντί στο σωστό content width (~55.9 για 4 χαρακτήρες). Αυτό συνέβαινε στο **πρώτο layout pass** για υπάρχοντα μηνύματα. Για νέα μηνύματα, το 1ο frame ήταν σωστό (55.9) αλλά το 2ο layout pass (ts=null → ts=Timestamp) το μετέτρεπε σε 264.0.

### Διάγνωση
Από `GlobalKey` στο Container + `BUBBLE_W` debug logs:
- Υπάρχοντα μηνύματα: `w=264.0` από την αρχή
- Νέο μήνυμα, 1ο frame: `w=55.9` (σωστό), μετά `w=264.0` (max)
- `constraintsMax=352.0`, `bubbleMax=264.0` — ΠΑΝΤΟΤΕ ίδια, δεν αλλάζουν
- `prevW=264.0` για όλα μετά το πρώτο layout

**Αιτία:** `Column(mainAxisSize: min, crossAxisAlignment: end)` μέσα σε `Container(constraints: BoxConstraints(maxWidth: 264))` — στο πρώτο layout pass, το Column αποτυγχάνει να υπολογίσει intrinsic width και παίρνει ολόκληρο το max constraint.

### Attempt #1 — SizedBox.shrink αντί conditional if (FAILED)
**Πρόταση:** Αντικατάσταση `if (timeStr.isNotEmpty) Padding(...)` με ternary `timeStr.isNotEmpty ? Padding(...) : SizedBox.shrink()` για σταθερό αριθμό children.
**Αποτέλεσμα:** ΔΕΝ δούλεψε — ακόμα και με 2 σταθερά children, το bug εμφανίζεται. Το intrinsic sizing αποτυγχάνει ανεξάρτητα από τον αριθμό children.

### Fix: IntrinsicWidth (ΛΥΣΗ)
**Πρόταση:** Wrapping του inner Column (text + time) με `IntrinsicWidth` στο Container.
**Αποτέλεσμα:** ✅ **ΕΠΙΤΥΧΙΑ** — `IntrinsicWidth` εξαναγκάζει ένα επιπλέον intrinsic measurement pass, διορθώνοντας το sizing από το πρώτο layout. `BUBBLE_W`: `w=55.9`, `w=83.9`, `w=103.4` (όλα σωστά). `prevW` διατηρείται σταθερά.

**Αρχείο:** `text_message_bubble.dart:236` — `child: IntrinsicWidth(child: Column(...))`

### Σημείωση
- `DebugConfig` import αφαιρέθηκε από `message_bubble.dart` και `text_message_bubble.dart`
- Όλα τα debug logs (`BUILD`, `TextBubble`, `BUBBLE_W`) και στατικές μεταβλητές (`_bubbleKeys`, `_loggedW`) αφαιρέθηκαν

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

### Backups
- `backups/message_expiry_fixes_20260728_154514/` (chat_provider.dart, firestore.indexes.json)

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

### Backups
- `backups/profile_editor_screen_20260729_230421.dart`
- `backups/privacy_editor_screen_20260729_230421.dart`

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
```
pendingDelete=false deleteResponseNeeded=false  → initial
pendingDelete=true  deleteResponseNeeded=false  → requestDeleteChat
pendingDelete=false deleteResponseNeeded=true   → after reject (Aris62)
pendingDelete=false deleteResponseNeeded=false  → after keepChat (Yahooman) ✓
```
- delete_request buttons disappear after reject ✅
- delete_rejected buttons disappear after keepChat ✅
- `chatDocProvider suppressed (pending)` observed during batch writes (rebuild storm prevention works)

### Backups
- (in-place edits, backup από προηγούμενο session)

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

### Backups
- `backups/photo_gallery_20260804_202542/`
- `backups/photo_gallery_zoom_20260804_221620/`
- `backups/oldsessions_20260804_223251.md`

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

### Backups
- `backups/autoscroll_fix_20260804_223849/`
- `backups/oldsessions_20260804_224646.md`

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

### Backups
- `backups/reply_thumbnail_20260804_231356/`
- `backups/oldsessions_20260804_232637.md`

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

### Backups
- `backups/oldsessions_20260805_103404.md`

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

### Backups
- `backups/profile_card_redesign_20260805_105116/`
- `backups/oldsessions_20260805_110620.md`

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

### Backups
- `backups/chat_repository_impl_20260805_125433.dart`
- `backups/oldsessions_20260805_130541.md`

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

### Backups
- `backups/app_messenger_20260805_143321.dart`

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

### Backups
- `backups/app_router_20260805_184037.dart`

### `flutter analyze`: clean ✅ (0 issues)

## Session 219 — Firebase init failure retry screen (0%) — ΠΛΗΡΕΣ REVERT — 5 Αυγ 2026

> **ΑΠΟΤΕΛΕΣΜΑ: Πλήρες revert. Το fix ΔΕΝ ισχύει πια. Κανένα ίχνος δεν έμεινε στον κώδικα.**

### Σκοπός (αρχικός, λάθος)
Φτιάξαμε retry screen για όταν αποτυγχάνει το `Firebase.initializeApp()` (γνήσιο config/platform error), αντί του παλιού fatal error χωρίς retry. Υλοποιήθηκε: `firebase_retry_screen.dart` (νέο), ErrorView `retryLabel`, idempotency guard στο firebase_init, `firebase/init-failed` error message, 3ο keyed child στο AnimatedSwitcher του main.dart + `_onFirebaseRetrySuccess()`. Backups: `main_20260805_191850.dart`, `firebase_init_20260805_191850.dart`, `error_messages_20260805_191850.dart`.

### Device tests (release APK, airplane mode) — γιατί REVERT
- **Firebase init ΔΕΝ απαιτεί δίκτυο**: διαβάζει bundled `google-services.json` τοπικά. Airplane mode → init επιτυχία πάντα (238ms/153ms), `Firebase initialized` σε κάθε cold start.
- Το "δεν υπάρχει σύνδεση στο διαδίκτυο" + Retry που έβλεπε ο χρήστης είναι **το υπάρχον offline UX του Discovery** (`_performSearch: no connectivity`, `ErrorView retry tapped` → `_onRefresh`), ΟΧΙ το δικό μας screen — το `FirebaseRetryScreen` **δεν χτίστηκε ποτέ**.
- Άρα το πρόβλημα "offline → dead app" **δεν υπάρχει στο init βήμα** · το offline το χειρίζεται ήδη σωστά το connectivity banner + search retry · το fix μας προστάτευε μόνο από σπάνιο config failure → κρίθηκε λάθος και περιττό.

### Revert (υλοποιημένο, verified)
- `main.dart`, `firebase_init.dart`, `error_messages.dart` → επαναφορά από backups `20260805_191850` (Copy-Item).
- `app_state_widget.dart` → `git checkout` (retryLabel αφαιρέθηκε, μόνο αυτό άλλαξε).
- `firebase_retry_screen.dart` → διαγράφηκε.
- **`flutter analyze`: clean ✅ · `flutter test`: 30/30 ✅ · `git status` καθαρό ✅**

### Backups
- `backups/main_20260805_191850.dart` · `backups/firebase_init_20260805_191850.dart` · `backups/error_messages_20260805_191850.dart` (κρατούνται μόνο ως reference, δεν χρησιμοποιούνται)

---

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

### Backups
- `backups/*_20260806_112344.bak` (crash fix) · `backups/*_20260806_121640.bak` (media forward) · `backups/oldsessions_20260806_123954.md`

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

**fix2 (απέτυχε, backup `backups/chat_messages_list_20260806_1640.fix2.bak`):**
- **Cached width:** `double _screenWidth` + `didChangeDependencies()` το διαβάζει και το ενημερώνει μόνο όταν αλλάξει πραγματικά.
- **Αποτυχία:** η `didChangeDependencies()` που καλούσε `MediaQuery.sizeOf(context)` δηλώνει κι αυτή MediaQuery dependency → το keyboard συνέχισε να ξαναχτίζει το widget. Επιβεβαιώθηκε: καθαρό log χωρίς πληκτρολόγιο, αλλά bursts με πληκτρολόγιο (`BUILD #7..#39`, 11-22×).
- **Μάθημα:** MediaQuery σε `didChangeDependencies` = **εξίσου** dependency. Η dependency δηλώνεται με την ΚΛΗΣΗ του MediaQuery, όχι μόνο στη build.

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

### Backups
- `backups/chat_messages_list_20260806_1455.fix.bak` (pre-fix nicknames/avatars)
- `backups/chat_messages_list_20260806_1530.hlog.bak` (pre-screenH)
- `backups/chat_messages_list_20260806_1610.diagT.bak` · `..._1620.diagT2.bak` (SIG diagnostics, προσωρινά)
- `backups/chat_messages_list_20260806_1640.fix2.bak` (pre-MediaQuery-fix — απότυχε, didChangeDependencies)
- `backups/chat_messages_list_20260806_1715.fix3.bak` (ΤΕΛΙΚΟ fix — LayoutBuilder + resolveWidth, zero MediaQuery)
- `backups/reply_preview_20260806_1600.bak`

### ⚠️ ΠΡΟΣΟΧΗ — ΕΠΑΚΟΛΟΥΘΟ FIX & REVERT (6 Αυγ, μετά το παραπάνω)

Οι παρακάτω σημειώσεις (fix4 memoization) είναι **REVERTED** — διατηρούνται μόνο για ιστορικό, ΔΕΝ είναι ενεργός κώδικας. Ο τρέχων ενεργός κώδικας = fix3 (LayoutBuilder) + νέα διακριτικά logs (βλ. πιο κάτω).

**fix4 (memoization ListView — ΑΠΟΡΡΙΦΘΗΚΕ/REVERT, backup `backups/chat_messages_list_20260806_memo.bak`):**
- Δοκιμάστηκε memoization ολόκληρου του `ListView` widget: fields `_cachedList`/`_cachedListWidth`, reset στο `build()`, short-circuit `return _cachedList!;` όταν το width δεν αλλάζει (μόνο το ύψος αλλάζει από keyboard).
- **Αιτία αποτυχίας:** τα device logs (16:51) έδειξαν `MSG_LIST: ListView reused (w=384) (×25)` **ΜΑΖΙ** με `ReplyPreview: thumbnail=yes (×26)` / `(×52)` — δηλαδή το ListView widget κρατιέται (reused) αλλά τα **items ξαναχτίζονται**. Ο λόγος: στο keyboard relayout ο **`itemBuilder` ξανακαλείται** για τα ορατά items (sliver child cycle), οπότε δημιουργούνται νέα `MessageBubble` widgets ανεξαρτήτως του memoized ListView.
- **Δεύτερη αιτία (μεθοδολογική):** το `ReplyPreview ×26/×52` ήταν **aggregate** χωρίς διάκριση — το `ReplyPreview` εμφανίζεται σε **5 εστίες** (`emoji_only_bubble.dart:115`, `gif_image_bubble.dart:175`, `audio_message_bubble.dart:223`, `video_message_bubble.dart:241`, `text_message_bubble.dart:223`) και το `ChatMessagesList` φτιάχνεται σε **4 σημεία** του chat_screen (γρ. 73, 134, 150, 161). Χωρίς msgId/instance/identityHashCode στα logs δεν μπορούμε να ξέρουμε ποια εστία και ποιο item ξαναχτίζεται. **Μάθημα: πρώτα διακριτικά diagnostics, μετά λύση — ποτέ speculative fix σε aggregate logs.**

**REVERT + νέα διακριτικά logs (τρέχουσα κατάσταση, backups `backups/chat_messages_list_20260806_diagnostics.bak` + `backups/reply_preview_20260806_diagnostics.bak`):**
- Αφαιρέθηκε πλήρως το memoization (ξανά clean fix3 LayoutBuilder, zero MediaQuery). `flutter analyze` clean ✅.
- **Log A** — `chat_messages_list.dart`: `MSG_LIST itemBuilder i=X (chat, inst)` + `MSG_LIST item type=... msgId=... (inst)` στο `itemBuilder` → δείχνει πόσα indices καλούνται ανά frame και ποια (flag `chatBubbleDesign`).
- **Log B** — `reply_preview.dart`: `ReplyPreview: id=<msgId> thumb=... h=<identityHashCode>` → ξεχωρίζει αν το ίδιο instance ξαναχτίζεται (ίδιο `h`) ή είναι διαφορετικά bubbles (flag `chatReply`).
- **Log C** — `chat_messages_list.dart`: `MSG_LIST BUILD ... inst=<instanceId>` → ποιο από τα 4 instances του chat_screen χτίζει (flag `chatBubbleDesign`).
- **Ανοιχτό:** εκκρεμεί device test από χρήστη + ανάλυση των νέων διακριτικών logs. → **✅ ΕΛΗΞΕ (13 Αυγ, Session 231)**

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

### Backups
- `backups/*_20260810_pre_bubbleMaxWidth_spot.bak.dart` (8 αρχεία: chat_messages_list, message_bubble, text_message_bubble, gif_image_bubble, audio_message_bubble, video_message_bubble, reply_preview, emoji_only_bubble)
- `backups/message_bubble_20260810_pre_probe.bak.dart` (πριν το temporary probe)
- `backups/oldsessions_20260810_pre_222.md`

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

### Backups
- `backups/chat_messages_list_20260810_pre_greek_cache_fix.bak` (κατάσταση με probes, πριν τα revert)
- `backups/chat_messages_list_20260810_sigprobe.bak`, `backups/chat_messages_list_20260810_sigprobe2.bak` (αναφέρονται στα TEMP markers που αφαιρέθηκαν)

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

### Backups
- `backups/incoming_share_media_<ts>/` (6 αρχεία πριν το media feature)
- `backups/incoming_share_video_thumb_<ts>/` (service + sheet πριν το thumbnail-preview)
- `backups/incoming_share_progress_<ts>/` (service + chat_input_bar πριν το upload progress)

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

### Backups
- `backups/geohash_utils_20260811_173442.dart`
- `backups/firestore_search_repository_20260811_173817.dart`
- `backups/{search_provider,profile_card,status_provider,profile_repository_impl}_20260811_174040.dart`
- `backups/{main,app_router,auth_provider}_20260811_175132.dart`
- `backups/oldsessions_20260811_175603.md`

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
| `ChatScreen` ξαναφτιάχνει `_messagesList` σε video play/fail (chat_screen.dart:134,150,161) — σκοτώνει το fix5 width-cache | Session 222 |
| ~~Device test νέων διακριτικών logs (Log A/B/C: item, ReplyPreview id/h, inst) + ανάλυση — ζητήθηκε από χρήστη~~ → **✅ ΕΛΗΞΕ (13 Αυγ)** | Session 221 |
| `join_confirmation_screen.dart:72` + `fcm_service.dart:89,166` — deep links χωρίς `extra` (group-capable) | Session 218 |
| `AppMessenger.showLoading/hideLoading` — dead code (δεν καλούνται πουθενά· τα media sends χρησιμοποιούν `_isLoading` spinner) | Session 225 |

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

### Backups
- Σε φάσεις: `reply_preview_20260812_115721.bak`, `text_message_bubble_20260812_120014.bak`, `reply_preview_20260812_121202.bak`, `20260812_121258`, `text_message_bubble_20260812_123853.bak`, `gif_image_bubble_20260812_132220.bak` + `gif_image_bubble_inst_20260812_132753.bak`, `audio_message_bubble_20260812_134432.bak`, `video_message_bubble_20260812_135045.bak`, `emoji_only_bubble_20260812_135700.bak`.
- **Cleanup:** `backups/*_before_instrumentation_20260812_140847.bak` (5 αρχεία) + `backups/oldsessions_20260812_141000.md`.

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

### Backups
- `backups/*_trigger_side_20260812_145805.bak` (φάση 1) · `backups/*_emoji_show_20260812_151503.bak` (πριν τη δοκιμή emoji-show)
- `backups/*_side_summary_20260812_154038.bak` (πριν το τελικό design) · `backups/*_isMe_hide_20260812_154725.bak` (πριν την απόκρυψη συνόλων στα δικά μου) · `backups/*_152324.bak` (revert-source)
- `backups/oldsessions_20260812_155017.md`

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

### Backups
- `backups/image_cache_guard_20260813_105056.dart` (original πριν τα temporary diagnostics)
- `backups/image_cache_guard_20260813_105756.dart` (κατάσταση με τα temporary diagnostics, ως reference)
- `backups/oldsessions_20260813_110229.md`

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

### Backups
- `backups/feature_flags_20260813_121012.dart`
- `backups/settings_screen_20260813_121012.dart`
- `backups/oldsessions_20260813_121944.md`

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

### Backups
- `backups/message_reactions_20260813_123055.dart`
- `backups/message_reactions_row_20260813_123055.dart`
- `backups/oldsessions_20260813_123256.md`
