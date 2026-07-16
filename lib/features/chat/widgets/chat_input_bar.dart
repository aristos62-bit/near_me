import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/error_messages.dart';
import '../../../repositories/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final String chatId;
  final bool isGroupChat;
  final TextEditingController textController;
  final bool emojiPickerVisible;
  final VoidCallback onEmojiToggle;
  final VoidCallback onEmojiDismiss;

  const ChatInputBar({
    super.key,
    required this.chatId,
    this.isGroupChat = false,
    required this.textController,
    required this.emojiPickerVisible,
    required this.onEmojiToggle,
    required this.onEmojiDismiss,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _focusNode = FocusNode();
  bool _isLoading = false;

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
    widget.textController.clear();
    setState(() => _isLoading = true);
    final ok = await ref
        .read(chatActionsProvider.notifier)
        .sendMessage(widget.chatId, text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
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

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final currentUser =
        ref.watch(authStateProvider).value ?? FirebaseAuth.instance.currentUser;
    final canComm = AuthRepository.canUserCommunicate(currentUser);
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatInputBar build: canComm=$canComm '
        'emojiVisible=${widget.emojiPickerVisible}');

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
                      icon: Icon(
                        widget.emojiPickerVisible
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                      ),
                      onPressed: widget.onEmojiToggle,
                      tooltip: 'Emoji',
                    ),
                  Expanded(child: TextField(
                    controller: widget.textController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
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
