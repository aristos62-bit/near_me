import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/message_action_bar.dart';

Widget wrapLocalized(Widget child) {
  return MaterialApp(
    locale: const Locale('el'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('el'), Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('MessageActionBar.show', () {
    testWidgets('returns a Future', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        Builder(builder: (context) {
          return GestureDetector(
            onTap: () {
              MessageActionBar.show(
                context: context,
                isOwn: true,
                globalPosition: const Offset(100, 100),
              );
            },
            child: const Text('tap'),
          );
        }),
      ));
      await tester.tap(find.text('tap'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('shows popup menu with items for own message', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        Builder(builder: (context) {
          return GestureDetector(
            onTap: () {
              MessageActionBar.show(
                context: context,
                isOwn: true,
                globalPosition: const Offset(100, 100),
              );
            },
            child: const Text('tap'),
          );
        }),
      ));
      await tester.tap(find.text('tap'));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsWidgets);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
