import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String currentUid;
  final bool isGroupChat;
  final String? senderNickname;
  final Map<String, String>? participantNicknames;
  final List<String> seenBy;
  final String? chatId;
  final Future<void> Function(String chatId)? onApproveDelete;
  final Future<void> Function(String chatId)? onRejectDelete;
  final Future<void> Function(String chatId)? onDeleteForMe;
  final Future<void> Function(String chatId)? onKeepChat;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUid,
    this.isGroupChat = false,
    this.senderNickname,
    this.participantNicknames,
    this.seenBy = const [],
    this.chatId,
    this.onApproveDelete,
    this.onRejectDelete,
    this.onDeleteForMe,
    this.onKeepChat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = message['type'] as String? ?? 'text';
    final senderId = message['senderId'] as String? ?? '';
    final content = message['content'] as String? ?? '';
    final timestamp = message['timestamp'] as dynamic;
    final timeStr = timestamp is Timestamp
        ? _formatTime(timestamp.toDate())
        : '';

    if (type == 'system') {
      final contentEn = message['contentEn'] as String?;
      final action = message['action'] as String?;
      final senderId = message['senderId'] as String? ?? '';
      return _SystemBubble(
        content: content,
        contentEn: contentEn,
        timeStr: timeStr,
        action: action,
        isRequester: senderId == currentUid,
        chatId: chatId,
        onApproveDelete: onApproveDelete,
        onRejectDelete: onRejectDelete,
        onDeleteForMe: onDeleteForMe,
        onKeepChat: onKeepChat,
      );
    }

    final isMe = senderId == currentUid;
    final isRead = message['isRead'] as bool? ?? false;
    final mentions = (message['mentions'] as List?)?.cast<String>() ?? <String>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth * 0.75;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isGroupChat && !isMe && senderNickname != null)
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 2),
                  child: Text(
                    senderNickname!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Container(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: mentions.isEmpty
                ? Text(content, style: TextStyle(
                    color: isMe
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface))
                : _buildRichContent(context, content, mentions, isMe),
          ),
          Padding(
            padding: EdgeInsets.only(
                top: 2,
                left: isMe ? 0 : 14,
                right: isMe ? 14 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(timeStr, style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                if (isGroupChat && isMe && seenBy.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.visibility, size: 14,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 2),
                  Text('${seenBy.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary)),
                ],
                if (!isGroupChat && isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildRichContent(
      BuildContext context, String content, List<String> mentions, bool isMe) {
    final theme = Theme.of(context);
    final baseColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final highlightColor = isMe
        ? theme.colorScheme.onPrimary.withAlpha(200)
        : theme.colorScheme.primary;

    final spans = <TextSpan>[];
    final mentionSet = mentions.toSet();
    final nicknameToUid = participantNicknames != null
        ? {for (final e in participantNicknames!.entries) e.value: e.key}
        : <String, String>{};
    final regex = RegExp(r'@(\S+)');
    int lastEnd = 0;

    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      final nickname = match.group(1);
      final mentionedUid = nickname != null ? nicknameToUid[nickname] : null;
      final isMentioned = mentionedUid != null && mentionSet.contains(mentionedUid);
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: isMentioned ? highlightColor : baseColor,
          fontWeight: isMentioned ? FontWeight.w600 : FontWeight.normal,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return Text.rich(TextSpan(children: spans, style: TextStyle(color: baseColor)));
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _SystemBubble extends StatelessWidget {
  final String content;
  final String? contentEn;
  final String timeStr;
  final String? action;
  final bool isRequester;
  final String? chatId;
  final Future<void> Function(String chatId)? onApproveDelete;
  final Future<void> Function(String chatId)? onRejectDelete;
  final Future<void> Function(String chatId)? onDeleteForMe;
  final Future<void> Function(String chatId)? onKeepChat;

  const _SystemBubble({
    required this.content,
    this.contentEn,
    required this.timeStr,
    this.action,
    this.isRequester = false,
    this.chatId,
    this.onApproveDelete,
    this.onRejectDelete,
    this.onDeleteForMe,
    this.onKeepChat,
  });

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final displayContent = isGreek ? content : (contentEn ?? content);
    final showActions = chatId != null && !isRequester && (
        action == 'delete_request' || action == 'delete_rejected'
    );

    DebugConfig.log(DebugConfig.uiInteraction,
        '_SystemBubble: action=$action isRequester=$isRequester showActions=$showActions hasEn=${contentEn != null}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Center(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(120),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                displayContent,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          ),
          if (showActions && action == 'delete_request')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonal(
                    onPressed: () => onApproveDelete?.call(chatId!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: Text(isGreek ? 'Ναι' : 'Yes'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => onRejectDelete?.call(chatId!),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: Text(isGreek ? 'Όχι' : 'No'),
                  ),
                ],
              ),
            ),
          if (showActions && action == 'delete_rejected')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonal(
                    onPressed: () => onDeleteForMe?.call(chatId!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: Text(isGreek ? 'Ναι, μόνο για εμένα' : 'Yes, for me'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async => onKeepChat?.call(chatId!),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: Text(isGreek ? 'Όχι, παράμεινε' : 'No, keep it'),
                  ),
                ],
              ),
            ),
          if (timeStr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(timeStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

