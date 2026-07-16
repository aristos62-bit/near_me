# NearMe — Media Input for Chats: Revised Analysis & Implementation Plan

> **Ημερομηνία:** 15 Ιουλίου 2026
> **Κατάσταση:** Revised after codebase re-audit

---

## 1. Υπάρχουσα Κατάσταση (Revised)

### 1.1 Chat Input (`_ChatInputBar` — `chat_screen.dart:272-374`)

Private widget στο `chat_screen.dart`. Μόνο text input with `TextEditingController`. Send button + `TextInputAction.send`. `_isLoading` guard prevents double-send. `canComm` guard blocks unverified users.

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

### 2.5 Συμπέρασμα

Για **1k χρήστες** στο μεσαίο σενάριο:
- **Επιπλέον κόστος:** ~€1.90/μήνα (από ~€3 → ~€5 σύνολο)
- **Χωρίς optimization:** θα ήταν ~€4-5/μήνα (από €3 → €7-8)
- **Εξοικονόμηση optimization:** ~€2-3/μήνα

**Μηδενικό κόστος από:** Firestore writes (ίδιο pattern με text), Cloud Functions (ίδιες), Tenor API (free tier 10k/day).

### 2.6 Cost-Aware Παράμετροι στην Υλοποίηση

```dart
// Κεντρικό config για media parameters — SPoT
class ChatMediaConfig {
  ChatMediaConfig._();

  // Image
  static const int imageMaxWidth = 1280;       // αντί 1920
  static const int imageMaxHeight = 1280;       // αντί 1920
  static const int imageQuality = 70;           // αντί 85

  // Video
  static const int videoMaxSizeBytes = 15 * 1024 * 1024;  // 15MB αντί 30MB

  // Storage retention (future)
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

### 3.2 Reuse Decision: Επέκταση StorageService (όχι νέα κλάση)

Το υπάρχον `StorageService` (storage_service.dart) έχει:
- `uploadAvatar(uid, bytes)`, `uploadPhoto(uid, index, bytes)`
- `deleteAvatar(uid)`, `deletePhoto(uid, index)`, `deleteAllUserFiles(uid)`

**Απόφαση:** Προσθήκη νέων μεθόδων στο ίδιο αρχείο αντί δημιουργίας `ChatStorageService`:
- `uploadChatImage(chatId, messageId, bytes)`
- `uploadChatVideo(chatId, messageId, bytes)`
- `uploadChatThumbnail(chatId, messageId, bytes)`
- `deleteChatMedia(chatId, messageId, ext)`
- `deleteAllChatMedia(chatId)`

**Λόγος:** Ίδιο pattern, ίδια κλάση, ίδιες εξαρτήσεις. Μείωση νέων αρχείων από 4 σε 2.

### 3.3 Reuse Decision: Unified sendMediaMessage (όχι ξεχωριστή μέθοδο)

Αντί `sendMediaMessage()` + `sendVideoMessage()` ως ξεχωριστές abstract methods:
```dart
Future<void> sendMediaMessage(
  String chatId, {
  required Uint8List bytes,
  required String fileName,
  required String type,   // 'image' ή 'video'
  Uint8List? thumbnailBytes,  // optional, only for video
});
```

**Λόγος:** Το `ChatRepository` έχει ήδη 33 abstract methods (συμπ. group chat features). Μία unified μέθοδος αντί δύο.

---

## 4. Φάσεις Υλοποίησης (Revised)

| Φάση | Τύπος | Νέα Αρχεία | Cost Impact (1k users) | Εκτίμηση |
|:----:|:-----:|:-----------|:----------------------:|:--------:|
| **1** | Emoji picker | 0 | €0 | 30-45 λεπτά |
| **2** | Photo sharing | 0 (extend existing) | ~€0.04-0.18/μήνα | 2 ώρες |
| **3** | Video sharing | 0 (inline) | ~€0.30-1.56/μήνα | 3-4 ώρες |
| **4** | GIF support | 2 | €0 (Tenor free tier) | 2-3 ώρες |

**Σύνολο νέων αρχείων:** 2 (GIF) — από 4 στην αρχική πρόταση.
**Σύνολο επιπλέον κόστους:** ~€0.34-1.74/μήνα για 1k χρήστες (optimized).

---

## 5. Φάση 1 — Emoji Picker

### 5.1 Υλοποίηση

```yaml
# pubspec.yaml
emoji_picker_flutter: ^4.0.0
```

```dart
// chat_screen.dart — _ChatInputBarState
bool _emojiPickerVisible = false;

// Build: emoji toggle button
IconButton(
  icon: Icon(_emojiPickerVisible ? Icons.keyboard : Icons.emoji_emotions_outlined),
  onPressed: () {
    setState(() => _emojiPickerVisible = !_emojiPickerVisible);
    DebugConfig.log(DebugConfig.uiInteraction,
        '_ChatInputBar: emoji picker ${!_emojiPickerVisible ? "shown" : "hidden"}');
  },
)

// Conditional emoji picker under the Row
if (_emojiPickerVisible)
  SizedBox(
    height: 250,
    child: EmojiPicker(
      onEmojiSelected: (_, emoji) {
        final pos = _textCtrl.selection.baseOffset;
        final text = _textCtrl.text;
        _textCtrl.text = '${text.substring(0, pos)}${emoji.emoji}${text.substring(pos)}';
        _textCtrl.selection = TextSelection.collapsed(offset: pos + emoji.emoji.length);
      },
    ),
  )
```

### 5.2 Edge Cases

| Σενάριο | Προστασία |
|---------|-----------|
| Emoji + keyboard overlap | Το picker είναι fixed 250px — η Column το διαχειρίζεται |
| Landscape mode | EmojiPicker config: `clipBehavior: Clip.none` |
| Insert at cursor (όχι append) | `text.substring(0, pos)` + emoji + `text.substring(pos)` |

### 5.3 Δεν χρειάζονται αλλαγές

Backend, encryption, message type, database schema, chat list — **κανένα**.

---

## 6. Φάση 2 — Photo Sharing

### 6.1 Message Schema

```dart
// Firestore message doc — type='image'
{
  'id': auto-generated,
  'type': 'image',
  'senderId': uid,
  'content': 'https://storage.googleapis.com/.../chat_media/{chatId}/{messageId}.jpg',
  'timestamp': Timestamp,
  'isRead': false,
}
// Chat doc update:
'lastMessageType': 'image',
'lastMessage': content,  // URL (not encrypted)
```

**Απόφαση:** Media messages ΔΕΝ κρυπτογραφούνται. Το `content` είναι Firebase Storage URL.
**Λόγος:** AES-256-GCM σε MB αρχεία είναι απαγορευτικό σε mobile. Firebase Storage encryption at rest.

### 6.2 Επέκταση StorageService (storage_service.dart)

```dart
// Προσθήκη στο υπάρχον StorageService:

Future<String> uploadChatMedia({
  required String chatId,
  required String messageId,
  required Uint8List bytes,
  required String contentType,
  String? extension,
}) async {
  DebugConfig.log(DebugConfig.storageUpload,
      'uploadChatMedia: chat=$chatId msg=$messageId type=$contentType');
  final ext = extension ?? (contentType.contains('video') ? 'mp4' : 'jpg');
  final ref = _storage.ref().child('chat_media/$chatId/$messageId.$ext');
  try {
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    DebugConfig.log(DebugConfig.storageUpload,
        'uploadChatMedia OK: chat=$chatId msg=$messageId');
    return url;
  } catch (e, s) {
    DebugConfig.error('uploadChatMedia failed', data: e, exception: s);
    throw AppException.storage('uploadChatMedia', e, s);
  }
}

Future<void> deleteChatMedia(String chatId, String messageId, {String? extension}) async {
  final ext = extension ?? 'jpg';
  DebugConfig.log(DebugConfig.storageUpload, 'deleteChatMedia: $chatId/$messageId.$ext');
  try {
    await _storage.ref().child('chat_media/$chatId/$messageId.$ext').delete();
  } catch (e) {
    DebugConfig.warn('deleteChatMedia: may not exist', data: e);
  }
}

Future<void> deleteAllChatMedia(String chatId) async {
  DebugConfig.log(DebugConfig.storageUpload, 'deleteAllChatMedia: $chatId');
  try {
    final ref = _storage.ref().child('chat_media/$chatId');
    final result = await ref.listAll();
    for (final item in result.items) { await item.delete(); }
    DebugConfig.log(DebugConfig.storageUpload,
        'deleteAllChatMedia OK: ${result.items.length} files');
  } catch (e) {
    DebugConfig.warn('deleteAllChatMedia failed', data: e);
  }
}
```

### 6.3 ChatRepository Interface (chat_repository.dart)

```dart
abstract class ChatRepository {
  // Υπάρχον
  Future<void> sendMessage(String chatId, String content);

  // Νέο — unified media method
  Future<void> sendMediaMessage(
    String chatId, {
    required Uint8List bytes,
    required String fileName,
    required String type,  // 'image' | 'video'
    Uint8List? thumbnailBytes,
  });
}
```

### 6.4 ChatRepositoryImpl.sendMediaMessage (chat_repository_impl.dart)

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
  DebugConfig.log(DebugConfig.repositoryCall,
      'sendMediaMessage: chat=$chatId type=$type file=$fileName');

  // Block check (copy from sendMessage lines 228-243)
  // ... (ίδιο pattern με text sendMessage)

  final msgRef = firestore.collection('chats').doc(chatId)
      .collection('messages').doc();
  final msgId = msgRef.id;

  // 1. Upload to Storage
  final contentType = type == 'video' ? 'video/mp4' : 'image/jpeg';
  final ext = type == 'video' ? 'mp4' : 'jpg';
  final url = await _storageService.uploadChatMedia(
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

  // 3. Firestore batch write
  final batch = firestore.batch();
  final msgData = <String, dynamic>{
    'senderId': user.uid,
    'content': url,
    'type': type,
    'timestamp': FieldValue.serverTimestamp(),
    'isRead': false,
  };
  if (thumbnailUrl != null) msgData['thumbnailUrl'] = thumbnailUrl;
  batch.set(msgRef, msgData);

  final updateData = <String, dynamic>{
    'lastMessageAt': FieldValue.serverTimestamp(),
    'lastMessageBy': user.uid,
    'lastMessage': url,
    'lastMessageType': type,
  };
  for (final p in participants) {
    if (p != user.uid) updateData['unreadCount.$p'] = FieldValue.increment(1);
  }
  batch.update(chatRef, updateData);
  await batch.commit();
  await updateChatCache(chatId, hasUnread: false);
  DebugConfig.log(DebugConfig.repositoryResult,
      'sendMediaMessage: success chat=$chatId msg=$msgId');
}
```

### 6.5 messagesStream — Media Handling (chat_repository_impl.dart)

```dart
// Στο asyncMap (γύρω από γραμμή 335), ΜΕΤΑ το decrypt block:
String displayContent;
final type = data['type'] as String? ?? 'text';

if (type == 'image' || type == 'video') {
  // Media messages: content = URL, no decryption
  displayContent = encrypted; // encrypted variable here = raw Firestore content field
} else if (type == 'system') {
  displayContent = encrypted;
} else {
  // text — decrypt (υπάρχον)
  displayContent = decrypted;
}
```

**Κρίσιμο:** Χωρίς αυτή την αλλαγή, η decryptMessage() θα crashάρει με URL string.

### 6.6 ChatActionsNotifier (chat_provider.dart)

```dart
Future<bool> sendMediaMessage(String chatId, {
  required Uint8List bytes,
  required String fileName,
  required String type,
  Uint8List? thumbnailBytes,
}) async {
  DebugConfig.log(DebugConfig.repositoryCall,
      'ChatActions: sendMediaMessage chat=$chatId type=$type');
  state = const ChatActionState(status: ChatActionStatus.loading);
  try {
    await _chatRepo.sendMediaMessage(chatId,
        bytes: bytes, fileName: fileName, type: type,
        thumbnailBytes: thumbnailBytes);
    state = const ChatActionState(status: ChatActionStatus.success);
    return true;
  } catch (e, s) {
    DebugConfig.error('ChatActions: sendMediaMessage failed', data: e, exception: s);
    state = ChatActionState(status: ChatActionStatus.error,
        errorMessage: _friendlyError(e));
    return false;
  }
}
```

### 6.7 _ChatInputBar — Photo Pick Button (chat_screen.dart)

```dart
// Στην κλάση _ChatInputBarState:
final ImagePicker _picker = ImagePicker(); // class field, reuse

// Στο Row, ΠΡΙΝ από το Expanded TextField:
IconButton(
  icon: const Icon(Icons.photo_library_outlined),
  onPressed: _pickAndSendPhoto,
),

Future<void> _pickAndSendPhoto() async {
  try {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: ChatMediaConfig.imageMaxWidth,   // 1280
      maxHeight: ChatMediaConfig.imageMaxHeight,  // 1280
      imageQuality: ChatMediaConfig.imageQuality, // 70
    );
    if (picked == null) return;

    // Προαιρετικό crop (ίδιο pattern με profile_editor_screen.dart)
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1024, maxHeight: 1024,  // crop is smaller than max
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: ChatMediaConfig.imageQuality, // 70
      uiSettings: [
        AndroidUiSettings(toolbarTitle: '', toolbarColor: Colors.transparent),
        IOSUiSettings(),
      ],
    );
    final imageFile = cropped ?? picked;
    final bytes = await imageFile.readAsBytes();

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
```

### 6.8 MessageBubble — _ImageBubble (message_bubble.dart)

```dart
// Στο build(), ΜΕΤΑ το system check:
final type = message['type'] as String? ?? 'text';
// ...
if (type == 'image') {
  return _MediaBubble(
    contentUrl: content,
    type: 'image',
    timeStr: timeStr,
    isMe: isMe,
    senderNickname: isGroupChat && !isMe ? senderNickname : null,
    seenBy: seenBy, isGroupChat: isGroupChat, isRead: isRead,
  );
}
if (type == 'video') {
  return _MediaBubble(
    contentUrl: content,
    thumbnailUrl: message['thumbnailUrl'] as String?,
    type: 'video',
    timeStr: timeStr,
    isMe: isMe,
    senderNickname: isGroupChat && !isMe ? senderNickname : null,
    seenBy: seenBy, isGroupChat: isGroupChat, isRead: isRead,
  );
}
```

### 6.9 _MediaBubble Widget (message_bubble.dart)

**Ενιαίο widget για image + video — αντί για δύο ξεχωριστά.**

```dart
class _MediaBubble extends StatefulWidget {
  final String contentUrl;
  final String? thumbnailUrl;
  final String type; // 'image' | 'video'
  final String timeStr;
  final bool isMe;
  final String? senderNickname;
  final List<String> seenBy;
  final bool isGroupChat;
  final bool isRead;

  // constructor...
}

class _MediaBubbleState extends State<_MediaBubble> {
  VideoPlayerController? _controller;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.contentUrl));
      await _controller!.initialize();
      if (mounted) setState(() => _videoInitialized = true);
    } catch (e) {
      DebugConfig.warn('_MediaBubble: video init failed', data: e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Shared bubble layout (όπως _ImageBubble proposal)
    // με max bubble width 75%, sender nickname, timestamp, read receipt
    // type='image' → CachedNetworkImage
    // type='video' → thumbnail + play icon overlay → tap → play via controller
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
                  child: CachedNetworkImage(imageUrl: widget.contentUrl))
              : _VideoPlayerScreen(url: widget.contentUrl),
        ),
      ),
    ));
  }
}
```

### 6.10 Storage Cleanup — _deleteChatForEveryone + clearMessages

**chat_repository_delete.dart (part of):**
```dart
// Στο _deleteChatForEveryone, ΠΡΙΝ delete messages:
try {
  await _storageService.deleteAllChatMedia(chatId);
} catch (e) {
  DebugConfig.warn('deleteAllChatMedia failed (non-fatal)', data: e);
}
```

**chat_repository_clear.dart (part of):**
```dart
// Στo clearMessages, μετά από batch delete messages:
try {
  await _storageService.deleteAllChatMedia(chatId);
} catch (e) {
  DebugConfig.warn('deleteAllChatMedia failed (non-fatal)', data: e);
}
```

**Σημείωση:** `deleteUserData` Cloud Function ΔΕΝ χρειάζεται αλλαγή — τα chat media είναι ανά chat, όχι ανά user. Όταν όλοι οι χρήστες αποχωρήσουν, το chat διαγράφεται και τα media καθαρίζονται από το `_deleteChatForEveryone`.

### 6.11 Storage Rules (storage.rules)

```javascript
// Στο υπάρχον storage.rules, ΠΡΙΝ το fallback deny:
match /chat_media/{chatId}/{fileName} {
  allow read: if request.auth != null;
  allow write: if request.auth != null;
}
```

**Απλοποιημένο** από την αρχική πρόταση — δεν κάνουμε senderId check στο metadata (δύσκολο με Firebase Storage rules + putData).

### 6.12 Debug Logging

```dart
// debug_config.dart
static const bool chatMedia = true; // media upload/download in chat
```

### 6.13 Feature Flag

```dart
// feature_flags.dart
static const bool mediaMessagesEnabled = true; // Φάση 2 — photo
```

### 6.14 Error Messages

```dart
// error_messages.dart — στο _fromCode():
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

---

### 6.15 Compatibility Notes (από codebase audit 15/7/2026)

#### 6.15.1 File Size: `_ChatInputBar` Extraction

Το `chat_screen.dart` είναι 374 γραμμές. Η προσθήκη emoji (~30), photo (~50), video (~50) + buttons (~15) = ~145 lines → σύνολο ~519.

**Απόφαση:** Εξαγωγή του `_ChatInputBar` σε ξεχωριστό widget `lib/features/chat/widgets/chat_input_bar.dart`. Έτσι το `chat_screen.dart` παραμένει ≤500 lines και το `_ChatInputBar` αποκτά δικό του αρχείο.

#### 6.15.2 File Size: `chat_repository_impl.dart` Part File

Το `chat_repository_impl.dart` είναι ήδη 673 γραμμές (exception με άδεια χρήστη). Η προσθήκη `sendMediaMessage` (~70 lines) + `messagesStream` media branch (~10 lines) θα το φτάσει ~750.

**Απόφαση:** Δημιουργία νέου part file `chat_repository_media.dart` για την υλοποίηση `sendMediaMessage` και τις media λειτουργίες (storage upload/download). Το κύριο `chat_repository_impl.dart` κάνει `part 'chat_repository_media.dart';`.

#### 6.15.3 Non-E2E UI Indication

Τα media messages ΔΕΝ είναι E2E encrypted (το URL είναι στο Firestore, το file στο Storage με access control). Σε αντίθεση με τα text messages που έχουν E2E.

**Απόφαση:** Το `_MediaBubble` εμφανίζει ένα μικρό εικονίδιο/note (π.χ. `Icons.lock_open` με tooltip "Δεν είναι E2E κρυπτογραφημένο") ώστε ο χρήστης να γνωρίζει ότι η φωτογραφία/βίντεο έχει διαφορετικό επίπεδο προστασίας από τα text messages.

#### 6.15.4 Group Chat State

Το `FeatureFlags.groupChatEnabled = true` (ενεργό). Τα group chats έχουν δικό τους media handling στο `group_chat_mixin.dart` που ΔΕΝ επηρεάζεται από το παρόν plan — το media input αφορά μόνο 1:1 chats προς το παρόν.

#### 6.15.5 Dependency Versions

Τα νέα packages ΔΕΝ έχουν version constraints στο plan. Θα χρησιμοποιηθεί `flutter pub add` το οποίο επιλέγει την πιο πρόσφατη συμβατή έκδοση με Flutter 3.44.4 / Dart 3.12.2:

| Package | Εντολή |
|---------|--------|
| `emoji_picker_flutter` | `flutter pub add emoji_picker_flutter` |
| `video_player` | `flutter pub add video_player` |
| `video_thumbnail` | `flutter pub add video_thumbnail` |
| `http` | `flutter pub add http` |

---

## 7. Φάση 3 — Video Sharing

### 7.1 Διαφορές από Photo

| Θέμα | Photo | Video |
|:----:|:-----:|:-----:|
| Picker | `_picker.pickImage()` | `_picker.pickVideo(source: ImageSource.gallery)` |
| Compression | ImageCropper (υπάρχει) | **Προαιρετικό** — feature flag `videoCompressionEnabled` |
| Thumbnail | Δεν χρειάζεται | `video_thumbnail` package (200×200 JPEG) |
| Player | CachedNetworkImage | `video_player` (in-bubble) |
| Storage path | `chat_media/{chatId}/{msgId}.jpg` | `chat_media/{chatId}/{msgId}.mp4` + `{msgId}_thumb.jpg` |
| APK impact | 0 | `video_player` ~2MB extra |

### 7.2 Απόφαση: Cost-Aware Video Parameters

**Δεν συμπεριλαμβάνεται `ffmpeg_kit_flutter` στο baseline.** Λόγοι:

1. APK increase ~5-8MB για chat feature
2. Σύγχρονα smartphones ήδη καταγράφουν σε reasonable bitrate
3. `image_picker.pickVideo()` επιστρέφει το αρχείο ως έχει — no re-encoding
4. Αν χρειαστεί compression, προστίθεται αργότερα με ξεχωριστό feature flag

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

### 7.3 Thumbnail Extraction (προαιρετικό)

```yaml
# pubspec.yaml
video_thumbnail: ^1.0.0
```

```dart
// Στο _pickAndSendVideo, πριν το send:
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

### 7.4 _ChatInputBar — Video Pick Button

```dart
IconButton(
  icon: const Icon(Icons.videocam_outlined),
  onPressed: _pickAndSendVideo,
),

Future<void> _pickAndSendVideo() async {
  try {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final fileSize = await file.length();
    if (fileSize > ChatMediaConfig.videoMaxSizeBytes) { // 15MB
      if (!mounted) return;
      AppMessenger.showError(context, ErrorMessages.get(
          'chat/video-too-large', L10n.isGreek(context)));
      return;
    }

    // Προαιρετικό thumbnail
    Uint8List? thumbBytes;
    try {
      thumbBytes = await VideoThumbnail.thumbnailData(
        video: picked.path, imageFormat: ImageFormat.JPEG,
        maxWidth: 200, quality: 80,
      );
    } catch (_) {}

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    setState(() => _isLoading = true);
    final ok = await ref.read(chatActionsProvider.notifier)
        .sendMediaMessage(widget.chatId,
            bytes: bytes, fileName: picked.name,
            type: 'video', thumbnailBytes: thumbBytes);
    if (!mounted) return;
    setState(() => _isLoading = false);
  } catch (e) {
    DebugConfig.error('_pickAndSendVideo failed', data: e);
  }
}
```

### 7.5 Video Bubble (μέρος του _MediaBubble)

```dart
// Στο _MediaBubble build(), για type='video':
if (widget.type == 'video') {
  if (_videoInitialized && _controller != null) {
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(children: [
        VideoPlayer(_controller!),
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
  } else {
    // Thumbnail + play overlay (πριν initialize)
    return Stack(children: [
      if (widget.thumbnailUrl != null)
        CachedNetworkImage(imageUrl: widget.thumbnailUrl!, fit: BoxFit.cover)
      else
        Container(color: Colors.black38, child: const Icon(Icons.play_circle, size: 48)),
      // play button overlay
    ]);
  }
}
```

### 7.6 Feature Flag

```dart
// feature_flags.dart
static const bool videoMessagesEnabled = true;  // Φάση 3
static const bool videoCompressionEnabled = false; // Φάση 4+ (ffmpeg)
```

### 7.7 Error Messages

```dart
// error_messages.dart
case 'chat/video-too-large':
  return isGreek ? 'Το βίντεο είναι πολύ μεγάλο (max 15MB)'
                 : 'Video too large (max 15MB)';
```

---

## 8. Φάση 4 — GIF Support (Προτεραιότητα: Μετά από Emoji + Photo + Video)

### 8.1 TenorService (lib/shared/utils/tenor_service.dart)

```dart
class TenorService {
  final String _apiKey;
  final http.Client _client;
  static const _baseUrl = 'https://tenor.googleapis.com/v2';

  TenorService({required String apiKey, http.Client? client})
      : _apiKey = apiKey, _client = client ?? http.Client();

  Future<List<TenorGif>> search(String query, {int limit = 20}) async {
    DebugConfig.log(DebugConfig.networkConnectivity, 'Tenor: search=$query');
    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': query, 'key': _apiKey, 'client_key': 'near_me',
      'limit': '$limit', 'media_filter': 'gif',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw AppException.network('tenor', 'Tenor error: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    return (json['results'] as List).map((r) => TenorGif.fromJson(r)).toList();
  }
}

class TenorGif {
  final String id; final String url; final int width; final int height;
  TenorGif({required this.id, required this.url, this.width = 0, this.height = 0});
  factory TenorGif.fromJson(Map<String, dynamic> json) { /* ... */ }
}
```

### 8.2 GifPickerSheet (lib/features/chat/widgets/gif_picker_sheet.dart)

Bottom sheet με search + GridView. GIFs από Tenor CDN — **κανένα upload στο δικό μας Storage**.

### 8.3 Message Schema

```dart
{
  'type': 'gif',
  'senderId': uid,
  'content': tenorUrl,  // Tenor CDN URL (not our Storage)
  'width': int?,
  'height': int?,
  'timestamp': Timestamp,
  'isRead': false,
}
```

### 8.4 Feature Flag

```dart
// feature_flags.dart
static const bool gifMessagesEnabled = false;  // Φάση 4 — προαιρετικό
```

---

## 9. Πλήρης Πίνακας Εμπλεκόμενων Αρχείων

### 9.1 Νέα Αρχεία (4 σύνολο)

| Αρχείο | Γραμμές | Φάση | Σκοπός |
|--------|:-------:|:----:|--------|
| `lib/features/chat/widgets/chat_input_bar.dart` | ~100 | 1,2,3 | Extracted `_ChatInputBar` (emoji, photo, video buttons) |
| `lib/repositories/chat_repository_media.dart` | ~80 | 2,3 | Part file: `sendMediaMessage` impl + messagesStream media branch |
| `lib/shared/utils/tenor_service.dart` | ~80 | 4 | Tenor GIF API |
| `lib/features/chat/widgets/gif_picker_sheet.dart` | ~120 | 4 | GIF search & picker UI |

### 9.2 Τροποποιούμενα Αρχεία (13 σύνολο)

| # | Αρχείο | Φάσεις | Αλλαγή |
|:-:|--------|:------:|--------|
| 1 | `pubspec.yaml` | 1,2,3,4 | +4 deps (emoji, video_thumbnail, video_player, http) |
| 2 | `storage_service.dart` | 2,3 | +3 methods (uploadChatMedia, deleteChatMedia, deleteAllChatMedia) |
| 3 | `storage.rules` | 2,3 | +1 match rule (chat_media) |
| 4 | `chat_repository.dart` | 2,3 | +1 abstract method (sendMediaMessage) |
| 5 | `chat_repository_impl.dart` | 2,3 | +1 part directive (`part 'chat_repository_media.dart'`) |
| 6 | `chat_repository_delete.dart` | 2,3 | +deleteAllChatMedia call in _deleteChatForEveryone |
| 7 | `chat_repository_clear.dart` | 2,3 | +deleteAllChatMedia call in clearMessages |
| 8 | `chat_provider.dart` | 2,3 | +ChatActionsNotifier.sendMediaMessage() |
| 9 | `chat_screen.dart` | 1,2,3 | Αφαίρεση `_ChatInputBar` (extracted) + import νέου widget |
| 10 | `message_bubble.dart` | 2,3 | +_MediaBubble (image + video) + type branches |
| 11 | `chat_list_screen.dart` | 2,3 | +'video' preview (type=='image' ήδη υπάρχει) |
| 12 | `feature_flags.dart` | 2,3,4 | +mediaMessagesEnabled, videoMessagesEnabled, gifMessagesEnabled |
| 13 | `debug_config.dart` | 2,3 | +chatMedia flag |
| 14 | `error_messages.dart` | 2,3 | +6 error codes |

### 9.3 Αμετάβλητα (Verified)

| Αρχείο | Λόγος |
|--------|-------|
| `encryption_utils.dart` | Media ΔΕΝ κρυπτογραφούνται — URL, όχι encrypted text |
| `firestore.rules` | Ήδη type-agnostic — no change needed |
| `functions/src/index.ts` | Chat media cleanup ανά chat (deleteChat), όχι ανά user (deleteUserData) |
| `profile_storage_mixin.dart` | Profile-specific |
| `profile_editor_screen.dart` | Profile-specific (το pattern reuse γίνεται από το chat_input_bar.dart) |
| `database.dart` / `chat_cache_table.dart` | `lastMessageType` ήδη υπάρχει |
| `system_message_formatter.dart` | Δεν επηρεάζεται |
| `mention_utils.dart` | Δεν επηρεάζεται |
| `group_chat_mixin.dart` | Δεν επηρεάζεται |
| `app_router.dart` | No new routes needed — full-screen via Navigator.push |
| `app_theme.dart` | No new theme |
| `l10n.dart` | Errors via ErrorMessages (ήδη bilingual) |
| `app_messenger.dart` | No change |
| `app_state_widget.dart` | No change |

---

## 10. Edge Cases & Θωράκιση

### 10.1 Δικτυακά

| Σενάριο | Προστασία |
|---------|-----------|
| Upload με απώλεια δικτύου | `_isLoading` guard + `mounted` check + AppException → error message |
| Video >15MB | `File.length()` pre-check πριν upload |
| Image file corrupt (0 bytes) | ImagePicker returns null → return; |
| Slow upload (5+ sec) | `CircularProgressIndicator` στο send button (υπάρχει ήδη) |
| Tenor API unavailable (Phase 4) | try-catch → AppMessenger.showError |
| Firebase Storage rate limit | `AppException.storage` → error message (υπάρχει ήδη AppException.storage) |

### 10.2 Αποθήκευση

| Σενάριο | Προστασία |
|---------|-----------|
| Storage file deleted, message doc remains | `CachedNetworkImage` errorWidget → broken icon |
| Message sent, Storage delete fails (cleanup) | Orphan accepted — negligible cost |
| Chat deleted mid-upload | `mounted` guard → silent failure |
| Thumbnail extraction fails (video) | Message sent without thumbnail → generic icon overlay |
| Orphan _thumb files | Deleted together with main file via deleteAllChatMedia |

### 10.3 Ασφάλεια

| Σενάριο | Προστασία |
|---------|-----------|
| Unverified user sends media | `canComm` guard (υπάρχει) |
| Blocked user sends media | Block check στο sendMediaMessage (copy from sendMessage) |
| Malicious URL in content | URL από δικό μας Storage ή Tenor CDN |
| Unauthorized Storage read | `storage.rules`: `allow read: if request.auth != null` |
| Unauthorized Storage write | `storage.rules`: `allow write: if request.auth != null` |
| Media in banned user's chat | Firestore rules `notBanned()` blocks message write |

### 10.4 User Experience

| Σενάριο | Προστασία |
|---------|-----------|
| Double-tap send | `_isLoading` guard |
| Keyboard + emoji picker | Fixed 250px height → Column adapts |
| Video plays while scrolling | `_MediaBubble` auto-pause on dispose (scroll = rebuild = dispose) |
| Rapid emoji insertion | Cursor position maintained |
| Very long GIF search | Tenor API handles (100+ chars) |
| Photo pick cancel | `if (picked == null) return` |
| Image cropper cancel | `if (cropped == null) return` → fallback to original |

---

## 11. Flutter Lifecycle Analysis

| Event | Emoji | Photo | Video |
|-------|:-----:|:-----:|:-----:|
| **Hot reload** | Picker state reset ✅ | Upload cancelled ✅ | _MediaBubble controller re-init ✅ |
| **App background** | Picker κλείνει ✅ | Upload continues ✅ | Upload continues ✅ |
| **App resume** | Picker re-opens αν state preserved ✅ | mounted check ✅ | mounted check ✅ |
| **Route pop** | autoDispose dispose ✅ | Upload cancelled ✅ | _controller.dispose() ✅ |
| **Widget dispose** | TextEditingController ✅ | Loading reset ✅ | `_controller?.dispose()` ✅ |
| **System back** | Emoji picker κλείνει ✅ | N/A | Full-screen video pops ✅ |
| **Scroll (ListView)** | N/A | N/A | Auto-pause (controller dispose + reinit) ⚠️ |

### Memory

| Σενάριο | Μέγεθος | Διαχείριση |
|---------|:-------:|-----------|
| Photo bytes in memory | ~2MB (1280px JPEG) | Released after send |
| Video raw file | ~5-15MB | File.readAsBytes() → released |
| Video playback | ~50-200MB RAM | `_controller.dispose()` in dispose |
| CachedNetworkImage | auto-managed | cache library |
| Emoji picker | ~2MB | allocated once |
| GIF picker grid | ~20 previews | builder — on demand |

---

## 12. Συνοπτικός Χάρτης Υλοποίησης

### Φάση 1 — Emoji Picker (30-45 λεπτά)

| Βήμα | Ενέργεια | Αρχείο |
|:----:|----------|--------|
| 1 | `flutter pub add emoji_picker_flutter` | pubspec.yaml |
| 2 | Backup `chat_screen.dart` | backups/ |
| 3 | Δημιουργία `chat_input_bar.dart` (extract `_ChatInputBar` από chat_screen) | `lib/features/chat/widgets/chat_input_bar.dart` |
| 4 | `_ChatInputBarState`: +`_emojiPickerVisible` state + emoji button | `chat_input_bar.dart` |
| 5 | `EmojiPicker` widget (conditional, 250px) + debug logs | `chat_input_bar.dart` |
| 6 | `flutter analyze` + device test | — |

### Φάση 2 — Photo Sharing (2 ώρες)

| Βήμα | Ενέργεια | Αρχείο |
|:----:|----------|--------|
| 1 | Backup: storage_service, chat_repository*, chat_provider, chat_input_bar, chat_screen, message_bubble, chat_list_screen, storage.rules, feature_flags, debug_config, error_messages | backups/ |
| 2 | +3 methods στο `StorageService`: uploadChatMedia, deleteChatMedia, deleteAllChatMedia | `storage_service.dart` |
| 3 | +1 match rule στο `storage.rules`: chat_media | `storage.rules` |
| 4 | +`mediaMessagesEnabled` flag | `feature_flags.dart` |
| 5 | +`chatMedia` debug flag | `debug_config.dart` |
| 6 | +`sendMediaMessage()` abstract in ChatRepository | `chat_repository.dart` |
| 7 | +part file `chat_repository_media.dart` + sendMediaMessage impl + messagesStream media branch | `chat_repository_media.dart` (part of) |
| 8 | +deleteAllChatMedia call in `_deleteChatForEveryone` + `clearMessages` | `chat_repository_delete.dart`, `chat_repository_clear.dart` |
| 9 | +ChatActionsNotifier.sendMediaMessage() | `chat_provider.dart` |
| 10 | +_MediaBubble widget + type=image branch | `message_bubble.dart` |
| 11 | +photo button + _pickAndSendPhoto | `chat_input_bar.dart` |
| 12 | +6 error codes | `error_messages.dart` |
| 13 | `flutter analyze` + device test | — |

### Φάση 3 — Video Sharing (3-4 ώρες)

| Βήμα | Ενέργεια | Αρχείο |
|:----:|----------|--------|
| 1 | `flutter pub add video_player video_thumbnail` | pubspec.yaml |
| 2 | Backup (ίδια αρχεία με Φάση 2) | backups/ |
| 3 | +`videoMessagesEnabled` flag | `feature_flags.dart` |
| 4 | +video error code | `error_messages.dart` |
| 5 | +video case στο messagesStream media branch | `chat_repository_impl.dart` |
| 6 | +_MediaBubble video player + thumbnail + play overlay | `message_bubble.dart` |
| 7 | +video button + `_pickAndSendVideo` + size validation | `chat_input_bar.dart` |
| 8 | +'video' preview in chat_list_screen | `chat_list_screen.dart` |
| 9 | `flutter analyze` + dual-device test | — |

### Φάση 4 — GIF Support (2-3 ώρες, μετά από photo+video)

| Βήμα | Ενέργεια | Αρχείο |
|:----:|----------|--------|
| 1 | `flutter pub add http` | pubspec.yaml |
| 2 | Backup | backups/ |
| 3 | Δημιουργία `TenorService` | `lib/shared/utils/tenor_service.dart` |
| 4 | Δημιουργία `GifPickerSheet` | `lib/features/chat/widgets/gif_picker_sheet.dart` |
| 5 | +`gifMessagesEnabled` flag | `feature_flags.dart` |
| 6 | +GIF button + `_pickGif()` | `chat_input_bar.dart` |
| 7 | `flutter analyze` + test | — |

---

## Προϋποθέσεις

```
1. flutter analyze — CLEAN πριν ξεκινήσουμε
2. BACKUP όλων των αρχείων φάσης
3. feature flags σε false → ενεργοποίηση ΜΟΝΟ μετά από δοκιμή
4. Κάθε βήμα: edit → flutter analyze → user OK → επόμενο
5. Μέγεθος αρχείων ≤ 500 γραμμές
   - Exception: chat_repository_impl.dart (ήδη 673 lines) — ρητή άδεια χρήστη για επιπλέον μέγεθος
   - Λύση: νέο part file chat_repository_media.dart για νέο κώδικα
```
