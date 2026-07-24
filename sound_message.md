# NearMe — Voice Messages (Audio Messages) Πρόταση Υλοποίησης

> **Έκδοση:** 2.0 (αναθεωρημένη μετά από 2η ανάγνωση κώδικα)  
> **Βάση:** Πραγματική ανάλυση codebase — 107+ .dart files, firestore.rules, storage.rules, firestore.indexes.json  
> **Ημερομηνία:** 24 Ιουλίου 2026

---

## Πίνακας Περιεχομένων

1. [Αρχιτεκτονική](#1-αρχιτεκτονική)
2. [Νέες Εξαρτήσεις](#2-νέες-εξαρτήσεις-pubspecyaml)
3. [Feature Flag](#3-feature-flag)
4. [Debug Config](#4-debug-config)
5. [Error Messages](#5-error-messages)
6. [Media Action - MediaPickerSheet](#6-mediaaction--mediapickersheet)
7. [ChatInputBar](#7-chatinputbar)
8. [Repository Interface](#8-repository-interface-chatrepositorydart)
9. [Repository Implementation](#9-repository-implementation-chatrepository_impldart)
10. [Provider - ChatActionsNotifier](#10-provider---chatactionsnotifier)
11. [Message Decoding (_decodeMessageDoc)](#11-message-decoding-_decodemessagedoc)
12. [Cache Sync - 1-to-1](#12-cache-sync---1-to-1-synchatformfirestore)
13. [Cache Sync - Group](#13-cache-sync---group-syncgroupchattocache)
14. [MessageBubble Switch](#14-messagebubble-switch)
15. [AudioMessageBubble (Νέο Widget)](#15-audiomessagebubble-νέο-widget)
16. [ChatScreen - AudioPlayer Instance](#16-chatscreen---audioplayer-instance)
17. [ChatListScreen - Preview Text](#17-chatlistscreen---preview-text)
18. [Reply/Edit Banners - Type Cases](#18-replyedit-banners---type-cases)
19. [MessageActionBar - showEdit](#19-messageactionbar---showedit)
20. [BubbleLongPressWrapper - canEdit](#20-bubblelongpresswrapper---canedit)
21. [ChatMessagesList._onEdit - Type Guard](#21-chatmessageslist_onedit---type-guard)
22. [AudioRecorderSheet (Νέο Widget)](#22-audiorecordersheet-νέο-widget)
23. [Rebuild Storm Prevention](#23-rebuild-storm-prevention)
24. [Προαπαιτούμενα / Μπλοκαρίσματα](#24-προαπαιτούμενα--μπλοκαρίσματα)
25. [Edge Cases](#25-edge-cases)
26. [SPoTs - Τελικός Πίνακας](#26-spots---τελικός-πίνακας)

---

## 1. Αρχιτεκτονική

Ακολουθεί το **ίδιο ακριβώς μοτίβο** με τα image/gif messages (sendMediaMessage).

```
sendMediaMessage (chat_repository_impl.dart:777, chat_repository.dart:120, chat_provider.dart:252)
───────────────────────────────────────────────────────────────────────────────────────────────────────

UI (ChatInputBar):
  1. User taps mic → AudioRecorderSheet → record audio → bytes + duration (seconds)

Provider:
  2. ref.read(chatActionsProvider.notifier).sendMediaMessage(
       chatId, content: '', type: 'audio', audioBytes: bytes, duration: seconds)
       └── ΕΠΑΝΑΧΡΗΣΙΜΟΠΟΙΕΙ την υπάρχουσα provider method (chat_provider.dart:252)

Repository:
  3. sendMediaMessage() (chat_repository_impl.dart:777)
     └── Auth guard (line 783) + block check (line 802) ← ΗΔΗ ΥΠΑΡΧΟΥΝ
  4. Upload: chat_media/{chatId}/{msgRef.id}.m4a ← upload block NEW
     └── FirebaseStorage.instance.ref().child('chat_media/$chatId/${msgRef.id}.m4a')
  5. batch.write ← ΗΔΗ ΥΠΑΡΧΕΙ (lines 843-856)
     └── msg doc: { senderId, content: url, type: 'audio', timestamp, isRead: false, duration: X }
     └── chat doc update: lastMessage, lastMessageType: 'audio', lastMessageAt, unreadCount
  6. updateChatCache ← ΗΔΗ ΥΠΑΡΧΕΙ (line 860)

Stream & Decode:
  7. messagesStream (chat_repository_impl.dart:386) → _decodeMessageDoc (line 328)
  8. type == 'audio' → SKIP DECRYPT ← νέο case στην υπάρχουσα skip list (line 342)
  9. Return map: content = Storage URL, type = 'audio', duration = X

Cache Sync:
  10. _syncChatFromFirestore (chat_repository_impl.dart:594): skip decrypt για 'audio'
  11. _syncGroupChatToCache (group_chat_mixin.dart:173): skip decrypt για 'audio'

UI Render:
  12. MessageBubble (message_bubble.dart:60) → switch case 'audio' → AudioMessageBubble
  13. Audio player instance: shared AudioPlayer στο ChatScreen
  14. ChatListScreen._buildPreviewText (chat_list_screen.dart:274): case 'audio'
  15. Reply/Edit banners: contentPreview = '🎵 Ηχογράφηση' / '🎵 Recording'

Storage Cleanup:
  16. deleteAllChatMedia(chatId) (chat_repository_impl.dart:1008): ήδη διαγράφει chat_media/{chatId}/*
```

### Βασικές αρχές

- **Χωρίς encryption**: Το audio content είναι Storage URL, όχι κείμενο — ίδια λογική με gif/image/video
- **Χωρίς νέο Firestore index**: Τα messages queries είναι type-agnostic
- **Χωρίς νέο Storage rule**: Το `chat_media/{chatId}/` path είναι ήδη wildcard (storage.rules:28)
- **Χωρίς νέο Firestore rule**: Το `type` πεδίο δεν ελέγχεται από rules (firestore.rules:214)
- **Χωρίς schema migration**: Το `lastMessageType` στο ChatCacheTable ήδη υπάρχει
- **Shared AudioPlayer**: Ένα instance στο ChatScreen, όχι per-bubble (αποφυγή rebuild storm)

---

## 2. Νέες Εξαρτήσεις (pubspec.yaml)

```yaml
dependencies:
  record: ^5.0.0       # Recording audio → m4a (AAC), runtime permission handling
  audioplayers: ^6.0.0 # Playback audio → shared instance, seek, position stream
```

### Android manifest (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS Info.plist (`ios/Runner/Info.plist`)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Το NearMe χρειάζεται πρόσβαση στο μικρόφωνο για αποστολή φωνητικών μηνυμάτων / NearMe needs microphone access to send voice messages</string>
```

---

## 3. Feature Flag

**Αρχείο:** `lib/core/config/feature_flags.dart`

```dart
// Media
static const bool gifSupportEnabled = true;
static const bool mediaMessagesEnabled = true;
static const bool audioMessagesEnabled = true;   // ← NEW
```

---

## 4. Debug Config

**Αρχείο:** `lib/core/debug/debug_config.dart`

```dart
/// ─────────────────────────────────────────────────────────────
/// CHAT AUDIO — Voice message recording & playback
/// ─────────────────────────────────────────────────────────────
static const bool chatAudio = true;   // ← NEW, μαζί με chatEncrypt, chatReactions, chatReply, chatBubbleDesign
```

---

## 5. Error Messages

**Αρχείο:** `lib/core/utils/error_messages.dart`

```dart
case 'chat/audio-send-failed':
  return isGreek ? 'Αποστολή ηχογραφήματος απέτυχε' : 'Audio send failed';
case 'chat/audio-playback-error':
  return isGreek ? 'Σφάλμα αναπαραγωγής' : 'Playback error';
case 'chat/audio-permission-denied':
  return isGreek ? 'Δεν δόθηκε άδεια μικροφώνου' : 'Microphone permission denied';
case 'chat/audio-too-short':
  return isGreek ? 'Το ηχητικό μήνυμα είναι πολύ σύντομο' : 'Audio message is too short';
```

---

## 6. MediaAction & MediaPickerSheet

**Αρχείο:** `lib/features/chat/widgets/media_picker_sheet.dart`

### Enum
```dart
enum MediaAction { emoji, gif, photo, camera, record }   // ← record
```

### Available list
```dart
final available = <MediaAction>[
  MediaAction.emoji,
  if (FeatureFlags.gifSupportEnabled) MediaAction.gif,
  if (FeatureFlags.mediaMessagesEnabled) ...[MediaAction.photo, MediaAction.camera],
  if (FeatureFlags.audioMessagesEnabled && !kIsWeb) MediaAction.record,   // ← NEW
];
```

> **Σημείωση:** `kIsWeb` γιατί το `record` package δεν υποστηρίζει web. Το web είναι Phase 4 (`webVersionEnabled = false`).

### Tile
```dart
MediaAction.record => (Icons.mic_outlined, greek ? 'Ηχογράφηση' : 'Record'),
```

### Selection handler
```dart
DebugConfig.log(DebugConfig.chatAudio, 'MediaPickerSheet: record selected');
```

---

## 7. ChatInputBar

**Αρχείο:** `lib/features/chat/widgets/chat_input_bar.dart`

### 7α. Import
```dart
import 'dart:io';                     // ήδη υπάρχει
import 'dart:typed_data';             // ← NEW (για Uint8List)

// ΔΕΝ χρειάζεται import για record/audioplayers — όλα στο νέο audio_recorder_sheet.dart
```

### 7β. MediaAction switch (line 233)
```dart
case MediaAction.record:
  DebugConfig.log(DebugConfig.chatAudio,
      'ChatInputBar: record pressed');
  _recordAndSend();
```

### 7γ. Νέα μέθοδος _recordAndSend
```dart
Future<void> _recordAndSend() async {
  if (widget.emojiPickerVisible) widget.onEmojiDismiss();
  final greek = L10n.isGreek(context);
  final result = await showAudioRecorderSheet(context);
  if (!mounted || result == null) return;
  final replyToData = _buildReplyData();
  _clearReply();
  setState(() => _isLoading = true);
  final ok = await ref.read(chatActionsProvider.notifier)
      .sendMediaMessage(widget.chatId,
          content: '', type: 'audio',
          replyTo: replyToData,
          audioBytes: result.bytes);
  if (!mounted) return;
  setState(() => _isLoading = false);
  if (!ok) {
    AppMessenger.showError(context,
        ErrorMessages.get('chat/audio-send-failed', greek));
  }
}
```

### 7δ. _buildReplyData() (line 142) — type case
```dart
if (type == 'audio') {
  contentPreview = greek ? '🎵 Ηχογράφηση' : '🎵 Recording';
} else if (type == 'gif') {
  // ... existing
} else if (type == 'image') {
  // ... existing
}
```

### 7ε. _buildReplyBanner() (line 261) — type case
```dart
if (type == 'audio') {
  preview = greek ? '🎵 Ηχογράφηση' : '🎵 Recording';
} else if (type == 'gif') {
  preview = '🎞️ GIF';
} else if (type == 'image') {
  preview = greek ? '📷 Φωτογραφία' : '📷 Photo';
}
```

### 7στ. _buildEditBanner() (line 331) — type case
```dart
if (type == 'audio') {
  preview = greek ? '🎵 Ηχογράφηση' : '🎵 Recording';
} else if (type == 'gif') {
  preview = '🎞️ GIF';
} else if (type == 'image') {
  preview = greek ? '📷 Φωτογραφία' : '📷 Photo';
}
```

---

## 8. Repository Interface (chat_repository.dart)

**Αρχείο:** `lib/repositories/chat_repository.dart` (line 120)

```dart
// Media messages
Future<void> sendMediaMessage(String chatId, {
  required String content,
  required String type,
  Map<String, dynamic>? replyTo,
  Uint8List? imageBytes,
  Uint8List? audioBytes,       // ← NEW
  int? duration,               // ← NEW (seconds)
});
```

---

## 9. Repository Implementation (chat_repository_impl.dart)

**Αρχείο:** `lib/repositories/chat_repository_impl.dart`

### 9α. sendMediaMessage signature (line 777)
```dart
Future<void> sendMediaMessage(String chatId, {
  required String content,
  required String type,
  Map<String, dynamic>? replyTo,
  Uint8List? imageBytes,
  Uint8List? audioBytes,      // ← NEW
  int? duration,              // ← NEW
}) async {
```

### 9β. Audio upload block (μετά το image block, line 825)
```dart
if (audioBytes != null && type == 'audio') {
  DebugConfig.log(DebugConfig.chatAudio,
      'sendMediaMessage: uploading audio chat=$chatId');
  final storageRef = FirebaseStorage.instance
      .ref().child('chat_media/$chatId/${msgRef.id}.m4a');
  await storageRef.putData(audioBytes,
      SettableMetadata(contentType: 'audio/mp4'));
  content = await storageRef.getDownloadURL();
}
```

### 9γ. Message data (line 832) — duration field
```dart
final msgData = <String, dynamic>{
  'senderId': user.uid,
  'content': content,
  'type': type,
  'timestamp': FieldValue.serverTimestamp(),
  'isRead': false,
  if (type == 'audio' && duration != null) 'duration': duration,
};
if (replyTo != null) {
  msgData['replyTo'] = replyTo;
}
```

### 9δ. Debug success
```dart
DebugConfig.log(DebugConfig.chatAudio,
    'sendMediaMessage: audio success chat=$chatId');
```

---

## 11. Message Decoding (_decodeMessageDoc)

**Αρχείο:** `lib/repositories/chat_repository_impl.dart` (line 328)

### 11α. Skip-decrypt condition (line 340)
```dart
String decrypted;
if (type == 'system') {
  decrypted = encrypted;
} else if (type == 'gif' || type == 'image' || type == 'video' || type == 'audio') {
  decrypted = encrypted;        // ← 'audio'
} else if (encCache[docId] == encrypted && decCache.containsKey(docId)) {
  // ... existing
```

### 11β. Return map (line 365) — duration field
```dart
return {
  'id': docId,
  'senderId': data['senderId'] ?? '',
  'content': decrypted,
  'type': data['type'] ?? 'text',
  'timestamp': data['timestamp'],
  'isRead': data['isRead'] ?? false,
  'edited': data['edited'] ?? false,
  'editedAt': data['editedAt'],
  'seenBy': (data['seenBy'] as List?)?.cast<String>() ?? <String>[],
  'mentions': (data['mentions'] as List?)?.cast<String>() ?? <String>[],
  'action': data['action'] as String?,
  'contentEn': data['contentEn'] as String?,
  'reactions': (data['reactions'] as Map<String, dynamic>?) ?? <String, dynamic>{},
  'replyTo': data['replyTo'] as Map<String, dynamic>?,
  'duration': data['duration'] as int? ?? 0,   // ← NEW
};
```

---

## 12. Cache Sync - 1-to-1 (_syncChatFromFirestore)

**Αρχείο:** `lib/repositories/chat_repository_impl.dart` (line 594)

```dart
if (encryptedLastMessage != null &&
    lastMessageType != 'system' &&
    lastMessageType != 'gif' &&
    lastMessageType != 'image' &&
    lastMessageType != 'video' &&
    lastMessageType != 'audio') {         // ← NEW
  try {
    final key = await EncryptionUtils.getKeyOrDerive(chatId);
    decryptedLastMessage = EncryptionUtils.decryptMessage(key, encryptedLastMessage);
  } catch (e) {
    DebugConfig.warn('_syncChatFromFirestore: decrypt lastMessage failed chat=$chatId', data: e);
    decryptedLastMessage = null;
  }
} else if (encryptedLastMessage != null) {
  decryptedLastMessage = encryptedLastMessage; // media: keep URL as-is
}
```

---

## 13. Cache Sync - Group (_syncGroupChatToCache)

**Αρχείο:** `lib/repositories/group_chat_mixin.dart` (line 173)

```dart
if (encryptedLastMessage != null &&
    lastMessageType != 'system' &&
    lastMessageType != 'gif' &&
    lastMessageType != 'image' &&
    lastMessageType != 'video' &&
    lastMessageType != 'audio') {         // ← NEW
  try {
    final key = await EncryptionUtils.getKeyOrDerive(chatId);
    decryptedLastMessage = EncryptionUtils.decryptMessage(key, encryptedLastMessage);
  } catch (_) { /* system messages stay as-is */ }
} else if (encryptedLastMessage != null) {
  decryptedLastMessage = encryptedLastMessage;
}
```

---

## 14. MessageBubble Switch

**Αρχείο:** `lib/features/chat/widgets/message_bubble/message_bubble.dart`

Πρόσθεσε case πριν το default `_ =>` για τα audio:

```dart
'audio' => AudioMessageBubble(
  content: content,
  duration: message['duration'] as int? ?? 0,
  timeStr: timeStr,
  isMe: isMe,
  isGroupChat: isGroupChat,
  isGrouped: isGrouped,
  isLastInGroup: isLastInGroup,
  showAvatar: showAvatar,
  senderNickname: senderNickname,
  senderAvatarUrl: senderAvatarUrl,
  seenBy: seenBy,
  isRead: isRead,
  chatId: chatId,
  currentUid: currentUid,
  messageId: msgId,
  reactions: reactions,
  onReact: callbacks.onReact,
  onRemove: callbacks.onRemove,
  replyTo: replyTo,
  onReply: callbacks.onReply,
  onDelete: callbacks.onDelete,
),
```

> **Σημείωση:** Θα χρειαστεί import `audio_message_bubble.dart` (νέο αρχείο).  
> **Σημείωση:** Το `onEdit` ΔΕΝ περνιέται — τα audio messages δεν επιδέχονται edit.

---

## 15. AudioMessageBubble (Νέο Widget)

**Αρχείο:** `lib/features/chat/widgets/message_bubble/audio_message_bubble.dart`

### 15α. Widget structure
```dart
class AudioMessageBubble extends StatefulWidget {   // StatefulWidget για play/pause state
  final String content;          // Storage URL
  final int duration;            // duration σε seconds
  final String timeStr;
  final bool isMe;
  final bool isGroupChat;
  final bool isGrouped;
  final bool isLastInGroup;
  final bool showAvatar;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final List<String> seenBy;
  final bool isRead;
  final String? chatId;
  final String currentUid;
  final String messageId;
  final Map<String, dynamic> reactions;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final AudioPlayer audioPlayer;   // shared instance από ChatScreen

  const AudioMessageBubble({...});
  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}
```

### 15β. State
```dart
class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  double _progress = 0.0; // 0.0 – 1.0

  @override
  void initState() { ... _initPlayerListeners(); ... }
  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    // ΔΕΝ dispose το audioPlayer — είναι shared instance
    super.dispose();
  }
  void _initPlayerListeners() { ... }
  void _togglePlayPause() async { ... }
}
```

### 15γ. Rebuild storm prevention
- **ValueKey**: Το `MessageBubble` ήδη χρησιμοποιεί `ValueKey(msgId)` (chat_messages_list.dart:314)  
- **Leaf widget**: Το `AudioMessageBubble` είναι leaf, δεν ξαναχτίζει το parent
- **Προσοχή**: `_isPlaying` και `_position` είναι **local state** — δεν επηρεάζουν άλλα bubbles
- **Όχι provider για playing state**: Η εναλλαγή play/pause ενός bubble ΔΕΝ πρέπει να ξαναχτίσει άλλα bubbles

### 15δ. Layout (pattern από gif_image_bubble.dart)
```
Column(
  crossAxisAlignment: isMe ? end : start,
  children: [
    SenderHeader (αν group + showAvatar),
    ReplyPreview (αν replyTo != null),
    Stack(
      children: [
        BubbleLongPressWrapper(
          canEdit: false,                       // ← IMPORTANT
          onReply: widget.onReply,
          onDelete: widget.onDelete,
          child: Container(
            constraints: maxWidth: bubbleMaxWidth,
            child: Row(children: [
              IconButton(play/pause),
              Expanded(LinearProgressIndicator or Slider),
              Text(duration label),
            ]),
          ),
        ),
        TailPainter (αν showTail),
      ],
    ),
    MessageReactionsRow,
    Padding(timestamp + ReadReceiptIndicator),
  ],
)
```

### 15ε. Behavior
- **Tap play**: `_audioPlayer.play(url)` + subscription σε position stream
- **Tap pause/playing**: `_audioPlayer.pause()`
- **Position change**: update `_progress` και `_position` → setState
- **Completion**: reset `_isPlaying = false`, `_progress = 0`
- **Auto-stop on new play**: `_audioPlayer.stop()` πριν play νέο URL (single instance)
- **Error**: `DebugConfig.error` + `AppMessenger.showError` (αν context mounted)

### 15στ. Debug logs
```dart
DebugConfig.log(DebugConfig.chatAudio, 'AudioBubble: play msg=$messageId');
DebugConfig.log(DebugConfig.chatAudio, 'AudioBubble: pause msg=$messageId');
DebugConfig.warn('AudioBubble: playback error msg=$messageId', data: e);
```

---

## 16. ChatScreen - AudioPlayer Instance

**Αρχείο:** `lib/features/chat/screens/chat_screen.dart`

### State
```dart
class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _emojiPickerVisible = false;
  final AudioPlayer _audioPlayer = AudioPlayer();   // ← NEW shared instance

  @override
  void dispose() {
    _textCtrl.dispose();
    _audioPlayer.dispose();     // ← NEW cleanup
    super.dispose();
  }
```

### Passing to ChatMessagesList
```dart
ChatMessagesList(
  chatId: widget.chatId,
  audioPlayer: _audioPlayer,     // ← NEW
),
```

### Σχετικές αλλαγές στο ChatMessagesList
- Πρόσθεσε `final AudioPlayer audioPlayer;` στο `ChatMessagesList` widget (γραμμή 24)
- Πέρασέ το στο `MessageBubble` (line 314)
- Το `MessageBubble` το περνάει στο `AudioMessageBubble`

---

## 17. ChatListScreen - Preview Text

**Αρχείο:** `lib/features/chat/screens/chat_list_screen.dart` (line 268)

```dart
String? _buildPreviewText(bool greek, String title, bool isGroup) {
  final msg = chat.lastMessage;
  final sender = chat.lastMessageSender;
  final type = chat.lastMessageType ?? 'text';

  if (type != 'text') {
    if (type == 'image') return greek ? '📷 Φωτογραφία' : '📷 Photo';
    if (type == 'gif') return '🎞️ GIF';
    if (type == 'audio') return greek ? '🎵 Φωνητικό μήνυμα' : '🎵 Voice message';  // ← NEW
    return greek ? '💬 Μήνυμα' : '💬 Message';
  }
  // ... existing text preview
}
```

---

## 18. Reply/Edit Banners - Type Cases

Όπως περιγράφεται στο [7δ, 7ε, 7στ](#7δ-_buildreplydata-line-142--type-case).  
Σε τρία σημεία του `chat_input_bar.dart`:

1. **`_buildReplyData()`** (line ~142) — content preview για reply
2. **`_buildReplyBanner()`** (line ~261) — reply banner display
3. **`_buildEditBanner()`** (line ~331) — edit banner display

**Και στα τρία:** Πρόσθεσε `if (type == 'audio')` case που δείχνει `'🎵 Ηχογράφηση' / '🎵 Recording'`.

---

## 19. MessageActionBar - showEdit

**Αρχείο:** `lib/features/chat/widgets/message_action_bar.dart`

### New parameter
```dart
static Future<String?> show({
  required BuildContext context,
  required bool isOwn,
  required Offset globalPosition,
  bool showEdit = true,       // ← NEW
}) {
```

### Usage (line 23)
```dart
if (FeatureFlags.editMessageEnabled && isOwn && showEdit)
  PopupMenuItem(
    value: 'edit',
    child: ListTile(...),
  ),
```

---

## 20. BubbleLongPressWrapper - canEdit

**Αρχείο:** `lib/features/chat/widgets/message_bubble/bubble_long_press_wrapper.dart`

### New parameter
```dart
class BubbleLongPressWrapper extends StatelessWidget {
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget child;
  final bool canEdit;                     // ← NEW

  const BubbleLongPressWrapper({
    super.key,
    required this.isMe,
    required this.child,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.canEdit = true,                  // ← NEW (default true for backward compat)
  });
```

### Usage in build (line 28)
```dart
final result = await MessageActionBar.show(
  context: context,
  isOwn: isMe,
  globalPosition: details.globalPosition,
  showEdit: canEdit,                       // ← NEW
);
```

### AudioMessageBubble usage
```dart
BubbleLongPressWrapper(
  canEdit: false,       // ← audio δεν επιδέχεται edit
  ...
)
```

---

## 21. ChatMessagesList._onEdit - Type Guard

**Αρχείο:** `lib/features/chat/widgets/chat_messages_list.dart` (line 100)

```dart
void _onEdit(Map<String, dynamic> msg) {
  final type = msg['type'] as String? ?? 'text';
  if (type != 'text') {
    DebugConfig.log(DebugConfig.chatReply,
        '_onEdit: skipped for type=$type');   // ← NEW type guard
    return;
  }
  // ... existing code
}
```

---

## 22. AudioRecorderSheet (Νέο Widget)

**Αρχείο:** `lib/features/chat/widgets/audio_recorder_sheet.dart`

### 22α. Function signature
```dart
Future<AudioRecordResult?> showAudioRecorderSheet(
  BuildContext context,
) async { ... }

class AudioRecordResult {
  final Uint8List bytes;
  final int durationSeconds;
  AudioRecordResult({required this.bytes, required this.durationSeconds});
}
```

### 22β. UI Structure
```
─── Sheet Header ───
  "🎤 Ηχογράφηση / Recording" (bilingual)

─── Timer ───
  "00:00" → "00:XX" (format: mm:ss)

─── Record Button ───
  CircleAvatar(icon: mic, tap: start/stop)
  Animation: pulsing red dot while recording (AnimatedContainer)

─── Waveform (v1 optional) ───
  Placeholder: Container(height: 40) with gradient

─── Action Buttons ───
  [Cancel] [Send] (Send enabled only when recording complete)
```

### 22γ. Behavior
- **Record**: `AudioRecorder.start()` → timer starts (Stream<Duration>)
- **Stop**: `AudioRecorder.stop()` → returns `AudioFile`
- **Cancel**: discard, pop sheet
- **Send**: read bytes + duration → pop with `AudioRecordResult`
- **Max duration**: 60 seconds → auto-stop, AppMessenger.showInfo
- **Min duration**: <1 second → AppMessenger.showError ('chat/audio-too-short')

### 22δ. Responsive
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final w = ResponsiveUtils.resolveWidth(context, constraints);
    return SizedBox(
      height: 280,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.paddingValueFromWidth(w),
        ),
        child: Column(...),
      ),
    );
  },
)
```
(Pattern από `chat_input_bar.dart:420`)

### 22ε. Lifecycle & Dispose
```dart
class _AudioRecorderSheetState extends State<AudioRecorderSheet> {
  late final AudioRecorder _recorder;
  StreamSubscription? _recorderStateSub;
  bool _isRecording = false;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _startRecordingInternal();   // auto-start on open
  }

  @override
  void dispose() {
    _recorderStateSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
```

### 22στ. Debug logs
```dart
DebugConfig.log(DebugConfig.chatAudio, 'AudioRecorder: recording started');
DebugConfig.log(DebugConfig.chatAudio, 'AudioRecorder: recording stopped duration=$seconds');
DebugConfig.log(DebugConfig.chatAudio, 'AudioRecorder: sending audio duration=$seconds');
DebugConfig.log(DebugConfig.chatAudio, 'AudioRecorder: cancelled');
DebugConfig.warn('AudioRecorder: mic permission denied');
```

---

## 23. Rebuild Storm Prevention

| Session | Μάθημα | Εφαρμογή στο Audio |
|---------|--------|-------------------|
| 174 | `DeepCollectionEquality` cache | messagesStream return map — duration (int) και content (URL) δεν αλλάζουν, cache hit ✅ |
| 178 | participantUidsProvider identity | Ίδιο pattern, audio δεν προσθέτει νέο provider |
| 179 | Leaf widget extraction | `AudioMessageBubble` = leaf widget, δεν ξαναχτίζει parent ChatMessagesList |
| 188 | `ValueKey(msgId)` | Ήδη υπάρχει στο `ChatMessagesList:314` — audio messages το έχουν |
| 189 | MainShell StatefulWidget | `AudioPlayer` κρατιέται στο `ChatScreen` (StatefulWidget), όχι σε provider που θα προκαλούσε cascade |
| 192 | `select()` returns Map (deep comparison) | Δεν επηρεάζεται — audio είναι type στο message map |
| 195 | pending=true suppression | Δεν επηρεάζεται — audio πάει από sendMediaMessage (όχι sendMessage) |
| 196 | Pre-computed bubbleMaxWidth | `AudioMessageBubble` χρησιμοποιεί `LayoutBuilder` με `constraints.maxWidth * 0.75` (pattern gif_image_bubble:113) |
| 197 | markAsRead σε postFrameCallback | Δεν επηρεάζεται |
| 198 | `_SafeInputArea` leaf widget | Δεν επηρεάζεται |
| 199 | pending=true suppression | Δεν επηρεάζεται |
| 200 | `_MessageBubbleSignature` + `_obtainBubble` cache | AudioMessageBubble μπαίνει στο switch → signature περιλαμβάνει content+type+duration → cache δουλεύει αυτόματα |
| 200 | messagesStream equality caching | `DeepCollectionEquality` σε decrypted list — audio content (URL) και duration (int) σταθερά → cache hit ✅ |

### Κρίσιμη απόφαση για AudioPlayer

**Το `AudioPlayer` ΔΕΝ μπαίνει σε Riverpod provider** για να αποφευχθεί cascade:

- `ChatScreen` (StatefulWidget) κρατάει `final AudioPlayer _audioPlayer = AudioPlayer()`
- Περνιέται downstream: `ChatScreen → ChatMessagesList → MessageBubble → AudioMessageBubble`
- Κάθε `AudioMessageBubble` έχει **τοπικό** play/pause state (`StatefulWidget`)
- Μόνο το bubble που παίζει κάνει setState → κανένα cascade σε άλλα bubbles
- `dispose()` στο `ChatScreen` καλεί `_audioPlayer.dispose()`

---

## 24. Προαπαιτούμενα / Μπλοκαρίσματα

| # | Προαπαιτούμενο | Τύπος | Λεπτομέρειες |
|---|---------------|-------|-------------|
| 1 | `record: ^5.0.0` | pubspec.yaml | Recording audio (m4a/AAC) |
| 2 | `audioplayers: ^6.0.0` | pubspec.yaml | Playback |
| 3 | `RECORD_AUDIO` permission | Android manifest | `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` |
| 4 | `NSMicrophoneUsageDescription` | iOS Info.plist | Περιγραφή στα ελληνικά + αγγλικά |
| 5 | `import 'dart:typed_data'` | chat_input_bar.dart | Για `Uint8List` στο `_recordAndSend` |
| 6 | `import 'dart:io'` | chat_input_bar.dart | Ήδη υπάρχει |
| 7 | `kIsWeb` import | media_picker_sheet.dart | `import 'dart:io' show kIsWeb;` ή `import 'package:flutter/foundation.dart' show kIsWeb;` |

### ΔΕΝ χρειάζονται

| Τι | Γιατί |
|----|-------|
| Firestore rules changes | Type-agnostic (firestore.rules:214-256) |
| Storage rules changes | `chat_media/{chatId}/` already wildcard (storage.rules:28-36) |
| Firestore indexes changes | Messages queries unchanged |
| Drift schema migration | `lastMessageType` already exists, `duration` is Firestore-only |
| Auth guards changes | Already handled by `sendMediaMessage` (line 783) |
| Block checks changes | Already handled by `sendMediaMessage` (line 802) |
| deleteAllChatMedia changes | Already deletes `chat_media/{chatId}/*` (line 1008) |
| Permission handler package | `record` package handles runtime permissions |

---

## 25. Edge Cases

| # | Edge Case | Προστασία |
|---|-----------|-----------|
| 1 | **max 60s duration** | Force stop, truncate, `AppMessenger.showInfo` |
| 2 | **min <1s** | Discard + `AppMessenger.showError('chat/audio-too-short')` |
| 3 | **file >5MB** | Storage rules reject → catch → `AppMessenger.showError('chat/audio-send-failed')` |
| 4 | **permission denied** | `DebugConfig.warn` + `AppMessenger.showError('chat/audio-permission-denied')` |
| 5 | **app backgrounded during record** | `_recorder.stop()` στο dispose, discard recording |
| 6 | **phone call during record** | `AppLifecycleState.inactive` (Session 152 fix) → stop + discard |
| 7 | **playback overlap** | Single `AudioPlayer` — stop πριν play νέο URL |
| 8 | **navigate away during record** | Bottom sheet dismiss → discard → `recorder.dispose()` |
| 9 | **navigate away during playback** | `ChatScreen.dispose()` → `_audioPlayer.dispose()` → stop |
| 10 | **edit on audio message** | 3-layer guard: `MessageActionBar.showEdit: false`, `_onEdit` type check, `BubbleLongPressWrapper.canEdit: false` |
| 11 | **reply to audio** | Preview: `'🎵 Ηχογράφηση' / '🎵 Recording'` |
| 12 | **group chat audio** | sendMediaMessage ήδη υποστηρίζει groups (block check skipped για groups, line 802) |
| 13 | **encrypt attempt on audio** | `_decodeMessageDoc`: `'audio'` στο skip-decrypt list |
| 14 | **decrypt attempt on audio lastMessage** | `_syncChatFromFirestore` + `_syncGroupChatToCache`: `'audio'` στο skip-decrypt list |
| 15 | **storage cleanup on delete** | `deleteAllChatMedia(chatId)` διαγράφει όλα τα `chat_media/{chatId}/*` — .m4a περιλαμβάνεται |
| 16 | **kIsWeb** | `MediaAction.record` μόνο αν `!kIsWeb` |
| 17 | **release mode** | Όλα τα debug logs via `DebugConfig.log(chatAudio, ...)` → invisible in release |
| 18 | **widget rebuild during playback** | `AudioMessageBubble` StatefulWidget, `didUpdateWidget` check αν `content` άλλαξε |
| 19 | **playback error (corrupted file)** | Catch → `DebugConfig.error` + showError |
| 20 | **recording error (no storage)** | Catch → `DebugConfig.error` + showError |

---

## 26. SPoTs - Τελικός Πίνακας

| SPoT | Αλλαγή | Τύπος |
|------|---------|:-----:|
| `chat_repository.dart:120` | `Uint8List? audioBytes`, `int? duration` | New params |
| `chat_repository_impl.dart:777` | Audio upload block + duration field + debug logs | New code |
| `chat_repository_impl.dart:342` | `'audio'` in skip-decrypt list | Edit |
| `chat_repository_impl.dart:365` | `'duration': data['duration'] ?? 0` | Edit |
| `chat_repository_impl.dart:596` | `'audio'` in skip-decrypt list | Edit |
| `group_chat_mixin.dart:173` | `'audio'` in skip-decrypt list | Edit |
| `chat_provider.dart:252` | `audioBytes`, `duration` pass-through | New params |
| `message_bubble.dart:60` | `'audio'` case → `AudioMessageBubble` | New case |
| `message_action_bar.dart` | `showEdit` param | New param |
| `bubble_long_press_wrapper.dart` | `canEdit` param | New param |
| `chat_messages_list.dart:100` | `_onEdit` type guard | New guard |
| `chat_list_screen.dart:274` | `'audio'` preview | New case |
| `chat_input_bar.dart:233` | `MediaAction.record` case → `_recordAndSend()` | New case |
| `chat_input_bar.dart:142,261,331` | `'audio'` reply/edit preview | New case |
| `media_picker_sheet.dart` | `MediaAction.record` enum + available + tile | New enum value |
| `feature_flags.dart` | `audioMessagesEnabled` | New flag |
| `debug_config.dart` | `chatAudio` flag | New flag |
| `error_messages.dart` | 4 error codes | New entries |
| `chat_screen.dart` | `AudioPlayer _audioPlayer` + dispose + pass downstream | New code |
| `chat_messages_list.dart` | `audioPlayer` param + pass to `MessageBubble` | New param |
| `audio_recorder_sheet.dart` | Νέο widget — recording UI | **NEW FILE** |
| `audio_message_bubble.dart` | Νέο widget — playback bubble | **NEW FILE** |
| **Firestore rules** | ❌ **Καμία** | — |
| **Storage rules** | ❌ **Καμία** | — |
| **Firestore indexes** | ❌ **Καμία** | — |
| **ChatCacheTable (Drift)** | ❌ **Καμία** | — |
| **Auth guards** | ❌ **Καμία** | — |
| **Block checks** | ❌ **Καμία** | — |
| **deleteAllChatMedia** | ❌ **Καμία** | Already covers `chat_media/{chatId}/*` |
| **pubspec.yaml** | `record: ^5.0.0`, `audioplayers: ^6.0.0` | New packages |

---

## Παράρτημα: Βασικές Εντολές για το νέο chat

```bash
# Μετά από αλλαγές σε models/providers
dart run build_runner build --delete-conflicting-outputs

# Έλεγχος
flutter analyze
flutter test

# Run με debug logs
flutter run --dart-define=ENABLE_RELEASE_DEBUG=true

# Για να δεις το νέο debug flag chatAudio
# Φιλτράρισμα: adb logcat | grep "chatAudio"
```

---

*Τέλος πρότασης — Έκδοση 2.0 — 24 Ιουλίου 2026*
