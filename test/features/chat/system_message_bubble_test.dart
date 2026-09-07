import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/message_bubble/system_message_bubble.dart';

Widget wrapLocalized(Widget child) {
  return MaterialApp(
    locale: const Locale('el'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('el'), Locale('en')],
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('SystemMessageBubble', () {
    testWidgets('displays content text', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const SystemMessageBubble(
          content: 'Nikos created the group',
          timeStr: '10:00',
        ),
      ));
      expect(find.text('Nikos created the group'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('displays timeStr', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const SystemMessageBubble(
          content: 'Test',
          timeStr: '14:30',
        ),
      ));
      expect(find.text('14:30'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('hides timeStr when empty', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const SystemMessageBubble(
          content: 'Test',
          timeStr: '',
        ),
      ));
      expect(find.text('14:30'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('shows delete_request buttons when conditions met', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const SystemMessageBubble(
          content: 'Delete request',
          timeStr: '10:00',
          action: 'delete_request',
          isRequester: false,
          hasPendingDelete: true,
          chatId: 'chat1',
        ),
      ));
      expect(find.text('Ναι'), findsOneWidget);
      expect(find.text('Όχι'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('hides delete_request buttons when isRequester', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const SystemMessageBubble(
          content: 'Delete request',
          timeStr: '10:00',
          action: 'delete_request',
          isRequester: true,
          hasPendingDelete: true,
          chatId: 'chat1',
        ),
      ));
      expect(find.byType(FilledButton), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('hides action buttons when no chatId', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const SystemMessageBubble(
          content: 'Delete request',
          timeStr: '10:00',
          action: 'delete_request',
          isRequester: false,
          hasPendingDelete: true,
        ),
      ));
      expect(find.byType(FilledButton), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('onApproveDelete callback fires on tap', (tester) async {
      var called = false;
      await tester.pumpWidget(wrapLocalized(
        SystemMessageBubble(
          content: 'Delete request',
          timeStr: '10:00',
          action: 'delete_request',
          isRequester: false,
          hasPendingDelete: true,
          chatId: 'chat1',
          onApproveDelete: (_) async { called = true; },
        ),
      ));
      await tester.tap(find.byType(FilledButton));
      expect(called, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('onRejectDelete callback fires on tap', (tester) async {
      var called = false;
      await tester.pumpWidget(wrapLocalized(
        SystemMessageBubble(
          content: 'Delete request',
          timeStr: '10:00',
          action: 'delete_request',
          isRequester: false,
          hasPendingDelete: true,
          chatId: 'chat1',
          onRejectDelete: (_) async { called = true; },
        ),
      ));
      await tester.tap(find.byType(OutlinedButton));
      expect(called, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('shows delete_rejected action buttons when hasDeleteResponseNeeded', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const SystemMessageBubble(
          content: 'Delete rejected',
          timeStr: '10:00',
          action: 'delete_rejected',
          isRequester: false,
          hasDeleteResponseNeeded: true,
          chatId: 'chat1',
        ),
      ));
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('no action buttons when action is null', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const SystemMessageBubble(
          content: 'System message',
          timeStr: '10:00',
          chatId: 'chat1',
        ),
      ));
      expect(find.byType(FilledButton), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}