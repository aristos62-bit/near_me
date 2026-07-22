import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../repositories/chat_repository.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/avatar_stack.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_messages_list.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/emoji_picker_panel.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenNicknames {
  final Map<String, String> data;
  const _ChatScreenNicknames(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatScreenNicknames &&
          const DeepCollectionEquality().equals(data, other.data);

  @override
  int get hashCode => const DeepCollectionEquality().hash(data);
}

class _ChatScreenState extends ConsumerState<ChatScreen> {

  static int _counter = 0;
  final int _instanceId = _counter++;
  final _textCtrl = TextEditingController();
  bool _emojiPickerVisible = false;
  int _buildCount = 0;
  DateTime? _initTime;
  late final Widget _messagesList;

  @override
  void initState() {
    super.initState();
    _initTime = DateTime.now();
    _messagesList = ChatMessagesList(chatId: widget.chatId);
    FcmService.registerActiveChat(widget.chatId);
    ref.read(replyToMessageProvider.notifier).clear();
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen init #$_instanceId: ${widget.chatId}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatActionsProvider.notifier)
            .markAsRead(widget.chatId, isGroupChat: false);
        DebugConfig.log(DebugConfig.uiInteraction,
            'ChatScreen: markAsRead scheduled chat=${widget.chatId}');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    DebugConfig.log(DebugConfig.uiRebuild,
        'ChatScreen #$_instanceId: didChangeDependencies');
  }

  @override
  void dispose() {
    FcmService.unregisterActiveChat(widget.chatId);
    _textCtrl.dispose();
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen dispose #$_instanceId: ${widget.chatId}');
    super.dispose();
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

  void _toggleEmojiPicker() {
    if (!_emojiPickerVisible) {
      FocusScope.of(context).unfocus();
    }
    setState(() => _emojiPickerVisible = !_emojiPickerVisible);
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen: emoji picker '
        '${_emojiPickerVisible ? "shown" : "hidden"}');
  }

  void _dismissEmojiPicker() {
    if (_emojiPickerVisible) {
      setState(() => _emojiPickerVisible = false);
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final pos = _textCtrl.selection.baseOffset;
    final text = _textCtrl.text;
    if (pos < 0 || pos > text.length) {
      _textCtrl.text = '$text${emoji.emoji}';
      _textCtrl.selection =
          TextSelection.collapsed(offset: _textCtrl.text.length);
    } else {
      _textCtrl.text =
          '${text.substring(0, pos)}${emoji.emoji}${text.substring(pos)}';
      _textCtrl.selection =
          TextSelection.collapsed(offset: pos + emoji.emoji.length);
    }
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen: emoji selected ${emoji.emoji}');
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    final elapsed = _initTime != null
        ? DateTime.now().difference(_initTime!).inMilliseconds
        : 0;
    DebugConfig.log(DebugConfig.uiRebuild,
        'ChatScreen #$_instanceId BUILD #$_buildCount +${elapsed}ms');
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final isGroupChat = ref.watch(chatDocProvider(widget.chatId).select(
      (a) =>
          (a.asData?.value?.data() as Map<String, dynamic>?)?['isGroupChat'] ==
          true,
    ));
    final groupName = ref.watch(chatDocProvider(widget.chatId).select(
      (a) =>
          (a.asData?.value?.data() as Map<String, dynamic>?)?['groupName']
              as String?,
    ));
    final participantNicknames = ref
        .watch(chatDocProvider(widget.chatId).select(
          (a) {
            final raw = (a.asData?.value?.data() as Map<String, dynamic>?)
                ?['participantNicknames'] as Map<String, dynamic>?;
            if (raw == null) return const _ChatScreenNicknames(<String, String>{});
            return _ChatScreenNicknames(
                raw.map((k, v) => MapEntry(k, v as String? ?? k)));
          },
        ))
        .data;

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
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showE2EInfo(isGroupChat ? (groupName ?? widget.chatId) : (otherNickname ?? widget.chatId)),
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
                  Text(otherNickname ?? widget.chatId),
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
        Expanded(child: _messagesList),
        _SafeInputArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_emojiPickerVisible)
                EmojiPickerPanel(onEmojiSelected: _onEmojiSelected),
              ChatInputBar(
                chatId: widget.chatId,
                isGroupChat: isGroupChat,
                textController: _textCtrl,
                emojiPickerVisible: _emojiPickerVisible,
                onEmojiToggle: _toggleEmojiPicker,
                onEmojiDismiss: _dismissEmojiPicker,
                participantNicknames: isGroupChat ? participantNicknames : const {},
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SafeInputArea extends StatelessWidget {
  final Widget child;
  const _SafeInputArea({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: child,
    );
  }
}

