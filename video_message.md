# Video Message Support — Πρόταση Υλοποίησης v1.0

> **Βασισμένο στην ίδια αρχιτεκτονική με το Audio Message v2.0**
> Ημερομηνία: 24 Ιουλίου 2026

---

## Πίνακας Περιεχομένων

1. [Σκοπός](#1-σκοπός)
2. [User Flow](#2-user-flow)
3. [Αρχιτεκτονική Επισκόπηση](#3-αρχιτεκτονική-επισκόπηση)
4. [Feature Flag](#4-feature-flag)
5. [Debug Flag](#5-debug-flag)
6. [MediaAction Enum — Προσθήκη `video`](#6-mediaaction-enum--προσθήκη-video)
7. [Media Picker Sheet](#7-media-picker-sheet)
8. [ChatInputBar — `_pickAndSendVideo`](#8-chatinputbar--_pickandsendvideo)
9. [ChatInputBar — `_showMediaPicker` switch](#9-chatinputbar--_showmediapicker-switch)
10. [ChatInputBar — Reply Banner Preview](#10-chatinputbar--reply-banner-preview)
11. [ChatRepository — `sendMediaMessage`](#11-chatrepository--sendmediamessage)
12. [ChatRepositoryImpl — Video Upload Block](#12-chatrepositoryimpl--video-upload-block)
13. [ChatRepositoryImpl — Duration Field](#13-chatrepositoryimpl--duration-field)
14. [ChatRepositoryImpl — Skip-Decrypt Lists](#14-chatrepositoryimpl--skip-decrypt-lists)
15. [GroupChatMixin — Skip-Decrypt](#15-groupchatmixin--skip-decrypt)
16. [ChatProvider — `sendMediaMessage` Pass-through](#16-chatprovider--sendmediamessage-pass-through)
17. [MessageBubble — `'video'` Case](#17-messagebubble--video-case)
18. [VideoMessageBubble (Νέο Widget)](#18-videomessagebubble-νέο-widget)
19. [ChatScreen — VideoPlayer Ownership](#19-chatscreen--videoplayer-ownership)
20. [ChatMessagesList — Pass videoPlayer Downstream](#20-chatmessageslist--pass-videoplayer-downstream)
21. [ChatMessagesList._onEdit — Type Guard](#21-chatmessageslist_onedit--type-guard)
22. [MessageActionBar — `showEdit` Param](#22-messageactionbar--showedit-param)
23. [BubbleLongPressWrapper — `canEdit` Param](#23-bubblelongpresswrapper--canedit-param)
24. [ChatListScreen — Last Message Preview](#24-chatlistscreen--last-message-preview)
25. [Picker UI (Βιντεοκάμερα)](#25-picker-ui-βιντεοκάμερα)
26. [VideoThumbnailGenerator (Βοηθητικό)](#26-videothumbnailgenerator-βοηθητικό)
27. [Αναγκαία Packages](#27-αναγκαία-packages)
28. [Android Permissions](#28-android-permissions)
29. [iOS Permissions](#29-ios-permissions)
30. [Προαπαιτούμενα / Μπλοκαρίσματα](#30-προαπαιτούμενα--μπλοκαρίσματα)
31. [ΔΕΝ χρειάζονται](#31-δεν-χρειάζονται)
32. [Edge Cases](#32-edge-cases)
33. [SPoTs — Τελικός Πίνακας](#33-spots--τελικός-πίνακας)
34. [Παράρτημα: Βασικές Εντολές](#34-παράρτημα-βασικές-εντολές)

---

## 1. Σκοπός

Δυνατότητα αποστολής **σύντομων video μηνυμάτων** στο chat, παρόμοια με το audio message:

- **Λήψη**: από κάμερα (video capture) ή gallery (υπάρχον video)
- **Διάρκεια**: max **30 δευτερόλεπτα** (προσομοίωση Instagram/TikTok short video)
- **Upload**: Firebase Storage → `chat_media/{chatId}/{msgId}.mp4`
- **Playback**: Inline στο chat bubble με video_player
- **Auto-play**: Μόνο όταν το bubble είναι ορατό (lazy load)
- **Thumbnail**: Frame extraction για preview πριν το play
- **Mute toggle**: Το video παίζει muted by default, tap για sound
- **Loop**: Το short video κάνει loop μέχρι ο χρήστης να φύγει από την οθόνη

---

## 2. User Flow

```
1. Χρήστης πατάει "+" → MediaPickerSheet εμφανίζεται
2. Πατάει "Video" →   [Gallery] [Camera]
3. Επιλογή:
   a. Camera: Ανοίγει native camera recorder (max 30s)
   b. Gallery: Ανοίγει file picker για short video (max 30s)
4. (Optional) Preview μετά την εγγραφή/επιλογή
5. Auto-compress/convert → upload → send
6. Receiver βλέπει video thumbnail → tap → inline playback
```

---

## 3. Αρχιτεκτονική Επισκόπηση

```
┌─────────────────────────────────────────────────────────────┐
│                      ChatInputBar                           │
│  _showMediaPicker → MediaAction.video → _pickAndSendVideo  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  ChatProvider (sendMediaMessage)             │
│  type: 'video', videoBytes: Uint8List?, duration: int?      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              ChatRepositoryImpl.sendMediaMessage             │
│  ● videoBytes → Firebase Storage (chat_media/*.mp4)        │
│  ● thumbnailBytes → Firebase Storage (chat_media/*.jpg)    │
│  ● Firestore document: type='video', duration, thumbnail   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│               ChatMessagesList / MessageBubble              │
│  type == 'video' → VideoMessageBubble                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   VideoMessageBubble                        │
│  ● Thumbnail preview (cached_network_image)                 │
│  ● Play button overlay                                      │
│  ● video_player inline (muted, loop)                        │
│  ● Mute/unmute toggle, timer overlay                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Feature Flag

**Αρχείο:** `lib/core/config/feature_flags.dart:26`

```dart
// Media
static const bool gifSupportEnabled = true;
static const bool mediaMessagesEnabled = true;
static const bool audioMessagesEnabled = true;
static const bool videoMessagesEnabled = false;   // ← NEW
```

---

## 5. Debug Flag

**Αρχείο:** `lib/core/debug/debug_config.dart`

```dart
// Chat flags
static const int chatAudio = 1 << 29;
static const int chatVideo = 1 << 30;   // ← NEW
```

---

## 6. MediaAction Enum — Προσθήκη `video`

**Αρχείο:** `lib/features/chat/widgets/media_picker_sheet.dart:7`

```dart
enum MediaAction { emoji, gif, photo, camera, record, video }   // ← NEW: video
```

---

## 7. Media Picker Sheet

**Αρχείο:** `lib/features/chat/widgets/media_picker_sheet.dart:13`

### 7α. Available list
```dart
final available = <MediaAction>[
  MediaAction.emoji,
  if (FeatureFlags.gifSupportEnabled) MediaAction.gif,
  if (FeatureFlags.mediaMessagesEnabled) ...[MediaAction.photo, MediaAction.camera],
  if (FeatureFlags.audioMessagesEnabled && !kIsWeb) MediaAction.record,
  if (FeatureFlags.videoMessagesEnabled && !kIsWeb) MediaAction.video,   // ← NEW
];
```

### 7β. Tile
```dart
MediaAction.video => (Icons.videocam_outlined,
    greek ? 'Βίντεο' : 'Video'),
```

---

## 8. ChatInputBar — `_pickAndSendVideo`

**Αρχείο:** `lib/features/chat/widgets/chat_input_bar.dart`

```dart
Future<void> _pickAndSendVideo() async {
  DebugConfig.log(DebugConfig.chatVideo, 'ChatInputBar: video picker shown');
  if (widget.emojiPickerVisible) widget.onEmojiDismiss();
  final greek = L10n.isGreek(context);

  // Step 1: Gallery or Camera?
  final source = await showVideoSourceSheet(context);
  if (!mounted || source == null) return;

  try {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30),
    );
    if (picked == null || !mounted) return;

    // Step 2: Read video bytes
    final bytes = await File(picked.path).readAsBytes();

    // Step 3: Get duration via VideoPlayerController
    int durationSeconds = 0;
    try {
      final controller = VideoPlayerController.file(File(picked.path));
      await controller.initialize();
      durationSeconds = controller.value.duration.inSeconds;
      await controller.dispose();
    } catch (e) {
      DebugConfig.warn('ChatInputBar: video duration read failed', data: e);
    }

    // Step 4: Generate thumbnail (first frame)
    Uint8List? thumbnailBytes;
    try {
      final thumbnail = await VideoThumbnailGenerator.extractFrame(
        picked.path,
        positionSeconds: 0,
      );
      thumbnailBytes = thumbnail;
    } catch (e) {
      DebugConfig.warn('ChatInputBar: thumbnail extraction failed', data: e);
    }

    // Step 5: Validate duration
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

    // Step 6: Send
    final replyToData = _buildReplyData();
    _clearReply();
    setState(() => _isLoading = true);
    final ok = await ref.read(chatActionsProvider.notifier)
        .sendMediaMessage(widget.chatId,
            content: '', type: 'video',
            replyTo: replyToData,
            videoBytes: bytes,
            thumbnailBytes: thumbnailBytes,
            duration: durationSeconds);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      AppMessenger.showError(context,
          ErrorMessages.get('chat/video-send-failed', greek));
    }
  } catch (e, s) {
    DebugConfig.error('ChatInputBar: video pick failed', data: e, exception: s);
    if (mounted) {
      AppMessenger.showError(context,
          ErrorMessages.get('chat/video-send-failed', greek));
    }
  }
}
```

---

## 9. ChatInputBar — `_showMediaPicker` switch

**Αρχείο:** `lib/features/chat/widgets/chat_input_bar.dart:258`

```dart
case MediaAction.video:
  DebugConfig.log(DebugConfig.chatVideo,
      'ChatInputBar: media popup: video');
  _pickAndSendVideo();
```

---

## 10. ChatInputBar — Reply Banner Preview

**Αρχείο:** `lib/features/chat/widgets/chat_input_bar.dart:143 & 291`

```dart
// _buildReplyData (line 143)
} else if (type == 'video') {
  contentPreview = '🎬 Video';
}

// _buildReplyBanner (line 291)
} else if (type == 'video') {
  preview = greek ? '🎬 Βίντεο' : '🎬 Video';
}

// _buildEditBanner (line 362)
} else if (type == 'video') {
  preview = greek ? '🎬 Βίντεο' : '🎬 Video';
}
```

---

## 11. ChatRepository — `sendMediaMessage`

**Αρχείο:** `lib/repositories/chat_repository.dart:120`

```dart
Future<void> sendMediaMessage(String chatId, {
  required String content,
  required String type,
  Map<String, dynamic>? replyTo,
  Uint8List? imageBytes,
  Uint8List? audioBytes,
  Uint8List? videoBytes,        // ← NEW
  Uint8List? thumbnailBytes,    // ← NEW
  int? duration,
});
```

---

## 12. ChatRepositoryImpl — Video Upload Block

**Αρχείο:** `lib/repositories/chat_repository_impl.dart:777`

```dart
if (videoBytes != null && type == 'video') {
  DebugConfig.log(DebugConfig.chatVideo,
      'sendMediaMessage: uploading video chat=$chatId');
  final storageRef = FirebaseStorage.instance
      .ref().child('chat_media/$chatId/${msgRef.id}.mp4');
  await storageRef.putData(videoBytes,
      SettableMetadata(contentType: 'video/mp4'));
  content = await storageRef.getDownloadURL();

  // Upload thumbnail separately
  if (thumbnailBytes != null) {
    DebugConfig.log(DebugConfig.chatVideo,
        'sendMediaMessage: uploading thumbnail chat=$chatId');
    final thumbRef = FirebaseStorage.instance
        .ref().child('chat_media/$chatId/${msgRef.id}_thumb.jpg');
    await thumbRef.putData(thumbnailBytes,
        SettableMetadata(contentType: 'image/jpeg'));
    final thumbUrl = await thumbRef.getDownloadURL();
    // Θα το αποθηκεύσουμε στο msgData παρακάτω
    msgData['thumbnail'] = thumbUrl;
  }
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
  if (type == 'audio' && duration != null) 'duration': duration,
  if (type == 'video' && duration != null) 'duration': duration,   // ← NEW
  // thumbnail μπαίνει από το upload block παραπάνω
};
```

---

## 13. ChatRepositoryImpl — Duration Field

**Αρχείο:** `lib/repositories/chat_repository_impl.dart:342 & 365`

Στα σημεία όπου γίνεται decrypt/parse του μηνύματος, το `duration` χρειάζεται για video:

```dart
// Line ~342: _decodeMessageDoc
final msg = <String, dynamic>{
  'id': doc.id,
  'senderId': data['senderId'] ?? '',
  'content': skipDecrypt.contains(type) ? (data['content'] ?? '') : ...,
  'type': type,
  'timestamp': data['timestamp'],
  'isRead': data['isRead'] ?? false,
  'duration': data['duration'] ?? 0,              // ήδη υπάρχει
  'thumbnail': data['thumbnail'] ?? '',            // ← NEW
};
```

---

## 14. ChatRepositoryImpl — Skip-Decrypt Lists

**Αρχείο:** `lib/repositories/chat_repository_impl.dart`

```dart
// Σε όλα τα σημεία skip-decrypt check:
if (const {'audio', 'gif', 'image', 'video'}.contains(type)) {   // ← 'video'
  // skip decrypt
}
```

**Συγκεκριμένα σημεία:**
1. `_decodeMessageDoc` (~line 342) — `'video'` στο skip-decrypt
2. `_syncChatFromFirestore` (~line 596) — `'video'` στο skip-decrypt
3. `_syncGroupChatToCache` (~line 620-640) — `'video'` στο skip-decrypt

---

## 15. GroupChatMixin — Skip-Decrypt

**Αρχείο:** `lib/features/chat/mixins/group_chat_mixin.dart:173`

```dart
if (const {'audio', 'gif', 'image', 'video'}.contains(type)) {   // ← 'video'
  decrypted = message;
} else { ... }
```

---

## 16. ChatProvider — `sendMediaMessage` Pass-through

**Αρχείο:** `lib/features/chat/providers/chat_provider.dart:252`

```dart
Future<bool> sendMediaMessage(String chatId, {
  required String content,
  required String type,
  Map<String, dynamic>? replyTo,
  Uint8List? imageBytes,
  Uint8List? audioBytes,
  Uint8List? videoBytes,        // ← NEW
  Uint8List? thumbnailBytes,    // ← NEW
  int? duration,
}) async {
  ...
  await _chatRepository.sendMediaMessage(chatId,
    content: content,
    type: type,
    replyTo: replyTo,
    imageBytes: imageBytes,
    audioBytes: audioBytes,
    videoBytes: videoBytes,         // ← NEW
    thumbnailBytes: thumbnailBytes, // ← NEW
    duration: duration,
  );
  ...
}
```

---

## 17. MessageBubble — `'video'` Case

**Αρχείο:** `lib/features/chat/widgets/message_bubble/message_bubble.dart:63`

```dart
return switch (type) {
  'audio' => AudioMessageBubble(...),
  'system' => SystemMessageBubble(...),
  'gif' || 'image' => GifImageBubble(...),
  'video' => VideoMessageBubble(           // ← NEW case
    content: content,
    thumbnail: message['thumbnail'] as String? ?? '',
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

## 18. VideoMessageBubble (Νέο Widget)

**Αρχείο:** `lib/features/chat/widgets/message_bubble/video_message_bubble.dart`

### 18α. Σχεδιασμός

```
┌──────────────────────────────────┐
│  [ReplyPreview] (optional)       │
│  [SenderHeader] (group)          │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  │     Video Thumbnail        │  │
│  │     (cached_network_image) │  │
│  │                            │  │
│  │     ▶ Play Overlay         │  │
│  │                            │  │
│  │     0:00 / 0:05           │  │
│  └────────────────────────────┘  │
│  [ReadReceiptFooter]             │
│  [MessageReactionsRow]           │
└──────────────────────────────────┘
```

### 18β. Δομή Widget Tree

```
VideoMessageBubble (StatefulWidget)
├── BubbleLongPressWrapper
│   ├── Column
│   │   ├── ReplyPreview (if replyTo != null)
│   │   ├── SenderHeader (if isGroupChat && showAvatar)
│   │   └── ClipRRect (rounded corners)
│   │       └── Stack
│   │           ├── Image (thumbnail) — when not playing
│   │           ├── VideoPlayer — when playing
│   │           ├── Center
│   │           │   └── PlayButton (Circular icon, semi-transparent bg)
│   │           └── Positioned (bottom-right)
│   │               └── DurationBadge (time text)
│   ├── ReadReceiptFooter
│   └── MessageReactionsRow
```

### 18γ. Behavior (StatefulWidget)

```dart
class VideoMessageBubble extends StatefulWidget {
  // Όλες οι παράμετροι όπως GifImageBubble αλλά:
  final String thumbnail;
  final int duration;
  final dynamic videoPlayer; // VideoPlayerController? από ChatScreen

  const VideoMessageBubble({...});
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  bool _isPlaying = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    // ΔΕΝ κάνουμε initialize εδώ — το controller έρχεται από ChatScreen
  }

  void _togglePlay() {
    if (widget.videoPlayer == null) return;
    final controller = widget.videoPlayer as VideoPlayerController;
    if (_isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _toggleMute() {
    if (widget.videoPlayer == null) return;
    final controller = widget.videoPlayer as VideoPlayerController;
    controller.setVolume(_isMuted ? 1.0 : 0.0);
    setState(() => _isMuted = !_isMuted);
  }

  @override
  Widget build(BuildContext context) {
    return BubbleLongPressWrapper(
      canEdit: false,
      child: Column(
        children: [
          if (widget.replyTo != null)
            ReplyPreview(replyTo: widget.replyTo!, isMe: widget.isMe),
          if (widget.isGroupChat && widget.showAvatar)
            SenderHeader(...),
          // Video area
          GestureDetector(
            onTap: _togglePlay,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _bubbleWidth,
                height: _aspectRatioHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Thumbnail (when not playing)
                    if (!_isPlaying && widget.thumbnail.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: widget.thumbnail,
                        fit: BoxFit.cover,
                        width: _bubbleWidth,
                        height: _aspectRatioHeight,
                      ),
                    // VideoPlayer (when playing)
                    if (_isPlaying && widget.videoPlayer != null)
                      VideoPlayer(widget.videoPlayer as VideoPlayerController),
                    // Play/Pause overlay
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white, size: 28,
                      ),
                    ),
                    // Duration badge + mute toggle
                    Positioned(
                      bottom: 4, right: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isPlaying)
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Icon(
                                _isMuted ? Icons.volume_off : Icons.volume_up,
                                color: Colors.white70, size: 16,
                              ),
                            ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              formatDuration(widget.duration),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ReadReceiptFooter(...),
          MessageReactionsRow(...),
        ],
      ),
    );
  }
}
```

### 18δ. Responsive Width

```dart
static const double _bubbleMaxWidthRatio = 0.65; // slightly narrower than images
double get _bubbleWidth {
  // responsive - χρήση constraints από LayoutBuilder
  return constraints.maxWidth * _bubbleMaxWidthRatio;
}
double get _aspectRatioHeight => _bubbleWidth * 16 / 9; // fixed 16:9
```

### 18ε. Δεν γίνεται auto-play
- Το video παίζει **μόνο με tap** στο bubble
- Όταν φεύγει από την οθόνη, το `ChatScreen.dispose()` σταματάει όλα

---

## 19. ChatScreen — VideoPlayer Ownership

**Αρχείο:** `lib/features/chat/screens/chat_screen.dart`

```dart
class ChatScreen extends StatefulWidget {
  ...
}

class _ChatScreenState extends State<ChatScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();       // existing
  VideoPlayerController? _videoController;              // ← NEW

  @override
  void dispose() {
    _audioPlayer.dispose();
    _videoController?.dispose();                        // ← NEW
    super.dispose();
  }

  /// Καλείται όταν ο χρήστης tap σε video bubble
  Future<void> _playVideo(String url) async {
    // Stop προηγούμενο
    await _videoController?.pause();
    await _videoController?.dispose();

    _videoController = VideoPlayerController.network(url);
    await _videoController!.initialize();
    _videoController!.setVolume(0.0); // muted by default
    _videoController!.play();
    setState(() {}); // refresh UI
  }

  @override
  Widget build(BuildContext context) {
    return ChatMessagesList(
      ...
      audioPlayer: _audioPlayer,
      videoPlayer: _videoController,       // ← NEW
      onPlayVideo: _playVideo,             // ← NEW callback
    );
  }
}
```

**Κρίσιμο:** Το `VideoPlayerController` ΔΕΝ μπαίνει σε Riverpod provider (ίδια λογική με AudioPlayer, βλ. sound_message.md §23).

---

## 20. ChatMessagesList — Pass videoPlayer Downstream

**Αρχείο:** `lib/features/chat/widgets/chat_messages_list.dart`

```dart
class ChatMessagesList extends StatelessWidget {
  final dynamic audioPlayer;         // existing
  final dynamic videoPlayer;         // ← NEW
  final Future<void> Function(String url)? onPlayVideo; // ← NEW

  const ChatMessagesList({
    ...
    this.audioPlayer,
    this.videoPlayer,
    this.onPlayVideo,
  });

  // Pass downstream to MessageBubble
  MessageBubble(
    ...
    audioPlayer: audioPlayer,
    videoPlayer: videoPlayer,     // ← NEW
    onPlayVideo: onPlayVideo,     // ← NEW
    callbacks: MessageCallbacks(
      onReact: ...,
      onPlayVideo: onPlayVideo,   // ← NEW callback type
    ),
  );
}
```

---

## 21. ChatMessagesList._onEdit — Type Guard

**Αρχείο:** `lib/features/chat/widgets/chat_messages_list.dart:100`

```dart
void _onEdit(Map<String, dynamic> msg) {
  final type = msg['type'] as String? ?? 'text';
  if (type != 'text') {
    DebugConfig.log(DebugConfig.chatReply,
        '_onEdit: skipped for type=$type');   // ήδη υπάρχει guard
    return;
  }
  ...
}
```

> Δεν χρειάζεται αλλαγή — το υπάρχον guard ήδη αποκλείει όλα τα non-text.

---

## 22. MessageActionBar — `showEdit` Param

**Αρχείο:** `lib/features/chat/widgets/message_action_bar.dart`

(Ίδιο pattern με audio — βλ. sound_message.md §20)

```dart
static Future<void> showEditMenu(
  BuildContext context, {
  ...
  bool showEdit = true,                    // ← υπάρχει από audio
  bool showVideoInfo = false,             // ← NEW (για future use)
}) async {
```

> **Δεν χρειάζεται αλλαγή:** το `showEdit: false` για video πάει από το `BubbleLongPressWrapper`.

---

## 23. BubbleLongPressWrapper — `canEdit` Param

**Αρχείο:** `lib/features/chat/widgets/message_bubble/bubble_long_press_wrapper.dart`

```dart
// Στο VideoMessageBubble usage:
BubbleLongPressWrapper(
  canEdit: false,       // ← video δεν επιδέχεται edit (ίδιο με audio)
  ...
)
```

> **Δεν χρειάζεται αλλαγή:** το `canEdit` param υπάρχει ήδη από audio.

---

## 24. ChatListScreen — Last Message Preview

**Αρχείο:** `lib/features/chat/screens/chat_list_screen.dart:274`

```dart
// Στο build του chat list item, για lastMessage preview:
final preview = switch (lastMessageType) {
  'audio' => greek ? '🎵 Ηχογράφηση' : '🎵 Recording',
  'video' => greek ? '🎬 Βίντεο' : '🎬 Video',   // ← NEW
  'gif'   => '🎞️ GIF',
  'image' => greek ? '📷 Φωτογραφία' : '📷 Photo',
  _       => lastMessage,
};
```

---

## 25. Picker UI (Βιντεοκάμερα)

**Νέο widget:** `lib/features/chat/widgets/video_source_sheet.dart`

```dart
Future<ImageSource?> showVideoSourceSheet(BuildContext context) async {
  final greek = L10n.isGreek(context);
  final result = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.video_library_outlined, size: 28),
              title: Text(greek ? 'Από τη συλλογή' : 'From Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, size: 28),
              title: Text(greek ? 'Εγγραφή βίντεο' : 'Record Video'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
  return result;
}
```

---

## 26. VideoThumbnailGenerator (Βοηθητικό)

**Νέο αρχείο:** `lib/core/utils/video_thumbnail_generator.dart`

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class VideoThumbnailGenerator {
  /// Extract a frame from video as JPEG bytes.
  /// Uses platform channel (MethodChannel) for video frame extraction.
  ///
  /// Falls back to: first frame via video_player, or empty bytes.
  static Future<Uint8List?> extractFrame(
    String videoPath, {
    int positionSeconds = 0,
  }) async {
    try {
      // Try platform-specific thumbnail extraction
      final result = await _extractViaPlatform(videoPath, positionSeconds);
      if (result != null) return result;
    } catch (e) {
      DebugConfig.warn('VideoThumbnailGenerator: platform extract failed', data: e);
    }

    // Fallback: first frame via video_player Dart (heavy but reliable)
    try {
      return await _extractViaVideoPlayer(videoPath, positionSeconds);
    } catch (e) {
      DebugConfig.warn('VideoThumbnailGenerator: fallback failed', data: e);
    }

    return null;
  }

  static Future<Uint8List?> _extractViaPlatform(String path, int position) async {
    // Platform channel: thumbnails.extract
    final result = await SystemChannels.platform.invokeMethod<Uint8List>(
      'VideoThumbnailGenerator/extractFrame',
      {'path': path, 'positionMs': position * 1000},
    );
    return result;
  }

  static Future<Uint8List?> _extractViaVideoPlayer(String path, int position) async {
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    await controller.seekTo(Duration(seconds: position));
    // Force a single frame render
    await Future.delayed(const Duration(milliseconds: 100));
    // Capture current frame (requires RenderRepaintBoundary in widget)
    // Simplified: read raw bytes from controller if available
    await controller.dispose();
    return null; // Placeholder
  }
}
```

> **Σημείωση:** Για v1, αν δε δουλεύει platform channel, χρησιμοποιούμε `video_thumbnail` package.
> Εναλλακτικά: αποστολή χωρίς thumbnail (το video έχει poster frame από το πρώτο δευτερόλεπτο).

---

## 27. Αναγκαία Packages

**Αρχείο:** `pubspec.yaml`

| Package | Έκδοση (προτεινόμενη) | Χρήση |
|---------|----------------------|--------|
| `video_player` | ^2.9.0 | Playback inline |
| `video_thumbnail` | ^0.6.0 | Frame extraction (εναλλακτικά: platform channel) |

```yaml
dependencies:
  video_player: ^2.9.0           # ← NEW
  video_thumbnail: ^0.6.0        # ← NEW (optional via platform channel)
```

---

## 28. Android Permissions

**Αρχείο:** `android/app/src/main/AndroidManifest.xml`

```xml
<!-- Υπάρχον -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<!-- Νέο -->
<uses-permission android:name="android.permission.CAMERA"/>          <!-- video capture -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/> <!-- gallery read -->
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>      <!-- Android 13+ video -->
```

---

## 29. iOS Permissions

**Αρχείο:** `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>Η εφαρμογή χρειάζεται πρόσβαση στην κάμερα για εγγραφή βίντεο / The app needs camera access to record video</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Η εφαρμογή χρειάζεται πρόσβαση στη συλλογή για αποστολή βίντεο / The app needs photo library access to send videos</string>
```

> Το `NSMicrophoneUsageDescription` υπάρχει ήδη από audio. Η εγγραφή video χρειάζεται μικρόφωνο — καλύπτεται.

---

## 30. Προαπαιτούμενα / Μπλοκαρίσματα

| # | Προαπαιτούμενο | Τύπος | Λεπτομέρειες |
|---|---------------|-------|-------------|
| 1 | `video_player: ^2.9.0` | pubspec.yaml | Playback inline |
| 2 | `video_thumbnail: ^0.6.0` | pubspec.yaml | Thumbnail extraction |
| 3 | `CAMERA` permission | Android manifest | Για εγγραφή video |
| 4 | `READ_MEDIA_VIDEO` permission | Android manifest | Android 13+ |
| 5 | `NSCameraUsageDescription` | iOS Info.plist | Κάμερα |
| 6 | `NSPhotoLibraryUsageDescription` | iOS Info.plist | Gallery |
| 7 | `import 'dart:typed_data'` | chat_input_bar.dart | Για `Uint8List` |
| 8 | `import 'dart:io'` | chat_input_bar.dart | Ήδη υπάρχει |
| 9 | `kIsWeb` import | media_picker_sheet.dart | Ήδη υπάρχει |

---

## 31. ΔΕΝ χρειάζονται

| Τι | Γιατί |
|----|-------|
| Firestore rules changes | Type-agnostic (firestore.rules:214-256) — ήδη accepts 'video' |
| Storage rules changes | `chat_media/{chatId}/` already wildcard (storage.rules:28-36) — .mp4, .jpg covered |
| Firestore indexes changes | Messages queries unchanged |
| Drift schema migration | `lastMessageType` already exists, `duration` is Firestore-only |
| Auth guards changes | Already handled by `sendMediaMessage` (line 783) |
| Block checks changes | Already handled by `sendMediaMessage` (line 802) |
| deleteAllChatMedia changes | Already deletes `chat_media/{chatId}/*` (line 1008) — .mp4, _thumb.jpg included |
| Permission handler package | `image_picker` handles runtime permissions for camera/gallery |
| AudioPlayer | Video έχει δικό του controller, ξεχωριστό από AudioPlayer |

---

## 32. Edge Cases

| # | Edge Case | Προστασία |
|---|-----------|-----------|
| 1 | **max 30s duration** | `ImagePicker.pickVideo(maxDuration:)` + duration validation after pick |
| 2 | **min <1s** | Validation after pick → `AppMessenger.showError` |
| 3 | **file >10MB** | Storage rules reject → catch → `AppMessenger.showError('chat/video-send-failed')` |
| 4 | **permission denied (camera)** | `DebugConfig.warn` + `AppMessenger.showError('chat/video-permission-denied')` |
| 5 | **permission denied (gallery)** | `DebugConfig.warn` + `AppMessenger.showError('chat/video-permission-denied')` |
| 6 | **thumbnail extraction failure** | Soft fallback: send without thumbnail, show generic video icon |
| 7 | **playback overlap** | Single `VideoPlayerController` — dispose πριν create νέο |
| 8 | **navigate away during playback** | `ChatScreen.dispose()` → `_videoController.dispose()` |
| 9 | **edit on video message** | 3-layer guard: `MessageActionBar.showEdit: false`, `_onEdit` type check, `BubbleLongPressWrapper.canEdit: false` |
| 10 | **reply to video** | Preview: `'🎬 Βίντεο' / '🎬 Video'` |
| 11 | **group chat video** | sendMediaMessage ήδη υποστηρίζει groups (block check skipped για groups) |
| 12 | **encrypt attempt on video** | `'video'` στο skip-decrypt list |
| 13 | **storage cleanup on delete** | `deleteAllChatMedia(chatId)` διαγράφει όλα τα `chat_media/{chatId}/*` — .mp4, _thumb.jpg covered |
| 14 | **kIsWeb** | `MediaAction.video` μόνο αν `!kIsWeb` |
| 15 | **release mode** | Όλα τα debug logs via `DebugConfig.log(chatVideo, ...)` → invisible in release |
| 16 | **widget rebuild during playback** | `VideoMessageBubble` StatefulWidget, `didUpdateWidget` check αν `content` άλλαξε |
| 17 | **playback error (corrupted file)** | Catch → `DebugConfig.error` + showError |
| 18 | **unsupported video codec** | ImagePicker δεσμεύει για MP4 (H.264) — native recorder παράγει συμβατό format |
| 19 | **very long video selected** | `ImagePicker.pickVideo(maxDuration:)` το κόβει στο native picker |
| 20 | **no internet during upload** | Repository catch → `AppMessenger.showError('chat/video-send-failed')` |

---

## 33. SPoTs — Τελικός Πίνακας

| SPoT | Αλλαγή | Τύπος |
|------|---------|:-----:|
| `chat_repository.dart:120` | `Uint8List? videoBytes`, `Uint8List? thumbnailBytes` | New params |
| `chat_repository_impl.dart:777` | Video upload block + thumbnail upload + duration field + msgData | New code |
| `chat_repository_impl.dart:342` | `'video'` in skip-decrypt list | Edit |
| `chat_repository_impl.dart:365` | `'thumbnail': data['thumbnail'] ?? ''` | Edit |
| `chat_repository_impl.dart:596` | `'video'` in skip-decrypt list | Edit |
| `group_chat_mixin.dart:173` | `'video'` in skip-decrypt list | Edit |
| `chat_provider.dart:252` | `videoBytes`, `thumbnailBytes`, `duration` pass-through | New params |
| `message_bubble.dart:63` | `'video'` case → `VideoMessageBubble` | New case |
| `message_action_bar.dart` | (Ήδη υπάρχει `showEdit`) | — |
| `bubble_long_press_wrapper.dart` | (Ήδη υπάρχει `canEdit`) | — |
| `chat_messages_list.dart:100` | (Ήδη υπάρχει type guard) | — |
| `chat_messages_list.dart` | `videoPlayer`, `onPlayVideo` params | New params |
| `chat_list_screen.dart:274` | `'video'` preview | New case |
| `chat_input_bar.dart` | `_pickAndSendVideo()` + `MediaAction.video` case | New code |
| `chat_input_bar.dart:143,291,362` | `'video'` reply/edit preview | New case |
| `media_picker_sheet.dart` | `MediaAction.video` enum + available + tile | New enum value |
| `feature_flags.dart` | `videoMessagesEnabled` | New flag |
| `debug_config.dart` | `chatVideo` flag | New flag |
| `error_messages.dart` | 4 error codes (`chat/video-send-failed`, `chat/video-permission-denied`, `chat/video-too-long`, `chat/video-too-short`) | New entries |
| `chat_screen.dart` | `VideoPlayerController?`, `_playVideo()`, `dispose()` + pass downstream | New code |
| `video_message_bubble.dart` | Νέο widget — video playback bubble | **NEW FILE** |
| `video_source_sheet.dart` | Νέο widget — gallery/camera picker | **NEW FILE** |
| `video_thumbnail_generator.dart` | Νέο utility — frame extraction | **NEW FILE** |
| **Firestore rules** | ❌ **Καμία** | — |
| **Storage rules** | ❌ **Καμία** | — |
| **Firestore indexes** | ❌ **Καμία** | — |
| **ChatCacheTable (Drift)** | ❌ **Καμία** | — |
| **Auth guards** | ❌ **Καμία** | — |
| **Block checks** | ❌ **Καμία** | — |
| **deleteAllChatMedia** | ❌ **Καμία** | Already covers `chat_media/{chatId}/*` |
| **pubspec.yaml** | `video_player: ^2.9.0`, `video_thumbnail: ^0.6.0` | New packages |

---

## 34. Παράρτημα: Βασικές Εντολές για το νέο chat

```bash
# Μετά από αλλαγές σε models/providers
dart run build_runner build --delete-conflicting-outputs

# Προσθήκη πακέτων
flutter pub add video_player
flutter pub add video_thumbnail

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

*Τέλος πρότασης — Έκδοση 1.0 — 24 Ιουλίου 2026*
