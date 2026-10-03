import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/auth/screens/verify_account_screen.dart';
import 'package:near_me/repositories/auth_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Widget tests για `VerifyAccountScreen` (Form + observer, Γ6).
class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

_MockUser _anonUser() {
  final u = _MockUser();
  when(() => u.uid).thenReturn('anon');
  when(() => u.isAnonymous).thenReturn(true);
  return u;
}

_MockUser _linkedUser() {
  final u = _MockUser();
  when(() => u.uid).thenReturn('me');
  when(() => u.isAnonymous).thenReturn(false);
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
        home: VerifyAccountScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// Scroll-into-view + tap (ListView, κουμπί εκτός 600px viewport στα tests).
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('VerifyAccountScreen anonymous', () {
    testWidgets('φόρμα link + validation errors', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final anon = _anonUser();
      when(() => repo.currentUser).thenReturn(anon);
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Επιβεβαίωσε τον λογαριασμό σου'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'bad');
      await tester.enterText(find.byType(TextFormField).at(1), '123');
      await _tapVisible(tester, find.text('Αποστολή Επαλήθευσης'));
      await tester.pump();
      expect(find.text('Μη έγκυρο email'), findsOneWidget);
      expect(find.text('Ο κωδικός είναι πολύ αδύναμος'), findsOneWidget);
      verifyNever(() => repo.linkWithEmailAndPassword(any(), any()));
      await _settleTimer(tester);
    });

    testWidgets('έγκυρα → link + verification email', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final anon = _anonUser();
      when(() => repo.currentUser).thenReturn(anon);
      when(() => repo.linkWithEmailAndPassword(any(), any()))
          .thenAnswer((_) async {});
      when(() => repo.sendEmailVerification()).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.gr');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw12345');
      await tester.ensureVisible(find.text('Αποστολή Επαλήθευσης'));
      await tester.pump();
      await tester.tap(find.text('Αποστολή Επαλήθευσης'));
      await tester.pump();
      await tester.pump();
      verify(() => repo.linkWithEmailAndPassword('a@b.gr', 'pw12345'))
          .called(1);
      expect(find.text('Email Στάλθηκε'), findsOneWidget);
      await _settleTimer(tester);
    });
  });

  group('VerifyAccountScreen linked', () {
    testWidgets('δείχνει email-sent χωρίς φόρμα', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final linked = _linkedUser();
      when(() => repo.currentUser).thenReturn(linked);
      when(() => repo.sendEmailVerification()).thenAnswer((_) async {});
      when(() => repo.reloadUser()).thenAnswer((_) async {});
      when(() => repo.isEmailVerified).thenReturn(false);
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Email Στάλθηκε'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      // Ο 3s timer τρέχει — ένας κύκλος, χωρίς pumpAndSettle (periodic).
      await tester.pump(const Duration(seconds: 3));
      verify(() => repo.reloadUser()).called(1);
      await _settleTimer(tester);
    });
  });
}
