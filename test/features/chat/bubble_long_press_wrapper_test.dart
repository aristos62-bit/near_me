import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/message_bubble/bubble_long_press_wrapper.dart';

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
  group('BubbleLongPressWrapper', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const BubbleLongPressWrapper(
          isMe: true,
          child: Text('hello'),
        ),
      ));
      expect(find.text('hello'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('child is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapLocalized(
        BubbleLongPressWrapper(
          isMe: true,
          child: GestureDetector(
            onTap: () => tapped = true,
            child: const Text('tap me'),
          ),
        ),
      ));
      await tester.tap(find.text('tap me'));
      expect(tapped, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('long press triggers action bar', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        const BubbleLongPressWrapper(
          isMe: true,
          child: Text('long press me'),
        ),
      ));
      await tester.longPress(find.text('long press me'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
