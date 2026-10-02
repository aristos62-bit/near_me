import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/shared/widgets/chat_recipient_picker.dart';

/// `showChatRecipientPicker` — bottom sheet με snapshot λίστας (χωρίς watch).
ChatCacheTableData _chat({
  required String chatId,
  String? nickname,
  bool group = false,
  String? groupName,
}) =>
    ChatCacheTableData(
      id: 0,
      chatId: chatId,
      otherUid: group ? null : 'other-$chatId',
      otherNickname: nickname,
      isGroupChat: group,
      groupName: groupName,
      unreadCount: 0,
      hasUnread: false,
      participantCount: group ? 3 : 2,
      messageExpiry: 'off',
    );

Future<void> _pumpHost(
  WidgetTester tester,
  Future<String?> Function(BuildContext) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('el'),
      supportedLocales: const [Locale('el'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return FilledButton(
            onPressed: () => open(ctx),
            child: const Text('open'),
          );
        }),
      ),
    ),
  );
}

void main() {
  group('showChatRecipientPicker', () {
    testWidgets('λίστα 1-1 + group → τίτλοι, tap επιστρέφει chatId',
        (tester) async {
      Future<String?>? result;
      await _pumpHost(
          tester, (ctx) => result = showChatRecipientPicker(
                ctx,
                [
                  _chat(chatId: 'c1', nickname: 'Aris'),
                  _chat(chatId: 'g1', group: true, groupName: 'Παρέα'),
                ],
                blurEnabled: false,
              ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Προώθηση σε'), findsOneWidget);
      expect(find.text('Aris'), findsOneWidget);
      expect(find.text('Παρέα'), findsOneWidget);
      await tester.tap(find.text('Παρέα'));
      await tester.pumpAndSettle();
      expect(await result, 'g1');
    });

    testWidgets('κενή λίστα → μόνο τίτλος, χωρίς tiles', (tester) async {
      await _pumpHost(
          tester,
          (ctx) => showChatRecipientPicker(ctx, const [],
              blurEnabled: false));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Προώθηση σε'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('en locale → αγγλικός τίτλος', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('el'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return FilledButton(
                onPressed: () => showChatRecipientPicker(ctx,
                    [_chat(chatId: 'c1', nickname: 'Aris')],
                    blurEnabled: false),
                child: const Text('open'),
              );
            }),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Forward to'), findsOneWidget);
    });

    testWidgets('tap 1-1 → επιστρέφει το chatId του', (tester) async {
      Future<String?>? result;
      await _pumpHost(
          tester, (ctx) => result = showChatRecipientPicker(
                ctx,
                [_chat(chatId: 'c9', nickname: 'Maria')],
                blurEnabled: false,
              ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maria'));
      await tester.pumpAndSettle();
      expect(await result, 'c9');
    });
  });
}
