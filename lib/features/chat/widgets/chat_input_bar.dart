import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/utils/image_utils.dart';
import '../../../repositories/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'audio_recorder_sheet.dart';
import 'emoji_only_bubble.dart';
import 'gif_picker_sheet.dart';
import 'media_picker_sheet.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final String chatId;
  final bool isGroupChat;
  final TextEditingController textController;
  final bool emojiPickerVisible;
  final VoidCallback onEmojiToggle;
  final VoidCallback onEmojiDismiss;
  final Map<String, String> participantNicknames;

  const ChatInputBar({
    super.key,
    required this.chatId,
    this.isGroupChat = false,
    required this.textController,
    required this.emojiPickerVisible,
    required this.onEmojiToggle,
    required this.onEmojiDismiss,
    this.participantNicknames = const {},
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _focusNode = FocusNode();
  bool _isLoading = false;
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatInputBar init: ${widget.chatId}');
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatInputBar dispose: ${widget.chatId}');
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.emojiPickerVisible) {
      widget.onEmojiDismiss();
    }
  }

  Future<void> _send() async {
    final text = widget.textController.text.trim();
    if (text.isEmpty || _isLoading) return;
    final editingMsg = ref.read(editingMessageProvider);
    setState(() => _isLoading = true);
    if (editingMsg != null) {
      final msgId = editingMsg['id'] as String? ?? '';
      final ok = await ref
          .read(chatActionsProvider.notifier)
          .editMessage(widget.chatId, msgId, text);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        widget.textController.clear();
        _clearEdit();
        widget.onEmojiDismiss();
      } else {
        widget.textController.text = text;
        final chatState = ref.read(chatActionsProvider);
        AppMessenger.showError(
          context,
          ErrorMessages.get(
              chatState.errorMessage ?? 'chat/edit-failed',
              L10n.isGreek(context)),
        );
      }
    } else {
      final replyToData = _buildReplyData();
      final ok = await ref
          .read(chatActionsProvider.notifier)
          .sendMessage(widget.chatId, text, replyTo: replyToData);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        widget.textController.clear();
        _clearReply();
        widget.onEmojiDismiss();
      } else {
        widget.textController.text = text;
        final chatState = ref.read(chatActionsProvider);
        AppMessenger.showError(
          context,
          ErrorMessages.get(
              chatState.errorMessage ?? 'chat/send-failed',
              L10n.isGreek(context)),
        );
      }
    }
  }

  void _clearReply() {
    DebugConfig.log(DebugConfig.chatReply, 'ChatInputBar: clear reply');
    ref.read(replyToMessageProvider.notifier).clear();
  }

  void _clearEdit() {
    DebugConfig.log(DebugConfig.chatReply, 'ChatInputBar: clear edit');
    ref.read(editingMessageProvider.notifier).clear();
  }

  String _mediaPreview(String type, String content, bool isEmoji, {bool greek = false}) {
    if (type == 'audio') return greek ? '🎵 Ηχογράφηση' : '🎵 Recording';
    if (type == 'gif') return '🎞️ GIF';
    if (type == 'image') return greek ? '📷 Φωτογραφία' : '📷 Photo';
    if (type == 'video') return greek ? '🎬 Βίντεο' : '🎬 Video';
    if (isEmoji) return content.trim();
    return content.length > 80 ? '${content.substring(0, 80)}...' : content;
  }

  Map<String, dynamic>? _buildReplyData() {
    final replyToMsg = ref.read(replyToMessageProvider);
    if (replyToMsg == null) return null;

    final content = replyToMsg['content'] as String? ?? '';
    final type = replyToMsg['type'] as String? ?? 'text';
    final senderId = replyToMsg['senderId'] as String? ?? '';
    final currentUid = ref.read(authStateProvider).value?.uid ?? '';
    final isEmoji = type == 'text' && isOnlyEmoji(content);

    final contentPreview = _mediaPreview(type, content, isEmoji);

    final senderNickname = widget.isGroupChat
        ? (widget.participantNicknames[senderId] ?? senderId)
        : (senderId == currentUid ? '' : '');

    return {
      'messageId': replyToMsg['id'] ?? '',
      'senderId': senderId,
      'contentPreview': contentPreview,
      'senderNickname': senderNickname,
    };
  }

  Future<void> _pickGif() async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatInputBar: GIF picker shown');
    if (widget.emojiPickerVisible) widget.onEmojiDismiss();
    final greek = L10n.isGreek(context);
    await showGifPickerSheet(context, onSelected: (url) async {
      if (!mounted) return;
      final replyToData = _buildReplyData();
      _clearReply();
      setState(() => _isLoading = true);
      final ok = await ref.read(chatActionsProvider.notifier)
          .sendMediaMessage(widget.chatId, content: url, type: 'gif', replyTo: replyToData);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!ok) {
        AppMessenger.showError(context, ErrorMessages.get(
            'chat/gif-send-failed', greek));
      }
    });
  }

  Future<void> _pickAndSendPhoto() => _pickImage(ImageSource.gallery, 'photo');

  Future<void> _pickAndSendCamera() => _pickImage(ImageSource.camera, 'camera');

  Future<void> _pickImage(ImageSource source, String debugLabel) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatInputBar: $debugLabel picker shown');
    if (widget.emojiPickerVisible) widget.onEmojiDismiss();
    final greek = L10n.isGreek(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null || !mounted) return;
      final cropped = await ImageCropper.platform.cropImage(
        sourcePath: picked.path,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (cropped == null || !mounted) return;
      final bytes = await ImageUtils.stripExif(
          await File(cropped.path).readAsBytes());
      final replyToData = _buildReplyData();
      _clearReply();
      setState(() => _isLoading = true);
      final ok = await ref.read(chatActionsProvider.notifier)
          .sendMediaMessage(widget.chatId, content: '', type: 'image', replyTo: replyToData, imageBytes: bytes);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!ok) {
        AppMessenger.showError(context, ErrorMessages.get('chat/image-send-failed', greek));
      }
    } catch (e, s) {
      DebugConfig.error('ChatInputBar: _$debugLabel pick failed', data: e, exception: s);
      if (mounted) {
        AppMessenger.showError(context, ErrorMessages.get('chat/image-send-failed', greek));
      }
    }
  }

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
            audioBytes: result.bytes,
            duration: result.durationSeconds);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      AppMessenger.showError(context,
          ErrorMessages.get('chat/audio-send-failed', greek));
    }
  }

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

      final fileSize = await picked.length();
      if (fileSize >= 50 * 1024 * 1024) {
        if (!mounted) return;
        AppMessenger.showError(context,
            ErrorMessages.get('chat/video-too-large', greek));
        return;
      }

      int durationSeconds = 0;
      try {
        final controller = VideoPlayerController.file(File(picked.path));
        await controller.initialize();
        durationSeconds = controller.value.duration.inSeconds;
        await controller.dispose();
      } catch (e) {
        DebugConfig.warn('ChatInputBar: video duration read failed', data: e);
      }

      if (!mounted) return;
      if (durationSeconds > 30) {
        AppMessenger.showError(context,
            ErrorMessages.get('chat/video-too-long', greek));
        return;
      }
      if (durationSeconds < 1) {
        AppMessenger.showError(context,
            ErrorMessages.get('chat/video-too-short', greek));
        return;
      }

      final replyToData = _buildReplyData();
      _clearReply();
      setState(() => _isLoading = true);
      final ok = await ref.read(chatActionsProvider.notifier)
          .sendMediaMessage(widget.chatId,
              content: '', type: 'video',
              replyTo: replyToData,
              videoPath: picked.path,
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

  Future<void> _showMediaPicker() async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatInputBar: media + pressed');
    if (widget.emojiPickerVisible) widget.onEmojiDismiss();
    final action = await showMediaPickerSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case MediaAction.emoji:
        DebugConfig.log(DebugConfig.uiInteraction,
            'ChatInputBar: media popup: emoji');
        widget.onEmojiToggle();
      case MediaAction.gif:
        DebugConfig.log(DebugConfig.uiInteraction,
            'ChatInputBar: media popup: gif');
        _pickGif();
      case MediaAction.photo:
        DebugConfig.log(DebugConfig.uiInteraction,
            'ChatInputBar: media popup: photo');
        _pickAndSendPhoto();
      case MediaAction.camera:
        DebugConfig.log(DebugConfig.uiInteraction,
            'ChatInputBar: media popup: camera');
        _pickAndSendCamera();
      case MediaAction.record:
        DebugConfig.log(DebugConfig.chatAudio,
            'ChatInputBar: record pressed');
        _recordAndSend();
      case MediaAction.videoGallery:
        DebugConfig.log(DebugConfig.chatVideo,
            'ChatInputBar: media popup: video gallery');
        _pickAndSendVideoGallery();
      case MediaAction.videoCamera:
        DebugConfig.log(DebugConfig.chatVideo,
            'ChatInputBar: media popup: video camera');
        _pickAndSendVideoCamera();
    }
  }

  Widget _buildReplyBanner(BuildContext context, ThemeData theme, bool greek, Map<String, dynamic> replyToMsg) {
    final senderId = replyToMsg['senderId'] as String? ?? '';
    final content = replyToMsg['content'] as String? ?? '';
    final type = replyToMsg['type'] as String? ?? 'text';
    final currentUid = ref.read(authStateProvider).value?.uid ?? '';
    final isEmoji = type == 'text' && isOnlyEmoji(content);

    final preview = _mediaPreview(type, content, isEmoji, greek: greek);

    final senderNickname = widget.isGroupChat
        ? (widget.participantNicknames[senderId] ?? senderId)
        : (senderId == currentUid ? '' : '');

    DebugConfig.log(DebugConfig.chatReply,
        'ChatInputBar: reply banner for @$senderNickname: $preview');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (senderNickname.isNotEmpty)
                  Text(
                    senderNickname,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Text(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _clearReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildEditBanner(BuildContext context, ThemeData theme, bool greek, Map<String, dynamic> editingMsg) {
    final content = editingMsg['content'] as String? ?? '';
    final type = editingMsg['type'] as String? ?? 'text';
    final isEmoji = type == 'text' && isOnlyEmoji(content);

    final preview = _mediaPreview(type, content, isEmoji, greek: greek);

    DebugConfig.log(DebugConfig.chatReply,
        'ChatInputBar: edit banner: $preview');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greek ? 'Επεξεργασία μηνύματος' : 'Editing message',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              widget.textController.clear();
              _clearEdit();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final currentUser =
        ref.watch(authStateProvider).value ?? FirebaseAuth.instance.currentUser;
    final canComm = AuthRepository.canUserCommunicate(currentUser);
    final replyToMsg = ref.watch(replyToMessageProvider);
    final editingMsg = ref.watch(editingMessageProvider);
    _buildCount++;
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatInputBar build#$_buildCount: canComm=$canComm '
        'emojiVisible=${widget.emojiPickerVisible}');

    ref.listen(editingMessageProvider, (prev, next) {
      if (next != null && prev != next) {
        final content = next['content'] as String? ?? '';
        widget.textController.text = content;
        widget.textController.selection = TextSelection.collapsed(offset: content.length);
        _focusNode.requestFocus();
      }
    });

    final hintText = widget.isGroupChat
        ? (greek ? 'Γράψε στην ομάδα...' : 'Type to group...')
        : (greek ? 'Γράψε ένα μήνυμα...' : 'Type a message...');

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = ResponsiveUtils.resolveWidth(context, constraints);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
                top: BorderSide(color: theme.dividerColor)),
          ),
          padding: EdgeInsets.only(
            left: ResponsiveUtils.paddingValueFromWidth(w),
            right: ResponsiveUtils.paddingValueFromWidth(w),
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (editingMsg != null)
                _buildEditBanner(context, theme, greek, editingMsg)
              else if (replyToMsg != null)
                _buildReplyBanner(context, theme, greek, replyToMsg),
              if (!canComm)
                Row(children: [
                  const SizedBox(width: 12),
                  Icon(Icons.info_outline,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    greek
                        ? 'Πρέπει να επαληθεύσεις τον λογαριασμό σου '
                          'για να στείλεις μηνύματα'
                        : 'You must verify your account '
                          'to send messages',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )),
                ])
              else
                Row(children: [
                  if (!_isLoading)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _showMediaPicker,
                      tooltip: greek ? 'Προσθήκη' : 'Add',
                    ),
                  Expanded(child: TextField(
                    controller: widget.textController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 5,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: theme
                          .colorScheme.surfaceContainerHighest
                          .withAlpha(80),
                    ),
                  )),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _send,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                  ),
                ]),

            ],
          ),
        );
      },
    );
  }
}
