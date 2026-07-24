# Video Message Support — Πρόταση Υλοποίησης v2.1

> **Βασισμένο στην αρχιτεκτονική Audio Message v2.0**
> **Επαναχρησιμοποίηση υπαρχόντων patterns αντί δημιουργίας νέων**
> Ημερομηνία: 24 Ιουλίου 2026
> **v2.1**: Διορθώσεις από audit — DebugConfig bool (όχι int), error_messages, `_messagesList` late→late Widget, line numbers, missing 'video' cases σε reply/edit banners

---

## Πίνακας Περιεχομένων

1. [Σκοπός](#1-σκοπός)
2. [Αλλαγές από v1.0](#2-αλλαγές-από-v10)
3. [User Flow](#3-user-flow)
4. [Αρχιτεκτονική Επισκόπηση](#4-αρχιτεκτονική-επισκόπηση)
5. [Feature Flag](#5-feature-flag)
6. [Debug Flag](#6-debug-flag)
7. [MediaAction Enum — videoGallery & videoCamera](#7-mediaaction-enum--videogallery--videocamera)
8. [Media Picker Sheet](#8-media-picker-sheet)
9. [ChatInputBar — `_pickAndSendVideoGallery` / `_pickAndSendVideoCamera`](#9-chatinputbar--_pickandsendvideogallery--_pickandsendvideocamera)
10. [ChatInputBar — `_showMediaPicker` switch](#10-chatinputbar--_showmediapicker-switch)
11. [ChatInputBar — Reply/Edit Banner Preview](#11-chatinputbar--replyedit-banner-preview)
12. [ChatRepository — `sendMediaMessage`](#12-chatrepository--sendmediamessage)
13. [ChatRepositoryImpl — Video Upload Block](#13-chatrepositoryimpl--video-upload-block)
14. [ChatRepositoryImpl — Duration Field](#14-chatrepositoryimpl--duration-field)
15. [ChatRepositoryImpl — Skip-Decrypt (ήδη υπάρχει)](#15-chatrepositoryimpl--skip-decrypt-ήδη-υπάρχει)
16. [GroupChatMixin — Skip-Decrypt (ήδη υπάρχει)](#16-groupchatmixin--skip-decrypt-ήδη-υπάρχει)
17. [ChatProvider — `sendMediaMessage` Pass-through](#17-chatprovider--sendmediamessage-pass-through)
18. [MessageBubble — `'video'` Case](#18-messagebubble--video-case)
19. [VideoMessageBubble (Νέο Widget)](#19-videomessagebubble-νέο-widget)
20. [ChatScreen — VideoPlayer Ownership](#20-chatscreen--videoplayer-ownership)
21. [ChatMessagesList — Pass videoPlayer Downstream](#21-chatmessageslist--pass-videoplayer-downstream)
22. [ChatMessagesList._onEdit — Type Guard (ήδη υπάρχει)](#22-chatmessageslist_onedit--type-guard-ήδη-υπάρχει)
23. [MessageActionBar & BubbleLongPressWrapper (ήδη υπάρχει)](#23-messageactionbar--bubblelongpresswrapper-ήδη-υπάρχει)
24. [ChatListScreen — Last Message Preview](#24-chatlistscreen--last-message-preview)
25. [Error Messages](#25-error-messages)
26. [Αναγκαία Packages](#26-αναγκαία-packages)
27. [Android Permissions](#27-android-permissions)
28. [iOS Permissions](#28-ios-permissions)
29. [Rebuild Storm Prevention](#29-rebuild-storm-prevention)
30. [Προαπαιτούμενα / Μπλοκαρίσματα](#30-προαπαιτούμενα--μπλοκαρίσματα)
31. [ΔΕΝ χρειάζονται](#31-δεν-χρειάζονται)
32. [Edge Cases](#32-edge-cases)
33. [SPoTs — Τελικός Πίνακας](#33-spots--τελικός-πίνακας)
34. [Παράρτημα: Βασικές Εντολές](#34-παράρτημα-βασικές-εντολές)

---

## 1. Σκοπός

Δυνατότητα αποστολής **σύντομων video μηνυμάτων** στο chat:

- **Λήψη**: από gallery (υπάρχον) ή κάμερα (νέα εγγραφή)
- **Διάρκεια**: max **30 δευτερόλεπτα** (native picker constraint + validation after pick)
- **Upload**: Firebase Storage → `chat_media/{chatId}/{msgId}.mp4`
- **Playback**: Inline στο chat bubble με video_player
- **Play**: Μόνο με tap (ποτέ auto-play)
- **Mute**: Παίζει muted by default, tap ηχείου για unmute
- **v1 χωρίς thumbnail**: Play button overlay σε σκούρο container με film icon

---

## 2. Αλλαγές από v1.0

| v1.0 | v2.1 | Αιτιολογία |
|------|------|-------------|
| `MediaAction.video` | `MediaAction.videoGallery`, `MediaAction.videoCamera` | Αντιστοιχεί ακριβώς στο photo/camera pattern |
| `VideoSourceSheet` (νέο widget) | ❌ **Απαλείφθηκε** | Δύο MediaAction entries = zero νέα widget |
| `VideoThumbnailGenerator` (νέο utility) | ❌ **Απαλείφθηκε** | v1 χωρίς thumbnail — play button overlay |
| `thumbnail` Firestore field | ❌ **Απαλείφθηκε** | Δε χρειάζεται χωρίς thumbnail |
| `video_thumbnail` package | ❌ **Απαλείφθηκε** | Εξάρτηση που δεν χρειάζεται |
| `ReadReceiptFooter` (νέο) | `ReadReceiptFooter` (υπάρχον) | Ήδη υπάρχει στο `message_bubble/` |
| `BubbleLongPressWrapper.canEdit` | Ήδη υπάρχει | Από audio implementation |
| `chat_list_screen.dart:276` fallback | `chat_list_screen.dart:277` `'video'` case | Missing preview για video |
| `debug_config.dart` `int` flags | `bool` flags | Το codebase χρησιμοποιεί `bool`, όχι `int` |
| `error_messages.dart` 3 codes | ❌ **Έλειπαν** — 3 codes `chat/video-*` | Πρέπει να προστεθούν |

### Συνοπτικά:
- **v1.0 είχε**: 3 new files, 2 new packages, 2 new permissions, 26 SPoTs
- **v2.1 έχει**: 1 new file (VideoMessageBubble), 1 new package, 2 new permissions, 21 SPoTs, 3 error codes
- **Επαναχρησιμοποιήθηκαν**: `ReadReceiptFooter`, `BubbleLongPressWrapper`, `MessageActionBar`, skip-decrypt lists, `deleteAllChatMedia`

---

## 3. User Flow

```
1. Χρήστης πατάει "+" → MediaPickerSheet
2. Βλέπει: [Emoji] [GIF] [Photo] [Camera] [Video Gallery] [Video Camera] [Record]
3. Πατάει "Video Gallery" → native gallery picker (φιλτράρει μόνο video)
4. Πατάει "Video Camera" → native camera recorder (max 30s native + validation)
5. Επιλέγει/εγγράφει video → bytes → upload → send
6. Παραλήπτης βλέπει: film icon + play button + duration badge
7. Tap → inline playback (muted, loop)
```

---

## 4. Αρχιτεκτονική Επισκόπηση

```
ChatInputBar._showMediaPicker
  │
  ├─ MediaAction.videoGallery → _pickAndSendVideoGallery()
  │     └─ ImagePicker.pickVideo(source: ImageSource.gallery)
  │
  └─ MediaAction.videoCamera  → _pickAndSendVideoCamera()
        └─ ImagePicker.pickVideo(source: ImageSource.camera)

→ ChatProvider.sendMediaMessage(type: 'video', videoBytes, duration)
→ ChatRepositoryImpl.sendMediaMessage
    → Firebase Storage: chat_media/{chatId}/{msgId}.mp4
    → Firestore: {type:'video', content:URL, duration:N}

→ MessageBubble (type=='video') → VideoMessageBubble (StatefulWidget)
    → Stack[ Container(film icon + play ▶) , DurationBadge ]
    → VideoPlayerController από ChatScreen (όχι provider)
```

---

## 5. Feature Flag

**Αρχείο:** `lib/core/config/feature_flags.dart:22-26`

```dart
// Media (lines 22-26)
static const bool gifSupportEnabled = true;
static const bool mediaMessagesEnabled = true;
static const bool audioMessagesEnabled = true;
static const bool videoMessagesEnabled = false;   // ← NEW (line 26)
```

---

## 6. Debug Flag

**Αρχείο:** `lib/core/debug/debug_config.dart:122-123`

```dart
// Chat flags (section lines 113-123)
static const bool chatAudio = true;              // line 122 (existing — bool, όχι int!)
static const bool chatVideo = true;              // ← NEW (line 123, after chatAudio)
```

> **ΣΗΜΕΙΩΣΗ v2.1:** Το codebase χρησιμοποιεί `static const bool` για όλα τα debug flags.
> Η αρχική πρόταση (v1.0/v2.0) είχε `static const int chatVideo = 1 << 30` που είναι **ΛΑΘΟΣ**.
> Στο `debug_config.dart` line 122: `static const bool chatAudio = true;`, όχι `int`.

---

## 7. MediaAction Enum — videoGallery & videoCamera

**Αρχείο:** `lib/features/chat/widgets/media_picker_sheet.dart:7`

```dart
enum MediaAction { emoji, gif, photo, camera, record,
  videoGallery, videoCamera,        // ← NEW (δύο entries, matching photo/camera)
}
```

---

## 8. Media Picker Sheet

**Αρχείο:** `lib/features/chat/widgets/media_picker_sheet.dart:13`

### 8α. Available list (line 13-18)
```dart
final available = <MediaAction>[
  MediaAction.emoji,
  if (FeatureFlags.gifSupportEnabled) MediaAction.gif,
  if (FeatureFlags.mediaMessagesEnabled) ...[MediaAction.photo, MediaAction.camera],
  if (FeatureFlags.audioMessagesEnabled && !kIsWeb) MediaAction.record,
  if (FeatureFlags.videoMessagesEnabled && !kIsWeb) ...[
    MediaAction.videoGallery, MediaAction.videoCamera,   // ← NEW
  ],
];
```

### 8β. Tiles (line 63-73, switch)
```dart
MediaAction.videoGallery => (Icons.video_library_outlined,
    greek ? 'Βίντεο' : 'Video'),
MediaAction.videoCamera => (Icons.videocam_outlined,
    greek ? 'Εγγραφή βίντεο' : 'Record Video'),
```

---

## 9. ChatInputBar — `_pickAndSendVideoGallery` / `_pickAndSendVideoCamera`

**Αρχείο:** `lib/features/chat/widgets/chat_input_bar.dart`

Ακολουθεί το ακριβές pattern των `_pickAndSendPhoto` / `_pickAndSendCamera` (lines 189-229):

```dart
Future<void> _pickAndSendVideoGallery() =>
    _pickVideo(ImageSource.gallery, 'videoGallery');

Future<void> _pickAndSendVideoCamera() =>
    _pickVideo(ImageSource.camera, 'videoCamera');

Future<void> _pickVideo(ImageSource source, String debugLabel) async {
  DebugConfig.log(DebugConfig.chatVideo,
      'ChatInputBar: $debugLabel picker shown');
  if (widget.emojiPickerVisible) widget.onEmojiDismiss();
  final greek = L10n.isGreek(context);

  try {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30),
    );
    if (picked == null || !mounted) return;

    // Διάβασμα bytes
    final bytes = await File(picked.path).readAsBytes();

    // Duration από VideoPlayerController (προσωρινό)
    int durationSeconds = 0;
    try {
      final controller = VideoPlayerController.file(File(picked.path));
      await controller.initialize();
      durationSeconds = controller.value.duration.inSeconds;
      await controller.dispose();
    } catch (e) {
      DebugConfig.warn('ChatInputBar: video duration read failed', data: e);
    }

    // Validation
    if (durationSeconds > 30) {
      AppMessenger.showError(context,
          greek ? 'Το βίντεο είναι πολύ μεγάλο (μέγιστο 30s)'
                : 'Video is too long (max 30 seconds)');
      return;
    }
    if (durationSeconds < 1) {
      AppMessenger.showError(context,
          greek ? 'Το βίντεο είναι πολύ μικρό'
                : 'Video is too short');
      return;
    }

    // Αποστολή
    final replyToData = _buildReplyData();
    _clearReply();
    setState(() => _isLoading = true);
    final ok = await ref.read(chatActionsProvider.notifier)
        .sendMediaMessage(widget.chatId,
            content: '', type: 'video',
            replyTo: replyToData,
            videoBytes: bytes,
            duration: durationSeconds);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      AppMessenger.showError(context,
          ErrorMessages.get('chat/video-send-failed', greek));
    }
  } catch (e, s) {
    DebugConfig.error('ChatInputBar: $debugLabel pick failed', data: e,
        exception: s);
    if (mounted) {
      AppMessenger.showError(context,
          ErrorMessages.get('chat/video-send-failed', greek));
    }
  }
}
```

> **Import:** `dart:io` ήδη υπάρχει (line 1). `package:video_player/video_player.dart` χρειάζεται για `VideoPlayerController`.

---

## 10. ChatInputBar — `_showMediaPicker` switch

**Αρχείο:** `lib/features/chat/widgets/chat_input_bar.dart:258-279`

```dart
case MediaAction.videoGallery:
  DebugConfig.log(DebugConfig.chatVideo,
      'ChatInputBar: media popup: video gallery');
  _pickAndSendVideoGallery();
case MediaAction.videoCamera:
  DebugConfig.log(DebugConfig.chatVideo,
      'ChatInputBar: media popup: video camera');
  _pickAndSendVideoCamera();
```

---

## 11. ChatInputBar — Reply/Edit Banner Preview

**Αρχείο:** `lib/features/chat/widgets/chat_input_bar.dart`

Το codebase χρησιμοποιεί if-else-if chains (όχι switch). Χρειάζεται `'video'` case σε 3 σημεία.

### 11α. `_buildReplyData` (line 143)
```dart
if (type == 'audio') {
  contentPreview = '🎵 Recording';
} else if (type == 'gif') {
  contentPreview = '🎞️ GIF';
} else if (type == 'image') {
  contentPreview = '📷 Photo';
} else if (type == 'video') {             // ← NEW (μετά το image)
  contentPreview = '🎬 Video';
} else if (isEmoji) {
  contentPreview = content.trim();
} else {
  contentPreview = content.length > 80 ? '${content.substring(0, 80)}...' : content;
}
```

### 11β. `_buildReplyBanner` (line 290)
```dart
if (type == 'audio') {
  preview = greek ? '🎵 Ηχογράφηση' : '🎵 Recording';
} else if (type == 'gif') {
  preview = '🎞️ GIF';
} else if (type == 'image') {
  preview = greek ? '📷 Φωτογραφία' : '📷 Photo';
} else if (type == 'video') {             // ← NEW (μετά το image)
  preview = greek ? '🎬 Βίντεο' : '🎬 Video';
} else if (isEmoji) {
  preview = content.trim();
} else {
  preview = content.length > 80 ? '${content.substring(0, 80)}...' : content;
}
```

### 11γ. `_buildEditBanner` (line 362)
```dart
if (type == 'audio') {
  preview = greek ? '🎵 Ηχογράφηση' : '🎵 Recording';
} else if (type == 'gif') {
  preview = '🎞️ GIF';
} else if (type == 'image') {
  preview = greek ? '📷 Φωτογραφία' : '📷 Photo';
} else if (type == 'video') {             // ← NEW (μετά το image)
  preview = greek ? '🎬 Βίντεο' : '🎬 Video';
} else if (isEmoji) {
  preview = content.trim();
} else {
  preview = content.length > 80 ? '${content.substring(0, 80)}...' : content;
}
```

---

## 12. ChatRepository — `sendMediaMessage`

**Αρχείο:** `lib/repositories/chat_repository.dart:120`

```dart
Future<void> sendMediaMessage(String chatId, {
  required String content,
  required String type,
  Map<String, dynamic>? replyTo,
  Uint8List? imageBytes,
  Uint8List? audioBytes,
  Uint8List? videoBytes,        // ← NEW
  int? duration,
});
```

> **Σημείωση:** `thumbnailBytes` ΔΕΝ προστίθεται (v1 χωρίς thumbnails).

---

## 13. ChatRepositoryImpl — Video Upload Block

**Αρχείο:** `lib/repositories/chat_repository_impl.dart:779`

```dart
// Στο sendMediaMessage, μετά το audio upload block (line 836-844):
if (videoBytes != null && type == 'video') {
  DebugConfig.log(DebugConfig.chatVideo,
      'sendMediaMessage: uploading video chat=$chatId');
  final storageRef = FirebaseStorage.instance
      .ref().child('chat_media/$chatId/${msgRef.id}.mp4');
  await storageRef.putData(videoBytes,
      SettableMetadata(contentType: 'video/mp4'));
  content = await storageRef.getDownloadURL();
}
```

**Στο msgData (line 846):**
```dart
final msgData = <String, dynamic>{
  'senderId': user.uid,
  'content': content,
  'type': type,
  'timestamp': FieldValue.serverTimestamp(),
  'isRead': false,
  if ((type == 'audio' || type == 'video') && duration != null)
    'duration': duration,                       // ← NEW: 'video' added
};
```

> Το `'video'` προστίθεται στην ίδια συνθήκη με το `'audio'` (line 852).

---

## 14. ChatRepositoryImpl — Duration Field

**Αρχείο:** `lib/repositories/chat_repository_impl.dart:380`

```dart
// _decodeMessageDoc — ήδη υπάρχει (line 380):
'duration': data['duration'] as int? ?? 0,
```

> **Δεν χρειάζεται αλλαγή** — το `duration` ήδη διαβάζεται από το doc για όλα τα types.

---

## 15. ChatRepositoryImpl — Skip-Decrypt (ήδη υπάρχει)

**Αρχείο:** `lib/repositories/chat_repository_impl.dart`

```dart
// _decodeMessageDoc line 342 — 'video' ήδη υπάρχει:
} else if (type == 'gif' || type == 'image' || type == 'video' || type == 'audio') {

// _syncChatFromFirestore line 599 — 'video' ήδη υπάρχει:
lastMessageType != 'gif' &&
lastMessageType != 'image' &&
lastMessageType != 'video' &&
lastMessageType != 'audio'
```

> ✅ **Zero changes** — `'video'` ήδη συμπεριλαμβάνεται στα skip-decrypt lists.

---

## 16. GroupChatMixin — Skip-Decrypt (ήδη υπάρχει)

**Αρχείο:** `lib/repositories/group_chat_mixin.dart:177`

```dart
lastMessageType != 'video' &&
```

> ✅ **Zero changes** — `'video'` ήδη συμπεριλαμβάνεται.

---

## 17. ChatProvider — `sendMediaMessage` Pass-through

**Αρχείο:** `lib/features/chat/providers/chat_provider.dart:252`

```dart
Future<bool> sendMediaMessage(String chatId, {
  required String content,
  required String type,
  Map<String, dynamic>? replyTo,
  Uint8List? imageBytes,
  Uint8List? audioBytes,
  Uint8List? videoBytes,        // ← NEW
  int? duration,
}) async {
  DebugConfig.log(DebugConfig.repositoryCall,
      'ChatActions: sendMediaMessage chat=$chatId type=$type');
  state = const ChatActionState(status: ChatActionStatus.loading);
  try {
    await _chatRepo.sendMediaMessage(chatId,
        content: content, type: type,
        replyTo: replyTo,
        imageBytes: imageBytes,
        audioBytes: audioBytes,
        videoBytes: videoBytes,     // ← NEW
        duration: duration);
    ...
  }
}
```

---

## 18. MessageBubble — `'video'` Case

**Αρχείο:** `lib/features/chat/widgets/message_bubble/message_bubble.dart:63`

```dart
return switch (type) {
  'audio' => AudioMessageBubble(...),
  'system' => SystemMessageBubble(...),
  'gif' || 'image' => GifImageBubble(...),
  'video' => VideoMessageBubble(           // ← NEW case (μετά gif/image)
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
    videoPlayer: videoPlayer,
  ),
  _ when type == 'text' && isOnlyEmoji(content) => EmojiOnlyBubble(...),
  _ => TextMessageBubble(...),
};
```

---

## 19. VideoMessageBubble (Νέο Widget)

**Αρχείο:** `lib/features/chat/widgets/message_bubble/video_message_bubble.dart`

### 19α. Σχεδιασμός

```
┌──────────────────────────────────┐
│  [ReplyPreview] (optional)       │
│  [SenderHeader] (group)          │
│  ┌────────────────────────────┐  │
│  │       🎬 Film icon         │  │
│  │       ▶ Play button        │  │
│  │                            │  │
│  │           0:05 (duration)  │  │
│  └────────────────────────────┘  │
│  [ReadReceiptFooter]             │
│  [MessageReactionsRow]           │
└──────────────────────────────────┘
```

### 19β. Δομή Widget Tree (reusing `AudioMessageBubble` pattern)

```
VideoMessageBubble (StatefulWidget)
├── LayoutBuilder
│   └── Column
│       ├── SenderHeader (if group + showAvatar)
│       ├── ReplyPreview (if replyTo)
│       ├── Stack
│       │   ├── BubbleLongPressWrapper (canEdit: false)
│       │   │   └── Container (bubbleColor, borderRadius → constraints)
│       │   │       └── GestureDetector (onTap: togglePlay)
│       │   │           └── SizedBox (16:9 aspect ratio)
│       │   │               └── Stack
│       │   │                   ├── Container (dark bg + film icon) [όταν stopped]
│       │   │                   ├── VideoPlayer [όταν playing]
│       │   │                   ├── Center → Icon (play/pause, semi-transparent)
│       │   │                   └── Positioned(bottom-right) → DurationBadge
│       │   └── Positioned → TailPainter
│       ├── MessageReactionsRow
│       └── ReadReceiptFooter (υπάρχον widget)
```

### 19γ. StatefulWidget lifecycle (pattern από AudioMessageBubble)

```dart
class VideoMessageBubble extends StatefulWidget {
  // Ίδιες παράμετροι με AudioMessageBubble, αλλά:
  //   audioPlayer → videoPlayer (VideoPlayerController?)
  //   ΔΕΝ έχει duration display (εκτός από badge)
  final dynamic videoPlayer;   // VideoPlayerController? από ChatScreen

  const VideoMessageBubble({...});
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  bool _isPlaying = false;
  bool _isMuted = true;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _initPlayerListeners();
  }

  @override
  void didUpdateWidget(VideoMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _resetState();
      _initPlayerListeners();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    super.dispose();
  }

  void _resetState() {
    setState(() {
      _isPlaying = false;
      _isMuted = true;
    });
  }

  void _initPlayerListeners() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    final controller = _getController();
    if (controller == null) return;
  }

  VideoPlayerController? _getController() {
    if (widget.videoPlayer == null) return null;
    final c = widget.videoPlayer as VideoPlayerController;
    if (!c.value.isInitialized) return null;
    return c;
  }

  Future<void> _togglePlayPause() async {
    final controller = _getController();
    if (controller == null) return;
    try {
      if (_isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
      setState(() => _isPlaying = !_isPlaying);
    } catch (e, s) {
      DebugConfig.error('VideoBubble: playback error msg=${widget.messageId}',
          data: e, exception: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder → Column[ SenderHeader, ReplyPreview,
    //   Stack[BubbleLongPressWrapper, Container[GestureDetector[SizedBox[
    //     Stack[bg+icon, playButton, durationBadge]]]], TailPainter],
    //   MessageReactionsRow, ReadReceiptFooter ]
    ...
  }
}
```

### 19δ. Visual layout details

```
SizedBox with 16:9 aspect ratio:
  width: constraints.maxWidth * 0.75
  height: width * 9 / 16

When NOT playing:
  Container(color: Colors.black38)
  Center: Icon(Icons.play_circle_filled, size: 48, color: Colors.white70)

When playing:
  VideoPlayer(controller)

Duration badge (always visible):
  Positioned(bottom: 4, right: 4)
  Container(padding: 2x4, color: black54, borderRadius: 4)
  Text("0:05", white, fontSize: 11)

Mute toggle:
  Positioned(bottom: 4, left: 4)
  GestureDetector → Icon(volume_off/volume_up, white70, size: 16)
```

---

## 20. ChatScreen — VideoPlayer Ownership

**Αρχείο:** `lib/features/chat/screens/chat_screen.dart`

### 20α. Import
```dart
import 'package:video_player/video_player.dart';   // ← NEW
```

### 20β. State — **ΚΡΙΣΙΜΟ: `_messagesList` ΔΕΝ είναι `final`**
```dart
class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _audioPlayer = AudioPlayer();      // existing
  VideoPlayerController? _videoController;  // ← NEW
  late Widget _messagesList;                // ← FIX: ήταν `late final`, αφαιρέθηκε το `final`
                                            //   γιατί το _playVideo() το reassign

  @override
  void initState() {
    super.initState();
    _messagesList = ChatMessagesList(
      chatId: widget.chatId,
      audioPlayer: _audioPlayer,
      videoPlayer: _videoController,     // ← NEW (initially null)
    );
    ...
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _audioPlayer.dispose();
    _videoController?.dispose();         // ← NEW
    super.dispose();
  }
}
```

> **v2.1 FIX:** Το `late final Widget _messagesList` (γραμμή 62) πρέπει να γίνει `late Widget _messagesList`. Το `final` εμποδίζει το reassign που κάνει το `_playVideo()`.

### 20γ. Play callback
```dart
Future<void> _playVideo(String url) async {
  // Stop προηγούμενο
  await _videoController?.pause();
  await _videoController?.dispose();

  final controller = VideoPlayerController.network(url);
  await controller.initialize();
  controller.setVolume(0.0);       // muted by default
  controller.setLooping(true);     // loop για short video
  await controller.play();

  setState(() {
    _videoController = controller;
    _messagesList = ChatMessagesList(   // rebuild messages list with new controller
      chatId: widget.chatId,
      audioPlayer: _audioPlayer,
      videoPlayer: _videoController,
    );
  });
}
```

### 20δ. Κρίσιμη απόφαση (ίδια με AudioPlayer)
**Το `VideoPlayerController` ΔΕΝ μπαίνει σε Riverpod provider.**
- Αποφυγή cascade rebuild όλων των bubbles όταν αλλάζει state
- Μόνο το bubble που παίζει κάνει setState
- `dispose()` στο `ChatScreen` καθαρίζει τα πάντα

---

## 21. ChatMessagesList — Pass videoPlayer Downstream

**Αρχείο:** `lib/features/chat/widgets/chat_messages_list.dart`

```dart
class ChatMessagesList extends ConsumerStatefulWidget {
  final String chatId;
  final dynamic audioPlayer;
  final dynamic videoPlayer;                 // ← NEW
  final Future<void> Function(String url)? onPlayVideo;  // ← NEW

  const ChatMessagesList({
    super.key,
    required this.chatId,
    this.audioPlayer,
    this.videoPlayer,                        // ← NEW
    this.onPlayVideo,                        // ← NEW
  });
```

Στο `itemBuilder` (line 321):
```dart
return MessageBubble(
  key: ValueKey(msgId),
  message: msg,
  currentUid: currentUid,
  ...
  audioPlayer: widget.audioPlayer,
  videoPlayer: widget.videoPlayer,     // ← NEW
  callbacks: MessageCallbacks(
    ...
    onPlayVideo: widget.onPlayVideo,   // ← NEW
  ),
);
```

**MessageCallbacks νέο πεδίο:**
```dart
// message_callbacks.dart
class MessageCallbacks {
  final Future<void> Function(String url)? onPlayVideo;   // ← NEW
  ...
}
```

---

## 22. ChatMessagesList._onEdit — Type Guard (ήδη υπάρχει)

**Αρχείο:** `lib/features/chat/widgets/chat_messages_list.dart:100`

```dart
void _onEdit(Map<String, dynamic> msg) {
  final type = msg['type'] as String? ?? 'text';
  if (type != 'text') {
    DebugConfig.log(DebugConfig.chatReply,
        '_onEdit: skipped for type=$type');   // ήδη υπάρχει
    return;
  }
  ...
}
```

> ✅ **Zero changes.** Το guard ήδη αποκλείει όλα τα non-text.

---

## 23. MessageActionBar & BubbleLongPressWrapper (ήδη υπάρχει)

**Αρχείο:** `lib/features/chat/widgets/message_action_bar.dart`
**Αρχείο:** `lib/features/chat/widgets/message_bubble/bubble_long_press_wrapper.dart`

- `MessageActionBar.showEdit: false` → ήδη υπάρχει
- `BubbleLongPressWrapper.canEdit: false` → ήδη υπάρχει (από audio)

Στο `VideoMessageBubble.build`:
```dart
BubbleLongPressWrapper(
  isMe: widget.isMe,
  canEdit: false,                    // video δεν επιδέχεται edit
  onReply: widget.onReply,
  onDelete: widget.onDelete,
  child: Container(...),
)
```

> ✅ **Zero changes.** Reuse of existing params.

---

## 24. ChatListScreen — Last Message Preview

**Αρχείο:** `lib/features/chat/screens/chat_list_screen.dart:268-277`

```dart
String? _buildPreviewText(bool greek, String title, bool isGroup) {
  final msg = chat.lastMessage;
  final sender = chat.lastMessageSender;
  final type = chat.lastMessageType ?? 'text';

  if (type != 'text') {
    if (type == 'image') return greek ? '📷 Φωτογραφία' : '📷 Photo';
    if (type == 'gif') return '🎞️ GIF';
    if (type == 'audio') return greek ? '🎵 Φωνητικό μήνυμα' : '🎵 Voice message';
    if (type == 'video') return greek ? '🎬 Βίντεο' : '🎬 Video';    // ← NEW (line 277, πριν default)
    return greek ? '💬 Μήνυμα' : '💬 Message';
  }
  ...
```

> **v2.1 FIX:** Line number διορθώθηκε από 276 σε 277. Το `video` case μπαίνει πριν το default return.

---

## 25. Error Messages

**Αρχείο:** `lib/core/utils/error_messages.dart:71-78`

Πρέπει να προστεθούν 3 νέα error codes (μετά το `chat/audio-too-short`):

```dart
case 'chat/audio-too-short':                      // υπάρχον (line 77)
  return isGreek ? 'Το ηχητικό μήνυμα είναι πολύ σύντομο' : 'Audio message is too short';
case 'chat/video-send-failed':                    // ← NEW
  return isGreek ? 'Αποστολή βίντεο απέτυχε' : 'Video send failed';
case 'chat/video-permission-denied':              // ← NEW
  return isGreek ? 'Δεν δόθηκε άδεια κάμερας' : 'Camera permission denied';
case 'chat/video-too-short':                      // ← NEW
  return isGreek ? 'Το βίντεο είναι πολύ σύντομο' : 'Video is too short';
```

> **v2.1 FIX:** Τα 3 error codes `chat/video-*` **έλειπαν** από την αρχική πρόταση. Το `assert` στο τέλος του switch θα πετούσε crash αν καλούνταν χωρίς mapping.

---

## 26. Αναγκαία Packages

**Αρχείο:** `pubspec.yaml`

| Package | Έκδοση | Χρήση |
|---------|--------|-------|
| `video_player` | ^2.9.0 | Playback inline |

```yaml
dependencies:
  video_player: ^2.9.0           # ← NEW (μόνο αυτό)
```

> **ΔΕΝ χρειάζεται:** `video_thumbnail`, `image_picker` (ήδη υπάρχει), `video_compress` (v1)

---

## 27. Android Permissions

**Αρχείο:** `android/app/src/main/AndroidManifest.xml`

```xml
<!-- Υπάρχον -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<!-- Νέο -->
<uses-permission android:name="android.permission.CAMERA"/>
```

> `READ_MEDIA_VIDEO` (Android 13+) το χειρίζεται το `image_picker` αυτόματα.

---

## 28. iOS Permissions

**Αρχείο:** `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>Η εφαρμογή χρειάζεται πρόσβαση στην κάμερα για εγγραφή βίντεο / The app needs camera access to record video</string>
```

> `NSPhotoLibraryUsageDescription` ήδη υπάρχει από photos. `NSMicrophoneUsageDescription` ήδη υπάρχει από audio.

---

## 29. Rebuild Storm Prevention

| Session | Μάθημα | Εφαρμογή στο Video |
|---------|--------|-------------------|
| 174 | `DeepCollectionEquality` cache | messagesStream return map — duration (int) και content (URL) δεν αλλάζουν, cache hit ✅ |
| 178 | participantUidsProvider identity | Ίδιο pattern, video δεν προσθέτει νέο provider |
| 179 | Leaf widget extraction | `VideoMessageBubble` = leaf widget, δεν ξαναχτίζει parent ChatMessagesList |
| 188 | `ValueKey(msgId)` | Ήδη υπάρχει στο `ChatMessagesList:322` — video messages το έχουν |
| 189 | MainShell StatefulWidget | `VideoPlayerController` κρατιέται στο `ChatScreen` (StatefulWidget), όχι σε provider |
| 192 | `select()` returns Map (deep comparison) | Δεν επηρεάζεται — video είναι type στο message map |
| 195 | pending=true suppression | Δεν επηρεάζεται — video πάει από sendMediaMessage |
| 196 | Pre-computed bubbleMaxWidth | `VideoMessageBubble` χρησιμοποιεί `LayoutBuilder` με `constraints.maxWidth * 0.75` |
| 197 | markAsRead σε postFrameCallback | Δεν επηρεάζεται |
| 198 | `_SafeInputArea` leaf widget | Δεν επηρεάζεται |
| 199 | pending=true suppression | Δεν επηρεάζεται |
| 200 | `_MessageBubbleSignature` + `_obtainBubble` cache | VideoMessageBubble μπαίνει στο switch → signature περιλαμβάνει content+type+duration → cache δουλεύει αυτόματα |
| 200 | messagesStream equality caching | `DeepCollectionEquality` σε decrypted list — video content (URL) και duration (int) σταθερά → cache hit ✅ |

### Κρίσιμη απόφαση για VideoPlayerController

**Το `VideoPlayerController` ΔΕΝ μπαίνει σε Riverpod provider** (ίδια λογική με AudioPlayer):

- `ChatScreen` (ConsumerStatefulWidget) κρατάει `VideoPlayerController?`
- Περνιέται downstream: `ChatScreen → ChatMessagesList → MessageBubble → VideoMessageBubble`
- Κάθε `VideoMessageBubble` έχει **τοπικό** play/pause state (`StatefulWidget`)
- Μόνο το bubble που παίζει κάνει setState → κανένα cascade
- `dispose()` στο `ChatScreen` καλεί `_videoController?.dispose()`
- Όταν ο χρήστης tap σε διαφορετικό video, το `_playVideo(url)` callback:
  1. Κάνει dispose του προηγούμενου controller
  2. Δημιουργεί νέο για το νέο URL
  3. Κάνει rebuild το `ChatMessagesList` με το νέο controller (reassign `_messagesList`)
  4. Το νέο bubble παίρνει τον controller, το παλιό bubble βλέπει `null` → σταματάει

---

## 30. Προαπαιτούμενα / Μπλοκαρίσματα

| # | Προαπαιτούμενο | Τύπος | Λεπτομέρειες |
|---|---------------|-------|-------------|
| 1 | `video_player: ^2.9.0` | pubspec.yaml | Playback inline |
| 2 | `CAMERA` permission | Android manifest | Για εγγραφή video |
| 3 | `NSCameraUsageDescription` | iOS Info.plist | Κάμερα |
| 4 | `import 'dart:typed_data'` | chat_input_bar.dart | Για `Uint8List` |
| 5 | `import 'dart:io'` | chat_input_bar.dart | Ήδη υπάρχει |
| 6 | `kIsWeb` import | media_picker_sheet.dart | Ήδη υπάρχει |
| 7 | `import 'package:video_player/video_player.dart'` | chat_screen.dart, chat_input_bar.dart | Για `VideoPlayerController` |

---

## 31. ΔΕΝ χρειάζονται

| Τι | Γιατί |
|----|-------|
| Firestore rules changes | Type-agnostic — ήδη accepts 'video' |
| Storage rules changes | `chat_media/{chatId}/` already wildcard — .mp4 covered |
| Firestore indexes changes | Messages queries unchanged |
| Drift schema migration | `lastMessageType` already exists, `duration` is Firestore-only |
| Auth guards changes | Already handled by `sendMediaMessage` |
| Block checks changes | Already handled by `sendMediaMessage` |
| deleteAllChatMedia changes | Already deletes `chat_media/{chatId}/*` — .mp4 included |
| Permission handler package | `image_picker` handles runtime permissions |
| `video_thumbnail` package | v1 χωρίς thumbnails |
| `VideoSourceSheet` widget | Δύο MediaAction entries cover gallery + camera |
| `VideoThumbnailGenerator` utility | Δε χρειάζεται thumbnail για v1 |
| `thumbnail` Firestore field | Δε χρειάζεται για v1 |
| Skip-decrypt lists | `'video'` ήδη υπάρχει σε όλα τα σημεία ✅ |
| `BubbleLongPressWrapper.canEdit` | Ήδη υπάρχει από audio ✅ |
| `MessageActionBar.showEdit` | Ήδη υπάρχει από audio ✅ |
| `_onEdit` type guard | Ήδη υπάρχει, αποκλείει όλα τα non-text ✅ |
| `ReadReceiptFooter` | Ήδη υπάρχει στο message_bubble/ ✅ |

---

## 32. Edge Cases

| # | Edge Case | Προστασία |
|---|-----------|-----------|
| 1 | **max 30s duration** | `ImagePicker.pickVideo(maxDuration:)` + validation after pick |
| 2 | **min <1s** | Validation after pick → `AppMessenger.showError('chat/video-too-short')` |
| 3 | **file >10MB** | Storage rules reject → catch → `AppMessenger.showError('chat/video-send-failed')` |
| 4 | **permission denied (camera)** | `DebugConfig.warn` + `AppMessenger.showError('chat/video-permission-denied')` |
| 5 | **permission denied (gallery)** | `DebugConfig.warn` + `AppMessenger.showError('chat/video-permission-denied')` |
| 6 | **playback overlap (tap video B while A plays)** | `_playVideo()` dispose previous → new controller → old bubble sees null → stops |
| 7 | **navigate away during playback** | `ChatScreen.dispose()` → `_videoController?.dispose()` |
| 8 | **edit on video message** | 3-layer guard: `canEdit: false`, `_onEdit` type check, `showEdit: false` |
| 9 | **reply to video** | Preview: `'🎬 Βίντεο' / '🎬 Video'` |
| 10 | **group chat video** | sendMediaMessage ήδη υποστηρίζει groups |
| 11 | **encrypt attempt on video** | `'video'` ήδη στο skip-decrypt list ✅ |
| 12 | **storage cleanup on delete** | `deleteAllChatMedia(chatId)` — .mp4 covered ✅ |
| 13 | **kIsWeb** | Both `videoGallery` & `videoCamera` only if `!kIsWeb` |
| 14 | **release mode** | All debug logs via `DebugConfig.log(chatVideo, ...)` |
| 15 | **widget rebuild during playback** | `VideoMessageBubble` StatefulWidget, `didUpdateWidget` checks `content` URL |
| 16 | **playback error (corrupted file)** | Catch → `DebugConfig.error` + showError |
| 17 | **unsupported video codec** | ImagePicker δεσμεύει για MP4 (H.264) |
| 18 | **very long video selected** | `ImagePicker.pickVideo(maxDuration:)` truncates natively |
| 19 | **no internet during upload** | Repository catch → `AppMessenger.showError('chat/video-send-failed')` |
| 20 | **controller not initialized** | `_getController()` checks `isInitialized`, returns null if not ready |

---

## 33. SPoTs — Τελικός Πίνακας

| SPoT | Αλλαγή | Τύπος |
|------|---------|:-----:|
| `chat_repository.dart:120` | `Uint8List? videoBytes` | New param |
| `chat_repository_impl.dart:779` | Video upload block + duration condition (line 852) | New code |
| `chat_repository_impl.dart:342` | `'video'` in skip-decrypt list | ✅ Ήδη υπάρχει |
| `chat_repository_impl.dart:599` | `'video'` in skip-decrypt list | ✅ Ήδη υπάρχει |
| `chat_provider.dart:252` | `videoBytes`, `duration` pass-through | New params |
| `message_bubble.dart:63` | `'video'` case → `VideoMessageBubble` | New case |
| `message_callbacks.dart` | `onPlayVideo` callback | New field |
| `chat_messages_list.dart` | `videoPlayer`, `onPlayVideo` params + pass to MessageBubble | New params |
| `chat_messages_list.dart:100` | `_onEdit` type guard | ✅ Ήδη υπάρχει |
| `message_action_bar.dart` | `showEdit` param | ✅ Ήδη υπάρχει |
| `bubble_long_press_wrapper.dart` | `canEdit` param | ✅ Ήδη υπάρχει |
| `chat_list_screen.dart:277` | `'video'` preview case (πριν default) | New case |
| `chat_input_bar.dart` | `_pickAndSendVideoGallery()` + `_pickAndSendVideoCamera()` | New methods |
| `chat_input_bar.dart:258` | `MediaAction.videoGallery` + `videoCamera` cases | New cases |
| `chat_input_bar.dart:143,290,362` | `'video'` reply/edit preview (if-else-if chain) | New cases |
| `media_picker_sheet.dart` | `MediaAction.videoGallery` + `videoCamera` enum + available + tiles | New enum values |
| `feature_flags.dart:26` | `videoMessagesEnabled` | New flag |
| `debug_config.dart:123` | `chatVideo` flag (`bool`, όχι `int`) | New flag |
| `error_messages.dart:79-85` | 3 error codes: `chat/video-send-failed`, `chat/video-permission-denied`, `chat/video-too-short` | New entries |
| `chat_screen.dart:59-68` | `VideoPlayerController?`, `_playVideo()`, `late Widget _messagesList` (όχι final), `dispose()` + pass downstream + import | New code |
| `video_message_bubble.dart` | Νέο widget — video playback bubble | **NEW FILE** |
| `group_chat_mixin.dart:177` | `'video'` in skip-decrypt list | ✅ Ήδη υπάρχει |
| `ReadReceiptFooter` | (χρήση υπάρχοντος widget) | ✅ Ήδη υπάρχει |
| `deleteAllChatMedia` | (καλύπτει ήδη .mp4) | ✅ Ήδη υπάρχει |
| **Firestore rules** | ❌ **Καμία** | — |
| **Storage rules** | ❌ **Καμία** | — |
| **Firestore indexes** | ❌ **Καμία** | — |
| **Drift schema** | ❌ **Καμία** | — |
| **Auth guards** | ❌ **Καμία** | — |
| **Block checks** | ❌ **Καμία** | — |
| **pubspec.yaml** | `video_player: ^2.9.0` | 1 new package |

### Σύνοψη

| Μέγεθος | v1.0 | v2.1 |
|---------|:----:|:----:|
| **New files** | 3 (VideoMessageBubble, VideoSourceSheet, VideoThumbnailGenerator) | **1** (VideoMessageBubble) |
| **New packages** | 2 (video_player, video_thumbnail) | **1** (video_player) |
| **New Firestore fields** | 2 (duration, thumbnail) | **1** (duration) |
| **SPoTs requiring edits** | 26 | **21** (5 ήδη υπάρχουν) |
| **Edge cases** | 20 | **20** |
| **Error codes** | 0 | **3** (video-send-failed, video-permission-denied, video-too-short) |
| **Debug flags** | 1 (`int chatVideo`) | **1** (`bool chatVideo`) |

---

## 34. Παράρτημα: Βασικές Εντολές για το νέο chat

```bash
# Προσθήκη πακέτου
flutter pub add video_player

# Μετά από αλλαγές σε models/providers
dart run build_runner build --delete-conflicting-outputs

# Έλεγχος
flutter analyze
flutter test

# Run με debug logs
flutter run --dart-define=ENABLE_RELEASE_DEBUG=true

# Φιλτράρισμα video debug logs
# Android: adb logcat | grep "chatVideo"
# iOS: flutter logs | grep "chatVideo"
```

---

## 35. Εκκρεμότητα — Video Thumbnails (v2.2)

**Σχεδίαση:** 24 Ιουλίου 2026 — υπό έγκριση.

### Απαιτείται
- `flutter pub add video_thumbnail` (native-only, web → non-fatal fallback)

### Αλλαγές

| SPoT | Αλλαγή |
|------|--------|
| `chat_input_bar.dart:264` | Thumbnail extraction (`kIsWeb` guard + try-catch) μετά duration, πριν sendMediaMessage |
| `chat_input_bar.dart:311` | `thumbnailBytes:` pass to sendMediaMessage |
| `chat_repository.dart:120` | `Uint8List? thumbnailBytes` new param |
| `chat_repository_impl.dart:848-869` | Thumbnail upload (`putData`, `${msgId}_thumb.jpg`) + msgData `thumbnailUrl` |
| `chat_provider.dart:252` | `thumbnailBytes` param + pass-through |
| `message_bubble.dart:105-130` | `thumbnailUrl` extraction + pass to VideoMessageBubble |
| `video_message_bubble.dart` | `thumbnailUrl` property + `CachedNetworkImage` (placeholder/errorWidget → generic icon) |

### Λογική εμφάνισης
- `isMyController` → `VideoPlayer`
- `else if thumbnailUrl != null` → `CachedNetworkImage`
- `else` → generic icon (`Icons.movie_creation_outlined`)
- loading → spinner (υπάρχων μηχανισμός `isLoadingUrl`)

### Rebuild storm
- `DeepCollectionEquality` σε 3 layers (messagesStream, messagesProvider, combinedMessagesProvider)
- `thumbnailUrl` string γράφεται μία φορά, ποτέ δεν αλλάζει → cache hit ✅
- `ValueKey(msgId)` → Flutter reuses widget

### Edge cases (12)
| # | Edge | Προστασία |
|---|------|-----------|
| 1 | Extraction fails | try-catch → non-fatal → generic icon |
| 2 | kIsWeb | `kIsWeb` guard + catch → non-fatal |
| 3 | Upload fails | try-catch → msg χωρίς `thumbnailUrl` → generic icon |
| 4 | Orphan `_thumb.jpg` | `deleteAllChatMedia` listAll → auto-deleted |
| 5 | Παλιά μηνύματα | `message['thumbnailUrl']` null → generic icon |
| 6 | Empty thumbnailUrl | `isNotEmpty` check → null → generic icon |
| 7 | Tap play | `isMyController` → true → `VideoPlayer` replaces thumbnail |
| 8 | CachedNetworkImage error | `errorWidget` → generic icon |
| 9 | Navigate away | `mounted` guard (υπάρχει) |
| 10 | Dispose mid-extraction | `mounted` guard (υπάρχει) |
| 11 | Rebuild storm | 3-layer equality cache + stable URL ✅ |
| 12 | Video >15MB | Guarded πριν extraction |

### Δεν χρειάζονται
- Storage rules (wildcard covers `_thumb.jpg`)
- Firestore rules (type-agnostic)
- feature_flags (covered by `videoMessagesEnabled`)
- debug_config (`chatVideo` exists)
- error_messages (non-fatal)
- StorageService new method (inline pattern)
- chat_list_screen (preview unchanged)
- chat_screen `_playVideo` (works as-is)

---

*Τέλος πρότασης — Έκδοση 2.2 (pending) — 24 Ιουλίου 2026*
*Επόμενο: έγκριση από χρήστη και υλοποίηση step-by-step*
