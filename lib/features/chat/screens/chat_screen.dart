import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/chat_repository.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/avatar_stack.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_messages_list.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String? _nickname;
  static int _counter = 0;
  final int _instanceId = _counter++;

  @override
  void initState() {
    super.initState();
    FcmService.registerActiveChat(widget.chatId);
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen init #$_instanceId: ${widget.chatId}');
  }

  @override
  void dispose() {
    FcmService.unregisterActiveChat(widget.chatId);
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen dispose #$_instanceId: ${widget.chatId}');
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nickname ??= GoRouterState.of(context).extra as String?;
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen didChangeDependencies #$_instanceId: '
            'nickname=${_nickname ?? "null (will show chatId)"}');
  }

  void _showE2EInfo(String label) {
    final greek = L10n.isGreek(context);
    AppMessenger.showInfoDialog(
      context,
      icon: Icons.lock,
      title: greek ? 'E2E Κρυπτογράφηση' : 'E2E Encryption',
      message: greek
          ? 'Τα μηνύματά σου προστατεύονται με κρυπτογράφηση AES-256 από άκρο σε άκρο. '
              'Μόνο εσύ και η ομάδα "$label" μπορείτε να τα διαβάσετε.'
          : 'Your messages are protected with end-to-end AES-256 encryption. '
              'Only you and group "$label" can read them.',
      dismissLabel: greek ? 'Εντάξει' : 'OK',
    );
  }

  Future<void> _leaveGroup() async {
    final greek = L10n.isGreek(context);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Αποχώρηση / Leave group'),
      message: L10n.localizedMessage(context,
          'Θα αποχωρήσεις από την ομάδα. Συνέχεια; / You will leave the group. Continue?'),
      confirmLabel: greek ? 'Αποχώρηση' : 'Leave',
      cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (confirmed && mounted) {
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      final ok = await ref.read(chatActionsProvider.notifier).removeParticipant(widget.chatId, uid);
      if (ok && mounted && context.canPop()) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final chatDocAsync = ref.watch(chatDocProvider(widget.chatId));
    final chatData = chatDocAsync.asData?.value?.data() as Map<String, dynamic>?;
    final isGroupChat = chatData?['isGroupChat'] == true;
    final groupName = chatData?['groupName'] as String?;
    final participantNicknames = (chatData?['participantNicknames'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as String? ?? k)) ??
        {};

    final participantUids = ref.watch(participantUidsProvider(widget.chatId));
    final memberCount = isGroupChat ? participantUids.length : null;

    final currentUid = ref.read(authStateProvider).value?.uid ?? '';
    final permsAsync = isGroupChat ? ref.watch(groupPermissionsProvider(widget.chatId)) : null;
    final permsInfo = permsAsync?.asData?.value;
    final canInvite = permsInfo?.hasPermission(currentUid, GroupPermission.inviteMembers) ?? false;
    final canDeleteMsgs = permsInfo?.hasPermission(currentUid, GroupPermission.deleteMessages) ?? false;
    DebugConfig.log(DebugConfig.authGuard,
        'ChatScreen #$_instanceId: isGroup=$isGroupChat canInvite=$canInvite canDeleteMsgs=$canDeleteMsgs');
    final otherUid = isGroupChat ? null : participantUids.where((u) => u != currentUid).firstOrNull;
    final otherNickname = otherUid != null ? participantNicknames[otherUid] : null;
    ref.listen(participantUidsProvider(widget.chatId), (prev, next) {
      if (!mounted) return;
      if (currentUid.isNotEmpty && !next.contains(currentUid) && context.canPop()) {
        context.pop();
      }
    });

    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen #$_instanceId: isGroup=$isGroupChat groupName=$groupName');

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showE2EInfo(isGroupChat ? (groupName ?? widget.chatId) : (_nickname ?? otherNickname ?? widget.chatId)),
          child: isGroupChat
              ? Column(children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    AvatarStack(
                      uids: participantUids,
                      nicknames: participantNicknames,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(groupName ?? widget.chatId, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  if (memberCount != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock, size: 12, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        greek ? '$memberCount μέλη' : '$memberCount members',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ]),
                ])
              : Column(children: [
                  Text(_nickname ?? otherNickname ?? widget.chatId),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock, size: 12, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      greek ? 'Προσωπικά μηνύματα' : 'Personal messages',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ]),
                ]),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear') {
                final confirmed = await AppMessenger.showConfirmDialog(
                  context,
                  title: L10n.localizedMessage(context, 'Διαγραφή μηνυμάτων / Clear messages'),
                  message: L10n.localizedMessage(context,
                      'Θα διαγραφούν όλα τα μηνύματα. Η συνομιλία θα παραμείνει. '
                      'Συνέχεια; / All messages will be deleted. The conversation remains. Continue?'),
                  confirmLabel: greek ? 'Διαγραφή' : 'Delete',
                  cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
                  isDestructive: true,
                );
                if (confirmed && context.mounted) {
                  await ref.read(chatActionsProvider.notifier).clearMessages(widget.chatId);
                  if (context.mounted) {
                    AppMessenger.showSuccess(context,
                        L10n.localizedMessage(context, 'Τα μηνύματα διαγράφηκαν / Messages cleared'));
                  }
                }
              } else if (v == 'group_info') {
                context.push('/groups/${widget.chatId}/info');
              } else if (v == 'add_member') {
                context.push('/groups/${widget.chatId}/add');
              } else if (v == 'group_audit_log') {
                context.push('/groups/${widget.chatId}/audit-log');
              } else if (v == 'group_call') {
                context.push('/groups/${widget.chatId}/call', extra: groupName);
              } else if (v == 'leave_group') {
                await _leaveGroup();
              }
            },
            itemBuilder: (_) => [
              if (isGroupChat) ...[
                PopupMenuItem(
                  value: 'group_info',
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, size: 20),
                    title: Text(greek ? 'Πληροφορίες ομάδας' : 'Group info'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (canInvite)
                  PopupMenuItem(
                    value: 'add_member',
                    child: ListTile(
                      leading: const Icon(Icons.person_add, size: 20),
                      title: Text(greek ? 'Προσθήκη μέλους' : 'Add member'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem(
                  value: 'group_audit_log',
                  child: ListTile(
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(greek ? 'Αρχείο καταγραφής' : 'Audit log'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'group_call',
                  child: ListTile(
                    leading: const Icon(Icons.videocam, size: 20),
                    title: Text(greek ? 'Κλήση' : 'Call'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'leave_group',
                  child: ListTile(
                    leading: const Icon(Icons.exit_to_app, size: 20),
                    title: Text(greek ? 'Αποχώρηση' : 'Leave group'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              if (!isGroupChat || canDeleteMsgs)
                PopupMenuItem(
                  value: 'clear',
                  child: Row(children: [
                    Icon(Icons.delete_sweep, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Text(greek ? 'Διαγραφή μηνυμάτων' : 'Clear messages'),
                  ]),
                ),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: ChatMessagesList(
          chatId: widget.chatId,
          isGroupChat: isGroupChat,
          participantNicknames: isGroupChat ? participantNicknames : null,
          otherUid: otherUid,
        )),
        _ChatInputBar(chatId: widget.chatId, isGroupChat: isGroupChat),
      ]),
    );
  }
}

class _ChatInputBar extends ConsumerStatefulWidget {
  final String chatId;
  final bool isGroupChat;
  const _ChatInputBar({required this.chatId, this.isGroupChat = false});

  @override
  ConsumerState<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<_ChatInputBar> {
  final _textCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;
    _textCtrl.clear();
    setState(() => _isLoading = true);
    final ok = await ref.read(chatActionsProvider.notifier)
        .sendMessage(widget.chatId, text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      _textCtrl.text = text;
      final chatState = ref.read(chatActionsProvider);
      AppMessenger.showError(context, ErrorMessages.get(
          chatState.errorMessage ?? 'chat/send-failed', L10n.isGreek(context)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final currentUser = ref.watch(authStateProvider).value ?? FirebaseAuth.instance.currentUser;
    final canComm = AuthRepository.canUserCommunicate(currentUser);
    DebugConfig.log(DebugConfig.uiInteraction, '_ChatInputBar build: canComm=$canComm');

    final hintText = widget.isGroupChat
        ? (greek ? 'Γράψε στην ομάδα...' : 'Type to group...')
        : (greek ? 'Γράψε ένα μήνυμα...' : 'Type a message...');

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = ResponsiveUtils.resolveWidth(context, constraints);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          padding: EdgeInsets.only(
            left: ResponsiveUtils.paddingValueFromWidth(w),
            right: ResponsiveUtils.paddingValueFromWidth(w),
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: !canComm
              ? Row(children: [
                  const SizedBox(width: 12),
                  Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    greek
                        ? 'Πρέπει να επαληθεύσεις τον λογαριασμό σου για να στείλεις μηνύματα'
                        : 'You must verify your account to send messages',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )),
                ])
              : Row(children: [
                  Expanded(child: TextField(
                    controller: _textCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
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
        );
      },
    );
  }
}
