import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/widgets/read_receipt_indicator.dart';

/// Leaf `ReadReceiptIndicator` — asserts σε icons/counts (τα Tooltip messages
/// θέλουν gesture, δεν assertάρονται).
Widget _host(ReadReceiptIndicator child, {String locale = 'el'}) {
  return MaterialApp(
    locale: Locale(locale),
    supportedLocales: const [Locale('el'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  group('ReadReceiptIndicator 1-1', () {
    testWidgets('δικά μου + διαβασμένο → visibility', (tester) async {
      await tester.pumpWidget(_host(const ReadReceiptIndicator(
        isGroupChat: false,
        isMe: true,
        isRead: true,
        seenBy: [],
      )));
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('δικά μου + αδιάβαστο → visibility_outlined', (tester) async {
      await tester.pumpWidget(_host(const ReadReceiptIndicator(
        isGroupChat: false,
        isMe: true,
        isRead: false,
        seenBy: [],
      )));
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('ξένο μήνυμα → τίποτα (shrink)', (tester) async {
      await tester.pumpWidget(_host(const ReadReceiptIndicator(
        isGroupChat: false,
        isMe: false,
        isRead: true,
        seenBy: [],
      )));
      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });
  });

  group('ReadReceiptIndicator group', () {
    testWidgets('κενό seenBy → τίποτα', (tester) async {
      await tester.pumpWidget(_host(const ReadReceiptIndicator(
        isGroupChat: true,
        isMe: true,
        isRead: true,
        seenBy: [],
      )));
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('seenBy → icon + πλήθος', (tester) async {
      await tester.pumpWidget(_host(const ReadReceiptIndicator(
        isGroupChat: true,
        isMe: true,
        isRead: true,
        seenBy: ['u1', 'u2', 'u3'],
      )));
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('en locale → ίδιο layout', (tester) async {
      await tester.pumpWidget(_host(
        const ReadReceiptIndicator(
          isGroupChat: true,
          isMe: true,
          isRead: true,
          seenBy: ['u1'],
        ),
        locale: 'en',
      ));
      expect(find.text('1'), findsOneWidget);
    });
  });
}
