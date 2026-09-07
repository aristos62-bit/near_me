import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/message_reactions.dart';

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

  Widget sheetHost({
    required void Function(BuildContext) onOpen,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onOpen(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  group('ReactionTriggerIcon', () {
    testWidgets('renders nothing when chatId is null', (tester) async {
      await tester.pumpWidget(wrap(
        const ReactionTriggerIcon(
          chatId: null,
          messageId: 'm1',
          reactions: <String, dynamic>{},
          currentUid: 'me',
          isMe: false,
        ),
      ));
      expect(find.byIcon(Icons.add_reaction_outlined), findsNothing);
    });

    testWidgets('renders add-reaction icon without my reaction', (tester) async {
      await tester.pumpWidget(wrap(
        const ReactionTriggerIcon(
          chatId: 'chat1',
          messageId: 'm1',
          reactions: <String, dynamic>{},
          currentUid: 'me',
          isMe: false,
        ),
      ));
      expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget);
    });

    testWidgets('renders my emoji when I reacted', (tester) async {
      await tester.pumpWidget(wrap(
        const ReactionTriggerIcon(
          chatId: 'chat1',
          messageId: 'm1',
          reactions: <String, dynamic>{'me': '❤️'},
          currentUid: 'me',
          isMe: false,
        ),
      ));
      expect(find.text('❤️'), findsOneWidget);
      expect(find.byIcon(Icons.add_reaction_outlined), findsNothing);
    });

    testWidgets('groups other reactions with counts, excludes mine',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ReactionTriggerIcon(
          chatId: 'chat1',
          messageId: 'm1',
          reactions: <String, dynamic>{
            'me': '❤️',
            'a': '😂',
            'b': '😂',
            'c': '😮',
          },
          currentUid: 'me',
          isMe: false,
        ),
      ));
      expect(find.text('😂 2'), findsOneWidget);
      expect(find.text('😮'), findsOneWidget);
      expect(find.textContaining('❤️'), findsOneWidget);
    });

    testWidgets('tap with my reaction calls onRemove with messageId',
        (tester) async {
      final removed = <String>[];
      await tester.pumpWidget(wrap(
        ReactionTriggerIcon(
          chatId: 'chat1',
          messageId: 'm1',
          reactions: const <String, dynamic>{'me': '❤️'},
          currentUid: 'me',
          isMe: false,
          onRemove: (id) async => removed.add(id),
        ),
      ));
      await tester.tap(find.byType(ReactionTriggerIcon));
      expect(removed, ['m1']);
    });

    testWidgets('tap without my reaction does nothing', (tester) async {
      var onRemoveCalled = false;
      var onReactCalled = false;
      await tester.pumpWidget(wrap(
        ReactionTriggerIcon(
          chatId: 'chat1',
          messageId: 'm1',
          reactions: const <String, dynamic>{},
          currentUid: 'me',
          isMe: false,
          onRemove: (id) async => onRemoveCalled = true,
          onReact: (id, emoji) async => onReactCalled = true,
        ),
      ));
      await tester.tap(find.byIcon(Icons.add_reaction_outlined));
      await tester.pump();
      expect(onRemoveCalled, isFalse);
      expect(onReactCalled, isFalse);
      expect(find.text('😂'), findsNothing);
    });

    testWidgets('long-press opens the reaction picker sheet', (tester) async {
      await tester.pumpWidget(wrap(
        const ReactionTriggerIcon(
          chatId: 'chat1',
          messageId: 'm1',
          reactions: <String, dynamic>{},
          currentUid: 'me',
          isMe: false,
        ),
      ));
      await tester.longPress(find.byIcon(Icons.add_reaction_outlined));
      await tester.pumpAndSettle();
      expect(find.text('😂'), findsOneWidget);
      expect(find.text('👏'), findsOneWidget);
    });
  });

  group('showReactionPicker', () {
    testWidgets('renders 6 preset emojis and the full picker add button',
        (tester) async {
      await tester.pumpWidget(sheetHost(
        onOpen: (context) => showReactionPicker(
          context: context,
          messageId: 'm1',
          onReact: (_, _) async {},
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final emoji in ['😂', '😮', '😢', '😠', '❤️', '👏']) {
        expect(find.text(emoji), findsOneWidget);
      }
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('tapping a preset calls onReact and closes the sheet',
        (tester) async {
      final reacted = <List<String>>[];
      await tester.pumpWidget(sheetHost(
        onOpen: (context) => showReactionPicker(
          context: context,
          messageId: 'm1',
          onReact: (id, emoji) async {
            reacted.add([id, emoji]);
          },
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😂'));
      await tester.pumpAndSettle();
      expect(reacted, [
        ['m1', '😂']
      ]);
    });

    testWidgets('tapping my current emoji calls onRemove instead of onReact',
        (tester) async {
      final removed = <String>[];
      var onReactCalled = false;
      await tester.pumpWidget(sheetHost(
        onOpen: (context) => showReactionPicker(
          context: context,
          messageId: 'm1',
          currentEmoji: '😂',
          onReact: (_, _) async => onReactCalled = true,
          onRemove: (id) async => removed.add(id),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😂'));
      await tester.pumpAndSettle();
      expect(removed, ['m1']);
      expect(onReactCalled, isFalse);
    });

    testWidgets('dismissing the sheet returns null and fires no callback',
        (tester) async {
      var onReactCalled = false;
      var onRemoveCalled = false;
      await tester.pumpWidget(sheetHost(
        onOpen: (context) => showReactionPicker(
          context: context,
          messageId: 'm1',
          onReact: (_, _) async => onReactCalled = true,
          onRemove: (id) async => onRemoveCalled = true,
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(onReactCalled, isFalse);
      expect(onRemoveCalled, isFalse);
    });
  });
}