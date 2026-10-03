import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/settings/screens/delete_account_screen.dart';
import 'package:near_me/repositories/auth_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Widget tests για `DeleteAccountScreen` (312 γρ., πλήρης ανάγνωση).
/// Real notifier + MockAuthRepository + connectivity mock.
/// GoRouter harness για το success-go('/auth').
class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

_MockUser _verifiedUser() {
  final u = _MockUser();
  when(() => u.uid).thenReturn('me');
  when(() => u.isAnonymous).thenReturn(false);
  when(() => u.emailVerified).thenReturn(true);
  when(() => u.phoneNumber).thenReturn(null);
  return u;
}

_MockUser _anonUser() {
  final u = _MockUser();
  when(() => u.uid).thenReturn('anon');
  when(() => u.isAnonymous).thenReturn(true);
  when(() => u.emailVerified).thenReturn(false);
  when(() => u.phoneNumber).thenReturn(null);
  return u;
}

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required User? user,
  required _MockAuthRepository repo,
  GoRouter? router,
}) async {
  final c = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      authRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  if (router != null) {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('el'),
          supportedLocales: const [Locale('el'), Locale('en')],
          localizationsDelegates: _delegates,
        ),
      ),
    );
  } else {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('el'),
          supportedLocales: [Locale('el'), Locale('en')],
          localizationsDelegates: _delegates,
          home: DeleteAccountScreen(),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
  return c;
}

GoRouter _router() => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('home'))),
        GoRoute(
            path: '/auth',
            builder: (_, _) => const Scaffold(body: Text('auth-page'))),
        GoRoute(
            path: '/delete',
            builder: (_, _) => const DeleteAccountScreen()),
      ],
    );

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _typeDelete(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'delete');
  await tester.pumpAndSettle();
}

/// Scroll-into-view + tap στο κουμπί διαγραφής (κάτω από το fold σε 600px).
Future<void> _tapDeleteButton(WidgetTester tester) async {
  final btn = find.widgetWithText(FilledButton, 'Διαγραφή Λογαριασμού');
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  group('DeleteAccountScreen πύλη DELETE', () {
    testWidgets('anonymous → προσωρινή οθόνη', (tester) async {
      await _pump(tester, user: _anonUser(), repo: _MockAuthRepository());
      expect(find.text('Ο λογαριασμός είναι προσωρινός'), findsOneWidget);
      expect(find.text('Επαλήθευση Λογαριασμού'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('null user → προσωρινή οθόνη', (tester) async {
      await _pump(tester, user: null, repo: _MockAuthRepository());
      expect(find.text('Ο λογαριασμός είναι προσωρινός'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('χωρίς DELETE → κουμπί disabled', (tester) async {
      await _pump(tester, user: _verifiedUser(), repo: _MockAuthRepository());
      final btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Διαγραφή Λογαριασμού'));
      expect(btn.onPressed, isNull);
      await _settleTimer(tester);
    });

    testWidgets('λάθος κείμενο → disabled· σωστό (case-insensitive) → enabled',
        (tester) async {
      await _pump(tester, user: _verifiedUser(), repo: _MockAuthRepository());
      await tester.enterText(find.byType(TextField), 'delet');
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Διαγραφή Λογαριασμού'))
              .onPressed,
          isNull);
      await _typeDelete(tester);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Διαγραφή Λογαριασμού'))
              .onPressed,
          isNotNull);
      await _settleTimer(tester);
    });
  });

  group('DeleteAccountScreen ροή διαγραφής', () {
    testWidgets('confirm-cancel → μένει, χωρίς repo call', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      await _pump(tester, user: _verifiedUser(), repo: repo);
      await _typeDelete(tester);
      await _tapDeleteButton(tester);
      await tester.tap(find.text('Ακύρωση'));
      await tester.pumpAndSettle();
      verifyNever(() => repo.deleteAccount());
      expect(find.text('Διαγραφή Λογαριασμού'), findsWidgets);
      await _settleTimer(tester);
    });

    testWidgets('confirm → loading → success → go(/auth)', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.deleteAccount()).thenAnswer((_) async {});
      final router = _router();
      await _pump(tester, user: _verifiedUser(), repo: repo, router: router);
      router.go('/delete');
      await tester.pumpAndSettle();
      await _typeDelete(tester);
      await _tapDeleteButton(tester);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Διαγραφή')));
      await tester.pumpAndSettle();
      verify(() => repo.deleteAccount()).called(1);
      expect(find.text('auth-page'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('failure → error snackbar', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.deleteAccount()).thenThrow(Exception('boom'));
      await _pump(tester, user: _verifiedUser(), repo: repo);
      await _typeDelete(tester);
      await _tapDeleteButton(tester);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Διαγραφή')));
      await tester.pumpAndSettle();
      expect(find.text('Σφάλμα διαγραφής λογαριασμού. Δοκίμασε ξανά.'),
          findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('needsReauth → dialog με email', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final user = _verifiedUser();
      when(() => user.email).thenReturn('a@b.gr');
      final repo = _MockAuthRepository();
      when(() => repo.currentUser).thenReturn(user);
      when(() => repo.deleteAccount()).thenThrow(
          FirebaseAuthException(code: 'requires-recent-login'));
      await _pump(tester, user: user, repo: repo);
      await _typeDelete(tester);
      await _tapDeleteButton(tester);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Διαγραφή')));
      await tester.pumpAndSettle();
      expect(find.text('Επιβεβαίωση ταυτότητας'), findsOneWidget);
      expect(find.text('a@b.gr'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('reauth κενό password → no-op· γεμάτο → deleteWithPassword',
        (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final user = _verifiedUser();
      when(() => user.email).thenReturn('a@b.gr');
      final repo = _MockAuthRepository();
      when(() => repo.currentUser).thenReturn(user);
      when(() => repo.deleteAccount()).thenThrow(
          FirebaseAuthException(code: 'requires-recent-login'));
      when(() => repo.deleteAccount(password: 'pw'))
          .thenAnswer((_) async {});
      final router = _router();
      await _pump(tester, user: user, repo: repo, router: router);
      router.go('/delete');
      await tester.pumpAndSettle();
      await _typeDelete(tester);
      await _tapDeleteButton(tester);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Διαγραφή')));
      await tester.pumpAndSettle();
      // Κενό password → tap Επιβεβαίωση δεν κάνει τίποτα.
      await tester.tap(find.widgetWithText(FilledButton, 'Επιβεβαίωση'));
      await tester.pumpAndSettle();
      verifyNever(() => repo.deleteAccount(password: 'pw'));
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField)),
          'pw');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Επιβεβαίωση'));
      await tester.pumpAndSettle();
      verify(() => repo.deleteAccount(password: 'pw')).called(1);
      await _settleTimer(tester);
    });
  });
}
