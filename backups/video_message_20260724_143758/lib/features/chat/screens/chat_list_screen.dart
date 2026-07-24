import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../repositories/auth_repository.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../data/local/database.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../screens/chat_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greek = L10n.isGreek(context);
    final authUser = ref.watch(authStateProvider).value;
    final syncUser = FirebaseAuth.instance.currentUser;
    final user = authUser ?? syncUser;
    final canComm = AuthRepository.canUserCommunicate(user);
    final chatsAsync = ref.watch(chatsProvider);

    DebugConfig.log(DebugConfig.uiRebuild, 'ChatListScreen build: canComm=$canComm');

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(greek ? 'Μηνύματα' : 'Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: greek ? 'Ανακάλυψη ομάδων' : 'Discover groups',
            onPressed: () => context.push('/groups/search'),
          ),
        ],
      ),
      floatingActionButton: canComm
          ? FloatingActionButton.small(
              onPressed: () => context.push('/groups/create'),
              tooltip: greek ? 'Δημιουργία ομάδας' : 'Create group',
              child: const Icon(Icons.group_add),
            )
          : null,
      body: !canComm
          ? _buildVerifyBanner(context, greek)
          : chatsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) {
                DebugConfig.error('ChatListScreen load failed', data: e);
                return ErrorView(
                  message: L10n.localizedMessage(context, 'Σφάλμα φόρτωσης / Failed to load'),
                  onRetry: () => ref.invalidate(chatsProvider),
                );
              },
              data: (chats) {
                if (chats.isEmpty) {
                  return EmptyView(
                    icon: Icons.chat_bubble_outline,
                    message: greek ? 'Δεν υπάρχουν μηνύματα' : 'No messages yet',
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final w = ResponsiveUtils.resolveWidth(context, constraints);
                    // ── ΠΡΟΣΩΡΙΝΟ DIAGNOSTIC LOG — Πρόβλημα 2 (θα αφαιρεθεί μετά) ──
                    DebugConfig.log(DebugConfig.uiRebuild,
                        'ChatListScreen LayoutBuilder REBUILT — '
                            'time=${DateTime.now().toIso8601String().substring(11, 23)}');
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.paddingValueFromWidth(w),
                      ),
                      itemCount: chats.length,
                      itemBuilder: (_, i) => _ChatTile(chat: chats[i]),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildVerifyBanner(BuildContext context, bool greek) {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatListScreen: showing verify banner for anonymous');
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 72,
                color: theme.colorScheme.primary.withAlpha(80)),
            const SizedBox(height: 20),
            Text(
              greek ? 'Τα μηνύματα είναι κλειδωμένα' : 'Messages are locked',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              greek
                  ? 'Για να στείλεις και να λάβεις μηνύματα, πρέπει πρώτα να επαληθεύσεις τον λογαριασμό σου.'
                  : 'To send and receive messages, you need to verify your account first.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                DebugConfig.log(DebugConfig.uiInteraction,
                    'ChatListScreen: navigate to verify from banner');
                context.push('/auth');
              },
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              label: Text(greek ? 'Επαλήθευση Λογαριασμού' : 'Verify Account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  final ChatCacheTableData chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final chatId = chat.chatId ?? '';
    final isGroup = chat.isGroupChat;
    final title = isGroup ? (chat.groupName ?? chatId) : (chat.otherNickname ?? chat.otherUid ?? '?');
    DebugConfig.log(DebugConfig.uiInteraction,
        '_ChatTile: chatId=$chatId isGroup=$isGroup '
        'otherNickname=${chat.otherNickname ?? "null"} '
        'otherUid=${chat.otherUid ?? "null"} '
        'groupName=${chat.groupName ?? "null"} '
        'title=$title');
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final avatarUrl = isGroup ? chat.groupAvatarUrl : chat.otherAvatarUrl;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final hasUnread = chat.hasUnread;
    final lastTime = chat.lastMessageAt;
    final unreadCount = chat.unreadCount;
    final showDelete = !isGroup || chat.groupCreatedBy == currentUid;

    final previewText = _buildPreviewText(greek, title, isGroup);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: isGroup
            ? CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Icon(Icons.group, color: theme.colorScheme.onSecondaryContainer)
                    : null,
              )
            : CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(initial, style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ))
                    : null,
              ),
        title: Text(
          title,
          style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (previewText != null)
              Text(
                previewText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                  color: hasUnread
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (isGroup && chat.participantCount > 2)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  greek ? '${chat.participantCount} μέλη' : '${chat.participantCount} members',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (lastTime != null)
              Text(_formatTime(context, greek, lastTime), style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (showDelete)
              IconButton(
              icon: Icon(Icons.delete_forever, color: theme.colorScheme.error, size: 20),
              onPressed: () async {
                final message = isGroup
                    ? L10n.localizedMessage(context, 'Θα διαγραφεί ολόκληρη η ομάδα "$title". Συνέχεια; / This will delete the entire group "$title". Continue?')
                    : L10n.localizedMessage(context, 'Θα σταλεί αίτημα διαγραφής στον άλλο χρήστη. Συνέχεια; / A delete request will be sent to the other user. Continue?');
                final confirmed = await AppMessenger.showConfirmDialog(
                  context,
                  title: L10n.localizedMessage(context, 'Διαγραφή συνομιλίας / Delete conversation'),
                  message: message,
                  confirmLabel: greek ? 'Διαγραφή' : 'Delete',
                  cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
                  isDestructive: true,
                );
                if (confirmed && context.mounted) {
                  DebugConfig.log(DebugConfig.uiInteraction, 'ChatListScreen: deleteChat $chatId isGroup=$isGroup');
                  await ref.read(chatActionsProvider.notifier).deleteChat(chatId);
                }
              },
            ),
          ],
        ),
        onTap: () {
          DebugConfig.log(DebugConfig.uiInteraction, 'ChatListScreen: tap chat=$chatId isGroup=$isGroup');
          context.push('/chat/$chatId',
              extra: ChatNavExtra(isGroupChat: isGroup, groupName: isGroup ? title : null));
        },
      ),
    );
  }

  String? _buildPreviewText(bool greek, String title, bool isGroup) {
    final msg = chat.lastMessage;
    final sender = chat.lastMessageSender;
    final type = chat.lastMessageType ?? 'text';

    if (type != 'text') {
      if (type == 'image') return greek ? '📷 Φωτογραφία' : '📷 Photo';
      if (type == 'gif') return '🎞️ GIF';
      if (type == 'audio') return greek ? '🎵 Φωνητικό μήνυμα' : '🎵 Voice message';
      return greek ? '💬 Μήνυμα' : '💬 Message';
    }

    if (msg == null) return null;

    final truncated = msg.length > 50 ? '${msg.substring(0, 50)}...' : msg;
    if (isGroup) {
      return truncated;
    }
    if (sender == 'me') {
      final prefix = greek ? 'Εσύ: ' : 'You: ';
      return '$prefix$truncated';
    }
    return '$title: $truncated';
  }

  String _formatTime(BuildContext context, bool greek, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return greek ? 'Τώρα' : 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return greek ? 'Χθές' : 'Yesterday';
    return L10n.formatDate(context, dt);
  }
}
