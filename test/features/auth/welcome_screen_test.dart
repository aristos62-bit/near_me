import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/auth/screens/welcome_screen.dart';
import 'package:near_me/repositories/auth_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Widget tests για `WelcomeScreen` (Form + SPoT dialog, Γ6).
/// Mock AuthRepository + connectivity channel mock.
class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

_MockUser _anonUser() {
  final u = _MockUser();
  when(() => u.uid).thenReturn('anon');
  when(() => u.isAnonymous).thenReturn(true);
  when(() => u.emailVerified).thenReturn(false);
  return u;
}

ProviderContainer _container(_MockAuthRepository repo) => ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> _pump(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        locale: Locale('el'),
        supportedLocales: [Locale('el'), Locale('en')],
        localizationsDelegates: _delegates,
        home: WelcomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// Scroll-into-view + tap (η φόρμα είναι σε SingleChildScrollView και το
/// κουμπί βγαίνει εκτός 600px viewport στα tests).
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('WelcomeScreen render', () {
    testWidgets('login mode: toggle + φόρμα + browse', (tester) async {
      final c = _container(_MockAuthRepository());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Είσοδος'), findsWidgets);
      expect(find.text('Περιήγηση χωρίς λογαριασμό'), findsOneWidget);
      expect(find.text('Ξέχασες τον κωδικό;'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('toggle → register: εμφανίζεται επιβεβαίωση', (tester) async {
      final c = _container(_MockAuthRepository());
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.tap(find.text('Εγγραφή'));
      await tester.pumpAndSettle();
      expect(find.text('Επιβεβαίωση Κωδικού'), findsOneWidget);
      await _settleTimer(tester);
    });
  });

  group('WelcomeScreen validation (SPoT)', () {
    testWidgets('άκυρο email → Μη έγκυρο email', (tester) async {
      final c = _container(_MockAuthRepository());
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.enterText(find.byType(TextFormField).at(0), 'bad');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw12345');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Είσοδος'));
      expect(find.text('Μη έγκυρο email'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('mismatch → Οι κωδικοί δεν ταιριάζουν', (tester) async {
      final c = _container(_MockAuthRepository());
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.tap(find.text('Εγγραφή'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.gr');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw12345');
      await tester.enterText(find.byType(TextFormField).at(2), 'other');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Εγγραφή'));
      expect(find.text('Οι κωδικοί δεν ταιριάζουν'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('offline signIn → snackbar, χωρίς repo call', (tester) async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.gr');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw12345');
      await _tapVisible(
          tester, find.widgetWithText(FilledButton, 'Είσοδος'));
      expect(
          find.text('Δεν υπάρχει σύνδεση στο διαδίκτυο'), findsOneWidget);
      verifyNever(() => repo.signInWithEmailAndPassword(any(), any()));
      await _settleTimer(tester);
    });

    testWidgets('online signIn → repo call με σωστά args', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.signInWithEmailAndPassword(any(), any()))
          .thenAnswer((_) async => _anonUser());
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.gr');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw12345');
      // Μετά το success δείχνει LoadingView (spinner) — όχι pumpAndSettle.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Είσοδος'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Είσοδος'));
      await tester.pump();
      await tester.pump();
      verify(() => repo.signInWithEmailAndPassword('a@b.gr', 'pw12345'))
          .called(1);
      await _settleTimer(tester);
    });
  });

  group('WelcomeScreen forgot-password dialog (SPoT)', () {
    testWidgets('ανοίγει με prefill + άκυρο μένει ανοιχτό', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final c = _container(_MockAuthRepository());
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.gr');
      await _tapVisible(tester, find.text('Ξέχασες τον κωδικό;'));
      expect(find.text('Ξέχασες τον κωδικό;'), findsNWidgets(2));
      final dialogField = find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField));
      expect(dialogField, findsOneWidget);
      await tester.enterText(dialogField, 'bad');
      await tester.tap(find.widgetWithText(FilledButton, 'Αποστολή'));
      await tester.pumpAndSettle();
      expect(find.text('Μη έγκυρο email'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('έγκυρο → pop + sendPasswordReset', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.sendPasswordResetEmail(any()))
          .thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pump(tester, c);
      await _tapVisible(tester, find.text('Ξέχασες τον κωδικό;'));
      final dialogField = find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(dialogField, 'a@b.gr');
      await tester.tap(find.widgetWithText(FilledButton, 'Αποστολή'));
      await tester.pumpAndSettle();
      verify(() => repo.sendPasswordResetEmail('a@b.gr')).called(1);
      expect(find.text('Στάλθηκε email επαναφοράς'), findsOneWidget);
      await _settleTimer(tester);
    });
  });
}
