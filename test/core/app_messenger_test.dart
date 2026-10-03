import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_messenger.dart';

/// `AppMessenger` — snackbars + dialogs (χωρίς Firebase).
/// Το showError με ' / ' κάνει split κατά locale (ίδιο με L10n).
Future<void> _pumpScaffold(WidgetTester tester, {String locale = 'el'}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('el'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return FilledButton(
            onPressed: () {},
            child: const Text('host'),
          );
        }),
      ),
    ),
  );
}

/// Flush DebugConfig 1s Timer + snackbar timers (pattern S264/S269).
/// Χωρίς αυτό, το pending Timer ρίχνει το invariant στο dispose.
Future<void> _flushTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('AppMessenger snackbars', () {    testWidgets('showSuccess → κείμενο + εικονίδιο', (tester) async {
      await _pumpScaffold(tester);
      final ctx = tester.element(find.text('host'));
      AppMessenger.showSuccess(ctx, 'Αποθηκεύτηκε');
      await tester.pumpAndSettle();
      expect(find.text('Αποθηκεύτηκε'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await _flushTimers(tester);
    });

    testWidgets('showError bilingual → ελληνικό μέρος', (tester) async {
      await _pumpScaffold(tester);
      final ctx = tester.element(find.text('host'));
      AppMessenger.showError(ctx, 'Αποστολή απέτυχε / Send failed');
      await tester.pumpAndSettle();
      expect(find.text('Αποστολή απέτυχε'), findsOneWidget);
      expect(find.text('Send failed'), findsNothing);
      await _flushTimers(tester);
    });

    testWidgets('showError en locale → αγγλικό μέρος', (tester) async {
      await _pumpScaffold(tester, locale: 'en');
      final ctx = tester.element(find.text('host'));
      AppMessenger.showError(ctx, 'Αποστολή απέτυχε / Send failed');
      await tester.pumpAndSettle();
      expect(find.text('Send failed'), findsOneWidget);
      await _flushTimers(tester);
    });

    testWidgets('showError χωρίς separator → ως έχει', (tester) async {
      await _pumpScaffold(tester);
      final ctx = tester.element(find.text('host'));
      AppMessenger.showError(ctx, 'Σφάλμα συστήματος');
      await tester.pumpAndSettle();
      expect(find.text('Σφάλμα συστήματος'), findsOneWidget);
      await _flushTimers(tester);
    });

    testWidgets('showInfo → κείμενο + info icon', (tester) async {
      await _pumpScaffold(tester);
      final ctx = tester.element(find.text('host'));
      AppMessenger.showInfo(ctx, 'Πληροφορία');
      await tester.pumpAndSettle();
      expect(find.text('Πληροφορία'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      await _flushTimers(tester);
    });
  });

  group('AppMessenger dialogs', () {
    testWidgets('confirm → true/false', (tester) async {
      await _pumpScaffold(tester);
      final ctx = tester.element(find.text('host'));
      final future = AppMessenger.showConfirmDialog(
        ctx,
        title: 'Τίτλος',
        message: 'Σίγουρα;',
        confirmLabel: 'Ναι',
        cancelLabel: 'Όχι',
      );
      await tester.pumpAndSettle();
      expect(find.text('Τίτλος'), findsOneWidget);
      await tester.tap(find.text('Ναι'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);
      await _flushTimers(tester);
    });

    testWidgets('confirm cancel → false', (tester) async {
      await _pumpScaffold(tester);
      final ctx = tester.element(find.text('host'));
      final future = AppMessenger.showConfirmDialog(
        ctx,
        title: 'Τίτλος',
        message: 'Σίγουρα;',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await future, isFalse);
      await _flushTimers(tester);
    });

    testWidgets('info dialog → κλείνει με OK', (tester) async {
      await _pumpScaffold(tester);
      final ctx = tester.element(find.text('host'));
      final future = AppMessenger.showInfoDialog(
        ctx,
        title: 'Πληροφορίες',
        message: 'Λεπτομέρειες',
      );
      await tester.pumpAndSettle();
      expect(find.text('Πληροφορίες'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await future;
      expect(find.text('Πληροφορίες'), findsNothing);
      await _flushTimers(tester);
    });
  });
}
