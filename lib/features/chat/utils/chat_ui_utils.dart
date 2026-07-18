import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/debug/debug_config.dart';

enum RenderItemType { message, dateSeparator }

class RenderItem {
  final RenderItemType type;
  final Map<String, dynamic>? message;
  final DateTime? date;
  final bool isGrouped;
  final bool isLastInGroup;
  final bool showAvatar;

  const RenderItem._({
    required this.type,
    this.message,
    this.date,
    this.isGrouped = false,
    this.isLastInGroup = false,
    this.showAvatar = false,
  });

  factory RenderItem.message({
    required Map<String, dynamic> message,
    required bool isGrouped,
    required bool isLastInGroup,
    required bool showAvatar,
  }) =>
      RenderItem._(
        type: RenderItemType.message,
        message: message,
        isGrouped: isGrouped,
        isLastInGroup: isLastInGroup,
        showAvatar: showAvatar,
      );

  factory RenderItem.dateSeparator(DateTime date) =>
      RenderItem._(type: RenderItemType.dateSeparator, date: date);
}

class ChatGroupingCalculator {
  ChatGroupingCalculator._();

  static List<RenderItem>? _cachedResult;
  static List<Map<String, dynamic>>? _cachedMessages;

  static List<RenderItem> calculate(
      List<Map<String, dynamic>> messages, String currentUid) {
    if (messages.isEmpty) return [];
    if (identical(_cachedMessages, messages)) return _cachedResult!;

    final stopwatch = Stopwatch()..start();
    final items = _buildItems(messages);
    stopwatch.stop();

    _cachedMessages = messages;
    _cachedResult = items;

    DebugConfig.log(
      DebugConfig.chatBubbleDesign,
      'ChatGroupingCalculator: ${items.length} items from ${messages.length} msgs '
      'in ${stopwatch.elapsedMicroseconds}us',
    );
    return items;
  }

  static List<RenderItem> _buildItems(List<Map<String, dynamic>> messages) {
    final groups = <_MessageGroup>[];
    _MessageGroup? current;

    for (final msg in messages) {
      final senderId = msg['senderId'] as String? ?? '';
      final type = msg['type'] as String? ?? 'text';
      final rawTs = msg['timestamp'];
      final ts = rawTs is Timestamp ? rawTs.toDate() : null;

      final isNewGroup = current == null ||
          senderId != current.senderId ||
          type == 'system' ||
          current.type == 'system' ||
          (ts != null &&
              current.lastTimestamp != null &&
              ts.difference(current.lastTimestamp!).inMinutes > 5);

      if (isNewGroup) {
        current = _MessageGroup(
          senderId: senderId,
          type: type,
          messages: [],
          lastTimestamp: ts,
        );
        groups.add(current);
      }

      current.messages.add(msg);
      if (ts != null) current.lastTimestamp = ts;
    }

    final items = <RenderItem>[];
    DateTime? lastDate;

    for (final group in groups) {
      for (int i = 0; i < group.messages.length; i++) {
        final msg = group.messages[i];
        final rawTs = msg['timestamp'];
        final ts = rawTs is Timestamp ? rawTs.toDate() : null;

        if (ts != null) {
          final msgDate = DateTime(ts.year, ts.month, ts.day);
          if (lastDate == null || msgDate != lastDate) {
            items.add(RenderItem.dateSeparator(ts));
            lastDate = msgDate;
          }
        }

        final isFirstInGroup = i == 0;
        final isLastInGroup = i == group.messages.length - 1;
        final isGrouped = !isFirstInGroup;

        items.add(RenderItem.message(
          message: msg,
          isGrouped: isGrouped,
          isLastInGroup: isLastInGroup,
          showAvatar: !isGrouped || isLastInGroup,
        ));
      }
    }

    return items;
  }
}

class _MessageGroup {
  final String senderId;
  final String type;
  final List<Map<String, dynamic>> messages;
  DateTime? lastTimestamp;

  _MessageGroup({
    required this.senderId,
    required this.type,
    required this.messages,
    this.lastTimestamp,
  });
}
