import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/emoji_only_bubble.dart';
import 'package:near_me/features/chat/widgets/message_bubble/reply_preview.dart';
import 'package:near_me/features/chat/widgets/message_bubble/sender_header.dart';
import 'package:near_me/features/chat/widgets/message_bubble/tail_painter.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );
  }

  group('isOnlyEmoji', () {
    test('empty string → false', () {
      expect(isOnlyEmoji(''), isFalse);
    });

    test('whitespace only → false', () {
      expect(isOnlyEmoji('   '), isFalse);
    });

    test('plain text → false', () {
      expect(isOnlyEmoji('hello world'), isFalse);
    });

    test('single emoji → true', () {
      expect(isOnlyEmoji('😀'), isTrue);
    });

    test('multiple emoji → true', () {
      expect(isOnlyEmoji('😀😂😊'), isTrue);
    });

    test('text mixed with emoji → false', () {
      expect(isOnlyEmoji('hello 😀'), isFalse);
    });

    test('flag (regional indicators) → true', () {
      expect(isOnlyEmoji('🇬🇷'), isTrue);
    });

    test('ZWJ family sequence → true', () {
      expect(isOnlyEmoji('👨‍👩‍👧'), isTrue);
    });
  });

  group('emojiFontSize', () {
    test('one emoji → 55', () {
      expect(emojiFontSize('😀'), 55);
    });

    test('two emoji → 40', () {
      expect(emojiFontSize('😀😁'), 40);
    });

    test('three emoji → 40', () {
      expect(emojiFontSize('😀😁😂'), 40);
    });

    test('four emoji → 30', () {
      expect(emojiFontSize('😀😁😂🤣'), 30);
    });

    test('six emoji → 30', () {
      expect(emojiFontSize('😀😁😂🤣😃😄'), 30);
    });

    test('seven emoji → 28', () {
      expect(emojiFontSize('😀😁😂🤣😃😄😅'), 28);
    });

    test('ten emoji → 28', () {
      expect(emojiFontSize('😀😁😂🤣😃😄😅😆😉😊'), 28);
    });

    test('single flag pair counts as one → 55', () {
      expect(emojiFontSize('🇬🇷'), 55);
    });
  });

  group('EmojiOnlyBubble', () {
    const replyTo = {
      'contentPreview': 'original message',
      'senderNickname': 'Nick',
    };

    testWidgets('renders bare emoji text', (tester) async {
      await tester.pumpWidget(wrap(
        const EmojiOnlyBubble(
          content: '😀',
          bubbleMaxWidth: 300,
          timeStr: '',
          isMe: false,
        ),
      ));
      expect(find.text('😀'), findsOneWidget);
    });

    testWidgets('renders timeStr below emoji', (tester) async {
      await tester.pumpWidget(wrap(
        const EmojiOnlyBubble(
          content: '😀',
          bubbleMaxWidth: 300,
          timeStr: '14:30',
          isMe: false,
        ),
      ));
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('shows quote section when replyTo present', (tester) async {
      await tester.pumpWidget(wrap(
        EmojiOnlyBubble(
          content: '😀',
          bubbleMaxWidth: 300,
          timeStr: '14:30',
          isMe: false,
          replyTo: replyTo,
        ),
      ));
      expect(find.byType(BubbleQuoteSection), findsOneWidget);
      expect(find.text('😀'), findsOneWidget);
    });

    testWidgets('paints tail when isLastInGroup (quote card)', (tester) async {
      await tester.pumpWidget(wrap(
        EmojiOnlyBubble(
          content: '😀',
          bubbleMaxWidth: 300,
          timeStr: '14:30',
          isMe: false,
          replyTo: replyTo,
          isLastInGroup: true,
        ),
      ));
      final tailFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TailPainter,
      );
      expect(tailFinder, findsOneWidget);
    });

    testWidgets('no tail when isLastInGroup=false (quote card)', (tester) async {
      await tester.pumpWidget(wrap(
        EmojiOnlyBubble(
          content: '😀',
          bubbleMaxWidth: 300,
          timeStr: '14:30',
          isMe: false,
          replyTo: replyTo,
          isLastInGroup: false,
        ),
      ));
      final tailFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TailPainter,
      );
      expect(tailFinder, findsNothing);
    });

    testWidgets('shows SenderHeader for other sender with nickname',
        (tester) async {
      await tester.pumpWidget(wrap(
        EmojiOnlyBubble(
          content: '😀',
          bubbleMaxWidth: 300,
          timeStr: '14:30',
          isMe: false,
          showAvatar: true,
          senderNickname: 'Nick',
        ),
      ));
      expect(find.byType(SenderHeader), findsOneWidget);
    });

    testWidgets('hides SenderHeader when isMe', (tester) async {
      await tester.pumpWidget(wrap(
        EmojiOnlyBubble(
          content: '😀',
          bubbleMaxWidth: 300,
          timeStr: '14:30',
          isMe: true,
          senderNickname: 'Nick',
        ),
      ));
      expect(find.byType(SenderHeader), findsNothing);
    });

    testWidgets('renders no reaction icon when chatId is null', (tester) async {
      await tester.pumpWidget(wrap(
        const EmojiOnlyBubble(
          content: '😀',
          bubbleMaxWidth: 300,
          timeStr: '14:30',
          isMe: false,
        ),
      ));
      expect(find.byIcon(Icons.add_reaction_outlined), findsNothing);
    });

    testWidgets('renders reaction icon when chatId is set', (tester) async {
      await tester.pumpWidget(wrap(
        EmojiOnlyBubble(
          content: '😀',
          bubbleMaxWidth: 300,
          timeStr: '14:30',
          isMe: false,
          currentUid: 'me',
          messageId: 'm1',
          chatId: 'chat1',
        ),
      ));
      expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget);
    });
  });
}