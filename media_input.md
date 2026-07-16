# NearMe — Media Input for Chats: Revised Analysis & Implementation Plan v2

> **Ημερομηνία:** 16 Ιουλίου 2026
> **Κατάσταση:** Phase 1 ✅ v4 — Emoji picker complete (cache, SPoT, decrypt log summary)
> **Κατάσταση:** Phase 2 ✅ — GIF Support complete (GIPHY API, picker sheet, media branch)

---

## 1. Υπάρχουσα Κατάσταση

### 1.1 Chat Input (`_ChatInputBar` — `chat_screen.dart:272-374`)

Private widget στο `chat_screen.dart`. Μόνο text input με `TextEditingController`. Send button + `TextInputAction.send`. `_isLoading` guard prevents double-send. `canComm` guard blocks unverified users.

**Κανένα media button, καμία ενσωμάτωση image_picker.**

---

## 2. Cost Analysis — Firebase Resources & Λειτουργικά Κόστη

### 2.1 Υπάρχον Κόστος (βάση σύγκρισης)

| Υπηρεσία | Υπάρχον μηνιαίο κόστος (1k χρήστες) |
|:---------|:-------------------------------------:|
| Firestore reads | ~€2.51 (Phase A+B optimization) |
| Firestore writes | ~€0.30 |
| Firebase Storage | ~€0.10 (avatars + photos) |
| Cloud Functions | ~€0 (1st Gen, free tier) |
| **Σύνολο** | **~€3/μήνα** |

### 2.2 Νέο Κόστος ανά Μήνυμα (ανά τύπο)

| Τύπος | Μέγεθος | Storage cost/μήνυμα | Download cost/προβολή | Σύνολο/μήνυμα |
|:-----:|:-------:|:-------------------:|:---------------------:|:--------------:|
| Text | ~200 bytes | €0 | €0 | **€0** |
| **GIF (Tenor CDN)** | **~500KB** | **€0** (δεν ανεβαίνει στο Storage μας) | **€0** | **€0** |
| **Photo (proposed)** | **~150KB** | **€0.0000039** | **€0.000018** | **€0.000022** |
| Photo (profile, 800px) | ~80KB | €0.0000021 | €0.0000096 | €0.000012 |
| **Video (proposed, 15MB limit)** | **~5MB** | **€0.00013** | **€0.0006** | **€0.00073** |
| Video raw (uncompressed, 100MB) | ~100MB | €0.0026 | €0.012 | €0.0146 |

### 2.3 Εκτίμηση Μηνιαίου Κόστους (1k χρήστες)

| Σενάριο | Μηνύματα/ημέρα | Storage/μήνα | Downloads/μήνα | **Σύνολο/μήνα** |
|:-------:|:--------------:|:------------:|:--------------:|:----------------:|
| **Χαμηλό** (10 φωτογραφίες, 0 video) | 10k φωτογραφίες | €0.04 | €0.18 | **€0.22** |
| **Μεσαίο** (20 φωτο+ 2 video/ημέρα) | 20k φωτο+ 2k video | €0.34 | €1.56 | **€1.90** |
| **Υψηλό** (50 φωτο+ 5 video/ημέρα) | 50k φωτο+ 5k video | €0.85 | €3.90 | **€4.75** |

### 2.4 Cost Optimization Decisions

| # | Απόφαση | Εξοικονόμηση | Λεπτομέρειες |
|:-:|---------|:------------:|--------------|
| 1 | **Χωρίς ffmpeg compression** (client-side) | ~€0.50/μήνα | Raw video = μεγαλύτερο κόστος. Compression on-by-default via feature flag. Αλλά στο baseline: size validation μόνο (15MB max) |
| 2 | **Image 1280×1280 max** (όχι 1920) | **~55% λιγότερο** | 1280px → ~150KB αντί ~350KB. Μείωση €0.12→€0.04/μήνα για μεσαίο σενάριο |
| 3 | **Image quality 70** (όχι 85) | **~30% λιγότερο** | Quality 70 είναι visually lossless για chat. ~150KB → ~100KB |
| 4 | **Video max 15MB** (όχι 30MB) | **50%** | Videos >15 δευτερολέπτων rarely watched in chat |
| 5 | **Auto-delete media >30 ημέρες** (CF scheduler) | **Μακροπρόθεσμα** | Αποτρέπει συσσώρευση. Προτείνεται για post-MVP |
| 6 | **Thumbnails μόνο 200px** (ήδη) | **~0.1% overhead** | Αμελητέο κόστος |
| 7 | **Storage cleanup on delete** (ήδη στον σχεδιασμό) | **Αποτρέπει orphan costs** | deleteAllChatMedia σε _deleteChatForEveryone + clearMessages |
| 8 | **EXIF stripping on photos** | **Privacy gain (όχι €)** | Image picker δεν αφαιρεί GPS metadata. Strip EXIF πριν upload για αποφυγή διαρροής τοποθεσίας |

### 2.5 Συμπέρασμα

Για **1k χρήστες** στο μεσαίο σενάριο:
- **Επιπλέον κόστος:** ~€1.90/μήνα (από ~€3 → ~€5 σύνολο)
- **Χωρίς optimization:** θα ήταν ~€4-5/μήνα (από €3 → €7-8)
- **Εξοικονόμηση optimization:** ~€2-3/μήνα
- **GIF:** €0 (Tenor free tier 10k/day, zero Storage cost)

**Μηδενικό κόστος από:** Firestore writes (ίδιο pattern με text), Cloud Functions (ίδιες), Tenor API (free tier 10k/day).

### 2.6 Cost-Aware Παράμετροι στην Υλοποίηση

```dart
class ChatMediaConfig {
  ChatMediaConfig._();

  static const int imageMaxWidth = 1280;
  static const int imageMaxHeight = 1280;
  static const int imageQuality = 70;

  static const int videoMaxSizeBytes = 15 * 1024 * 1024;

  static const Duration mediaRetentionDuration = Duration(days: 30);
}
```

---

## 3. Υπάρχουσες Λειτουργίες προς Reuse

| # | Λειτουργία | Αρχείο | Reuse για Media |
|:-:|-----------|--------|:----------------:|
| 1 | `ImagePicker().pickImage()` | `profile_editor_screen.dart:238` | Photo pick — **ίδιο pattern** |
| 2 | `ImageCropper().cropImage()` | `profile_editor_screen.dart:243-264` | Photo resize/crop — **ίδιο pattern** |
| 3 | `StorageService` (uploadAvatar/Photo) | `storage_service.dart` | **Επέκταση** με νέες μεθόδους (όχι νέα κλάση) |
| 4 | `updateGroupAvatar(dynamic image)` pattern | `group_chat_mixin.dart:676-699` | Accept `XFile` pattern |
| 5 | `_ChatInputBar._isLoading` guard | `chat_screen.dart:283` | Reuse for media send loading |
| 6 | `ChatActionsNotifier.sendMessage` | `chat_provider.dart:128-141` | Ίδιο state machine pattern |
| 7 | `chat_list_screen.dart:273` type=='image' | `chat_list_screen.dart` | Ήδη υπάρχει — μηδέν αλλαγή |
| 8 | `chat_cache_table.dart:lastMessageType` | `database.dart` | Ήδη υποστηρίζει 'image'/'video' |
| 9 | `_buildPreviewText` type switch | `chat_list_screen.dart:272-275` | Επέκταση με 'video' |
| 10 | `InteractiveViewer` full-screen pattern | (standard Flutter) | Reuse για photo viewer |
| 11 | `CachedNetworkImage` | Ήδη dependency | Reuse για image/gif bubbles |
| 12 | `part of 'chat_repository_impl.dart'` | `chat_repository_delete.dart` | Storage cleanup extension |

### 3.1 Message Types Status

| Type | `MessageBubble` | `messagesStream` | `chat_list_screen` | `chat_cache_table` |
|:----:|:---------------:|:----------------:|:-------------------:|:------------------:|
| text | ✅ | ✅ (decrypt) | ✅ | ✅ |
| system | ✅ | ✅ (skip decrypt) | ❌ (falls to default) | ✅ |
| **image** | **❌** | **❌** (θα crash αν decrypt) | ✅ **ήδη υπάρχει** | ✅ **ήδη υπάρχει** |
| **video** | **❌** | **❌** | **❌** | ✅ **ήδη υπάρχει** |
| **gif** | **❌** | **❌** | **❌** | **❌** |

### 3.2 Reuse Decision: Επέκταση StorageService (όχι νέα κλάση)

Το υπάρχον `StorageService` (storage_service.dart) έχει:
- `uploadAvatar(uid, bytes)`, `uploadPhoto(uid, index, bytes)`
- `deleteAvatar(uid)`, `deletePhoto(uid, index)`, `deleteAllUserFiles(uid)`

**Απόφαση:** Προσθήκη νέων μεθόδων στο ίδιο αρχείο αντί δημιουργίας `ChatStorageService`:
- `uploadChatMedia(chatId, messageId, bytes, contentType, {extension})` — επιστρέφει download URL (όπως uploadAvatar)
- `deleteChatMedia(chatId, messageId, {extension})`
- `deleteAllChatMedia(chatId)`

### 3.3 Codebase Compatibility Verification

Πριν την υλοποίηση, επαληθεύτηκε ότι ο υπάρχων κώδικας είναι συμβατός με media messages χωρίς αλλαγές:

| Έλεγχος | Αποτέλεσμα | Λεπτομέρειες |
|---------|:----------:|--------------|
| `chat_cache_table.dart` έχει `lastMessageType` | ✅ Υπάρχει | Προστέθηκε σε schema version μετά το blueprint v2.0 |
| `_buildPreviewText` στο `chat_list_screen.dart` | ✅ Ασφαλές | Ελέγχει `type` πριν χρησιμοποιήσει το `msg.content` — δεν crashάρει με media |
| `firestore.rules` message create rule | ✅ Συμβατό | Δεν περιορίζει fields — `type='image'`, `thumbnailUrl` κλπ. περνάνε χωρίς rule changes |
| Chat update rule (`lastMessage`, `lastMessageType`, `unreadCount`) | ✅ Συμβατό | Επιτρέπει ακριβώς τα πεδία που γράφει το `sendMediaMessage` |
| `part of` pattern (`chat_repository_delete.dart`) | ✅ Συνεπές | Το νέο `chat_repository_media.dart` ακολουθεί το ίδιο pattern |
| `unreadCount` map increment | ✅ Συνεπές | Ταιριάζει με το ήδη υλοποιημένο P1.5 optimization (Session 168) |
| Feature flags `false` by default | ✅ Συνεπές | Συνεπές με το υπάρχον `FeatureFlags` pattern |
| `messagesStream` decrypt attempt σε media path | ✅ Διαγνώστηκε (§7.5) | Χωρίς το media branch, το AES decrypt θα crashάρει ή θα δείξει "[Μη αναγνώσιμο μήνυμα]" |
| `deleteUserData` Cloud Function | ✅ Αμετάβλητο | Chat media είναι ανά chat, όχι ανά user — δεν χρειάζεται αλλαγή |

### 3.4 Reuse Decision: Unified sendMediaMessage

```dart
Future<void> sendMediaMessage(
  String chatId, {
  required Uint8List bytes,
  required String fileName,
  required String type,   // 'image' | 'video' | 'gif'
  Uint8List? thumbnailBytes,
});
```

---

## 4. Φάσεις Υλοποίησης (Revised — GIF πριν Photo/Video)

| Φάση | Τύπος | Νέα Αρχεία | Cost Impact (1k users) | Εκτίμηση |
|:----:|:-----:|:-----------|:----------------------:|:--------:|
| **1** | Emoji picker | 1 (chat_input_bar.dart) | €0 | ✅ v4 |
| **2** | GIF support | 2 (GiphyService + GifPickerSheet) | €0 (GIPHY free tier) | ✅ v1 |
| **3** | Photo sharing | 1 (chat_repository_media.dart — part file) | ~€0.04-0.18/μήνα | 2 ώρες |
| **4** | Video sharing | 0 (inline) | ~€0.30-1.56/μήνα | 3-4 ώρες |

**Σύνολο νέων αρχείων:** 4 (Emoji 1 + GIF 2 + Photo 1 + Video 0).
**Σύνολο επιπλέον κόστους:** ~€0.34-1.74/μήνα για 1k χρήστες (optimized).

**Αιτιολόγηση σειράς:** GIF = €0 κόστος, απλούστερο από photo/video, μέγιστο UX impact με μηδενικό operational risk.

---

## 5. Φάση 1 — Emoji Picker ✅ (v4 — 16/7/2026: Instance-level cache + SPoT alignment + decrypt log summary)

**Κόστος:** €0. Entirely client-side. Καμία επιβάρυνση σε Firestore, Storage, Cloud Functions, ή Tenor. Μόνο dependency: `emoji_picker_flutter` (free, MIT).

### 5.1 Προαπαιτούμενα & Μπλοκαρίσματα

| Έλεγχος | Κατάσταση | Αν χρειάζεται ενέργεια |
|---------|:---------:|-----------------------|
| `emoji_picker_flutter` στο pubspec.yaml | ✅ v4.4.0 | `flutter pub add emoji_picker_flutter` |
| `ChatInputBar` extraction | ✅ `chat_input_bar.dart` (~180γρ, v2 refactor) | Props-based: emoji state από ChatScreen |
| `EmojiPickerConfig` SPoT | ✅ `emoji_picker_config.dart` | Theme-aware Config factory + responsive height |
| `EmojiPickerPanel` isolation | ✅ `emoji_picker_panel.dart` (27γρ) | Leaf widget, MediaQuery/Theme isolation |
| `chat_screen.dart` — emoji state owner | ✅ Owns `_emojiPickerVisible`, `_textCtrl`, `_onEmojiSelected` | 3 selectors αντί 1 direct watch (Session 178) |
| `flutter analyze` | ✅ Clean | 0 issues |
| Feature flag για emoji | **Δεν χρειάζεται** | Client-side UI μόνο |
| Firestore / Storage / Cloud Functions | **Καμία αλλαγή** | Pure client-side |
| Device test (emoji toggle, insert at cursor, send) | ✅ **Verified** | 3 ανοίγματα verified. Zero ChatScreen rebuild storm. Μόνο EmojiPickerPanel rebuilds (internal package loading ~400ms) |

### 5.2 Εμπλεκόμενα Αρχεία

| Αρχείο | Αλλαγή | Γραμμές |
|--------|--------|:-------:|
| `pubspec.yaml` | +`emoji_picker_flutter: ^4.4.0` | +1 |
| `lib/features/chat/utils/emoji_picker_config.dart` | **ΝΕΟ (v2)** — Theme-aware Config factory + responsive height SPoT | 83 |
| `lib/features/chat/widgets/emoji_picker_panel.dart` | **ΝΕΟ (v4)** — StatefulWidget, instance cache, SPoT delegation, dispose log | 65 |
| `lib/features/chat/widgets/chat_input_bar.dart` | `ChatInputBar` (v2 refactor) — props-based, emoji logic removed, 4 props | ~180 |
| `lib/features/chat/screens/chat_screen.dart` | (v1) Extraction `_ChatInputBar`; (v2) emoji state owner + 3 selectors; (v3) `EmojiPickerPanel` αντί SizedBox/EmojiPicker | ~322 |
| `backups/chat_screen.dart.bak_2026-07-16_phase1` | Backup pre-extraction v1 | — |
| `backups/chat_screen.dart.bak_2026-07-16_v2` | Backup pre-refactor v2 | — |
| `backups/chat_screen.dart.bak_2026-07-16_emojiPanel` | Backup pre-EmojiPickerPanel v3 | — |
| `backups/chat_input_bar.dart.bak_2026-07-16_fix1` | Backup pre-Config fix | — |
| `backups/chat_input_bar.dart.bak_2026-07-16_v2` | Backup pre-refactor v2 | — |

### 5.3 Αλλαγές v2 (από audit — Sessions 177-178)

| # | Αλλαγή | Περιγραφή |
|:-:|--------|-----------|
| 1 | `EmojiPickerConfig` SPoT | Theme-aware Config factory, responsive height, locale-aware (`lib/features/chat/utils/emoji_picker_config.dart`) |
| 2 | `ChatInputBar` refactor | 213→180 γρ., emoji logic removed, 4 νέα props (`textEditingController`, `emojiPickerVisible`, `onEmojiToggle`, `onEmojiDismiss`) |
| 3 | `ChatScreen` emoji state owner | `_textCtrl`, `_emojiPickerVisible`, `_toggleEmojiPicker`, `_dismissEmojiPicker`, `_onEmojiSelected` |
| 4 | Rebuild storm fix (Session 178) | `participantUidsProvider` cache + `DeepCollectionEquality` + `select()` αντί direct `chatDocProvider` watch |

### 5.3β Αλλαγές v3 (Session 179 — EmojiPickerPanel extraction)

| # | Αλλαγή | Περιγραφή |
|:-:|--------|-----------|
| 1 | `EmojiPickerPanel` leaf widget | Απομονώνει `MediaQuery.of(context)`/`Theme.of(context)` — keyboard animation cascade rebuilds ΜΟΝΟ το panel, όχι ChatScreen |
| 2 | Debug log | `DebugConfig.log(DebugConfig.uiInteraction, 'EmojiPickerPanel build')` |
| 3 | Error boundary | `_onEmojiSelected()` wrapper με try-catch + `DebugConfig.error()` |
| 4 | Convention alignment | Responsive ✅, bilingual ✅, SPoT ✅, debug ✅, edge cases ✅ |

### 5.3γ Αλλαγές v4 (Session 180 — Cache, SPoT fix, decrypt log summary)

| # | Αλλαγή | Περιγραφή |
|:-:|--------|-----------|
| 1 | `EmojiPickerPanel` → StatefulWidget + instance cache | Instance-level `_cachedConfig`, `_cachedIsDark`, `_cachedIsGreek` — auto-dispose, zero memory leak |
| 2 | SPoT restoration | `_getConfig()` καλεί `EmojiPickerConfig.create()` αντί να ξαναγράφει factory — Config creation σε ένα σημείο |
| 3 | `dispose()` με debug log | `DebugConfig.log(DebugConfig.uiInteraction, 'EmojiPickerPanelState dispose')` + cache null |
| 4 | Static cache removed | `EmojiPickerConfig.create()` ξανά pure factory |
| 5 | `messagesStream` decrypt log summary | `decrypt cache N hits, M misses` αντί 30+ γραμμές `decrypt cache hit: msg=...` |
| 6 | Device test v4 | 4 ανοίγματα: `ChatScreen didChangeDependencies` 0-1×, Config creation **1×/open** (cache miss), μηδενικό rebuild storm |

### 5.4 Υπάρχοντες Κανόνες προς Reuse (από codebase)

| # | Pattern | Χρήση στο ChatInputBar |
|:-:|---------|------------------------|
| 1 | `ConsumerStatefulWidget` | Ολόκληρο το widget |
| 2 | `chatActionsProvider.notifier.sendMessage()` | `_send()` μέθοδος |
| 3 | `authStateProvider` + `canComm` guard | Έλεγχος verified user |
| 4 | `DebugConfig.uiInteraction` | Debug logs (init, dispose, toggle, build) |
| 5 | `L10n.isGreek(context)` | Bilingual hints + errors |
| 6 | `ResponsiveUtils` + `LayoutBuilder` | Responsive padding |
| 7 | `AppMessenger.showError` + `ErrorMessages.get` | Error handling |
| 8 | `_isLoading` + `mounted` guard | Double-send protection |
| 9 | `theme.colorScheme.surface` / `theme.dividerColor` | Container styling |
| 10 | `theme.colorScheme.surfaceContainerHighest.withAlpha(80)` | TextField fill |

### 5.5 Τρέχουσα Αρχιτεκτονική (v4)

```
ChatScreen (emoji state owner)
├── selectors: isGroupChat, groupName, participantNicknames (όχι direct chatDocProvider watch)
├── _textCtrl, _emojiPickerVisible, _toggleEmojiPicker, _dismissEmojiPicker, _onEmojiSelected
├── ChatMessagesList
├── EmojiPickerPanel (LEAF — StatefulWidget + instance cache)
│   └── _getConfig() → EmojiPickerConfig.create(context)   // SPoT + cache
└── ChatInputBar (props-based)
      ├── textController: _textCtrl
      ├── emojiPickerVisible: _emojiPickerVisible
      ├── onEmojiToggle: _toggleEmojiPicker
      └── onEmojiDismiss: _dismissEmojiPicker
```

#### emoji_picker_panel.dart (v4 — StatefulWidget + instance cache)

```dart
class EmojiPickerPanel extends StatefulWidget {
  final void Function(Category? category, Emoji emoji) onEmojiSelected;

  const EmojiPickerPanel({super.key, required this.onEmojiSelected});

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  Config? _cachedConfig;
  bool? _cachedIsDark;
  bool? _cachedIsGreek;

  Config _getConfig(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greek = L10n.isGreek(context);
    if (_cachedConfig != null && _cachedIsDark == isDark && _cachedIsGreek == greek) {
      return _cachedConfig!;
    }
    _cachedConfig = EmojiPickerConfig.create(context);   // SPoT
    _cachedIsDark = isDark;
    _cachedIsGreek = greek;
    return _cachedConfig!;
  }

  // ... dispose + build + error boundary
}
```

#### emoji_picker_config.dart (v2 — SPoT factory)

```dart
class EmojiPickerConfig {
  EmojiPickerConfig._();

  static Config create(BuildContext context) {
    // Theme-aware: backgroundColor, indicatorColor, iconColor, etc.
    // Locale-aware: L10n.isGreek(context) → el/en
    // 6 sub-configs: EmojiViewConfig, CategoryViewConfig, κλπ.
  }

  static double responsiveHeight(BuildContext context) {
    // 35% mobile, 30% tablet, 25% desktop (portrait)
    // 55% landscape
  }
}
```

#### ChatInputBar (v2 — props-based, emoji logic removed)

Το `ChatInputBar` είναι πλέον pure input bar — λαμβάνει `textEditingController`, `emojiPickerVisible`, `onEmojiToggle`, `onEmojiDismiss` ως props. Δεν διαχειρίζεται emoji state.

### 5.6 Τροποποίηση — chat_screen.dart

```diff
- import '../utils/emoji_picker_config.dart';
- import '../widgets/chat_input_bar.dart';
+ import '../widgets/chat_input_bar.dart';
+ import '../widgets/emoji_picker_panel.dart';

  // Στο body: Column, αντικατάσταση SizedBox/EmojiPicker:
- if (_emojiPickerVisible)
-   SizedBox(
-     height: EmojiPickerConfig.responsiveHeight(context),
-     child: EmojiPicker(
-       onEmojiSelected: _onEmojiSelected,
-       config: EmojiPickerConfig.create(context),
-     ),
-   ),
+ if (_emojiPickerVisible)
+   EmojiPickerPanel(onEmojiSelected: _onEmojiSelected),
```

### 5.7 Edge Cases & Θωράκιση (αναθεωρημένο v3)

| # | Σενάριο | Προστασία |
|:-:|---------|-----------|
| 1 | **Keyboard + emoji picker overlap** | `FocusScope.of(context).unfocus()` πριν show — picker αντικαθιστά το πληκτρολόγιο |
| 2 | **Picker ανοιχτό + πατάει TextField** | `_focusNode.listener` → `setState(() => _emojiPickerVisible = false)` |
| 3 | **Landscape mode** | `EmojiPickerConfig.responsiveHeight`: 55% landscape |
| 4 | **Insert emoji at cursor (όχι append)** | `_onEmojiSelected()`: `text.substring(0, pos)` + emoji + `text.substring(pos)` |
| 5 | **Rapid emoji taps** | Cursor position επαναϋπολογίζεται κάθε φορά — thread-safe |
| 6 | **Cursor not visible (no focus)** | `baseOffset` < 0 → emoji appended στο τέλος |
| 7 | **canComm = false** | Δεν εμφανίζεται emoji button (μόνο verified info UI) |
| 8 | **_isLoading = true** | Δεν εμφανίζεται emoji button |
| 9 | **Hot reload** | `_emojiPickerVisible` reset → picker εξαφανίζεται (αποδεκτό) |
| 10 | **App background → resume** | Emoji picker κλείνει αυτόματα από platform |
| 11 | **Route pop** | autoDispose → dispose chain: panel → providers → controller |
| 12 | **TextField με πολύ κείμενο** | Cursor-aware substring insertion |
| 13 | **iOS/Android keyboard** | `emoji_picker_flutter` handles natively |
| 14 | **Double-tap send** | `_isLoading` guard + `mounted` check |
| 15 | **EmojiPickerPanel callback throws** | Error boundary: try-catch + `DebugConfig.error()` |
| 16 | **Keyboard animation cascade rebuilds** | EmojiPickerPanel isolation — rebuilds μόνο panel, όχι ChatScreen |
| 17 | **Theme change while picker open** | `EmojiPickerConfig.create(context)` — theme-aware Config σε κάθε build |
| 18 | **Locale change while picker open** | `EmojiPickerConfig.create(context)` — locale-aware Config |

### 5.8 Flutter Lifecycle Analysis

| Event | Behavior |
|-------|----------|
| **Hot restart** | Full rebuild, picker closed ✅ |
| **Hot reload** | `_emojiPickerVisible` = false, picker closed ✅ |
| **App background** | Emoji picker κλείνει (platform gesture) ✅ |
| **App resume** | `mounted` check σε pending async operations ✅ |
| **Route pop** | `ChatInputBar.dispose()` → `_focusNode.dispose()` + `_textCtrl.dispose()` ✅ |
| **Widget rebuild (setState)** | Μόνο emoji picker section rebuild ✅ |
| **Chat scroll (messages list)** | Picker below ListView, unaffected ✅ |
| **System back** | Emoji picker κλείνει ✅ |

### 5.9 Memory

| Στοιχείο | Μέγεθος | Διαχείριση |
|----------|:-------:|-----------|
| Emoji picker | ~2MB | allocated once, released on dispose |
| FocusNode | ~0.5KB | released on dispose |
| TextEditingController | ~1KB | released on dispose |
| Emoji data | ~500KB (cached by package) | cached, released on dispose |

### 5.10 Implementation Order

| Βήμα | Ενέργεια | Επαλήθευση |
|:----:|----------|:----------:|
| 1 | `flutter pub add emoji_picker_flutter` | pubspec.yaml ενημερωμένο |
| 2 | Backup `chat_screen.dart` → `backups/` | Αρχείο υπάρχει |
| 3 | Δημιουργία `chat_input_bar.dart` | `flutter analyze` ✅ |
| 4 | Αφαίρεση `_ChatInputBar` από `chat_screen.dart` + import | `flutter analyze` ✅ |
| 5 | `flutter run` + device test: emoji toggle, insert at cursor, send | Λειτουργικό ✅ |

### 5.11 Σύνοψη Flags, Keys & Guards

| Flag/Guard | Τύπος | Τιμή | Πού ορίζεται |
|------------|:-----:|:----:|:------------:|
| `emoji_picker_flutter: ^4.4.0` | dependency | — | pubspec.yaml |
| `_emojiPickerVisible` | local state | false | chat_screen.dart |
| `_textCtrl` | TextEditingController | new | chat_screen.dart |
| `_focusNode` | FocusNode | new | chat_input_bar.dart |
| `_isLoading` | local state | false | chat_input_bar.dart |
| `canComm` | computed | AuthRepository.canUserCommunicate() | chat_screen.dart |
| `mounted` | lifecycle | State.mounted | chat_input_bar.dart |
| `EmojiPickerPanel` | leaf widget | — | emoji_picker_panel.dart |
| `EmojiPickerConfig` | SPoT | — | emoji_picker_config.dart |
| `_cachedConfig` / `_cachedIsDark` / `_cachedIsGreek` | instance cache | null | emoji_picker_panel.dart |
| Feature flag | **Δεν χρειάζεται** | — | — |

### 5.12 Δεν χρειάζονται αλλαγές

Backend, encryption, message type, database schema, chat list, Firestore rules, Storage rules, Cloud Functions, feature flags, debug flags, error messages — **κανένα**.

Το emoji picker είναι pure client-side UI: δεν αλλάζει το message format, δεν γράφει στο Firestore διαφορετικά, δεν χρειάζεται νέο type. Απλά εισάγει emoji characters στο ίδιο text field.

---


## 6. Φάση 2 — GIF Support ✅ (Ολοκληρωμένη — 16/7/2026)

**Κόστος:** €0. GIFs από GIPHY CDN — κανένα upload στο δικό μας Storage. GIPHY free tier 10k requests/hour.

> **Σημείωση:** Η αρχική πρόταση χρησιμοποιούσε Tenor API, αλλά το Tenor API διακόπηκε στις 30 Ιουνίου 2026. Αντικαταστάθηκε με **GIPHY API** (`api.giphy.com/v1/gifs`).

### 6.0 Προαπαιτούμενα & Μπλοκαρίσματα ✅ (Όλα επιλύθηκαν)

| # | Προαπαιτούμενο | Τύπος | Κατάσταση |
|:-:|---------------|:-----:|:---------:|
| 1 | **`messagesStream` media branch** | **BLOCKING** | ✅ media branch προστέθηκε (`type == 'gif' \|\| type == 'image' \|\| type == 'video'` skip decrypt) |
| 2 | **GIPHY API key** | **Config** | ✅ `--dart-define=GIPHY_API_KEY` |
| 3 | **Feature flag** | Config | ✅ `gifSupportEnabled = true` (ενεργοποιήθηκε μετά από testing) |

### 6.1 Επαναχρησιμοποίηση Υπαρχόντων

| Ανάγκη | Υπάρχον Αρχείο | Τρόπος Reuse |
|--------|----------------|:------------:|
| HTTP client | `location_autocomplete_service.dart:39` — `dart:io` `HttpClient()` | **Ίδιο pattern** — connectionTimeout, headers, getUrl |
| API key config | `debug_config.dart:25` — `--dart-define=ENABLE_RELEASE_DEBUG` | **Ίδιο pattern** — `--dart-define=GIPHY_API_KEY` + `String.fromEnvironment()` |
| Image loading | `CachedNetworkImage` (ήδη στο pubspec.yaml) | **Ίδιο package** για GIF bubble |
| Error mapping | `chat_provider.dart:253` `_friendlyError()` + `error_messages.dart` | **Αλυσίδα** — `AppException` → error code → `ErrorMessages.get()` |
| Feature flag check | `group_call_screen.dart:19` — `FeatureFlags.videoCallEnabled` | **Ίδιο pattern** — `if (FeatureFlags.gifSupportEnabled)` |
| Message rendering | `message_bubble.dart` — timeStr, isMe, seenBy, group nickname | **Ίδια δομή** για `_GifBubble` |
| Chat list preview | `chat_list_screen.dart:272-274` — `_buildPreviewText` | **Επέκταση** — `'gif'` → `'🎞️ GIF'` |

**Κανένα νέο dependency.** `dart:io` `HttpClient` όπως το `location_autocomplete_service.dart`.

### 6.2 Νέα Αρχεία (2 υλοποιήθηκαν)

#### 6.2.1 `lib/shared/utils/giphy_service.dart` — SPoT GIPHY API (~100 γραμμές)

```
class GiphyService
  - static const _apiKey = String.fromEnvironment('GIPHY_API_KEY')
  - _baseUrl = 'https://api.giphy.com/v1/gifs'
  - HttpClient με connectionTimeout 6s

  Future<List<GiphyGif>> search(String query, {int limit = 20})
    → GET /search?api_key=_apiKey&q=query&limit=20&rating=g
    → DebugConfig.log(DebugConfig.repositoryCall, 'GiphyService.search: q=$query')

  Future<List<GiphyGif>> trending({int limit = 20})
    → GET /trending?api_key=_apiKey&limit=20&rating=g

class GiphyGif
  - id, url (original), previewUrl (fixed_width), width, height
  - factory GiphyGif.fromJson(Map<String, dynamic> json)
```

#### 6.2.2 `lib/features/chat/widgets/gif_picker_sheet.dart` — SPoT GIF UI (~150 γραμμές)

```
showGifPickerSheet(BuildContext context, {required void Function(String gifUrl) onSelected})
  → bottom sheet

Structure:
  - Search TextField με debounce 300ms
  - GridView.builder (2 columns, 200px tiles)
  - Initial load: trending GIFs από GiphyService.trending()
  - Search: GiphyService.search() με debounce
  - Loading: shimmer placeholders
  - Empty: bilingual "Δεν βρέθηκαν GIF / No GIFs found"
  - Error: bilingual "Σφάλμα φόρτωσης / Failed to load" + retry
  - Tap GIF → Navigator.pop(context, gifUrl)

Edge cases:
  - No internet → error snackbar
  - Empty query → trending
  - Rapid typing → debounce cancels previous
  - GIPHY rate limit → error snackbar
```

### 6.3 Τροποποιημένα Αρχεία (9) ✅

| # | Αρχείο | Αλλαγή |
|:-:|--------|--------|
| 1 | `lib/core/config/feature_flags.dart` | +`gifSupportEnabled = false` (τέθηκε `true` μετά από testing) |
| 2 | `lib/core/utils/error_messages.dart` | +`chat/gif-send-failed`, `chat/gif-api-error` (bilingual) |
| 3 | `lib/repositories/chat_repository.dart` | +`sendMediaMessage(chatId, {content, type})` abstract |
| 4 | `lib/repositories/chat_repository_impl.dart` | **2 αλλαγές**: (α) `sendMediaMessage` impl (β) media branch `type == 'gif' \|\| type == 'image' \|\| type == 'video'` |
| 5 | `lib/features/chat/providers/chat_provider.dart` | +`sendMediaMessage(chatId, {content, type})` στο `ChatActionsNotifier` |
| 6 | `lib/features/chat/widgets/chat_input_bar.dart` | + GIF button (`Icons.gif_box_outlined`) + `_pickGif()` |
| 7 | `lib/features/chat/widgets/message_bubble.dart` | +`if (type == 'gif')` → `_GifBubble` με `CachedNetworkImage` (maxHeight=200) |
| 8 | `lib/features/chat/screens/chat_list_screen.dart` | +`'gif'` → `'🎞️ GIF'` στο `_buildPreviewText` |
| 9 | `lib/features/chat/screens/chat_screen.dart` | Καμία αλλαγή (GIF picker = bottom sheet, όχι inline state) |

### 6.4 Υλοποιημένες Τροποποιήσεις ✅

**(Ακολουθείται η αρχική πρόταση, με Tenor→GIPHY.)**

#### 6.4.1 `feature_flags.dart`
```dart
static const bool gifSupportEnabled = true;  // Ενεργοποιήθηκε μετά από testing
```

#### 6.4.2 `error_messages.dart`
```dart
case 'chat/gif-send-failed':
  return isGreek ? 'Αποστολή GIF απέτυχε' : 'GIF send failed';
case 'chat/gif-api-error':
  return isGreek ? 'Σφάλμα φόρτωσης GIF' : 'GIF loading error';
```

#### 6.4.3 `chat_repository.dart` — Interface + `chat_repository_impl.dart` sendMediaMessage

#### 6.4.4 `chat_repository_impl.dart` — messagesStream media branch:
```dart
} else if (type == 'gif' || type == 'image' || type == 'video') {
  decrypted = encrypted;  // URL, όχι decrypt
}
```

#### 6.4.5 `chat_provider.dart` — ChatActionsNotifier.sendMediaMessage()
#### 6.4.6 `chat_input_bar.dart` — GIF button + `_pickGif()`
#### 6.4.7 `message_bubble.dart` — `_GifBubble` (CachedNetworkImage, maxHeight=200)
#### 6.4.8 `chat_list_screen.dart` — `'gif'` → `'🎞️ GIF'`

### 6.5 Device Test Results ✅
```
GiphyService.trending: limit=20
GiphyService.search: q=smile limit=20
GifPickerSheet: selected
sendMediaMessage: success chat=SOuOdL9ojVQsAzt9Zy4u type=gif
messagesStream: media message t1GACtYRznH1yrvXJs4W type=gif
decrypt cache 27 hits, 0 misses for chat=SOuOdL9ojVQsAzt9Zy4u
```

### 6.6 Tenor → GIPHY Migration Note

| Πάροχος | URL | Free Tier |
|:--------|:---:|:---------:|
| ~~Tenor~~ (discontinued 30/6/2026) | ~~tenor.googleapis.com/v2~~ | ~~10k/day~~ |
| **GIPHY** ✅ | `api.giphy.com/v1/gifs` | **10k/hour** |

Το `tenor_service.dart` διαγράφηκε. Δημιουργήθηκε `giphy_service.dart` (ίδιο pattern: `dart:io` `HttpClient`, `--dart-define=GIPHY_API_KEY`).

---


## 7. Φάση 3 — Photo Sharing

### 7.1 Message Schema

```dart
{
  'id': auto-generated,
  'type': 'image',        // 'image' | 'video' | 'gif'
  'senderId': uid,
  'content': download_url, // download URL από getDownloadURL()
  'encrypted': false,     // ← forward-compatible: false τώρα, true αν προστεθεί Ε2Ε
  'timestamp': Timestamp,
  'isRead': false,
}
```

**Απόφαση:** Media messages ΔΕΝ κρυπτογραφούνται (v1). Το `content` είναι Firebase Storage URL (προστατευμένο από Storage rules participant check — βλ. §7.11).
**Λόγος:** AES-256-GCM σε MB αρχεία είναι βαρύ σε mobile. Firebase Storage encryption at rest + Storage rules με participant check.

**Forward-compatible:** Το `encrypted: false` flag επιτρέπει μελλοντική προσθήκη E2E χωρίς migration — παλιά messages δουλεύουν, νέα με `encrypted: true` ακολουθούν διαφορετικό path στο `_MediaBubble`.

### 7.2 Επέκταση StorageService (storage_service.dart)

```dart
  Future<String> uploadChatMedia({
  required String chatId,
  required String messageId,
  required Uint8List bytes,
  required String contentType,
  String? extension,
}) async {
  final ext = extension ?? (contentType.contains('video') ? 'mp4' : 'jpg');
  final ref = _storage.ref().child('chat_media/$chatId/$messageId.$ext');
  try {
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();  // Ίδιο pattern με uploadAvatar/Photo
    return url;  // επιστρέφουμε download URL
  } catch (e, s) {
    throw AppException.storage('uploadChatMedia', e, s);
  }
}

Future<void> deleteChatMedia(String chatId, String messageId, {String? extension}) async {
  final ext = extension ?? 'jpg';
  try {
    await _storage.ref().child('chat_media/$chatId/$messageId.$ext').delete();
  } catch (e) {
    DebugConfig.warn('deleteChatMedia: may not exist', data: e);
  }
}

Future<void> deleteAllChatMedia(String chatId) async {
  try {
    final ref = _storage.ref().child('chat_media/$chatId');
    final result = await ref.listAll();
    for (final item in result.items) { await item.delete(); }
  } catch (e) {
    DebugConfig.warn('deleteAllChatMedia failed', data: e);
  }
}
```

### 7.3 ChatRepository Interface (chat_repository.dart)

```dart
abstract class ChatRepository {
  Future<void> sendMessage(String chatId, String content);

  Future<void> sendMediaMessage(
    String chatId, {
    required Uint8List bytes,
    required String fileName,
    required String type,
    Uint8List? thumbnailBytes,
  });
}
```

### 7.4 ChatRepositoryImpl.sendMediaMessage (chat_repository_media.dart)

```dart
@override
Future<void> sendMediaMessage(
  String chatId, {
  required Uint8List bytes,
  required String fileName,
  required String type,
  Uint8List? thumbnailBytes,
}) async {
  final user = auth.currentUser;
  if (user == null) throw AppException.auth('send_media', 'No user');
  if (!AuthRepository.canUserCommunicate(user)) {
    throw AppException.auth('send_media', 'Verify required');
  }

  // 🔴 Block check — group-conditional (Session 159 fix)
  if (!isGroupChat) {
    // ... block check only for 1-to-1 (groups handled by Firestore rules)
  }

  final msgRef = firestore.collection('chats').doc(chatId)
      .collection('messages').doc();
  final msgId = msgRef.id;

  // 1. Upload to Storage
  final contentType = type == 'video' ? 'video/mp4' : 'image/jpeg';
  final ext = type == 'video' ? 'mp4' : 'jpg';
  final downloadUrl = await _storageService.uploadChatMedia(
    chatId: chatId, messageId: msgId,
    bytes: bytes, contentType: contentType, extension: ext,
  );

  // 2. Upload thumbnail (video only)
  String? thumbnailUrl;
  if (thumbnailBytes != null && type == 'video') {
    try {
      thumbnailUrl = await _storageService.uploadChatMedia(
        chatId: chatId, messageId: '${msgId}_thumb',
        bytes: thumbnailBytes, contentType: 'image/jpeg', extension: 'jpg',
      );
    } catch (e) {
      DebugConfig.warn('sendMediaMessage: thumbnail upload failed', data: e);
    }
  }

  // 3. Firestore batch write — αποθηκεύουμε download URL
  final batch = firestore.batch();
  final msgData = <String, dynamic>{
    'senderId': user.uid,
    'content': downloadUrl,
    'type': type,
    'timestamp': FieldValue.serverTimestamp(),
    'isRead': false,
  };
  if (thumbnailUrl != null) msgData['thumbnailUrl'] = thumbnailUrl;
  batch.set(msgRef, msgData);

  final updateData = <String, dynamic>{
    'lastMessageAt': FieldValue.serverTimestamp(),
    'lastMessageBy': user.uid,
    'lastMessage': downloadUrl,
    'lastMessageType': type,
  };
  for (final p in participants) {
    if (p != user.uid) updateData['unreadCount.$p'] = FieldValue.increment(1);
  }
  batch.update(chatRef, updateData);
  await batch.commit();
  await updateChatCache(chatId, hasUnread: false);
}
```

### 7.5 messagesStream — Media Handling (chat_repository_impl.dart)

```dart
// Στο asyncMap, ΜΕΤΑ το decrypt block:
String displayContent;
final type = data['type'] as String? ?? 'text';

if (type == 'image' || type == 'video' || type == 'gif') {
  // Media messages: content = download URL, no decryption
  displayContent = encrypted;
} else if (type == 'system') {
  displayContent = encrypted;
} else {
  // text — decrypt (υπάρχον)
  displayContent = decrypted;
}
```

**Κρίσιμο:** Χωρίς αυτή την αλλαγή, η decryptMessage() θα crashάρει με URL string.

**Known side-effect:** Τα `_syncChatFromFirestore` / `_syncGroupChatToCache` διαβάζουν το `lastMessage` από το chat doc και προσπαθούν να το αποκρυπτογραφήσουν (δεν γνωρίζουν τον τύπο πριν το attempt). Για media messages, το decrypt θα αποτύχει σιωπηλά (try/catch) και το preview θα εμφανιστεί σωστά μέσω `lastMessageType` guard. Αμελητέο CPU κόστος — δεν επηρεάζει λειτουργικότητα ούτε Firestore reads.

### 7.6 ChatActionsNotifier (chat_provider.dart)

```dart
Future<bool> sendMediaMessage(String chatId, {
  required Uint8List bytes,
  required String fileName,
  required String type,
  Uint8List? thumbnailBytes,
}) async {
  state = const ChatActionState(status: ChatActionStatus.loading);
  try {
    await _chatRepo.sendMediaMessage(chatId,
        bytes: bytes, fileName: fileName, type: type,
        thumbnailBytes: thumbnailBytes);
    state = const ChatActionState(status: ChatActionStatus.success);
    return true;
  } catch (e, s) {
    state = ChatActionState(status: ChatActionStatus.error,
        errorMessage: _friendlyError(e));
    return false;
  }
}
```

### 7.7 _ChatInputBar — Photo Pick Button (chat_input_bar.dart)

**Προστέθηκε κάμερα + EXIF stripping note:**

```dart
final ImagePicker _picker = ImagePicker();

// Στο Row, ΠΡΙΝ από το Expanded TextField:
IconButton(
  icon: const Icon(Icons.photo_library_outlined),
  onPressed: _pickAndSendPhoto,
),
IconButton(
  icon: const Icon(Icons.photo_camera_outlined),
  onPressed: _pickAndSendCamera,  // ΝΕΟ: λήψη από κάμερα
),

Future<void> _pickAndSendPhoto({bool fromCamera = false}) async {
  try {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: ChatMediaConfig.imageMaxWidth,
      maxHeight: ChatMediaConfig.imageMaxHeight,
      imageQuality: ChatMediaConfig.imageQuality,
    );
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1024, maxHeight: 1024,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: ChatMediaConfig.imageQuality,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: '', toolbarColor: Colors.transparent),
        IOSUiSettings(),
      ],
    );
    final imageFile = cropped ?? picked;
    final bytes = await imageFile.readAsBytes();
    // TODO: EXIF stripping — remove GPS + device metadata before upload
    // Χρήση flutter_image_compress ή native exif removal
    // Βλ. Security Addendum §10

    if (!mounted) return;
    setState(() => _isLoading = true);
    final ok = await ref.read(chatActionsProvider.notifier)
        .sendMediaMessage(widget.chatId,
            bytes: bytes, fileName: imageFile.name, type: 'image');
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      AppMessenger.showError(context, ErrorMessages.get(
          'chat/media-send-failed', L10n.isGreek(context)));
    }
  } catch (e, s) {
    DebugConfig.error('_pickAndSendPhoto failed', data: e, exception: s);
  }
}

Future<void> _pickAndSendCamera() => _pickAndSendPhoto(fromCamera: true);
```

### 7.8 MessageBubble — _MediaBubble (message_bubble.dart)

```dart
// Στο build(), ΜΕΤΑ το system check:
final type = message['type'] as String? ?? 'text';
final isEncrypted = message['encrypted'] == true;  // ← forward-compatible

if (type == 'gif' || type == 'image' || type == 'video') {
  return _MediaBubble(
    chatId: chatId,              // ← για deriveKey (μελλοντικά)
    content: content,
    thumbnailUrl: message['thumbnailUrl'] as String?,
    type: type,
    isEncrypted: isEncrypted,    // ← forward-compatible
    timeStr: timeStr,
    isMe: isMe,
    senderNickname: isGroupChat && !isMe ? senderNickname : null,
    seenBy: seenBy, isGroupChat: isGroupChat, isRead: isRead,
  );
}
```

### 7.9 _MediaBubble Widget (message_bubble.dart)

**Ενιαίο widget για gif + image + video.** Σχεδιασμένο με **dual-path** για forward compatibility:

```
encrypted == false → direct URL (CachedNetworkImage / VideoPlayerController.networkUrl)
encrypted == true  → download→decrypt→display (Image.memory / temp file + VideoPlayerController.file)
```

```dart
class _MediaBubble extends StatefulWidget {
  final String chatId;         // ← για deriveKey (μελλοντικά E2E)
  final String content;
  final String? thumbnailUrl;
  final String type;           // 'gif' | 'image' | 'video'
  final bool isEncrypted;      // ← forward-compatible flag
  // ... remaining fields
}

class _MediaBubbleState extends State<_MediaBubble> {
  VideoPlayerController? _controller;
  bool _videoInitialized = false;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.content));
      await _controller!.initialize();
      if (mounted) setState(() => _videoInitialized = true);
    } catch (e) {
      DebugConfig.warn('_MediaBubble: video init failed', data: e);
      if (mounted) setState(() => _videoError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'gif') {
      return _buildGifBubble();
    } else if (widget.type == 'image') {
      return _buildImageBubble();
    } else {
      return _buildVideoBubble();
    }
  }

  Widget _buildImageBubble() {
    // Dual-path: encrypted ? decrypt→Image.memory : direct CachedNetworkImage
    // CachedNetworkImage + InteractiveViewer full-screen on tap
  }

  Widget _buildVideoBubble() {
    if (_videoError) {
      return Container(
        color: Colors.black38,
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.white54, size: 48),
            Text('Video unavailable', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (_videoInitialized && _controller != null) {
      return _buildVideoPlayer();
    }
    return _buildThumbnailWithPlayButton();
  }

  Widget _buildGifBubble() {
    // CachedNetworkImage with loop animation
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
          child: widget.type == 'image'
              ? InteractiveViewer(
                  child: CachedNetworkImage(imageUrl: widget.content))
              : _VideoPlayerScreen(url: widget.content),
        ),
      ),
    ));
  }
}
```

### 7.10 Storage Cleanup (3 σημεία)

**1. chat_repository_delete.dart — `_deleteChatForEveryone`:**
```dart
try {
  await _storageService.deleteAllChatMedia(chatId);
} catch (e) {
  DebugConfig.warn('deleteAllChatMedia failed (non-fatal)', data: e);
}
```

**2. chat_repository_clear.dart — `clearMessages`:**
```dart
try {
  await _storageService.deleteAllChatMedia(chatId);
} catch (e) {
  DebugConfig.warn('deleteAllChatMedia failed (non-fatal)', data: e);
}
```

**3. group_chat_mixin.dart — `deleteGroup`:**
```dart
// Μέσα στο deleteGroup(), πριν ή μετά το delete chat doc:
try {
  await _storageService.deleteAllChatMedia(chatId);
} catch (e) {
  DebugConfig.warn('deleteAllChatMedia failed (non-fatal)', data: e);
}
```

### 7.11 Storage Rules + Participant Check

Το project ήδη χρησιμοποιεί `firestore.get()`/`firestore.exists()` στα Storage rules (βλ. `group_avatars`). Το ίδιο pattern εφαρμόζεται και για `chat_media`:

```javascript
match /chat_media/{chatId}/{fileName} {
  allow read: if request.auth != null
              && firestore.exists(/databases/(default)/documents/chats/$(chatId))
              && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
  allow write: if request.auth != null
               && firestore.exists(/databases/(default)/documents/chats/$(chatId))
               && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
}
```

**Πλεονεκτήματα έναντι signed URL + CF:**
| Κριτήριο | Signed URL + CF ❌ | Firestore.get() rules ✅ |
|:---------|:------------------:|:------------------------:|
| Νέες Cloud Functions | 1 | **0** |
| Latency ανά media view | ~500ms (CF call) | **0** (άμεσο) |
| Caching logic | signed URL 1h expiry | **Κανένα** |
| Γραμμές κώδικα | ~50 (CF) + ~10 (client) | **0** (μόνο rules) |
| Σημεία αστοχίας | CF timeout, cache miss | **0** |
| Ασφάλεια | Participant check | **Ίδια** |
| Συμβατότητα | Νέο pattern | **Ίδιο με group_avatars** |

### 7.12 Storage Rules (storage.rules)

```javascript
// Ίδιο pattern με group_avatars — firestore.get() participant check
match /chat_media/{chatId}/{fileName} {
  allow read: if request.auth != null
              && firestore.exists(/databases/(default)/documents/chats/$(chatId))
              && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
  allow write: if request.auth != null
               && firestore.exists(/databases/(default)/documents/chats/$(chatId))
               && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
}
```

### 7.13 Non-E2E UI Indication

Τα media messages ΔΕΝ είναι E2E encrypted. Το `_MediaBubble` εμφανίζει:
- Μικρό `Icons.lock_open` με tooltip "Δεν είναι E2E κρυπτογραφημένο" / "Not E2E encrypted"
- Στο full-screen viewer, επεξηγηματικό text ότι το media προστατεύεται από signed URLs & Storage encryption at rest, όχι E2E

### 7.14 Feature Flag

```dart
static const bool mediaMessagesEnabled = false;  // ← false → true only after testing
```

### 7.15 Debug Flag

```dart
static const bool chatMedia = true;
```

### 7.16 Error Messages

```dart
case 'chat/media-send-failed':
  return isGreek ? 'Αποστολή πολυμέσου απέτυχε' : 'Media send failed';
case 'chat/media-too-large':
  return isGreek ? 'Το αρχείο είναι πολύ μεγάλο' : 'File too large';
case 'chat/media-upload-failed':
  return isGreek ? 'Αποτυχία μεταφόρτωσης' : 'Upload failed';
case 'chat/media-type-unsupported':
  return isGreek ? 'Μη υποστηριζόμενος τύπος' : 'Unsupported type';
case 'chat/media-not-found':
  return isGreek ? 'Το αρχείο δεν βρέθηκε' : 'File not found';
```

### 7.17 Compatibility Notes

#### 7.17.1 File Size: `_ChatInputBar` Extraction

Το `chat_screen.dart` είναι 374 γραμμές. Εξαγωγή του `_ChatInputBar` σε ξεχωριστό widget `chat_input_bar.dart`. Εκτίμηση: ~200 γραμμές (emoji ~30 + GIF button ~15 + photo ~60 + video ~60 + boilerplate ~35).

**Προσοχή:** Αν ξεπεράσει τις 500, split σε `chat_input_bar.dart` (βασικό input) + `chat_media_actions.dart` (media pickers).

#### 7.17.2 Part File: `chat_repository_media.dart`

Δημιουργία νέου part file `chat_repository_media.dart` για `sendMediaMessage` impl. Το κύριο `chat_repository_impl.dart` κάνει `part 'chat_repository_media.dart';`.

#### 7.17.3 Group Chat

Το `FeatureFlags.groupChatEnabled = true` (ενεργό). Το media input αφορά και 1:1 και group chats (το `message_bubble.dart` είναι ήδη group-aware).

---

## 8. Φάση 4 — Video Sharing

### 8.1 Διαφορές από Photo

| Θέμα | Photo | Video |
|:----:|:-----:|:-----:|
| Picker | `_picker.pickImage()` | `_picker.pickVideo(source: ImageSource.gallery)` + `ImageSource.camera` |
| Compression | ImageCropper (υπάρχει) | **Προαιρετικό** — feature flag `videoCompressionEnabled` |
| Thumbnail | Δεν χρειάζεται | `video_thumbnail` package (200×200 JPEG) |
| Player | CachedNetworkImage | `video_player` (in-bubble) |
| Upload progress | Instant (~1-2s) | **Progress indicator** (putFile + snapshotEvents) |
| Storage path | `chat_media/{chatId}/{msgId}.jpg` | `chat_media/{chatId}/{msgId}.mp4` + `{msgId}_thumb.jpg` |
| Scroll behavior | Auto | **Auto-pause on scroll** (VisibilityDetector) |
| APK impact | 0 | `video_player` ~2MB extra |
| Platform setup | Κανένα | Android ExoPlayer (default), iOS ATS στο Info.plist |

### 8.2 Απόφαση: Cost-Aware Video Parameters

**Δεν συμπεριλαμβάνεται `ffmpeg_kit_flutter` στο baseline.** Λόγοι:
1. APK increase ~5-8MB για chat feature
2. Σύγχρονα smartphones ήδη καταγράφουν σε reasonable bitrate
3. `image_picker.pickVideo()` επιστρέφει το αρχείο ως έχει — no re-encoding

**Αντ' αυτού:** Client-side size validation πριν το upload:
```dart
const int maxVideoSize = ChatMediaConfig.videoMaxSizeBytes; // 15MB

final file = File(picked.path);
final fileSize = await file.length();
if (fileSize > maxVideoSize) {
  AppMessenger.showError(context, ErrorMessages.get(
      'chat/video-too-large', L10n.isGreek(context)));
  return;
}
```

### 8.3 Thumbnail Extraction

```yaml
video_thumbnail: ^1.0.0
```

```dart
Uint8List? thumbnailBytes;
try {
  thumbnailBytes = await VideoThumbnail.thumbnailData(
    video: picked.path,
    imageFormat: ImageFormat.JPEG,
    maxWidth: 200,
    quality: 80,
  );
} catch (e) {
  DebugConfig.warn('thumbnail extraction failed (non-fatal)', data: e);
}
```

### 8.4 _ChatInputBar — Video Pick Button

```dart
IconButton(
  icon: const Icon(Icons.videocam_outlined),
  onPressed: _pickAndSendVideo,
),

Future<void> _pickAndSendVideo({bool fromCamera = false}) async {
  try {
    final picked = await _picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final fileSize = await file.length();
    if (fileSize > ChatMediaConfig.videoMaxSizeBytes) {
      if (!mounted) return;
      AppMessenger.showError(context, ErrorMessages.get(
          'chat/video-too-large', L10n.isGreek(context)));
      return;
    }

    // Thumbnail extraction
    Uint8List? thumbBytes;
    try {
      thumbBytes = await VideoThumbnail.thumbnailData(
        video: picked.path, imageFormat: ImageFormat.JPEG,
        maxWidth: 200, quality: 80,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isLoading = true);

    // 🔴 Upload with progress indicator
    final ok = await _uploadVideoWithProgress(file, thumbBytes);

    if (!mounted) return;
    setState(() => _isLoading = false);
  } catch (e) {
    DebugConfig.error('_pickAndSendVideo failed', data: e);
  }
}

Future<bool> _uploadVideoWithProgress(File file, Uint8List? thumbBytes) async {
  // Διάβασμα bytes
  final bytes = await file.readAsBytes();
  final ok = await ref.read(chatActionsProvider.notifier)
      .sendMediaMessage(widget.chatId,
          bytes: bytes, fileName: file.name,
          type: 'video', thumbnailBytes: thumbBytes);
  return ok;
}
```

### 8.5 Video Player Bubble (μέρος του _MediaBubble)

```dart
Widget _buildVideoPlayer() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Stack(children: [
      AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
      Center(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _controller!.value.isPlaying
                  ? _controller!.pause()
                  : _controller!.play();
            });
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black26, shape: BoxShape.circle),
            padding: const EdgeInsets.all(12),
            child: Icon(
              _controller!.value.isPlaying
                  ? Icons.pause : Icons.play_arrow,
              color: Colors.white, size: 32,
            ),
          ),
        ),
      ),
    ]),
  );
}

Widget _buildThumbnailWithPlayButton() {
  return Stack(children: [
    if (widget.thumbnailUrl != null)
      CachedNetworkImage(imageUrl: widget.thumbnailUrl!, fit: BoxFit.cover)
    else
      Container(color: Colors.black38,
        child: const Icon(Icons.play_circle, size: 48)),
    Center(child: Icon(Icons.play_circle, color: Colors.white, size: 48)),
  ]);
}
```

### 8.6 Platform Setup Notes

| Πλατφόρμα | Ενέργεια |
|:---------|----------|
| **Android** | `minSdkVersion` 21+ (ήδη ισχύει). ExoPlayer ενσωματωμένο στο `video_player`. Hardware acceleration default ON |
| **iOS** | Προσθήκη `NSPhotoLibraryUsageDescription` + `NSCameraUsageDescription` + `NSMicrophoneUsageDescription` στο Info.plist. `NSAppTransportSecurity` → `NSAllowsArbitraryLoads` για Tenor CDN |

### 8.7 Auto-pause on Scroll

Χρήση `VisibilityDetector` package για έξυπνη διαχείριση video playback:

```dart
import 'package:visibility_detector/visibility_detector.dart';

VisibilityDetector(
  key: Key('video_${widget.content}'),
  onVisibilityChanged: (info) {
    if (info.visibleFraction < 0.5) {
      _controller?.pause();  // Auto-pause όταν δεν είναι ορατό
    }
  },
  child: _buildVideoPlayer(),
);
```

### 8.8 Feature Flag

```dart
static const bool videoMessagesEnabled = false;  // ← false → true only after testing
static const bool videoCompressionEnabled = false;  // Phase 4+ (ffmpeg)
```

### 8.9 Error Messages

```dart
case 'chat/video-too-large':
  return isGreek ? 'Το βίντεο είναι πολύ μεγάλο (max 15MB)'
                 : 'Video too large (max 15MB)';
```

---

## 9. Πλήρης Πίνακας Εμπλεκόμενων Αρχείων

### 9.1 Νέα Αρχεία (4 σύνολο)

| Αρχείο | Γραμμές | Φάση | Σκοπός |
|--------|:-------:|:----:|--------|
| `lib/features/chat/widgets/chat_input_bar.dart` | ~200 | 1,2,3,4 | Extracted `_ChatInputBar` (emoji, GIF, photo, video buttons) |
| `lib/repositories/chat_repository_media.dart` | ~90 | 3,4 | Part file: `sendMediaMessage` impl + messagesStream media branch |
| `lib/shared/utils/giphy_service.dart` | ~100 | 2 | GIPHY GIF API (αντικατέστησε Tenor) |
| `lib/features/chat/widgets/gif_picker_sheet.dart` | ~120 | 2 | GIF search & picker UI |

### 9.2 Τροποποιούμενα Αρχεία (16 σύνολο)

| # | Αρχείο | Φάσεις | Αλλαγή |
|:-:|--------|:------:|--------|
| 1 | `pubspec.yaml` | 1,2,3,4 | +1 dep (emoji_picker_flutter) — GIF uses `dart:io` HttpClient (όχι `http`) |
| 2 | `storage_service.dart` | 3,4 | +3 methods (uploadChatMedia, deleteChatMedia, deleteAllChatMedia) |
| 3 | `storage.rules` | 3,4 | +1 match rule (chat_media — participant check via firestore.get(), ίδιο pattern με group_avatars) |
| 4 | `chat_repository.dart` | 3,4 | +1 abstract method (sendMediaMessage) |
| 5 | `chat_repository_impl.dart` | 3,4 | +1 part directive + messagesStream media branch |
| 6 | `chat_repository_media.dart` | 3,4 | sendMediaMessage impl (group-conditional block check) |
| 7 | `chat_repository_delete.dart` | 3,4 | +deleteAllChatMedia call |
| 8 | `chat_repository_clear.dart` | 3,4 | +deleteAllChatMedia call |
| 9 | **`group_chat_mixin.dart`** | 3,4 | **+deleteAllChatMedia call στο deleteGroup()** |
| 10 | `chat_provider.dart` | 3,4 | +ChatActionsNotifier.sendMediaMessage() |
| 11 | `chat_screen.dart` | 1,2,3,4 | Αφαίρεση `_ChatInputBar` + import νέου widget |
| 12 | `message_bubble.dart` | 2,3,4 | +_MediaBubble (gif + image + video) + error states |
| 13 | `chat_list_screen.dart` | 3,4 | +'video'/'gif' preview |
| 14 | `feature_flags.dart` | 2,3,4 | +mediaMessagesEnabled=false, videoMessagesEnabled=false, gifMessagesEnabled=false |
| 15 | `debug_config.dart` | 3,4 | +chatMedia flag |
| 16 | `error_messages.dart` | 3,4 | +5 error codes |

### 9.3 Αμετάβλητα (Verified)

| Αρχείο | Λόγος |
|--------|-------|
| `encryption_utils.dart` | Media ΔΕΝ κρυπτογραφούνται — download URL, όχι encrypted text |
| `firestore.rules` | Ήδη type-agnostic — no change needed |
| `functions/src/index.ts` | Chat media cleanup: ανά chat (deleteChat/deleteGroup), όχι ανά user (deleteUserData) |
| `profile_storage_mixin.dart` | Profile-specific |
| `profile_editor_screen.dart` | Profile-specific (pattern reuse από chat_input_bar.dart) |
| `database.dart` / `chat_cache_table.dart` | `lastMessageType` ήδη υπάρχει |
| `system_message_formatter.dart` | Δεν επηρεάζεται |
| `mention_utils.dart` | Δεν επηρεάζεται |
| `app_router.dart` | No new routes — full-screen via Navigator.push |
| `app_theme.dart` | No new theme |
| `l10n.dart` | Errors via ErrorMessages (ήδη bilingual) |
| `app_messenger.dart` | No change |
| `app_state_widget.dart` | No change |

---

## 10. Security Addendum

### 10.1 Storage Access Control

**Storage rules** χρησιμοποιούν `firestore.get()`/`firestore.exists()` για participant check — **ίδιο pattern με `group_avatars`**:

```javascript
match /chat_media/{chatId}/{fileName} {
  allow read: if request.auth != null
              && firestore.exists(/databases/(default)/documents/chats/$(chatId))
              && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
  allow write: if request.auth != null
               && firestore.exists(/databases/(default)/documents/chats/$(chatId))
               && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
}
```

Το project το υποστηρίζει ήδη — το `group_avatars` path χρησιμοποιεί ακριβώς αυτό το pattern σε production. **Καμία νέα Cloud Function, κανένα signed URL.**

### 10.2 EXIF Stripping

Οι φωτογραφίες από κινητό περιέχουν:
- GPS coordinates
- Device model
- Timestamp

**Λύση (2 επιλογές):**

| Επιλογή | Κόστος | Πλεονεκτήματα |
|:--------|:------:|---------------|
| A: `flutter_image_compress` (αφαιρεί EXIF αυτόματα) | ~0.5MB APK | Απλό, δοκιμασμένο |
| B: Native exif removal (dart:io) | 0 APK | Χωρίς extra dependency |

**Προτείνεται:** Επιλογή A (`flutter_image_compress`) για v1 — ήδη χρησιμοποιείται ευρέως, tested.

**Σημείωση:** Η EXIF stripping πρέπει να εφαρμοστεί **ενιαία** και στα δύο σημεία:
- Chat media (`_pickAndSendPhoto` στο `chat_input_bar.dart`)
- Profile avatar/photo (`_pickAndSaveProfileImage` στο `profile_editor_screen.dart` / `profile_storage_mixin.dart`)

Ξεχωριστό issue για το profile upload (εκτός του παρόντος plan) — αλλά η υλοποίηση να είναι κοινό utility function ώστε να αποφευχθεί duplication.

### 10.3 ConsentLog for Media

Το project καταγράφει consent actions (π.χ. `uploaded_photo`, `sent_request`). Η αποστολή media μηνύματος σε chat είναι μια αντίστοιχη ενέργεια που θα πρέπει να καταγράφεται για συνέπεια με τη φιλοσοφία **privacy-first / transparent**.

**Προσθήκη:** `db.logConsent(uid, 'sent_chat_media', 'chat_media', details: '{chatId: ..., type: ...}')` στο `sendMediaMessage()`, μετά το batch commit.

Χαμηλή προτεραιότητα — δεν μπλοκάρει το MVP, αλλά καλό να υπάρχει από την αρχή γιατί η προσθήκη εκ των υστέρων σημαίνει migration.

### 10.4 Participant Check Summary

| Layer | Προστασία |
|:-----|-----------|
| Firestore message read | `isParticipant()` rule (υπάρχει) |
| Storage read/write | `firestore.get()` participant check (ΝΕΟ, ίδιο pattern με group_avatars) |
| Chat doc update | Firestore rules — μόνο participants |
| ConsentLog | `sent_chat_media` καταγραφή (ΝΕΟ) |
| UI | Μόνο chat participants βλέπουν το media bubble |
| **Επικάλυψη** | **5 ανεξάρτητα layers** ✅ |

---

## 11. Edge Cases & Θωράκιση

### 11.1 Δικτυακά

| Σενάριο | Προστασία |
|---------|-----------|
| Upload με απώλεια δικτύου | `_isLoading` guard + `mounted` check + AppException → error message |
| Video >15MB | `File.length()` pre-check πριν upload |
| Image file corrupt (0 bytes) | ImagePicker returns null → return; |
| Slow upload (5+ sec) | Progress indicator + `CircularProgressIndicator` |
| Tenor API unavailable | try-catch → AppMessenger.showError |
| Firebase Storage rate limit | `AppException.storage` → error message |
| Signed URL expired (1h) | Refresh on demand → νέος signed URL |

### 11.2 Αποθήκευση

| Σενάριο | Προστασία |
|---------|-----------|
| Storage file deleted, message doc remains | `CachedNetworkImage` errorWidget → broken icon |
| Message sent, Storage delete fails | Orphan accepted — negligible cost |
| Chat deleted mid-upload | `mounted` guard → silent failure |
| Thumbnail extraction fails (video) | Message sent without thumbnail → generic icon overlay |
| Orphan _thumb files | Deleted together with main file via deleteAllChatMedia |

### 11.3 Ασφάλεια

| Σενάριο | Προστασία |
|---------|-----------|
| Unverified user sends media | `canComm` guard (υπάρχει) |
| Blocked user sends media | Group-conditional block check (group→rules, 1:1→client) |
| Malicious URL in content | URL από δικό μας Storage (signed) ή Tenor CDN |
| Non-participant reads media | Storage rules με `firestore.get()` participant check (ίδιο pattern με group_avatars) |
| Media in banned user's chat | Firestore rules `notBanned()` blocks message write |

### 11.4 User Experience

| Σενάριο | Προστασία |
|---------|-----------|
| Double-tap send | `_isLoading` guard |
| Keyboard + emoji picker | Fixed 250px height → Column adapts |
| Video plays while scrolling | Auto-pause via VisibilityDetector |
| Rapid emoji insertion | Cursor position maintained |
| Very long GIF search | Tenor API handles (100+ chars) |
| Photo pick cancel | `if (picked == null) return` |
| Image cropper cancel | `if (cropped == null) return` → fallback to original |
| Camera without permission | ImagePicker handles native permission flow |
| Video init failure | Error state with icon + text fallback (όχι infinite loading) |

---

## 12. Flutter Lifecycle Analysis

| Event | Emoji | GIF | Photo | Video |
|-------|:-----:|:---:|:-----:|:-----:|
| **Hot reload** | Picker reset ✅ | Search reset ✅ | Upload cancelled ✅ | Controller re-init ✅ |
| **App background** | Picker κλείνει ✅ | Sheet κλείνει ✅ | Upload continues ✅ | Upload continues ✅ |
| **App resume** | Picker re-opens ✅ | Re-search ✅ | mounted check ✅ | mounted check ✅ |
| **Route pop** | autoDispose ✅ | autoDispose ✅ | Upload cancelled ✅ | _controller.dispose() ✅ |
| **Widget dispose** | TextEditingController ✅ | TextEditingController ✅ | Loading reset ✅ | _controller?.dispose() ✅ |
| **System back** | Emoji κλείνει ✅ | Sheet κλείνει ✅ | N/A | Full-screen pops ✅ |
| **Scroll (ListView)** | N/A | N/A | N/A | Auto-pause (VisibilityDetector) ✅ |

### Memory

| Σενάριο | Μέγεθος | Διαχείριση |
|---------|:-------:|-----------|
| Photo bytes in memory | ~2MB (1280px JPEG) | Released after send |
| Video raw file | ~5-15MB | File.readAsBytes() → released |
| Video playback | ~50-200MB RAM | `_controller.dispose()` + auto-pause |
| CachedNetworkImage | auto-managed | cache library |
| Emoji picker | ~2MB | allocated once |
| GIF picker grid | ~20 previews | builder — on demand |
| Tenor API results | ~50KB JSON | released after parse |

---

## 13. Συνοπτικός Χάρτης Υλοποίησης

### Φάση 1 — Emoji Picker (30-45 λεπτά)

| Βήμα | Ενέργεια | Επαλήθευση |
|:----:|----------|:----------:|
| 1 | `flutter pub add emoji_picker_flutter` | pubspec.yaml ενημερωμένο |
| 2 | Backup `chat_screen.dart` → `backups/chat_screen.dart.bak` | Αρχείο υπάρχει |
| 3 | Δημιουργία `chat_input_bar.dart` (extract `_ChatInputBar` + emoji logic) | `flutter analyze` ✅ |
| 4 | Αφαίρεση `_ChatInputBar` από `chat_screen.dart` + import `ChatInputBar` | `flutter analyze` ✅ |
| 5 | `flutter run` + device test: emoji toggle, insert at cursor, send | Λειτουργικό ✅ |

**Βλ. §5 για πλήρη ανάλυση (edge cases, lifecycle, κώδικας, flags).**

### Φάση 2 — GIF Support ✅ (Ολοκληρωμένη)

| Βήμα | Ενέργεια | Αρχείο | Status |
|:----:|----------|--------|:------:|
| 1 | Δημιουργία `GiphyService` (αντί Tenor — API discontinued) | `lib/shared/utils/giphy_service.dart` | ✅ |
| 2 | Δημιουργία `GifPickerSheet` bottom sheet | `lib/features/chat/widgets/gif_picker_sheet.dart` | ✅ |
| 3 | +`gifSupportEnabled = false` flag (τέθηκε `true` μετά testing) | `feature_flags.dart` | ✅ |
| 4 | +GIF button + `_pickGif()` | `chat_input_bar.dart` | ✅ |
| 5 | +`type=='gif'` → `_GifBubble` | `message_bubble.dart` | ✅ |
| 6 | +`'gif'` preview στην chat list | `chat_list_screen.dart` | ✅ |
| 7 | +`sendMediaMessage()` abstract + impl | `chat_repository.dart`, `chat_repository_impl.dart` | ✅ |
| 8 | +messagesStream media branch (skip decrypt) | `chat_repository_impl.dart` | ✅ |
| 9 | `flutter analyze` clean ✅ + device test ✅ | — | ✅ |

### Φάση 3 — Photo Sharing (2 ώρες)

| Βήμα | Ενέργεια | Αρχείο |
|:----:|----------|--------|
| 1 | Backup: storage_service, chat_repository*, chat_provider, chat_input_bar, message_bubble, chat_list_screen, storage.rules, feature_flags, error_messages | backups/ |
| 2 | +3 methods στο `StorageService` | `storage_service.dart` |
| 3 | +Νέο storage.rules (participant check via firestore.get(), ίδιο pattern με group_avatars) | `storage.rules` |
| 4 | +`mediaMessagesEnabled=false` flag | `feature_flags.dart` |
| 5 | +`chatMedia` debug flag | `debug_config.dart` |
| 6 | +`sendMediaMessage()` abstract + group-conditional block check | `chat_repository.dart` |
| 7 | +part file `chat_repository_media.dart` + messagesStream media branch | `chat_repository_media.dart` |
| 8 | +deleteAllChatMedia call σε delete + clear + deleteGroup | `chat_repository_delete.dart`, `chat_repository_clear.dart`, `group_chat_mixin.dart` |
| 9 | +ChatActionsNotifier.sendMediaMessage() | `chat_provider.dart` |
| 10 | +_MediaBubble widget + type=image/video/gif branches | `message_bubble.dart` |
| 11 | +photo button + camera button + _pickAndSendPhoto + EXIF note | `chat_input_bar.dart` |
| 12 | +5 error codes | `error_messages.dart` |
| 13 | `flutter analyze` + device test | — |

### Φάση 4 — Video Sharing (3-4 ώρες)

| Βήμα | Ενέργεια | Αρχείο |
|:----:|----------|--------|
| 1 | `flutter pub add video_player video_thumbnail visibility_detector` | pubspec.yaml |
| 2 | Backup (ίδια αρχεία με Φάση 3) | backups/ |
| 3 | +`videoMessagesEnabled=false` + `videoCompressionEnabled=false` | `feature_flags.dart` |
| 4 | +video error code | `error_messages.dart` |
| 5 | +video case στο messagesStream | `chat_repository_impl.dart` |
| 6 | +_MediaBubble video player + thumbnail + error fallback | `message_bubble.dart` |
| 7 | +VisibilityDetector auto-pause | `message_bubble.dart` |
| 8 | +video button + _pickAndSendVideo + size validation + progress | `chat_input_bar.dart` |
| 9 | +'video' preview in chat_list_screen | `chat_list_screen.dart` |
| 10 | Platform setup: Info.plist (iOS), minSdkVersion check (Android) | — |
| 11 | `flutter analyze` + dual-device test | — |

---

## Προϋποθέσεις

```
1. flutter analyze — CLEAN πριν ξεκινήσουμε
2. BACKUP όλων των αρχείων φάσης
3. feature flags σε false → ενεργοποίηση ΜΟΝΟ μετά από δοκιμή
4. Deploy storage.rules πριν από Φάση 3 testing: `firebase deploy --only storage`
5. Κάθε βήμα: edit → flutter analyze → user OK → επόμενο
6. Μέγεθος αρχείων ≤ 500 γραμμές
   - Exception: chat_repository_impl.dart (ήδη >500) — ρητή άδεια χρήστη
   - Λύση: νέο part file chat_repository_media.dart για νέο κώδικα
   - Αν chat_input_bar.dart >500, split σε chat_input_bar.dart + chat_media_actions.dart

7. Το `encrypted: false` flag + dual-path `_MediaBubble` επιτρέπουν μελλοντική προσθήκη E2E χωρίς migration
```
