import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/message_bubble/sender_header.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('SenderHeader', () {
    testWidgets('shows initial letter when no avatar URL', (tester) async {
      await tester.pumpWidget(wrap(
        const SenderHeader(
          senderAvatarUrl: null,
          senderNickname: 'Nikos',
          isGroupChat: false,
        ),
      ));
      expect(find.text('N'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('shows nickname in group chat', (tester) async {
      await tester.pumpWidget(wrap(
        const SenderHeader(
          senderAvatarUrl: null,
          senderNickname: 'Maria',
          isGroupChat: true,
        ),
      ));
      expect(find.text('Maria'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('hides nickname in non-group chat', (tester) async {
      await tester.pumpWidget(wrap(
        const SenderHeader(
          senderAvatarUrl: null,
          senderNickname: 'Maria',
          isGroupChat: false,
        ),
      ));
      expect(find.text('Maria'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('hides nickname when senderNickname is null', (tester) async {
      await tester.pumpWidget(wrap(
        const SenderHeader(
          senderAvatarUrl: null,
          senderNickname: null,
          isGroupChat: true,
        ),
      ));
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('always renders CircleAvatar', (tester) async {
      await tester.pumpWidget(wrap(
        const SenderHeader(
          senderAvatarUrl: null,
          senderNickname: 'Test',
          isGroupChat: true,
        ),
      ));
      expect(find.byType(CircleAvatar), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
