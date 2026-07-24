# NearMe — Αναλυτική Αναφορά Ελέγχου & Προτάσεων

> Ημερομηνία: 24 Ιουλίου 2026 — Sessions 1-205
> Πηγή: nearme_blueprint.md, oldsessions.md, sound_message.md, πλήρης ανάλυση codebase (~122 .dart files)
> `flutter analyze`: clean ✅ (0 issues)

---

## Συνοπτική Εικόνα

| Φάση | Ολοκλήρωση | Κρίσιμα Gaps | Λειτουργικά Gaps | Ασφάλεια Gaps |
|:---|:---:|:---|:---|:---|
| **Φάση 1:** Core & Privacy | **100%** (24/24) | — | — | — |
| **Φάση 2:** Discovery | **100%** (15/15) | — | — | — |
| **Φάση 3:** Communication | **100%** (18/18) | — | — | — |
| **MultiChat (Group Chat)** | **100%** (31/31) | — | — | — |
| **Media Input** | **100%** (15/15) | — | — | — |
| **Chat UI Redesign** | **100%** (13/13) | — | — | — |
| **Audio Messages** | **100%** (22/22) | — | — | — |
| **Σύνολο** | **~99.9%** | **—** | **—** | **0 ασφάλειας** |

---

# Φάση 1 — Core & Privacy (100%)

## ✅ Ολοκληρωμένα

| # | Απαίτηση | Απόδειξη |
|---|----------|----------|
| 1 | Firebase Init + Anonymous Auth | `firebase_init.dart`, `auth_repository_impl.dart` |
| 2 | Local Database (Drift 2.33, 7 tables, schema v12) | `database.dart`, `database_service.dart`, tables/ |
| 3 | UserProfile CRUD (local, 23 fields, lat/lng ΠΟΤΕ στο cloud) | `profile_repository_impl.dart` |
| 4 | PrivacySettings (13 toggles: +showAvatar Session 164, schema v11→v12) | `privacy_settings_table.dart`, `privacy_editor_screen.dart` |
| 5 | ConsentLog (GDPR, local-only, UI με φίλτρα) | `consent_log_screen.dart`, `consent_log_provider.dart` |
| 6 | Publish/Unpublish (privacy-respecting, isOnline preserved, null filtering) | `profile_repository_impl.dart` |
| 7 | GPS + GeoHash (precision levels, auto-fill city/country) | `location_service.dart`, `discovery_screen.dart` |
| 8 | i18n el/en (18+ μέθοδοι) | `l10n.dart`, `app_el.arb`, `app_en.arb` |
| 9 | Dark/Light Theme (Material 3, system mode) | `app_theme.dart`, `app_colors.dart` |
| 10 | Firestore Composite Indexes (21 deployed) | `firestore.indexes.json` |
| 11 | Repository Pattern (8 abstract interfaces + mixins) | `repositories/` — Auth, Profile, Search, Chat (+ChatDeleteMixin, GroupChatMixin), Request, Block, Report |
| 12 | Unified Error Handling (AppMessenger + AppStateWidgets) | `app_messenger.dart`, `app_state_widget.dart` |
| 13 | Shared Widgets (10+ widgets) | `shared/widgets/` |
| 14 | BlockedUser (local + Firestore sync, search exclusion) | `block_repository_impl.dart`, `blocked_users_screen.dart` |
| 15 | Report User (Cloud Function, 6-step validation) | `report_repository_impl.dart`, `index.ts:onReportCreated` |
| 16 | Auto-ban CF (duplicate check, rate limit, 5 reports → ban) | `index.ts:onReportCreated` |
| 17 | Firestore Security Rules (100% helpers με `$(database)`) | `firestore.rules` (7 helpers) |
| 18 | flutter_secure_storage (encryption keys) | `encryption_utils.dart` |
| 19 | GDPR Core (Consent, Access, Erasure, Minimization) | ConsentLog + Privacy Editor + Delete Account CF |
| 20 | Delete Account CF (storage cleanup, requests, chats anonymize) | `index.ts:deleteUserData`, `auth_repository_impl.dart` |
| 21 | Screenshot Prevention (FLAG_SECURE, MethodChannel, toggle) | `screen_protector.dart`, `settings_screen.dart` |
| 22 | Biometric Lock + Auto-lock timer (LockScreen, lifecycle, provider, settings UI) | `lock_screen.dart`, `app_settings_provider.dart`, `settings_screen.dart`, `main.dart` |
| 23 | Feature Flags (16 flags από blueprint §14 + επεκτάσεις) | `feature_flags.dart` (typesense, videoCall, **groupChat**, gifSupport, mediaMessages, **audioMessages**, messageReactions, replyToMessage, editMessage, deleteMessage, messageInfo, aiMatching, verifiedBadge, premiumTier, groupEvents, webVersion) |
| 24 | GoRouter errorBuilder (themed error page) | `app_router.dart` |

---

# Φάση 2 — Discovery (100%)

## ✅ Ολοκληρωμένα

| # | Απαίτηση | Status |
|---|----------|--------|
| 1 | SearchFilters (freezed model: city, country, age, gender, radius, etc.) | ✅ |
| 2 | SearchFilters UI (TextFormFields, RangeSlider, ChipSelector) | `search_filters_screen.dart` |
| 3 | ProfileCard results (responsive ListView, lookingFor badge) | `profile_card.dart` |
| 4 | PublicProfile view (photo, nickname, age, city, country, bio, interests) | `public_profile_view_screen.dart` |
| 5 | Saved Searches CRUD (συμπ. 3 bool filters: allowVideoCall, allowDirectChat, onlineOnly) | `saved_search_provider.dart`, `saved_searches_screen.dart` |
| 6 | Block User (stream-based, search exclusion) | ✅ |
| 7 | Report User UI (shared widget) | `report_user_dialog.dart` |
| 8 | Auto-ban Cloud Function (6-step) | ✅ |
| 9 | SearchRepository interface (abstract + Firestore impl + Typesense stub) | `search_repository.dart` |
| 10 | View History (σωστά deferred) | ✅ |
| 11 | Cursor pagination (SearchCursor + startAfter + 300 cap) | `firestore_search_repository.dart` |
| 12 | Server-side filters + `_passesFilters()` client safety net | ✅ |
| 13 | City + Country filter (Firestore WHERE, hasLocationFilter για skip geo bounds) | ✅ |
| 14 | Manual location indicators (Icons.help red / Icons.check_circle green) | `profile_card.dart` |
| 15 | Nominatim autocomplete (800ms debounce, 1 req/sec rate limit) | `location_autocomplete_service.dart` |
| 16 | Haversine distance memoization (`_distanceCache`, 96% reduction) | `firestore_search_repository.dart` |

## Search Query Architecture

Το `firestore_search_repository.dart` έχει 4 query paths:

| Συνθήκη | Query | Index |
|---------|-------|-------|
| **GPS only** (city/country null) | `WHERE isVisible AND geoHash BETWEEN [...] ORDER BY geoHash` | `isVisible↑ geoHash↑` |
| **City+radius** (`hasRadiusFilter=true`) | `WHERE isVisible AND geoHash BETWEEN [...] ORDER BY geoHash` + client-side city filter (`_passesFilters`) | `isVisible↑ geoHash↑` |
| **City only** (`hasLocationFilter=true`, no radius) | `WHERE isVisible AND city = '...' ORDER BY __name__` | `isVisible↑ city↑` |
| **Country only** (`hasLocationFilter=true`) | `WHERE isVisible AND country = '...' ORDER BY __name__` | `isVisible↑ country↑` |

Routing logic: `hasGeoSearch && (!hasLocationFilter || hasRadiusFilter)` → `_geoSearch` (spatial). Διαφορετικά → `_generalSearch` (city/country exact match). `hasLocationFilter = cityFilterActive || countryFilterActive`. City+radius χρησιμοποιεί geoHash για efficient spatial query + client-side city post-filter. City χωρίς radius → exact city match server-side.

---

# Φάση 3 — Communication (100%)

## ✅ Ολοκληρωμένα

| # | Απαίτηση | Status |
|---|----------|--------|
| 1 | Request System CRUD (send, accept/decline, 48h expiry, chatId storage) | ✅ |
| 2 | Requests Dashboard (incoming/outgoing, filters, chat button, selection mode) | `requests_dashboard_screen.dart` |
| 3 | E2E Encrypted Chat (AES-256 GCM, deriveKey deterministic, key in secure storage) | `chat_screen.dart`, `encryption_utils.dart` |
| 4 | Online Presence (heartbeat 60s, lifecycle-aware, Future.wait) | `presence_service.dart` |
| 5 | Read Receipts (double-check marks) | `chat_screen.dart` |
| 6 | Rate Limiting (reports: 10/hour, auto-ban at 5) | `index.ts` |
| 7 | Request→Chat Flow (auto-create on accept, auto-navigate) | ✅ |
| 8 | FCM: New Message + New Request + Accept/Decline (3 CFs, locale-aware, retry with exponential backoff) | `index.ts` (3 functions), `fcm-utils.ts` |
| 9 | FCM Foreground/Background/Killed handlers (συμπ. biometric lock guard) | `fcm_service.dart` |
| 10 | Email Verification (Welcome Screen, signIn/signUp) | `verify_account_screen.dart` |
| 11 | **Phone Verification (P2.5)** — SMS με state machine, validation, ελλάδα | `phone_verify_provider.dart`, `phone_verify_screen.dart` |
| 12 | Chat preview (encrypted lastMessage + unread count badge) | ✅ |
| 13 | E2E encryption indicator (lock icon + tap dialog) | ✅ |
| 14 | Unread tracking requests (readAt, blue dot, bold, profile badge με count) | ✅ |
| 15 | FCM deep link /requests/:requestId | ✅ |
| 16 | Image message type σε chat (encrypted) | ✅ |
| 17 | Auto-expire stale requests (scheduled CF) | ✅ |
| 18 | **Audio Messages (Voice Messages)** — record AAC, upload `.m4a`, playback bubble, shared AudioPlayer | `audio_recorder_sheet.dart`, `audio_message_bubble.dart` |

---

# MultiChat (Group Chat) — 100% (Sessions 158-163)

| # | Απαίτηση | Status |
|---|----------|--------|
| 1 | Group Chat CRUD (create, delete, clear messages) | ✅ |
| 2 | Roles: creator/admin/member | ✅ |
| 3 | Role-based permissions (inviteMembers, removeMembers, deleteMessages, changeGroupName, changeGroupAvatar, managePermissions, manageAdmins, pinMessages) | ✅ |
| 4 | Permission overrides per user | ✅ |
| 5 | Invite links (create, redeem, revoke, max uses, expiry) | ✅ |
| 6 | Public groups (join, city tag) | ✅ |
| 7 | Group avatar (upload, remove) | ✅ |
| 8 | Max participants (configurable, deployed index) | ✅ |
| 9 | Audit log (permission changes, role changes, joins, leaves) | ✅ |
| 10 | Bilingual system messages (SystemMessageFormatter, 5+ actions) | ✅ |
| 11 | FCM: addParticipant + leaveGroup callable CFs (Admin SDK bypass) | ✅ |
| 12 | 4 composite indexes deployed for group queries | ✅ |
| 13 | `isGroupMember()` helper in Security Rules | ✅ |
| 14 | `notBanned()` σε 17 chat/request rules | ✅ |

---

# Media Input — 100% (Sessions 175-191)

| # | Απαίτηση | Status |
|---|----------|--------|
| 1 | **Phase 1: Emoji Picker** — emoji_picker_flutter v4.4.0, theme-aware, responsive height | ✅ |
| 2 | EmojiPickerPanel leaf widget (rebuild isolation) | ✅ |
| 3 | Instance cache (StatefulWidget + SPoT restoration) | ✅ |
| 4 | **Phase 2: GIF Support** — GIPHY API (Tenor discontinued) | ✅ |
| 5 | GifPickerSheet (search, trending, pagination) | ✅ |
| 6 | **Phase 3: Image Messages** — gallery/camera picker | ✅ |
| 7 | Image Cropper (1:1 avatar, free ratio photos) | ✅ |
| 8 | Upload → Firebase Storage (chat_media/{chatId}/{msgId}.jpg) | ✅ |
| 9 | Full-screen image preview | ✅ |
| 10 | Storage cleanup on delete (deleteAllChatMedia) | ✅ |
| 11 | **Phase 4: Media "+" Popup** — MediaAction enum + bottom sheet | ✅ |
| 12 | Multiline TextField (maxLines:5) | ✅ |
| 13 | **Audio Messages** → βλ. ξεχωριστή ενότητα | ✅ |

---

# Chat UI Redesign — 100% (Sessions 187-199)

| # | Απαίτηση | Status |
|---|----------|--------|
| 1 | **Viber-like bubble tails** — CustomPainter (TailPainter) | ✅ |
| 2 | **Date separators** — Σήμερα/Χθες/ημερομηνία | ✅ |
| 3 | **Message grouping** — ίδιος sender <5min | ✅ |
| 4 | Sent color `#075E54` (WhatsApp-style) | ✅ |
| 5 | Timestamp inside bubble | ✅ |
| 6 | `ReadReceiptIndicator` shared widget | ✅ |
| 7 | Emoji-only without bubble card | ✅ |
| 8 | `resizeToAvoidBottomInset: false` | ✅ |
| 9 | **Reaction System** — Map<UID, emoji>, toggle, preset + custom | ✅ |
| 10 | **Reply to Message** — long-press → reply banner → send (12 steps, 11 files) | ✅ |
| 11 | **Edit Message** — 15-min window, type guard (όχι edit σε media/audio) | ✅ |
| 12 | **Delete Message** — με confirmation | ✅ |
| 13 | **Rebuild cascade elimination** (5 phases, συμπ. _SafeInputArea, pending=true suppression, messagesStream equality caching, _MessageBubbleSignature cache) | ✅ |

---

# Audio Messages (Voice Messages) — 100% (Sessions 204-205)

| # | Απαίτηση | Status |
|---|----------|--------|
| 1 | Πρόταση sound_message.md v2.0 (24 Ιουλ 2026) | ✅ |
| 2 | Packages: `record ^7.1.1`, `audioplayers ^6.8.1` | ✅ |
| 3 | Permissions: `RECORD_AUDIO` (Android), `NSMicrophoneUsageDescription` (iOS) | ✅ |
| 4 | Feature flag: `audioMessagesEnabled` | ✅ |
| 5 | Debug flag: `chatAudio` | ✅ |
| 6 | Error codes: 4 νέα (audio-send-failed, audio-playback-error, audio-permission-denied, audio-too-short) | ✅ |
| 7 | Repository: `audioBytes` + `duration` params σε interface/impl/provider | ✅ |
| 8 | Upload: `.m4a` → `chat_media/{chatId}/{msgId}.m4a` (AAC 44kHz) | ✅ |
| 9 | Decode: `'audio'` σε skip-decrypt list (3 σημεία) | ✅ |
| 10 | Duration field: Firestore msgData + return map | ✅ |
| 11 | **AudioRecorderSheet** (νέο) — record UI, 60s max, ≥1s min, temp file | ✅ |
| 12 | **AudioMessageBubble** (νέο) — playback, shared AudioPlayer, progress, E2E lock icon | ✅ |
| 13 | Edit guard: 3-layer (showEdit=false, canEdit=false, _onEdit type guard) | ✅ |
| 14 | Media picker: `MediaAction.record` με `kIsWeb` guard | ✅ |
| 15 | Chat preview: `🎵 Φωνητικό μήνυμα / Voice message` | ✅ |
| 16 | Κανένα Firestore/Storage/Index/Schema change required | ✅ |
| 17 | `flutter analyze`: clean ✅ | ✅ |

---

# 🔴 Ασφάλεια & GDPR — ΟΛΑ FIXED

| # | Θέμα | Session | Κατάσταση |
|---|------|:-------:|:---------:|
| 1 | Anonymous guards (requests/messages/block/report) | 57 | ✅ |
| 2 | Blocked users σε chat (rules + client) | 58-60 | ✅ |
| 3 | Screenshot Prevention (FLAG_SECURE) | 58 | ✅ |
| 4 | Delete Account CF (storage, requests, chats) | 62 | ✅ |
| 5 | Security Rules: `$(database)` αντί `(default)` | 72 | ✅ |
| 6 | Biometric Lock (widget + lifecycle + provider + auto-lock timer) | 73 | ✅ |
| 7 | `notBanned()`: claims → Firestore doc exists | 68 | ✅ |
| 8 | Chat rebuild loop + security rules | 70 | ✅ |
| 9 | Request validation chain (4 layers: UI + provider + repo + rules) | 71 | ✅ |
| 10 | Biometric lock bypass via FCM notification tap | 135 | ✅ |
| 11 | Grace period + pending nav guard (biometric always required if pending FCM) | 136 | ✅ |
| 12 | **6× PERMISSION_DENIED after signOut** — static isSigningOut flag + autoDispose + provider invalidation πριν signOut | 151 | ✅ |
| 13 | **Biometric idle timer running on inactive** (notification shade, phone call) — handle AppLifecycleState.inactive | 152 | ✅ |
| 14 | **Idle timer active after sign-out** — LockScreen over welcome screen — ref.listen(authStateProvider) stop+reset | 152 | ✅ |
| 15 | **addParticipant PERMISSION_DENIED** (όταν ≥2 μέλη) — callable CF (Admin SDK bypass) | 160 | ✅ |
| 16 | **markAsRead PERMISSION_DENIED** — CEL string interpolation + nested affectedKeys() fix | 160 | ✅ |
| 17 | **joinPublicGroup crash** — rules read/update fix + isPublic self-join OR rule | 169 | ✅ |
| 18 | **notBanned() gaps** — 17 chat/request rules missing ban check — isGroupMember() helper + memberCount OR rule | 170 | ✅ |

---

# Δοκιμές

| Τύπος | Αριθμός | Περιγραφή |
|-------|:-------:|-----------|
| Unit tests | 29 | PublicProfile serialization + city/country display |
| Widget test | 1 | MaterialApp renders |
| Manual | συνεχώς | 2 συσκευές (Android 12 + 16), all flows verified ✅ |
| `flutter analyze` | — | **0 issues** ✅ |

---

# Πρόοδος Sessions 69-205

| Session | Σημαντικό |
|:-------:|-----------|
| **69** | Comm settings cleanup, Anonymous UX fix, LookingFor +3 options |
| **70** | Chat rebuild loop fix: page keys, smart auth notifier, batch pagination |
| **71** | Auto-publish on comm change, Request validation (4 layers), client-side search filters |
| **72** | Feature Flags (8), Security Rules `$(database)` (6 helpers) |
| **73** | Biometric Lock: LockScreen widget, lifecycle hooks, provider toggle |
| **74** | Typesense stub `implements SearchRepository` |
| **75** | GoRouter errorBuilder (themed error page) |
| **76** | PresenceService race condition fix + `Future.wait` |
| **77** | `showPhotos` privacy toggle (schema v3→v4) |
| **78** | Profile Editor unsaved-changes dialog + biometric short-pause skip |
| **79** | Country field: `showCountry` toggle, publish, display (schema v4→v5) |
| **80** | Null-overwrite fix (`removeWhere`), unit tests (13), widget test fix |
| **81** | Phone verification (P2.5): state machine, OTP, guards |
| **82-90** | Σειρά polish: stale state, 30s timeout, inline spinners, prefixText, validation |
| **91** | Empty string vs null fix (firebase_auth 6.5.1) |
| **92** | SettingsScreen cascade rebuild fix (ConsumerStatefulWidget + ref.listen) |
| **93-94** | Unlink Phone + stale cache fix (`reload()`) |
| **95** | Unlink not visible after verify + MediaQuery analysis |
| **96** | `isOnline` preserve in `publish()` (Read+Preserve) |
| **97** | Country filter activation + GPS-first location (session cache) |
| **98** | Auto-fill city/country + auto-publish + Nominatim + `isManualLocation` + geoHash search fix |
| **99** | Debug logs for city-filter diagnosis |
| **100** | **Search fix**: `hasLocationFilter`, `WHERE country = ...` server-side, 2 new indexes |
| **101** | Deploy indexes, test city=Λαμία + country=Κίνα verified |
| | |
| **132** | `userChanges()` fix — `authStateChanges()` δεν εκπέμπει μετά από `reload()` |
| **133** | Firestore null cast fix — legacy docs missing `uid` |
| **134** | ChatScreen crash (`GoRouterState` σε `initState`) + raw AlertDialog→AppMessenger |
| **135** | Biometric lock bypass via FCM notification tap — `FcmService.isLocked` flag |
| **136** | FCM navigation after unlock — deleted `checkPendingNavigation()`, pre-lock guard |
| **137** | ProfileCards ~20× rebuild fix — `ValueKey` + `select()` + extract `SearchResultsGrid` |
| **138** | FCM retry mechanism (exponential backoff 1s→2s→4s, 3 retries) |
| **139** | Unread tracking για requests + FCM deep link `/requests/:requestId` |
| **140** | RenderFlex overflow fix (discovery + delete account: `LayoutBuilder` + `SingleChildScrollView`) |
| **141** | Image Cropper (1:1 avatar, free aspect ratio για photos) |
| **142** | Riverpod autoDispose race στο `_save()` — try-catch γύρω από `invalidate` |
| **143** | L2 badge iOS + L4 locale fallback `?? 'el'`→`?? 'en'` + **P0 city-filter Firestore crash** |
| **144** | Saved search bool DB fix (3 columns, schema v7→v8, verification) |
| **145** | Log review: 3 optimization issues found |
| **146** | Breakpoint spam fix — cache + 16/16 files constraint-based responsive |
| **147** | `_saveSearch()` stale state fix (local vars αντί provider) |
| **147b** | Duplicate Encrypt/Decrypt (3 fixes: reuse encrypt, cache, remove invalidate) |
| **148a** | RenderFlex overflow fix (request_card_widgets: Row→Wrap) |
| **148β** | Auto-scroll to last message on chat open |
| **149** | Auto-search after reset filters (preserve GPS) |
| **150** | 3 fixes: saved search apply async + city+radius→`_geoSearch` + GPS refresh |
| | |
| **151** | **6× PERMISSION_DENIED after signOut** — isSigningOut flag + autoDispose + provider invalidation |
| **152** | **Biometric fixes** — idle timer `inactive` handling + sign-out reset |
| **153** | **ChatCache duplicate bug** — remove `_saveChatCache` from createChat, `var rows`/`rows=[]` |
| **155** | **Online Status Flicker** — `streamOnline ?? profile.isOnline` null-coalescing |
| **156** | **Haversine Memoization** — `_distanceCache` → 96% reduction |
| **157** | **ConsentLog Pagination** — `LIMIT 50 OFFSET ?` + loadMore button |
| **158-163** | **MultiChat (Group Chat)** — 31/31 steps: CRUD, roles, permissions, invites, public groups, audit log, bilingual sys messages, FCM, 4 indexes |
| **164** | **showAvatar privacy toggle** — split photo privacy (schema v11→v12) |
| **165-166** | **Delete chat 1-to-1 flow** — request+approve/reject, maxParticipants display bug |
| **167** | chatsProvider dispose/recreate στο startup — `prev is AsyncData` guard |
| **168** | **Firestore Cost Phase B** — unreadCount map, parallel reads, conditional verify |
| **169** | **P0 joinPublicGroup crash** — rules fix + member status UI |
| **170** | **notBanned() σε 17 chat/request rules** + isGroupMember helper + memberCount fix |
| **171** | **leaveGroup callable CF** + GoError navigation race fix |
| **172-173** | GroupInfo search bug + blocked user bilingual error + disabled Chip UI |
| **174** | **Rebuild loop fix** — chatDocProvider cache + DeepCollectionEquality |
| **175-176** | **Media Input Plan** — Phase 1: Emoji Picker (emoji_picker_flutter v4.4.0) |
| **177-180** | Theme-aware EmojiPicker, rebuild isolation, instance cache |
| **181** | **Phase 2: GIF Support** — GIPHY API (Tenor discontinued) |
| **182** | **Phase 3: Large Emoji-Only** — EmojiOnlyBubble (font 64/48/36/28px) |
| **183** | **Profile Sync Across Chats** — nickname+avatar auto-sync |
| **184** | **Reaction System** — emoji reactions (Map<UID, emoji>), toggle, preset + custom |
| **185-186** | **Reply to Message** — long-press → reply banner → send (12 steps, 11 files) |
| **187** | **Viber-like Chat Redesign** — bubble tails, date separators, message grouping |
| **188-189** | **Chat rebuild storm** — GoRouterState removal, ValueKey, MainShell fix |
| **190-191** | **Phase 3: Image Messages** + Media "+" Popup + multiline TextField |
| **192-194** | ChatMessagesList rebuild fix, ReadReceiptIndicator widget, emoji card removal |
| **195-199** | **Rebuild cascade elimination** — pre-computed bubbleMaxWidth, markAsRead postFrameCallback, _SafeInputArea leaf, pending=true suppression |
| **200** | **messagesStream equality caching** — DeepCollectionEquality (chat_repository_impl) |
| **200** | **_MessageBubbleSignature + _obtainBubble cache** (chat_messages_list) |
| **201** | EmojiOnlyBubble _buildCounts cleanup + markAsRead guard (unreadCount==0 skip) |
| **201+** | **Bubble Width Bug fix** — IntrinsicWidth wrapper (text_message_bubble.dart) |
| **204-205** | **Audio Messages (Voice Messages)** — 22 SPoTs, record+audioplayers packages, AudioRecorderSheet, AudioMessageBubble, flutter analyze clean ✅ |

---

# Τρέχουσα Κατάσταση (Session 205)

| Μέτρο | Τιμή |
|---|---|
| Σύνολο `.dart` files | ~122 (μη generated) |
| Firestore indexes | 21 composite deployed |
| Cloud Functions | 6 deployed + `fcm-utils.ts` helper |
| Build | `flutter analyze` clean ✅, release APK ~15.8MB |
| Tests | 30/30 passed ✅ |
| Backup files | `backups/sound_message_20260724_130843/` |

## Υπόλοιπα Gaps

| Priority | Θέμα | Εκτίμηση |
|:--------:|------|:--------:|
| P3.2 | Message expiry (opt-in, CF scheduler) | 3-4 ώρες |
| P3.10 | Data export (GDPR portability) | ~1 εβδομάδα |
| Phase 4 | Typesense, Video (Agora), AI matching, Verified badge, Premium, Web, Admin | μήνες |

### Tech Debt
- Riverpod scheduler race (debug-only) — `Only one task can be scheduled at a time` σε respondToRequest. Deferred.
- Mock location detection — Pending.

## Key Conventions
- File size ≤ 500 lines (exceptions: profile_repository_impl ~570, chat_repository_impl ~590, group_chat_mixin ~971 with user permission)
- `DebugConfig.log(flag, msg)` σε κάθε operational action (34 flags, 3 levels)
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual el/en: `L10n.isGreek()` + `L10n.localizedMessage()`
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
- GPS-first location → session cache (5min) → last known → failure
- Shared AudioPlayer instance στο ChatScreen (StatefulWidget) — cascade prevention

## Firestore Security Rules (10+ helpers)
- `isAuthenticated()`, `isOwner(uid)`, `isParticipant(chatData)`
- `notBanned()` — `!exists(/banned/{uid})`
- `isVerified()` — `request.auth.token.email_verified == true || phone != null`
- `isGroupMember(chatId)` — `request.auth.uid in get(…).data.participants`
- `isGroupAdmin(chatId)` — `get(…).data.participantRoles[request.auth.uid] in ['admin', 'creator']`
- `isGroupChatRef(chatId)` — `get(…).data.isGroupChat == true`
- `isNotBlockedInChat(chatId)` — reads chat, checks other participant's blocked list
- `isNotBlockedByTarget(toUid)` — checks `/users/{toUid}/blocked/{request.auth.uid}`
- `targetCommAllowed(toUid, type)` — reads target public profile for isVisible + allowDirectChat/VideoCall
- `isPublicGroup(chatId)` — `get(…).data.isPublic == true`
