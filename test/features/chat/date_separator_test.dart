import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/date_separator.dart';

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
  group('DateSeparator', () {
    testWidgets('renders date label text', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        DateSeparator(date: DateTime(2026, 9, 7)),
      ));
      expect(find.byType(Text), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('renders two dividers', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        DateSeparator(date: DateTime(2026, 1, 1)),
      ));
      expect(find.byType(Divider), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('renders with different date', (tester) async {
      await tester.pumpWidget(wrapLocalized(
        DateSeparator(date: DateTime(2025, 12, 25)),
      ));
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, isNotEmpty);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
