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

