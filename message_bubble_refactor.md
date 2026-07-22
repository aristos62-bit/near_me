# MessageBubble Refactor — Τελική Πρόταση v2.0

## Συζήτηση — Ερωτήσεις & Απαντήσεις

### Ερώτηση 1 — Το MessageBubble κάνει υπερβολικά πολλά

**Προβληματισμός:** 779 γραμμές, παραβιάζει το file size limit (500), 3 widgets στο ίδιο αρχείο (MessageBubble, _SystemBubble, _GifBubble).

**Απάντηση:** Σωστά. Χωρίζεται σε εξειδικευμένα widgets.

### Ερώτηση 2 — Πολλά if(type)

**Προβληματισμός:** Αλυσίδα if για system/gif/image/text/emoji.

**Απάντηση:** Factory pattern με switch expression.

### Ερώτηση 3 — Πολύ μεγάλο build() (~250 γραμμές)

**Προβληματισμός:** Μη συντηρήσιμο.

**Απάντηση:** Λύνεται με τον διαχωρισμό σε leaf widgets.

### Ερώτηση 4 — Constructor με ~25 παραμέτρους

**Προβληματισμός:** MessageBubble δέχεται 21 params.

**Απάντηση:** MessageBubbleData model + MessageCallbacks.

### Ερώτηση 5 — bubbleMaxWidth constraint & widget cache

**Προβληματισμός:** _bubbleCache αποθηκεύει Widget instances → identity skip → stale layout. bubbleMaxWidth περνιέται από parent.

**Απάντηση:** Διαγραφή widget cache. Κάθε leaf widget υπολογίζει μόνο του το maxWidth με LayoutBuilder.

---

## Διορθωμένη Πρόταση v2.0 (μετά από επανέλεγχο)

### Τι άλλαξε από v1.0

Με βάση τον επανέλεγχο, εντόπισα τα εξής που μου είχαν διαφύγει:

| # | Τι διαπίστωσα | Επίπτωση στην πρόταση |
|---|--------------|----------------------|
| 1 | **`emoji_only_bubble.dart` κάνει import το `message_bubble.dart`** μόνο για το `ReplyPreview` και το `MessageActionBar` (που είναι ήδη ξεχωριστό) | Το import πρέπει να αλλάξει σε `reply_preview.dart` — ΔΕΝ δημιουργούμε νέο import cycle |
| 2 | **`isOnlyEmoji()` χρησιμοποιείται και στο `chat_input_bar.dart`** (3 φορές) — όχι μόνο στο MessageBubble | ΔΕΝ κάνουμε extract — η συνάρτηση μένει στο `emoji_only_bubble.dart` και γίνεται import από `chat_input_bar.dart` όπως ήδη γίνεται |
| 3 | **`_GifBubble` χειρίζεται ΚΑΙ gif ΚΑΙ image** — αλλά το image μέρος είναι μικρό (η διαφορά είναι μόνο το `onTap: isImage ? _showImageFullScreen : null` + `isImage` flag) | ΔΕΝ δημιουργούμε ξεχωριστό `ImageBubble` — κρατάμε ενιαίο `GifImageBubble` γιατί η επικάλυψη είναι ~95%. Αλλιώς θα είχαμε duplicate code |
| 4 | **`_showImageFullScreen()`** είναι private static μέθοδος 20 γραμμών — πολύ μικρή για ξεχωριστό widget | Μένει inline στο `GifImageBubble` |
| 5 | **`_MessageReadProps`** είναι private class στο `chat_messages_list.dart` — χρησιμοποιείται μόνο εκεί | ΔΕΝ το μετακινούμε — μένει ως έχει |
| 6 | **Κανένα formal Message model** δεν υπάρχει — όλα είναι `Map<String, dynamic>` | ΔΕΝ δημιουργούμε MessageBubbleData model σε αυτή τη φάση. Θα απαιτούσε αλλαγή σε repositories, providers, και ολόκληρο το data flow. Αλλάζουμε ΜΟΝΟ το UI layer |
| 7 | **`MentionService`** υπάρχει ήδη στο `shared/utils/mention_utils.dart` | Μπορούμε να το χρησιμοποιήσουμε στο `TextMessageBubble` αντί για inline regex |
| 8 | **`ReplyPreview`** και **`TailPainter`** είναι ήδη exportable — το `ReplyPreview` ήδη χρησιμοποιείται από `emoji_only_bubble.dart` | Απλή μεταφορά σε δικά τους αρχεία |
| 9 | **`ChatGroupingCalculator`** έχει το δικό του cache (`_cachedResults`, `_cachedMessages`), αλλά cache δεδομένων όχι widgets | ΔΕΝ το αγγίζουμε — είναι σωστό pattern |
| 10 | **`ResponsiveUtils.resolveWidth()`** υπάρχει στο `responsive_utils.dart` | Μπορούμε να το χρησιμοποιήσουμε για το bubble width αντί για hardcoded `w * 0.75` |

### Βασική απόφαση: Όχι MessageBubbleData model τώρα

Το `MessageBubbleData` model είναι καλή ιδέα μακροπρόθεσμα, αλλά:

- Θα απαιτούσε αλλαγή σε `chat_repository_impl.dart` (956 γραμμές), `chat_provider.dart` (617 γραμμές)
- Δεν λύνει κανένα από τα τρέχοντα bugs (layout cache, cold restart, rebuild cascade)
- Αυξάνει τον κίνδυνο regression χωρίς αντίστοιχο όφελος

**Αντί για model:** Κάθε leaf widget παίρνει το `Map<String, dynamic> message` και εξάγει internally τα πεδία που χρειάζεται. Αυτό είναι το ίδιο pattern που ήδη ακολουθεί ο κώδικας σήμερα.

---

## Πραγματικά Δεδομένα (από codebase analysis)

### Αρχεία που θα αλλάξουν

| Αρχείο | Γραμμές | Τι αλλάζει |
|--------|---------|-----------|
| `lib/features/chat/widgets/message_bubble.dart` | 779 | Διαγράφεται — αντικαθίσταται από φάκελο message_bubble/ |
| `lib/features/chat/widgets/chat_messages_list.dart` | 483 | Αφαίρεση cache system + direct MessageBubble |
| `lib/features/chat/widgets/emoji_only_bubble.dart` | 208 | Αλλάζει import (message_bubble → reply_preview) + αφαίρεση bubbleMaxWidth param |
| `lib/features/chat/widgets/chat_input_bar.dart` | 502 | ΚΑΜΙΑ αλλαγή (ήδη κάνει import emoji_only_bubble για isOnlyEmoji) |
| `lib/features/chat/screens/chat_screen.dart` | 399 | ΚΑΜΙΑ αλλαγή (μόνο import chat_messages_list) |

### Αρχεία που ΔΕΝ αλλάζουν

| Αρχείο | Λόγος |
|--------|-------|
| `message_reactions.dart` | Ήδη ξεχωριστό, δεν αλλάζει |
| `message_action_bar.dart` | Ήδη ξεχωριστό, δεν αλλάζει |
| `read_receipt_indicator.dart` | Ήδη ξεχωριστό shared widget |
| `chat_provider.dart` | Μόνο data layer, δεν αλλάζει |
| `chat_repository_impl.dart` | Μόνο data layer, δεν αλλάζει |
| `chat_ui_utils.dart` | Σωστό cache pattern (δεδομένα, όχι widgets) |
| `system_message_formatter.dart` | Δεν αλλάζει |
| `mention_utils.dart` | Θα το χρησιμοποιήσουμε, δεν το αλλάζουμε |

### Εξαρτήσεις (από search results)

```
message_bubble.dart χρησιμοποιείται από:
  └─ chat_messages_list.dart (import + MessageBubble constructor)
  └─ emoji_only_bubble.dart (import για ReplyPreview)

chat_messages_list.dart χρησιμοποιείται από:
  └─ chat_screen.dart (import + ChatMessagesList widget)
```

Κανένα άλλο αρχείο στο project δεν αναφέρει `MessageBubble`, `ReplyPreview`, `TailPainter`, `_obtainBubble`, `_bubbleCache`, ή `_MessageBubbleSignature`.

---

## Πλήρης Σχεδιασμός v2.0

### Βήμα 0 — Backup (κανόνας #7)

Δημιουργία backup φακέλου `backups/message_bubble_refactor_2026-07-22/` με:
- `message_bubble.dart`
- `chat_messages_list.dart`
- `emoji_only_bubble.dart`

### Βήμα 1 — Extract: `reply_preview.dart`

Μεταφορά `ReplyPreview` από `message_bubble.dart:12-57` σε δικό του αρχείο.

**Δεν αλλάζει τίποτα στην υλοποίηση** — απλή cut-paste.

**Imports που μεταφέρονται:** `package:flutter/material.dart`

### Βήμα 2 — Extract: `tail_painter.dart`

Μεταφορά `TailPainter` από `message_bubble.dart:59-77` σε δικό του αρχείο.

**Δεν αλλάζει τίποτα στην υλοποίηση.**

### Βήμα 3 — Extract: `system_message_bubble.dart`

Μεταφορά `_SystemBubble` από `message_bubble.dart:422-545` σε public class `SystemMessageBubble`.

**Αλλαγές:**
- `_SystemBubble` → `SystemMessageBubble` (public)
- Παίρνει τα δεδομένα του ως ξεχωριστά params (ίδιο pattern, χωρίς model)
- Χρησιμοποιεί ήδη `MediaQuery.of(context).size.width * 0.65` → σωστό, δεν αλλάζει

### Βήμα 4 — Extract & Split: `GifImageBubble`

Μεταφορά `_GifBubble` από `message_bubble.dart:547-777` σε public class `GifImageBubble`.

**Απόφαση:** Ενιαίο widget για GIF και Image. Λόγοι:
- ~95% κοινού κώδικα (CachedNetworkImage, tail, avatar, reactions, read receipt, reply preview, action bar)
- Μόνη διαφορά: `onTap` → `_showImageFullScreen` για images, null για GIFs
- Δύο ξεχωριστά widgets = duplication + διπλάσιο maintenance

**Αλλαγές:**
- `_GifBubble` → `GifImageBubble` (public)
- `_showImageFullScreen()` → παραμένει private static μέθοδος εδώ (20 γραμμές, too small για ξεχωριστό widget)
- Αφαίρεση `bubbleMaxWidth` param — χρήση `LayoutBuilder` internally

### Βήμα 5 — Create: `text_message_bubble.dart`

Νέο widget: `TextMessageBubble`.

Περιλαμβάνει:
- Text content + mentions rendering (μεταφορά `_buildRichContent` από `message_bubble.dart:378-418`)
- Bubble tail (TailPainter)
- Timestamp
- Reply preview (ReplyPreview)
- Long-press action (MessageActionBar)
- Avatar + sender nickname (για group chats)
- `LayoutBuilder` για maxWidth

**Δεν περιλαμβάνει:**
- Emoji-only (πάει σε EmojiOnlyBubble)
- Reactions (MessageReactions — ξεχωριστό)
- Read receipt (ReadReceiptIndicator — ξεχωριστό shared widget)

### Βήμα 6 — Update: `emoji_only_bubble.dart`

Αλλαγές:
- Import: `message_bubble.dart` → `reply_preview.dart` (το ReplyPreview είναι η μόνη εξάρτηση)
- Αφαίρεση `bubbleMaxWidth` param — χρήση `LayoutBuilder`
- `isOnlyEmoji()` και `emojiFontSize()` **παραμένουν εδώ** (χρησιμοποιούνται από chat_input_bar.dart)

### Βήμα 7 — Create: `message_bubble.dart` (factory router)

Νέο αρχείο, ~50 γραμμές, αντικαθιστά το παλιό.

```dart
class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String currentUid;
  final bool isGroupChat;
  final bool isRead;
  final bool isGrouped;
  final bool isLastInGroup;
  final bool showAvatar;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final Map<String, String>? participantNicknames;
  final List<String> seenBy;
  final String? chatId;
  final MessageCallbacks callbacks;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUid,
    this.isGroupChat = false,
    this.isRead = false,
    this.isGrouped = false,
    this.isLastInGroup = true,
    this.showAvatar = true,
    this.senderNickname,
    this.senderAvatarUrl,
    this.participantNicknames,
    this.seenBy = const [],
    this.chatId,
    this.callbacks = const MessageCallbacks(),
  });

  @override
  Widget build(BuildContext context) {
    final type = message['type'] as String? ?? 'text';
    final content = message['content'] as String? ?? '';
    final senderId = message['senderId'] as String? ?? '';
    final isMe = senderId == currentUid;

    return switch (type) {
      'system' => SystemMessageBubble(message: message, timeStr: ..., ...),
      'gif'  => GifImageBubble(message: message, ...),
      'image' => GifImageBubble(message: message, ...),
      _ when type == 'text' && isOnlyEmoji(content) 
          => EmojiOnlyBubble(message: message, ...),
      _ => TextMessageBubble(message: message, ...),
    };
  }
}
```

### Βήμα 8 — Create: `message_callbacks.dart`

```dart
class MessageCallbacks {
  final Future<void> Function(String chatId)? onApproveDelete;
  final Future<void> Function(String chatId)? onRejectDelete;
  final Future<void> Function(String chatId)? onDeleteForMe;
  final Future<void> Function(String chatId)? onKeepChat;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;
  final void Function()? onReply;
  final void Function()? onEdit;
  final void Function()? onDelete;

  const MessageCallbacks({
    this.onApproveDelete,
    this.onRejectDelete,
    this.onDeleteForMe,
    this.onKeepChat,
    this.onReact,
    this.onRemove,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });
}
```

Σημείωση: `onReply`, `onEdit`, `onDelete` αλλάζουν από `void Function(Map<String, dynamic> message)` σε `void Function()` — τα leaf widgets δεν χρειάζονται το raw message object για να καλέσουν το callback (τα callbacks στο chat_messages_list.dart ήδη ξέρουν το messageId).

### Βήμα 9 — Refactor: `chat_messages_list.dart`

**Διαγραφή:**
- `_MessageBubbleSignature` class (lines 25-82)
- `_bubbleCache` Map (line 112)
- `_bubbleSignatures` Map (line 113)
- `_obtainBubble()` method (lines 115-200)
- `_bubbleCache.removeWhere(...)` (line 362)
- `_bubbleSignatures.removeWhere(...)` (line 363)
- `DebugConfig.log('MSG_LIST: cache HIT/MISS...')` (lines 148-157)

**Προσθήκη:**
- Direct `MessageBubble(...)` στο `itemBuilder` (γραμμή 415)
- `MessageCallbacks(...)` με όλα τα callbacks
- Debug log για κάθε δημιουργία bubble (αντί για cache HIT/MISS)

```dart
itemBuilder: (_, i) {
  ...
  return MessageBubble(
    key: ValueKey(msgId),
    message: msg,
    currentUid: currentUid,
    isGroupChat: widget.isGroupChat,
    isRead: props.effectiveIsRead,
    isGrouped: item.isGrouped,
    isLastInGroup: item.isLastInGroup,
    showAvatar: item.showAvatar,
    senderNickname: senderNickname,
    senderAvatarUrl: senderAvatarUrl,
    participantNicknames: widget.participantNicknames,
    seenBy: props.seenBy,
    chatId: widget.chatId,
    callbacks: MessageCallbacks(
      onApproveDelete: _onApproveDelete,
      ...
    ),
  );
}
```

**Παραμένει:**
- `_MessageReadProps` class (για precomputed read state)
- `_precomputeReadProps()` method
- `_onMessagesChanged()` (για auto-scroll)
- `ChatGroupingCalculator.calculate()`
- Όλα τα callback methods (`_onApproveDelete`, `_onReact`, κλπ.)
- `_buildCount`, `_scrollCtrl`, lifecycle methods

### Βήμα 10 — Debug logging

| Σημείο | Flag | Τι log-άρει |
|--------|------|-------------|
| Factory router | `chatBubbleDesign` | `"MessageBubble: type=$type id=$msgId"` |
| TextMessageBubble | `chatBubbleDesign` | `"TextBubble: id=$msgId mentions=${mentions.length}"` |
| SystemMessageBubble | `chatBubbleDesign` | `"SystemBubble: action=$action isRequester=$isRequester"` |
| GifImageBubble | `chatBubbleDesign` | `"GifImageBubble: id=$msgId isImage=$isImage"` |
| EmojiOnlyBubble | `chatBubbleDesign` | Ήδη υπάρχει |
| chat_messages_list | `chatBubbleDesign` | `"MSG_LIST: create bubble id=$msgId"` (αντί για cache HIT/MISS) |
| Όλα τα leaf widgets | `uiInteraction` | Long-press action (reply/edit/delete) |
| Όλα τα leaf widgets | `uiRebuild` | Build counter (αν ενεργοποιηθεί το flag) |

---

## Edge Cases (10 documented)

| # | Edge Case | Πώς καλύπτεται |
|---|-----------|----------------|
| 1 | **Cold restart — stale constraints** | LayoutBuilder → πραγματικά constraints parent. Αν MediaQuery δεν έχει σταθεροποιηθεί, το LayoutBuilder δίνει σωστό πλάτος |
| 2 | **Orientation change** | Χωρίς widget cache, κάθε build είναι fresh instance. ValueKey(msgId) κάνει Element reuse, αλλά Widget instance είναι νέο |
| 3 | **Split-screen / foldable** | LayoutBuilder παίρνει constraints από parent, όχι από MediaQuery |
| 4 | **Empty message id** | Guard στο chat_messages_list.dart:360-361 (skip αν id.isEmpty) |
| 5 | **System message actions (delete_request)** | SystemMessageBubble αυτόνομο — παίρνει action + callbacks, ίδιο pattern |
| 6 | **GIF loading failure** | CachedNetworkImage errorWidget → broken_image icon (υπάρχει ήδη) |
| 7 | **Emoji + text mix** | Factory: isOnlyEmoji() check → αν false, πάει σε TextMessageBubble |
| 8 | **Mentions** | TextMessageBubble._buildRichContent() μεταφέρεται αυτούσιο |
| 9 | **Hot reload** | Χωρίς widget cache, hot reload λειτουργεί κανονικά |
| 10 | **Πολλαπλά chats ταυτόχρονα** | Κάθε ChatMessagesList έχει δικό του state → καμία cross-chat contamination |

---

## Flutter Lifecycle — Πριν vs Μετά

### Πριν
```
build() → _obtainBubble() → cache HIT → return cached Widget instance
→ Flutter: identical(old, new) → SKIP build → stale layout
→ orientation change → cache HIT → STALE
→ cold restart → cached instance with wrong constraints → STALE
```

### Μετά
```
build() → MessageBubble(key: ValueKey(msgId), ...)
→ Flutter: ValueKey matches → same Element → build() called with fresh Widget
→ LayoutBuilder → correct constraints always
→ orientation change → new Widget, new LayoutBuilder → correct
→ cold restart → MediaQuery/LayoutBuilder → correct from first frame
```

---

## Σύνοψη νέων/αλλαγμένων αρχείων

| Ενέργεια | Αρχείο | Γραμμές |
|----------|--------|---------|
| Δημιουργία | `message_bubble/message_bubble.dart` | ~50 (factory) |
| Δημιουργία | `message_bubble/message_callbacks.dart` | ~35 |
| Δημιουργία | `message_bubble/reply_preview.dart` | ~45 |
| Δημιουργία | `message_bubble/tail_painter.dart` | ~20 |
| Δημιουργία | `message_bubble/system_message_bubble.dart` | ~130 |
| Δημιουργία | `message_bubble/gif_image_bubble.dart` | ~200 |
| Δημιουργία | `message_bubble/text_message_bubble.dart` | ~120 |
| Τροποποίηση | `emoji_only_bubble.dart` | ~200 (μείον bubbleMaxWidth, αλλαγή import) |
| Τροποποίηση | `chat_messages_list.dart` | ~430 (μείον cache system) |
| Διαγραφή | `message_bubble.dart` (παλιό) | — |
| **Σύνολο νέου κώδικα** | | **~800 γραμμές** (αντί για 779 στο ένα αρχείο) |

---

## Σειρά Υλοποίησης

0. Backup message_bubble.dart, chat_messages_list.dart, emoji_only_bubble.dart
1. Δημιουργία `message_bubble/` φακέλου
2. Extract `reply_preview.dart`
3. Extract `tail_painter.dart`
4. Extract `system_message_bubble.dart`
5. Extract & refactor `gif_image_bubble.dart`
6. Create `message_callbacks.dart`
7. Create `text_message_bubble.dart`
8. Create factory `message_bubble.dart`
9. Update `emoji_only_bubble.dart` (αφαίρεση bubbleMaxWidth, αλλαγή import)
10. Refactor `chat_messages_list.dart` (αφαίρεση cache)
11. Διαγραφή παλιού `message_bubble.dart`
12. `flutter analyze` && `flutter test`
13. Αναφορά αποτελεσμάτων

---

---

## Phase 1 — Ολοκληρώθηκε ✅ (22 Ιουλίου 2026)

### Τι έγινε
Απομόνωση `ChatMessagesList` από το build tree του `ChatScreen`: αφαίρεση 4 constructor props (`isGroupChat`, `participantNicknames`, `participantAvatarUrls`, `otherUid`) και αντίστοιχη εσωτερική ανάγνωση από providers (`chatDocProvider.select()`, `participantUidsProvider`).

**Αλλαγές:**
- `chat_screen.dart`: `ChatMessagesList(chatId: widget.chatId)` — μόνο 1 prop
- `chat_messages_list.dart`: 4 internal `ref.watch(...)` για isGroupChat, participantNicknames, participantAvatarUrls, otherUid
- Backup: `backups\group1_fix_2026-07-22_225644\`

### Αποτέλεσμα Test (release build, ChatScreen #0)
| Μέτρο | Τιμή |
|-------|------|
| ChatScreen BUILD #0→#14 | Όλες οι ενέργειες (send, emoji, photo, reactions) |
| MSG_LIST BUILD #1→#25 | Κανένα crash, καμία regression |
| Emoji picker | ✅ Λειτουργεί |
| Camera photo send | ✅ Λειτουργεί |
| Reactions picker (+ icon) | ✅ Ορατό, `addReaction: success` |
| Reaction chips | ❌ **ΔΕΝ εμφανίζονται** (βλ. M5 update) |

### Επόμενο: Phase 2 (M3/M4 trigger reduction)
Στόχος: `const ChatMessagesList()` με zero constructor params (reading chatId από provider) → Flutter identity check → skip rebuild σε κάθε ChatScreen setState.

---

## Μετρικές Επιτυχίας

| Μέτρο | Πριν | Μετά |
|-------|------|------|
| message_bubble.dart γραμμές | 779 | ~50 (factory router) |
| Συνολικά αρχεία στον φάκελο | 0 | 6-7 |
| Widget cache (Widget instances) | Ναι | Όχι |
| bubbleMaxWidth dependency | Parent → child | Self-contained (LayoutBuilder) |
| Constructor params (MessageBubble) | 21 | 12 params + MessageCallbacks |
| Build() γραμμές (message_bubble.dart) | ~240 | ~15 |
| Κόστος αλλαγής (estimate) | — | 2-3 ώρες με testing |

---

## BUGS — Αναλυτική Καταγραφή & Κατάταξη

> Συλλεγμένα από 3 debug sessions μετά το refactor (22 Ιουλίου 2026)
> Session 1: 1-to-1 chat + group chat (είσοδος/έξοδος)
> Session 2: 2η είσοδος σε 1-to-1, αποστολή μηνύματος, έξοδος
> Session 3: 3η είσοδος, emoji picker, αποστολή emoji + GIF + photo
> Σύνολο builds στο Session 3: 21 MSG_LIST builds σε ~12 λεπτά
> Συμπεριλαμβάνει: orientation change (portrait↔landscape, 2 builds), photo picker (5 builds)

### 🔴 HIGH — FIXED

| # | Bug | Περιγραφή | Fix | Status |
|---|-----|-----------|-----|--------|
| H1 | **Cold restart — green card full-width** | Το widget cache (`_obtainBubble`) αποθήκευε instance → identity skip → stale layout. Σε cold restart, το πρώτο build είχε λάθος constraints και `build()` δεν ξανακαλούνταν ποτέ για το cached instance | Αφαίρεση όλου του cache system (`_MessageBubbleSignature`, `_bubbleCache`, `_bubbleSignatures`, `_obtainBubble`). `LayoutBuilder` + `ValueKey(msgId)` αντί για instance cache | ✅ **FIXED** |

### 🟡 MEDIUM — Προς Διόρθωση

| # | Bug | Περιοχή | Περιγραφή | Επίπτωση | Προτεινόμενο Fix |
|---|-----|---------|-----------|----------|-----------------|
| M1 | **Exit rebuild cascade (12-17× bubble rebuilds)** | `chat_messages_list.dart` + `chatsProvider` | Κατά την έξοδο από chat (back navigation), το `chatsProvider` κάνει emit (lightweight sync μετά το μήνυμα) → `ChatListScreen` rebuild → cascade στο `ChatMessagesList` που βρίσκεται ακόμα στο widget tree (exit animation). Τα ίδια bubbles ξαναχτίζονται 12-17 φορές στο ίδιο frame. | Frame drops σε slow devices. Ο χρήστης ΔΕΝ βλέπει το φλας (γίνεται κατά dispose). | (α) `isLeavingChat` flag για skip rebuild, (β) `AutoDispose` νωρίτερα, (γ) debounce στο lightweight sync όταν υπάρχει active exit animation |
| M2 | **ChatScreen `isGroupChat` delay** | `chat_screen.dart:161` | Το `isGroupChat` διαβάζεται από `chatDocProvider.select()`. Στην πρώτη build το provider δεν έχει κάνει emit → `isGroupChat=false`. Το app bar δείχνει "Προσωπικά μηνύματα" αντί για group name για 1-2 frames. | Οπτικό φλας (brief). Ο χρήστης βλέπει λάθος τίτλο για μια στιγμή. | Πέρασμα `isGroupChat` ως `extra` στο GoRouter route, ώστε να είναι διαθέσιμο από την πρώτη build χωρίς async lookup |
| M3 | **Emoji picker cascade — 7 MSG_LIST builds για 1 emoji** | `chat_screen.dart:118-126` + `_emojiPickerVisible setState` | Το `_toggleEmojiPicker()` καλεί `setState()` → ChatScreen rebuild → νέο `ChatMessagesList` instance → `build()` ξανά για ΟΛΑ τα μηνύματα. Cascade chain: BUILD #1 (init) → #2 (messages) → #3 (**emoji picker ON**, rebuild ×2 από keyboard/MediaQuery) → #4 (didChangeDependencies) → #5 (sendMessage, rebuild ×2) → #6 (**emoji picker OFF**, rebuild ×2) → #7 (pending→false). Σύνολο 7 builds για 111 μηνύματα. | Μεσαίο. Ο χρήστης δεν βλέπει φλας στα μηνύματα (Element reuse), αλλά το `EmojiPickerPanel` extraction είναι ήδη leaf widget, οπότε η ζημιά είναι περιορισμένη. Ωστόσο, 7 builds σε ένα frame μπορεί να προκαλέσουν frame drop (jank) σε slow devices, ειδικά με 111+ μηνύματα. | Απομόνωση `_emojiPickerVisible` σε ένα μικρό wrapper StatefulWidget γύρω από το `EmojiPickerPanel` + `Column` του input, ώστε το `setState` να μην ξαναχτίζει το `ChatMessagesList`. Εναλλακτικά, `ValueNotifier<bool>` + `AnimatedBuilder` ή μεταφορά του `_emojiPickerVisible` σε Riverpod provider αντί για `setState`. |
| M4 | **Picker sheet cascade — 7 MSG_LIST builds για 1 GIF** | `chat_screen.dart` → `didChangeDependencies` από `MediaPickerSheet` / `GifPickerSheet` | Όταν εμφανίζεται `MediaPickerSheet` (bottom sheet) → αλλάζουν view insets → `MediaQuery` change → `ChatScreen.didChangeDependencies()` → ChatScreen rebuild → ChatMessagesList rebuild. Ακολουθεί `GifPickerSheet` → 2ος `didChangeDependencies` → `ChatScreen` BUILD #5→#10. Μετά την αποστολή του GIF → αλυσίδα rebuilds #11→#14 (sendMessage, messagesProvider emit, pending→false). Σύνολο: 7 builds για ένα GIF. Κορύφωση `×28` στην factory router του MessageBubble (ίδια μηνύματα, 7×4 visible). | Μεσαίο. `×28` in `MessageBubble.build()` σημαίνει ότι το factory router `build()` εκτελέστηκε 28 φορές για ένα μήνυμα — 7 MSG_LIST builds × 4 visible items. Κάθε build καλεί `LayoutBuilder` → `Container.constraints` → νέο subtree. Αν και τα Elements επαναχρησιμοποιούνται (ValueKey), το Dart execution cost είναι μη αμελητέο (112 μηνύματα × 28 rebuilds). | (α) Απομόνωση `ChatMessagesList` σε leaf widget που ΔΕΝ κάνει rebuild όταν αλλάζει MediaQuery (override `didChangeDependencies` χωρίς super), (β) Wrapping του `ChatMessagesList` με `RepaintBoundary` + `const` constructor, (γ) αποφυγή `MediaQuery` reads στο ChatScreen που επηρεάζουν ChatMessagesList |
| ~~M5~~ | ~~**Reaction chips δεν εμφανίζονται σε real-time**~~ | ~~`chat_provider.dart:287-293`~~ | ~~**Αιτία:** Το `messagesStream` χρησιμοποιεί `orderBy('timestamp').snapshots()`. Όταν γίνεται `update({'reactions.$uid': emoji})`, το `timestamp` ΔΕΝ αλλάζει → Firestore snapshot ΔΕΝ triggerάρει~~ | ~~**Υψηλή**~~ | ✅ **FIXED** — `ref.invalidate(messagesProvider(chatId))` after `reactToMessage` + `removeReaction` |

### 🟢 LOW — Χαμηλής Προτεραιότητας

| # | Bug | Περιοχή | Περιγραφή | Επίπτωση | Προτεινόμενο Fix |
|---|-----|---------|-----------|----------|-----------------|
| L1 | **Extra MSG\_LIST BUILD #4 για group chats** | `chat_screen.dart` → `chat_messages_list.dart` | `groupPermissionsProvider` λύνει μετά τα messages → ChatScreen rebuild (λόγω `canInvite`/`canDeleteMsgs`) → ChatMessagesList λαμβάνει νέο widget instance → `build()` καλείται ξανά → new `itemBuilder` closures. | 1 extra build σε group chats. Τα Elements επαναχρησιμοποιούνται (ValueKey). Μηδενικό οπτικό κόστος. | Απομόνωση `groupPermissionsProvider` σε ξεχωριστό widget ώστε το rebuild του να μην επηρεάζει το ChatMessagesList |
| L2 | **EmojiOnlyBubble — λείπει LayoutBuilder** | `emoji_only_bubble.dart:96-164` | Το refactor plan (§Βήμα 6) προέβλεπε `LayoutBuilder` αντί για `bubbleMaxWidth` param. Η υλοποίηση έχει μόνο `Padding` χωρίς κανέναν περιορισμό πλάτους. | Ουσιαστικά καμία για τυπικά emoji-only μηνύματα (1-5 emojis). Θεωρητικά, ένα πολύ μακρύ string emojis θα εκτεινόταν στο πλήρες πλάτος. | Προσθήκη `LayoutBuilder` + `BoxConstraints(maxWidth: constraints.maxWidth * 0.75)` για συνέπεια με τα άλλα leaf widgets |
| L3 | **SystemMessageBubble — χρήση MediaQuery αντί LayoutBuilder** | `system_message_bubble.dart:45` | `MediaQuery.of(context).size.width * 0.65` αντί για `LayoutBuilder`. | Χαμηλό. Τα system messages είναι κεντραρισμένα και μικρά. Μόνο σε orientation change ή split-screen μπορεί να δώσει λάθος width. | Αντικατάσταση με `LayoutBuilder` |
| L4 | **MSG\_LIST debug log multiplier (×2 έως ×28)** | `chat_messages_list.dart:257-258` + `message_bubble.dart:61-62` | Το `'MSG_LIST: create bubble id=...'` τρέχει στο `itemBuilder`. Κάθε cascade αυξάνει τον counter. Στο Session 3, το `'MessageBubble: type=text id=... (×28)'` σημαίνει ότι το factory router `build()` εκτελέστηκε 28 φορές. Ανάλυση ×28: (α) ×4 MediaPickerSheet → didChangeDependencies, (β) ×4 GifPickerSheet, (γ) ×4 sendMediaMessage, (δ) ×4 messagesProvider emit, (ε) ×12 από 3 διπλότυπα frames (BUILD #10, #12, #14). | Μόνο debug noise, αλλά η κλίμακα (×28) δείχνει το πραγματικό κόστος του cascade. | Μεταφορά του log στο `MessageBubble` factory router + build counter αντί για logcat multiplier |
| L5 | **MessageBubble factory router ×28 rebuilds** | `message_bubble.dart:61-62` | Το `DebugConfig.log(DebugConfig.chatBubbleDesign, 'MessageBubble: type=$type id=$msgId')` εκτελείται σε κάθε `build()` του factory router. Για 4 visible μηνύματα × 7 MSG_LIST builds = 28 × factory router + 28 × leaf widget (TextBubble/GifImageBubble). Σύνολο: ~56 log lines για cascade 1 GIF. | Μηδενική. Τα debugs είναι conditional (μόνο όταν `chatBubbleDesign` flag ενεργό). Χωρίς το flag, το Dart execution είναι απλό string interpolation + boolean check. | — (εξαρτάται από M3/M4 fix — αν φύγει το cascade, φεύγει και το ×28) |
| L6 | **Orientation change — 2 MSG_LIST builds** | `chat_messages_list.dart` | Orientation portrait↔landscape → `MainShell` rebuild (isWide) → `ChatScreen` rebuild → `ChatMessagesList` rebuild. Στο Session 3: BUILD #15 (853px tablet) → BUILD #16 (384px mobile). Τα 2 builds έγιναν στο ίδιο frame, οπότε μόνο 1 layout/ render. | Καμία. 1 render για orientation change είναι το αναμενόμενο και αποδεκτό. Ο χρήστης βλέπει κανονική μετάβαση. | — (δεν χρειάζεται fix) |


### 📊 Συνοπτικός Πίνακας

| Priority | # | Bug | Effort Εκτίμηση | Depends On |
|:--------:|:-:|-----|:---------------:|:----------:|
| 🟡 MEDIUM | M1 | Exit rebuild cascade (17×) | 2-3 ώρες | — |
| 🟡 MEDIUM | M2 | isGroupChat delay | 1 ώρα | Route refactor (pass extra) |
| 🟡 MEDIUM | M3 | Emoji picker cascade (7 builds) | 2-3 ώρες | — |
| 🟡 MEDIUM | M4 | Picker sheet cascade (7 builds, ×28) | 2-3 ώρες | — |
| 🟡 MEDIUM | M5 | Reaction chips not real-time (Firestore nested field) | 2-3 ώρες (διάγνωση) | — |
| 🟢 LOW | L1 | Extra BUILD #4 group | 1-2 ώρες | Widget extraction |
| 🟢 LOW | L2 | EmojiOnlyBubble LayoutBuilder | 15 λεπτά | — |
| 🟢 LOW | L3 | SystemMessageBubble MediaQuery | 15 λεπτά | — |
| 🟢 LOW | L4 | MSG\_LIST debug log ×2-×28 | 5 λεπτά | M3/M4 |
| 🟢 LOW | L5 | Factory router ×28 rebuilds | — | M3/M4 |
| 🟢 LOW | L6 | Orientation change (2 builds) | — | — |

---

### 📊 Ομαδοποίηση κατά Ρίζα Αιτία

#### Ομάδα 1 — ChatScreen rebuild → ChatMessagesList rebuild (6 bugs)
**Ρίζα:** Το `ChatMessagesList` βρίσκεται μέσα στο build tree του `ChatScreen`. Κάθε rebuild του ChatScreen δημιουργεί νέο `ChatMessagesList` instance → `build()` τρέχει ξανά παρόλο που τα props είναι ίδια.

| Bug | Trigger | Μηχανισμός |
|:---:|---------|------------|
| **M1** | Exit navigation → `chatsProvider` emit | ChatScreen ακόμα alive (exit animation) → λαμβάνει provider emit → rebuild |
| **M3** | `_toggleEmojiPicker()` → `setState` | Αλλάζει `_emojiPickerVisible` → ολόκληρο ChatScreen rebuild |
| **M4** | `MediaPickerSheet` / `GifPickerSheet` → view insets | `MediaQuery` change → `didChangeDependencies` → ChatScreen rebuild |
| **L1** | `groupPermissionsProvider` resolves | ChatScreen rebuild → ChatMessagesList rebuild (μόνο group chats) |
| **L6** | Orientation change | `MainShell` rebuild (isWide) → ChatScreen rebuild |
| **L4/L5** | *(συνέπεια)* | Όσο περισσότερα ChatScreen rebuilds, τόσο μεγαλύτερος ο × multiplier |

**Προτεινόμενη Λύση (ενιαία):** Απομόνωση `ChatMessagesList` από το ChatScreen rebuild tree:
- Επιλογή 1: Wrap `ChatMessagesList` σε `ValueListenableBuilder` ή ξεχωριστό `Consumer` widget που ΔΕΝ ξαναχτίζεται όταν αλλάζει το ChatScreen
- Επιλογή 2: Override `didChangeDependencies` στο `ChatMessagesList` χωρίς να καλεί `super` (παίρνει μόνο όσα providers θέλει)
- Επιλογή 3: `RepaintBoundary` + `const` constructor ώστε το Flutter να συγκρίνει widget types και να κάνει skip αν τα props είναι ίδια

#### Ομάδα 2 — Ασυνεπής width constraint pattern στα leaf widgets (2 bugs)
**Ρίζα:** Κάθε leaf widget ακολουθεί διαφορετικό pattern για τον υπολογισμό του max bubble width.

| Bug | Widget | Τωρινό Pattern |
|:---:|--------|----------------|
| **L2** | `EmojiOnlyBubble` | Κανένα constraint (ούτε LayoutBuilder, ούτε MediaQuery) |
| **L3** | `SystemMessageBubble` | `MediaQuery.of(context).size.width * 0.65` |

**Αντίθεση:** `GifImageBubble` και `TextMessageBubble` χρησιμοποιούν `LayoutBuilder` + `constraints.maxWidth * 0.75`.

**Προτεινόμενη Λύση:** Ευθυγράμμιση όλων των leaf widgets στο `LayoutBuilder` pattern.

#### Ομάδα 3 — Data flow issues (2 bugs)
**Ρίζα:** Δεδομένα δεν είναι διαθέσιμα ή δεν προωθούνται σωστά στο render tree.

| Bug | Τι λείπει | Πού |
|:---:|-----------|-----|
| **M2** | `isGroupChat` από `chatDocProvider` | Στην πρώτη build, provider δεν έχει κάνει emit → false |
| **M5** | 🔴 **FIXED** | `reactions` map data στο leaf widget | **Αιτία:** `orderBy('timestamp').snapshots()` δεν triggerάρει για nested field update `reactions.$uid` — το `timestamp` δεν αλλάζει. **Fix:** `ref.invalidate(messagesProvider(chatId))` after `addReaction`/`removeReaction` (ίδιο pattern με `editMessage`) |

**Προτεινόμενη Λύση:**
- **M2:** Πέρασμα `isGroupChat` ως `extra` στο route (αποφυγή async lookup)
- **M5:** ✓ **FIXED** — `ref.invalidate(messagesProvider(chatId))` after `addReaction`/`removeReaction`

#### Ομάδα 4 — FIXED (2 bugs)
| Bug | Αιτία | Fix |
|:---:|-------|-----|
| **H1** | Widget instance cache (`_obtainBubble`) | `LayoutBuilder` + `ValueKey(msgId)` — **fixed** |
| **M5** | Firestore nested field update (`reactions.$uid`) | `ref.invalidate(messagesProvider(chatId))` after `reactToMessage`/`removeReaction` — **fixed** |

---

*Βασισμένο σε πλήρη ανάλυση codebase — 22 Ιουλίου 2026*
*107 .dart files, 21 composite indexes, 30 tests, flutter analyze clean*
