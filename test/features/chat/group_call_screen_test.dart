import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/screens/group_call_screen.dart';

Widget wrapLocalized(String locale) {
  return MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('el'), Locale('en')],
    home: const GroupCallScreen(chatId: 'chat_123', groupName: 'Παρέα'),
  );
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('GroupCallScreen', () {
    testWidgets('shows Greek labels when locale is el', (tester) async {
      await tester.pumpWidget(wrapLocalized('el'));
      expect(find.text('Οι κλήσεις δεν είναι διαθέσιμες'), findsOneWidget);
      expect(
        find.text('Αυτή η λειτουργία θα είναι διαθέσιμη σε μελλοντική ενημέρωση'),
        findsOneWidget,
      );
      await _settleTimer(tester);
    });

    testWidgets('shows English labels when locale is en', (tester) async {
      await tester.pumpWidget(wrapLocalized('en'));
      expect(find.text('Calls not available'), findsOneWidget);
      expect(
        find.text('This feature will be available in a future update'),
        findsOneWidget,
      );
      await _settleTimer(tester);
    });

    testWidgets('uses groupName as AppBar title', (tester) async {
      await tester.pumpWidget(wrapLocalized('el'));
      expect(find.widgetWithText(AppBar, 'Παρέα'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('falls back to chatId when groupName is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('el'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('el'), Locale('en')],
          home: const GroupCallScreen(chatId: 'chat_999'),
        ),
      );
      expect(find.widgetWithText(AppBar, 'chat_999'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('renders the unavailable-call icon', (tester) async {
      await tester.pumpWidget(wrapLocalized('el'));
      expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
      await _settleTimer(tester);
    });
  });
}