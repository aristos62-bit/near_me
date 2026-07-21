# NearMe — Old Sessions Archive

> Συμπυκνωμένο archive: τεχνολογίες, αρχιτεκτονική, σημαντικά fixes, τρέχουσα κατάσταση.

## Τεχνολογίες

| Layer | Επιλογή |
|---|---|
| State Management | Riverpod 3.x (Notifier, @riverpod) |
| Local DB | Drift 2.33 (SQLite, schema v12) |
| Navigation | GoRouter 17 (StatefulShellRoute) |
| Auth | Firebase (Anonymous → Email/Phone) |
| Cloud DB | Firestore (collectionGroup, 21 composite indexes) |
| Storage | Firebase Storage (avatars/photos/chat_media, max 5MB) |
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

## Αρχιτεκτονικές Αποφάσεις

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

## Φάσεις Υλοποίησης

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

## Κρίσιμα Bugs & Fixes

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

## Session Progression

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

## Current State

| Μέτρο | Τιμή |
|---|---|
| Completion | ~99.9% (Phases 1-3 100%, MultiChat 100%, Media 100%, Chat Redesign 100%) |
| `.dart` files | ~120 (non-generated) |
| Firestore indexes | 21 composite deployed |
| Cloud Functions | 6 deployed + `fcm-utils.ts` helper |
| Build | `flutter analyze` clean, release APK ~15.8MB |
| Tests | 30/30 passed |
| Schema | Drift v12, 7 tables |
| Feature Flags | 10 (typesenseEnabled, videoCallEnabled, groupChatEnabled, gifSupportEnabled, mediaMessagesEnabled, messageReactionsEnabled, replyToMessageEnabled, groupEventsEnabled, webVersionEnabled, aiMatchingEnabled, verifiedBadgeEnabled, premiumTierEnabled) |

## Key Conventions
- File size ≤ 500 lines (exceptions: profile_repository_impl ~570, chat_repository_impl ~590 with user permission)
- `DebugConfig.log(flag, msg)` σε κάθε operational action (33 flags, 3 levels)
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): `L10n.isGreek()` + `L10n.localizedMessage()`
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
- GPS-first → session cache (5min) → last known → failure
