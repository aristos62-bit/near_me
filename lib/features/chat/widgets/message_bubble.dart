import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import 'emoji_only_bubble.dart';
import 'message_action_bar.dart';
import 'message_reactions.dart';
import '../../../shared/widgets/read_receipt_indicator.dart';

class ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final bool isMe;
  final bool isGroupChat;

  const ReplyPreview({
    super.key,
    required this.replyTo,
    required this.isMe,
    this.isGroupChat = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senderNickname = replyTo['senderNickname'] as String?;
    final contentPreview = replyTo['contentPreview'] as String? ?? '';
    final preview = isGroupChat && senderNickname != null
        ? '@$senderNickname: $contentPreview'
        : contentPreview;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(180),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        preview,
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class TailPainter extends CustomPainter {
  final Color color;

  const TailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TailPainter old) => old.color != color;
}

class MessageBubble extends StatelessWidget {
  static final _buildCounts = <String, int>{};
  final double bubbleMaxWidth;
  final Map<String, dynamic> message;
  final String currentUid;
  final bool isGroupChat;
  final bool isRead;
  final bool isGrouped;
  final bool isLastInGroup;
  final bool showAvatar;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final Map<String, String>? participantNicknames;
  final List<String> seenBy;
  final String? chatId;
  final Future<void> Function(String chatId)? onApproveDelete;
  final Future<void> Function(String chatId)? onRejectDelete;
  final Future<void> Function(String chatId)? onDeleteForMe;
  final Future<void> Function(String chatId)? onKeepChat;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;
  final void Function(Map<String, dynamic> message)? onReply;
  final void Function(Map<String, dynamic> message)? onEdit;
  final void Function(Map<String, dynamic> message)? onDelete;

  const MessageBubble({
    super.key,
    required this.bubbleMaxWidth,
    required this.message,
    required this.currentUid,
    this.isGroupChat = false,
    this.isRead = false,
    this.isGrouped = false,
    this.isLastInGroup = true,
    this.showAvatar = true,
    this.senderNickname,
    this.senderAvatarUrl,
    this.participantNicknames,
    this.seenBy = const [],
    this.chatId,
    this.onApproveDelete,
    this.onRejectDelete,
    this.onDeleteForMe,
    this.onKeepChat,
    this.onReact,
    this.onRemove,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  static const double _bubbleRadius = 20;
  static const double _tailRadius = 8;
  static const Color _sentColor = Color(0xFF075E54);
  static const Color _sentTextColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = message['type'] as String? ?? 'text';
    final senderId = message['senderId'] as String? ?? '';
    final content = message['content'] as String? ?? '';
    final timestamp = message['timestamp'] as dynamic;
    final ts = timestamp is Timestamp ? timestamp.toDate() : null;
    final timeStr = ts != null
        ? L10n.formatTimeOfDay(context, TimeOfDay.fromDateTime(ts))
        : '';
    final reactions = (message['reactions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final replyTo = message['replyTo'] as Map<String, dynamic>?;

    final msgId = message['id'] as String? ?? '';
    _buildCounts[msgId] = (_buildCounts[msgId] ?? 0) + 1;
    final buildN = _buildCounts[msgId]!;
    DebugConfig.log(
      DebugConfig.chatBubbleDesign,
      'MessageBubble built: id=$msgId type=$type '
      'isGrouped=$isGrouped isLastInGroup=$isLastInGroup build#$buildN',
    );

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

    if (type == 'gif' || type == 'image') {
      final isMe = senderId == currentUid;
      return _GifBubble(
        bubbleMaxWidth: bubbleMaxWidth,
        content: content,
        timeStr: timeStr,
        isMe: isMe,
        isGroupChat: isGroupChat,
        isGrouped: isGrouped,
        isLastInGroup: isLastInGroup,
        showAvatar: showAvatar,
        senderNickname: senderNickname,
        senderAvatarUrl: senderAvatarUrl,
        seenBy: seenBy,
        isRead: isRead,
        chatId: chatId,
        currentUid: currentUid,
        messageId: message['id'] as String? ?? '',
        isImage: type == 'image',
        reactions: reactions,
        onReact: onReact,
        onRemove: onRemove,
        replyTo: replyTo,
        onReply: onReply != null ? () => onReply!(message) : null,
        onEdit: onEdit != null ? () => onEdit!(message) : null,
        onDelete: onDelete != null ? () => onDelete!(message) : null,
      );
    }

    if (type == 'text' && isOnlyEmoji(content)) {
      final isMe = senderId == currentUid;
      return EmojiOnlyBubble(
        bubbleMaxWidth: bubbleMaxWidth,
        content: content,
        timeStr: timeStr,
        isMe: isMe,
        isGroupChat: isGroupChat,
        isGrouped: isGrouped,
        isLastInGroup: isLastInGroup,
        showAvatar: showAvatar,
        senderNickname: senderNickname,
        senderAvatarUrl: senderAvatarUrl,
        seenBy: seenBy,
        isRead: isRead,
        chatId: chatId,
        currentUid: currentUid,
        messageId: message['id'] as String? ?? '',
        reactions: reactions,
        onReact: onReact,
        onRemove: onRemove,
        replyTo: replyTo,
        onReply: onReply != null ? () => onReply!(message) : null,
        onEdit: onEdit != null ? () => onEdit!(message) : null,
        onDelete: onDelete != null ? () => onDelete!(message) : null,
      );
    }

    final isMe = senderId == currentUid;
    final mentions = (message['mentions'] as List?)?.cast<String>() ?? <String>[];
    final showTail = isLastInGroup;
    final sentColor = _sentColor;
    final receivedColor = theme.colorScheme.surfaceContainerHighest;
    final bubbleColor = isMe ? sentColor : receivedColor;
    final textColor = isMe ? _sentTextColor : theme.colorScheme.onSurface;

    final bubbleBorderRadius = BorderRadius.only(
      topLeft: const Radius.circular(_bubbleRadius),
      topRight: const Radius.circular(_bubbleRadius),
      bottomLeft: Radius.circular(
          (!isMe && showTail) ? _tailRadius : _bubbleRadius),
      bottomRight: Radius.circular(
          (isMe && showTail) ? _tailRadius : _bubbleRadius),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMe
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
              if (!isMe && showAvatar
                  && (senderAvatarUrl != null || (isGroupChat && senderNickname != null)))
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: senderAvatarUrl != null
                            ? CachedNetworkImageProvider(senderAvatarUrl!)
                            : null,
                        child: senderAvatarUrl == null
                            ? Text(senderNickname![0],
                                style: const TextStyle(fontSize: 18))
                            : null,
                      ),
                      if (isGroupChat && senderNickname != null) ...[
                        const SizedBox(width: 4),
                        Text(senderNickname!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              GestureDetector(
                onLongPressStart: (details) async {
                  final result = await MessageActionBar.show(
                    context: context,
                    isOwn: message['senderId'] == currentUid,
                    globalPosition: details.globalPosition,
                  );
                  if (result == 'reply') onReply?.call(message);
                  if (result == 'edit') onEdit?.call(message);
                  if (result == 'delete') onDelete?.call(message);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (replyTo != null)
                      ReplyPreview(
                        replyTo: replyTo,
                        isMe: isMe,
                        isGroupChat: isGroupChat,
                      ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: bubbleBorderRadius,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              mentions.isEmpty
                                  ? Text(content, style: TextStyle(color: textColor), textAlign: TextAlign.end)
                                  : _buildRichContent(context, content, mentions, isMe),
                              if (timeStr.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Align(
                                    alignment: AlignmentDirectional.bottomEnd,
                                    child: Text(timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white.withAlpha(180)
                                            : theme.colorScheme.onSurfaceVariant.withAlpha(180),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (showTail)
                          Positioned(
                            bottom: 0,
                            right: isMe ? -8 : null,
                            left: !isMe ? -8 : null,
                            child: CustomPaint(
                              painter: TailPainter(color: bubbleColor),
                              size: const Size(10, 8),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          if (chatId != null && FeatureFlags.messageReactionsEnabled)
            MessageReactions(
              reactions: reactions,
              currentUid: currentUid,
              chatId: chatId!,
              messageId: message['id'] as String? ?? '',
              isMe: isMe,
              onReact: onReact,
              onRemove: onRemove,
            ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 14),
              child: ReadReceiptIndicator(
                isGroupChat: isGroupChat,
                isMe: isMe,
                isRead: isRead,
                seenBy: seenBy,
              ),
            ),
            ],
            ),
          ),
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

    return Text.rich(TextSpan(children: spans, style: TextStyle(color: baseColor)), textAlign: TextAlign.end);
  }

}

class _SystemBubble extends StatelessWidget {
  static int _sysBuildCount = 0;
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

    _sysBuildCount++;
    DebugConfig.log(DebugConfig.uiInteraction,
        '_SystemBubble build#$_sysBuildCount: action=$action '
        'isRequester=$isRequester showActions=$showActions '
        'hasEn=${contentEn != null}');

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

class _GifBubble extends StatelessWidget {
  static final _buildCounts = <String, int>{};
  final double bubbleMaxWidth;
  final String content;
  final String timeStr;
  final bool isMe;
  final bool isGroupChat;
  final bool isGrouped;
  final bool isLastInGroup;
  final bool showAvatar;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final List<String> seenBy;
  final bool isRead;
  final String? chatId;
  final String currentUid;
  final String messageId;
  final bool isImage;
  final Map<String, dynamic> reactions;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _GifBubble({
    required this.bubbleMaxWidth,
    required this.content,
    required this.timeStr,
    required this.isMe,
    this.isGroupChat = false,
    this.isGrouped = false,
    this.isLastInGroup = true,
    this.showAvatar = true,
    this.senderNickname,
    this.senderAvatarUrl,
    this.seenBy = const [],
    this.isRead = false,
    this.chatId,
    this.currentUid = '',
    this.messageId = '',
    this.isImage = false,
    this.reactions = const {},
    this.onReact,
    this.onRemove,
    this.replyTo,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  static const double _bubbleRadius = 20;
  static const double _tailRadius = 8;
  static const Color _sentColor = Color(0xFF075E54);

  static void _showImageFullScreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, _) => const CircularProgressIndicator(),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white),
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTail = isLastInGroup;
    final sentColor = _sentColor;
    final receivedColor = theme.colorScheme.surfaceContainerHighest;
    final bubbleColor = isMe ? sentColor : receivedColor;

    final bubbleBorderRadius = BorderRadius.only(
      topLeft: const Radius.circular(_bubbleRadius),
      topRight: const Radius.circular(_bubbleRadius),
      bottomLeft: Radius.circular(
          (!isMe && showTail) ? _tailRadius : _bubbleRadius),
      bottomRight: Radius.circular(
          (isMe && showTail) ? _tailRadius : _bubbleRadius),
    );

    final gifMsgId = messageId;
    _buildCounts[gifMsgId] = (_buildCounts[gifMsgId] ?? 0) + 1;
    final gifBuildN = _buildCounts[gifMsgId]!;
    DebugConfig.log(
      DebugConfig.chatBubbleDesign,
      '_GifBubble: id=$gifMsgId isGrouped=$isGrouped '
      'isLastInGroup=$isLastInGroup build#$gifBuildN',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && showAvatar
              && (senderAvatarUrl != null || (isGroupChat && senderNickname != null)))
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: senderAvatarUrl != null
                        ? CachedNetworkImageProvider(senderAvatarUrl!)
                        : null,
                    child: senderAvatarUrl == null && senderNickname != null
                        ? Text(senderNickname![0],
                            style: const TextStyle(fontSize: 18))
                        : null,
                  ),
                  if (isGroupChat && senderNickname != null) ...[
                    const SizedBox(width: 4),
                    Text(senderNickname!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (replyTo != null)
            ReplyPreview(
              replyTo: replyTo!,
              isMe: isMe,
              isGroupChat: isGroupChat,
            ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
            onTap: isImage ? () => _showImageFullScreen(context, content) : null,
            onLongPressStart: (details) async {
              final result = await MessageActionBar.show(
                context: context,
                isOwn: isMe,
                globalPosition: details.globalPosition,
              );
              if (result == 'reply') onReply?.call();
              if (result == 'edit') onEdit?.call();
              if (result == 'delete') onDelete?.call();
            },
            child: Container(
            constraints: BoxConstraints(
                maxWidth: bubbleMaxWidth, maxHeight: 200),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: bubbleBorderRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: content,
              fit: BoxFit.cover,
              placeholder: (_, _) => SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isMe
                          ? Colors.white
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              errorWidget: (_, _, _) => SizedBox(
                width: 200,
                height: 200,
                child: Icon(Icons.broken_image,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          ),
          if (showTail)
            Positioned(
              bottom: 0,
              right: isMe ? -8 : null,
              left: !isMe ? -8 : null,
              child: CustomPaint(
                painter: TailPainter(color: bubbleColor),
                size: const Size(10, 8),
              ),
            ),
        ],
          ),
          if (chatId != null && FeatureFlags.messageReactionsEnabled)
            MessageReactions(
              reactions: reactions,
              currentUid: currentUid,
              chatId: chatId!,
              messageId: messageId,
              isMe: isMe,
              onReact: onReact,
              onRemove: onRemove,
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
                ReadReceiptIndicator(
                  isGroupChat: isGroupChat,
                  isMe: isMe,
                  isRead: isRead,
                  seenBy: seenBy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


