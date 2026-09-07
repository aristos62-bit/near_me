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

