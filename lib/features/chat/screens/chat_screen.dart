import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();
  final _textCtrl = TextEditingController();
  bool _isLoading = false;
  String? _nickname;
  static int _counter = 0;
  final int _instanceId = _counter++;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatScreen init #$_instanceId: ${widget.chatId}');
    _nickname = GoRouterState.of(context).extra as String?;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatActionsProvider.notifier).markAsRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatScreen dispose #$_instanceId: ${widget.chatId}');
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onMessagesChanged(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showE2EInfo() {
    final greek = L10n.isGreek(context);
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatScreen: E2E info tapped');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock, size: 20),
            const SizedBox(width: 8),
            Text(greek ? 'E2E Κρυπτογράφηση' : 'E2E Encryption'),
          ],
        ),
        content: Text(
          greek
              ? 'Τα μηνύματά σου προστατεύονται με κρυπτογράφηση AES-256 από άκρο σε άκρο. Μόνο εσύ και ο/η ${_nickname ?? widget.chatId} μπορείτε να τα διαβάσετε.'
              : 'Your messages are protected with end-to-end AES-256 encryption. Only you and ${_nickname ?? widget.chatId} can read them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(greek ? 'Εντάξει' : 'OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;

    _textCtrl.clear();
    setState(() => _isLoading = true);

    DebugConfig.log(DebugConfig.uiInteraction, 'ChatScreen: sendMessage');
    final ok = await ref.read(chatActionsProvider.notifier).sendMessage(widget.chatId, text);
    setState(() => _isLoading = false);

    if (!ok && mounted) {
      _textCtrl.text = text;
      final chatState = ref.read(chatActionsProvider);
      final msg = chatState.errorMessage != null
          ? L10n.localizedMessage(context, chatState.errorMessage!)
          : (L10n.isGreek(context) ? 'Αποστολή απέτυχε' : 'Send failed');
      AppMessenger.showError(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final currentUser = ref.watch(authStateProvider).value;
    final currentUid = currentUser?.uid ?? '';

    DebugConfig.log(DebugConfig.uiRebuild, 'ChatScreen build: ${widget.chatId}');

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showE2EInfo,
          child: Column(
            children: [
              Text(_nickname ?? widget.chatId),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 12, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    greek ? 'Προσωπικά μηνύματα' : 'Personal messages',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear') {
                final confirmed = await AppMessenger.showConfirmDialog(
                  context,
                  title: L10n.localizedMessage(context, 'Διαγραφή μηνυμάτων / Clear messages'),
                  message: L10n.localizedMessage(context, 'Θα διαγραφούν όλα τα μηνύματα. Η συνομιλία θα παραμείνει. Συνέχεια; / All messages will be deleted. The conversation remains. Continue?'),
                  confirmLabel: greek ? 'Διαγραφή' : 'Delete',
                  cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
                  isDestructive: true,
                );
                if (confirmed && context.mounted) {
                  await ref.read(chatActionsProvider.notifier).clearMessages(widget.chatId);
                  if (context.mounted) {
                    AppMessenger.showSuccess(context, L10n.localizedMessage(context, 'Τα μηνύματα διαγράφηκαν / Messages cleared'));
                  }
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Text(greek ? 'Διαγραφή μηνυμάτων' : 'Clear messages'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) {
                DebugConfig.error('ChatScreen messages error', data: e);
                return ErrorView(
                  message: L10n.localizedMessage(context, 'Σφάλμα φόρτωσης / Failed to load'),
                  onRetry: () => ref.invalidate(messagesProvider(widget.chatId)),
                );
              },
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _onMessagesChanged(messages));
                if (messages.isEmpty) {
                  return EmptyView(
                    icon: Icons.chat_bubble_outline,
                    message: greek ? 'Καμία συνομιλία' : 'No messages',
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.paddingValue(context),
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _MessageBubble(
                    message: messages[i],
                    currentUid: currentUid,
                    theme: theme,
                  ),
                );
              },
            ),
          ),
          _buildInputBar(theme, greek),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool greek) {
    final currentUser = ref.watch(authStateProvider).value;
    final isAnonymous = currentUser == null || currentUser.isAnonymous;

    if (isAnonymous) {
      DebugConfig.log(DebugConfig.uiInteraction, 'ChatScreen: input bar disabled (anonymous)');
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: EdgeInsets.only(
        left: ResponsiveUtils.paddingValue(context),
        right: ResponsiveUtils.paddingValue(context),
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: isAnonymous
          ? Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    greek
                        ? 'Πρέπει να επαληθεύσεις τον λογαριασμό σου για να στείλεις μηνύματα'
                        : 'You must verify your account to send messages',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: greek ? 'Γράψε ένα μήνυμα...' : 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isLoading ? null : _send,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String currentUid;
  final ThemeData theme;

  const _MessageBubble({
    required this.message,
    required this.currentUid,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final senderId = message['senderId'] as String? ?? '';
    final content = message['content'] as String? ?? '';
    final timestamp = message['timestamp'] as dynamic;
    final isRead = message['isRead'] as bool? ?? false;
    final isMe = senderId == currentUid;
    final timeStr = timestamp is Timestamp ? _formatTime(timestamp.toDate()) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Text(content, style: TextStyle(
              color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            )),
          ),
          Padding(
            padding: EdgeInsets.only(top: 2, left: isMe ? 0 : 14, right: isMe ? 14 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(timeStr, style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
