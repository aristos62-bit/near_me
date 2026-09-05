import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/incoming_share_service.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/error_messages.dart';
import '../../../repositories/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_input_banners.dart';
import 'chat_media_sender_mixin.dart';
import 'emoji_only_bubble.dart';

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

class _ChatInputBarState extends ConsumerState<ChatInputBar>
    with ChatMediaSenderMixin<ChatInputBar> {
  final _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _errorTimer;
  DateTime? _lastSendAt;

  // Κρατάμε το notifier σε πεδίο από το initState, ώστε να μπορούμε να
  // καθαρίσουμε το stale quote στο dispose ΧΩΡΙΣ ref.read (απαγορεύεται στο
  // Riverpod 3 κατά το unmount — crash "Using ref when unmounted").
  late final ReplyToMessageNotifier _replyNotifier;

  @override
  String get chatId => widget.chatId;

  @override
  bool get emojiPickerVisible => widget.emojiPickerVisible;

  @override
  VoidCallback get onEmojiDismiss => widget.onEmojiDismiss;

  @override
  VoidCallback get onEmojiToggle => widget.onEmojiToggle;

  @override
  void setSending(bool value) => setState(() => _isLoading = value);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _replyNotifier = ref.read(replyToMessageProvider.notifier);
    final pending = ref.read(pendingPrivateReplyProvider.notifier).consumeFor(widget.chatId);
    if (pending != null) {
      DebugConfig.log(DebugConfig.chatReply,
          'ChatInputBar: applying pending private-reply quote chat=${widget.chatId} '
              'senderNicknameHint=${pending.senderNicknameHint}');
      final quoted = pending.senderNicknameHint != null
          ? {...pending.quotedMessage, '_privateReplySenderNickname': pending.senderNicknameHint}
          : pending.quotedMessage;
      _replyNotifier.setReply(widget.chatId, quoted);
    }
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatInputBar init: ${widget.chatId}');
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _errorTimer?.cancel();
    // Ασφαλές cleanup: χρησιμοποιούμε το captured notifier, όχι ref.read.
    // Το clear() είναι idempotent (no-op αν δεν υπάρχει ήδη quote).
    _replyNotifier.clear(widget.chatId);
    DebugConfig.log(DebugConfig.chatReply,
        'ChatInputBar dispose: cleared reply state chat=${widget.chatId}');
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatInputBar dispose: ${widget.chatId}');
    super.dispose();
  }

  @override
  void clearError() {
    _errorTimer?.cancel();
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  @override
  void showInlineError(String code) {
    final msg = ErrorMessages.get(code, L10n.isGreek(context));
    _errorTimer?.cancel();
    setState(() => _errorMessage = msg);
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.emojiPickerVisible) {
      widget.onEmojiDismiss();
    }
  }

  Future<void> _send() async {
    final text = widget.textController.text.trim();
    if (text.isEmpty || _isLoading) return;
    // Debounce fast-send μεταξύ ολοκληρωμένων αποστολών (local State guard).
    final now = DateTime.now();
    if (_lastSendAt != null && now.difference(_lastSendAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastSendAt = now;
    final editingMsg = ref.read(editingMessageProvider.select((s) => s[widget.chatId]));
    clearError();
    setSending(true);
    if (editingMsg != null) {
      final msgId = editingMsg['id'] as String? ?? '';
      final ok = await ref
          .read(chatActionsProvider.notifier)
          .editMessage(widget.chatId, msgId, text);
      if (!mounted) return;
      setSending(false);
      if (ok) {
        widget.textController.clear();
        _clearEdit();
        widget.onEmojiDismiss();
      } else {
        widget.textController.text = text;
        final chatState = ref.read(chatActionsProvider);
        showInlineError(chatState.errorMessage ?? 'chat/edit-failed');
      }
    } else {
      final replyToData = buildReplyData();
      final ok = await ref
          .read(chatActionsProvider.notifier)
          .sendMessage(widget.chatId, text, replyTo: replyToData);
      if (!mounted) return;
      setSending(false);
      if (ok) {
        widget.textController.clear();
        clearReply();
        widget.onEmojiDismiss();
      } else {
        widget.textController.text = text;
        final chatState = ref.read(chatActionsProvider);
        showInlineError(chatState.errorMessage ?? 'chat/send-failed');
      }
    }
  }

  @override
  void clearReply() {
    DebugConfig.log(DebugConfig.chatReply, 'ChatInputBar: clear reply');
    ref.read(replyToMessageProvider.notifier).clear(widget.chatId);
  }

  void _clearEdit() {
    DebugConfig.log(DebugConfig.chatReply, 'ChatInputBar: clear edit');
    ref.read(editingMessageProvider.notifier).clear(widget.chatId);
  }

  @override
  Map<String, dynamic>? buildReplyData() {
    final replyToMsg = ref.read(replyToMessageProvider.select((s) => s[widget.chatId]));
    if (replyToMsg == null) return null;

    final content = replyToMsg['content'] as String? ?? '';
    final type = replyToMsg['type'] as String? ?? 'text';
    final senderId = replyToMsg['senderId'] as String? ?? '';
    final currentUid = ref.read(authStateProvider).value?.uid ?? '';
    final isEmoji = type == 'text' && isOnlyEmoji(content);

    final contentPreview = chatMediaPreview(type, content, isEmoji);
    final thumbnailUrl = replyToMsg['thumbnailUrl'] as String?;
    final hasMediaUrl = (type == 'image' || type == 'gif') && content.isNotEmpty
        || type == 'video' && thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    DebugConfig.log(DebugConfig.chatReply,
        'ChatInputBar: reply data type=$type hasMediaUrl=$hasMediaUrl');

    final senderNickname = senderId == currentUid
        ? ''
        : (replyToMsg['_privateReplySenderNickname'] as String? ??
        widget.participantNicknames[senderId] ??
        senderId);

    return {
      'messageId': replyToMsg['id'] ?? '',
      'senderId': senderId,
      'contentPreview': contentPreview,
      'senderNickname': senderNickname,
      'type': type,
      if (type == 'image' || type == 'gif') 'content': content,
      if (type == 'video' && thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final currentUser =
        ref.watch(authStateProvider).value ?? FirebaseAuth.instance.currentUser;
    final authUid = ref.watch(authStateProvider).value?.uid ?? '';
    final canComm = AuthRepository.canUserCommunicate(currentUser);
    final replyToMsg = ref.watch(replyToMessageProvider.select((s) => s[widget.chatId]));
    final editingMsg = ref.watch(editingMessageProvider.select((s) => s[widget.chatId]));
    final incomingShareUploading =
        ref.watch(incomingShareUploadProvider) == widget.chatId;

    ref.listen(editingMessageProvider.select((s) => s[widget.chatId]), (prev, next) {
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
                ChatEditBanner(
                  message: editingMsg,
                  greek: greek,
                  onClose: () {
                    widget.textController.clear();
                    _clearEdit();
                  },
                )
              else if (replyToMsg != null)
                ChatReplyBanner(
                  message: replyToMsg,
                  participantNicknames: widget.participantNicknames,
                  currentUid: authUid,
                  onClose: clearReply,
                ),
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                  if (!_isLoading && !incomingShareUploading)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: showMediaPicker,
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
                    onPressed: (_isLoading || incomingShareUploading)
                        ? null
                        : _send,
                    icon: (_isLoading || incomingShareUploading)
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