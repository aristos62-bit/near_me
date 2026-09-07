import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/utils/chat_ui_utils.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Map<String, dynamic> _msg(
  String senderId, {
  String type = 'text',
  DateTime? ts,
}) {
  return {
    'senderId': senderId,
    'type': type,
    if (ts != null) 'timestamp': Timestamp.fromDate(ts),
  };
}

void main() {
  group('RenderItem', () {
    testWidgets('message factory sets fields correctly', (tester) async {
      final msg = _msg('u1');
      final item = RenderItem.message(
        message: msg,
        isGrouped: true,
        isLastInGroup: false,
        showAvatar: true,
      );
      expect(item.type, RenderItemType.message);
      expect(item.message, msg);
      expect(item.isGrouped, true);
      expect(item.isLastInGroup, false);
      expect(item.showAvatar, true);
      expect(item.date, isNull);
      await _settle(tester);
    });

    testWidgets('dateSeparator factory sets date and type', (tester) async {
      final d = DateTime(2026, 9, 7);
      final item = RenderItem.dateSeparator(d);
      expect(item.type, RenderItemType.dateSeparator);
      expect(item.date, d);
      expect(item.message, isNull);
      await _settle(tester);
    });
  });

  group('ChatGroupingCalculator.calculate', () {
    testWidgets('returns empty list for empty messages', (tester) async {
      final result = ChatGroupingCalculator.calculate('c1', [], 'me');
      expect(result, isEmpty);
      await _settle(tester);
    });

    testWidgets('single message produces one message item', (tester) async {
      final now = DateTime(2026, 9, 7, 10, 0);
      final msgs = [_msg('u1', ts: now)];
      final result = ChatGroupingCalculator.calculate('c2', msgs, 'me');
      expect(result.length, 2);
      expect(result[0].type, RenderItemType.dateSeparator);
      expect(result[1].type, RenderItemType.message);
      expect(result[1].isGrouped, false);
      expect(result[1].isLastInGroup, true);
      expect(result[1].showAvatar, true);
      await _settle(tester);
    });

    testWidgets('two messages from same sender within 5 min are grouped',
        (tester) async {
      final t1 = DateTime(2026, 9, 7, 10, 0);
      final t2 = DateTime(2026, 9, 7, 10, 3);
      final msgs = [_msg('u1', ts: t1), _msg('u1', ts: t2)];
      final result = ChatGroupingCalculator.calculate('c3', msgs, 'me');
      final messageItems =
          result.where((i) => i.type == RenderItemType.message).toList();
      expect(messageItems.length, 2);
      expect(messageItems[0].isGrouped, false);
      expect(messageItems[0].showAvatar, true);
      expect(messageItems[1].isGrouped, true);
      expect(messageItems[1].isLastInGroup, true);
      expect(messageItems[1].showAvatar, true);
      await _settle(tester);
    });

    testWidgets('messages from different senders start new groups',
        (tester) async {
      final t1 = DateTime(2026, 9, 7, 10, 0);
      final t2 = DateTime(2026, 9, 7, 10, 1);
      final msgs = [_msg('u1', ts: t1), _msg('u2', ts: t2)];
      final result = ChatGroupingCalculator.calculate('c4', msgs, 'me');
      final messageItems =
          result.where((i) => i.type == RenderItemType.message).toList();
      expect(messageItems.length, 2);
      expect(messageItems[0].isGrouped, false);
      expect(messageItems[1].isGrouped, false);
      await _settle(tester);
    });

    testWidgets('gap > 5 min starts new group', (tester) async {
      final t1 = DateTime(2026, 9, 7, 10, 0);
      final t2 = DateTime(2026, 9, 7, 10, 6);
      final msgs = [_msg('u1', ts: t1), _msg('u1', ts: t2)];
      final result = ChatGroupingCalculator.calculate('c5', msgs, 'me');
      final messageItems =
          result.where((i) => i.type == RenderItemType.message).toList();
      expect(messageItems[0].isGrouped, false);
      expect(messageItems[1].isGrouped, false);
      await _settle(tester);
    });

    testWidgets('system message always starts new group', (tester) async {
      final t1 = DateTime(2026, 9, 7, 10, 0);
      final t2 = DateTime(2026, 9, 7, 10, 1);
      final msgs = [
        _msg('u1', ts: t1),
        _msg('sys', type: 'system', ts: t2),
      ];
      final result = ChatGroupingCalculator.calculate('c6', msgs, 'me');
      final messageItems =
          result.where((i) => i.type == RenderItemType.message).toList();
      expect(messageItems[0].isGrouped, false);
      expect(messageItems[1].isGrouped, false);
      await _settle(tester);
    });

    testWidgets('date separator inserted on new day', (tester) async {
      final t1 = DateTime(2026, 9, 6, 23, 59);
      final t2 = DateTime(2026, 9, 7, 0, 1);
      final msgs = [_msg('u1', ts: t1), _msg('u1', ts: t2)];
      final result = ChatGroupingCalculator.calculate('c7', msgs, 'me');
      final dateItems =
          result.where((i) => i.type == RenderItemType.dateSeparator).toList();
      expect(dateItems.length, 2);
      await _settle(tester);
    });

    testWidgets('identity cache: same list reference returns cached result',
        (tester) async {
      final msgs = [_msg('u1', ts: DateTime(2026, 9, 7, 10, 0))];
      final r1 = ChatGroupingCalculator.calculate('c8', msgs, 'me');
      final r2 = ChatGroupingCalculator.calculate('c8', msgs, 'me');
      expect(identical(r1, r2), isTrue);
      await _settle(tester);
    });

    testWidgets('different list with same data recalculates', (tester) async {
      final msgs1 = [_msg('u1', ts: DateTime(2026, 9, 7, 10, 0))];
      final msgs2 = [_msg('u1', ts: DateTime(2026, 9, 7, 10, 0))];
      final r1 = ChatGroupingCalculator.calculate('c9', msgs1, 'me');
      final r2 = ChatGroupingCalculator.calculate('c9', msgs2, 'me');
      expect(identical(r1, r2), isFalse);
      expect(r1.length, r2.length);
      await _settle(tester);
    });

    testWidgets('message without timestamp is handled', (tester) async {
      final msgs = [
        {'senderId': 'u1', 'type': 'text'},
      ];
      final result = ChatGroupingCalculator.calculate('c10', msgs, 'me');
      final messageItems =
          result.where((i) => i.type == RenderItemType.message).toList();
      expect(messageItems.length, 1);
      expect(messageItems[0].isGrouped, false);
      await _settle(tester);
    });

    testWidgets('message without senderId defaults to empty string',
        (tester) async {
      final t1 = DateTime(2026, 9, 7, 10, 0);
      final msgs = [
        {'type': 'text', 'timestamp': Timestamp.fromDate(t1)},
      ];
      final result = ChatGroupingCalculator.calculate('c11', msgs, 'me');
      expect(result.length, 2);
      await _settle(tester);
    });

    testWidgets('mixed system + text messages', (tester) async {
      final t1 = DateTime(2026, 9, 7, 10, 0);
      final t2 = DateTime(2026, 9, 7, 10, 1);
      final t3 = DateTime(2026, 9, 7, 10, 2);
      final msgs = [
        _msg('u1', ts: t1),
        _msg('sys', type: 'system', ts: t2),
        _msg('u1', ts: t3),
      ];
      final result = ChatGroupingCalculator.calculate('c12', msgs, 'me');
      final messageItems =
          result.where((i) => i.type == RenderItemType.message).toList();
      expect(messageItems.length, 3);
      expect(messageItems[0].isGrouped, false);
      expect(messageItems[1].isGrouped, false);
      expect(messageItems[2].isGrouped, false);
      await _settle(tester);
    });

    testWidgets('three messages from same sender: grouped correctly',
        (tester) async {
      final t1 = DateTime(2026, 9, 7, 10, 0);
      final t2 = DateTime(2026, 9, 7, 10, 1);
      final t3 = DateTime(2026, 9, 7, 10, 2);
      final msgs = [
        _msg('u1', ts: t1),
        _msg('u1', ts: t2),
        _msg('u1', ts: t3),
      ];
      final result = ChatGroupingCalculator.calculate('c13', msgs, 'me');
      final messageItems =
          result.where((i) => i.type == RenderItemType.message).toList();
      expect(messageItems[0].isGrouped, false);
      expect(messageItems[0].showAvatar, true);
      expect(messageItems[1].isGrouped, true);
      expect(messageItems[1].showAvatar, false);
      expect(messageItems[2].isGrouped, true);
      expect(messageItems[2].isLastInGroup, true);
      expect(messageItems[2].showAvatar, true);
      await _settle(tester);
    });
  });
}
