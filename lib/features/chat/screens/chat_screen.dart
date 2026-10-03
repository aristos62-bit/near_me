import 'package:audioplayers/audioplayers.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../repositories/chat_repository.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/avatar_stack.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_messages_list.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/emoji_picker_panel.dart';
import '../widgets/expiry_banner.dart';
import '../widgets/one_to_one_expiry_sheet.dart';

/// Δεδομένα που περνάμε στο ChatScreen μέσω `extra` κατά την πλοήγηση, ώστε
/// ο τίτλος (group/1-1) να είναι σωστός ήδη από το πρώτο frame, χωρίς να
/// περιμένουμε να φορτώσει το chatDocProvider (αποφυγή "flash" τίτλου).
/// Χρησιμοποιείται ΜΟΝΟ ως fallback· η πραγματική τιμή από το
/// chatDocProvider υπερισχύει μόλις φορτώσει.
class ChatNavExtra {
  final bool isGroupChat;
  final String? groupName;
  const ChatNavExtra({required this.isGroupChat, this.groupName});
}

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final ChatNavExtra? navExtra;
  const ChatScreen({super.key, required this.chatId, this.navExtra});

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
  final _audioPlayer = AudioPlayer();
  late Widget _messagesList;
  // Riverpod: στο dispose() το ref είναι unsafe — κρατάμε τον notifier σε
  // field (αποθήκευση στο initState), όχι ref.read στο dispose.
  late final VideoPlaybackNotifier _videoPlayback;

  @override
  void initState() {
    super.initState();
    _videoPlayback = ref.read(videoPlaybackProvider.notifier);
    _messagesList = ChatMessagesList(chatId: widget.chatId, audioPlayer: _audioPlayer, videoPlayer: null, onPlayVideo: _playVideo, videoLoadingUrl: null);
    FcmService.registerActiveChat(widget.chatId);
    ref.read(replyToMessageProvider.notifier).clear(widget.chatId);
    ref.read(editingMessageProvider.notifier).clear(widget.chatId);
    DebugConfig.log(DebugConfig.chatReply,
        'ChatScreen: composer state cleared chat=${widget.chatId}');
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen init #$_instanceId: ${widget.chatId}');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final allChats = ref.read(chatsProvider).asData?.value ?? [];
      final cached = allChats.where((c) => c.chatId == widget.chatId).firstOrNull;
      final knownGroup = cached?.isGroupChat ?? widget.navExtra?.isGroupChat;

      bool isGroup;
      String src;
      if (knownGroup != null) {
        isGroup = knownGroup;
        src = cached != null ? 'drift' : 'navExtra';
      } else {
        // Cold path (invite link / FCM deep link, χωρίς cache/navExtra):
        // περιμένουμε το πραγματικό doc πριν κάνουμε markAsRead, ώστε να
        // μην κάνουμε λάθος batch write isRead:true σε group chat.
        final snap = await ref.read(chatDocProvider(widget.chatId).future);
        if (!mounted) return; // re-check ΜΕΤΑ το await, πριν ξαναγγίξουμε ref
        isGroup = snap?.data() != null &&
            (snap!.data() as Map<String, dynamic>)['isGroupChat'] == true;
        src = 'firestore-cold';
      }

      DebugConfig.log(DebugConfig.firestoreWrite,
          'ChatScreen: markAsRead chat=${widget.chatId} '
          'isGroupChat=$isGroup src=$src');

      ref.read(chatActionsProvider.notifier)
          .markAsRead(widget.chatId, isGroupChat: isGroup);
    });
  }

  @override
  void dispose() {
    FcmService.unregisterActiveChat(widget.chatId);
    _textCtrl.dispose();
    _audioPlayer.dispose();
    _videoPlayback.stop(widget.chatId);
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatScreen dispose #$_instanceId: ${widget.chatId}');
    super.dispose();
  }



  void _showEncryptionInfo(String label) {
    final greek = L10n.isGreek(context);
    AppMessenger.showInfoDialog(
      context,
      icon: Icons.lock,
      title: ErrorMessages.get('chat/e2e-info-title', greek),
      message: greek
          ? 'Τα μηνύματά σου προστατεύονται με κρυπτογράφηση AES-256. '
              'Μόνο εσύ και η ομάδα "$label" μπορείτε να τα διαβάσετε.'
          : 'Your messages are protected with AES-256 encryption. '
              'Only you and group "$label" can read them.',
      dismissLabel: greek ? 'Εντάξει' : 'OK',
    );
  }

  Future<void> _playVideo(String url) async {
    await ref.read(videoPlaybackProvider.notifier).play(widget.chatId, url);
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
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final isGroupChat = ref.watch(chatDocProvider(widget.chatId).select((a) {
      final data = a.asData?.value?.data() as Map<String, dynamic>?;
      if (data == null) return widget.navExtra?.isGroupChat ?? false;
      return data['isGroupChat'] == true;
    }));
    final groupName = ref.watch(chatDocProvider(widget.chatId).select((a) {
      final data = a.asData?.value?.data() as Map<String, dynamic>?;
      if (data == null) return widget.navExtra?.groupName;
      return data['groupName'] as String?;
    }));
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
    final otherUid = isGroupChat ? null : participantUids.where((u) => u != currentUid).firstOrNull;
    final otherNickname = otherUid != null ? participantNicknames[otherUid] : null;
    ref.listen(participantUidsProvider(widget.chatId), (prev, next) {
      if (!mounted) return;
      if (currentUid.isNotEmpty && !next.contains(currentUid) && context.canPop()) {
        context.pop();
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showEncryptionInfo(isGroupChat ? (groupName ?? widget.chatId) : (otherNickname ?? widget.chatId)),
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
                        ErrorMessages.get('chat/messages-cleared', greek));
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
              } else if (v == 'expiry_1to1') {
                final data = ref.read(chatDocProvider(widget.chatId)).asData?.value?.data() as Map<String, dynamic>?;
                final current = data?['messageExpiry'] as String? ?? 'off';
                await showOneToOneExpirySheet(context, ref, widget.chatId, current);
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
              if (!isGroupChat && FeatureFlags.messageExpiryEnabled)
                PopupMenuItem(
                  value: 'expiry_1to1',
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined, size: 20),
                    title: Text(greek ? 'Αυτόματη διαγραφή' : 'Auto-delete'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
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
        ExpiryBanner(chatId: widget.chatId),
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
                participantNicknames: participantNicknames,
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

