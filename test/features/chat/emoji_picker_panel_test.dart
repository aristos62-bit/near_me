import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/emoji_picker_panel.dart';

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

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('EmojiPickerPanel', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        EmojiPickerPanel(onEmojiSelected: (category, emoji) {}),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await _settleTimer(tester);
    });

    testWidgets('does not invoke callback on build', (tester) async {
      var called = false;
      await tester.pumpWidget(wrapLocalized(
        EmojiPickerPanel(
          onEmojiSelected: (category, emoji) => called = true,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(called, isFalse);
      await _settleTimer(tester);
    });
  });
}
