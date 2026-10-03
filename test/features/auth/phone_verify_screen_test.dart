import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/auth/screens/phone_verify_screen.dart';
import 'package:near_me/repositories/auth_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Widget tests για `PhoneVerifyScreen` (normalize + gate, Γ6).
class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

_MockUser _anonUser() {
  final u = _MockUser();
  when(() => u.uid).thenReturn('anon');
  when(() => u.isAnonymous).thenReturn(true);
  when(() => u.emailVerified).thenReturn(false);
  when(() => u.phoneNumber).thenReturn(null);
  return u;
}

_MockUser _verifiedUser() {
  final u = _MockUser();
  when(() => u.uid).thenReturn('me');
  when(() => u.isAnonymous).thenReturn(false);
  when(() => u.emailVerified).thenReturn(true);
  when(() => u.phoneNumber).thenReturn(null);
  return u;
}

ProviderContainer _container(_MockAuthRepository repo, User? user) =>
    ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(user)),
      ],
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
        home: PhoneVerifyScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('PhoneVerifyScreen gate', () {
    testWidgets('anonymous → not available + email CTA', (tester) async {
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenReturn(false);
      final c = _container(repo, _anonUser());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Η επαλήθευση τηλεφώνου δεν είναι διαθέσιμη'),
          findsOneWidget);
      expect(find.text('Επαλήθευση Email'), findsOneWidget);
      await _settleTimer(tester);
    });
  });

  group('PhoneVerifyScreen φόρμα (verified user)', () {
    testWidgets('άκυρος αριθμός → invalid-phone, χωρίς repo call',
        (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenReturn(false);
      final c = _container(repo, _verifiedUser());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Αριθμός Τηλεφώνου'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.text('Αποστολή Κωδικού'));
      await tester.pumpAndSettle();
      expect(find.text('Μη έγκυρος αριθμός τηλεφώνου'), findsOneWidget);
      verifyNever(() => repo.sendPhoneOtp(any()));
      await _settleTimer(tester);
    });

    testWidgets('έγκυρος (με αρχικό 0) → normalize + OTP φόρμα',
        (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenReturn(false);
      when(() => repo.sendPhoneOtp(any())).thenAnswer((_) async => 'vid-1');
      final c = _container(repo, _verifiedUser());
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.enterText(find.byType(TextFormField), '0691234567');
      await tester.tap(find.text('Αποστολή Κωδικού'));
      await tester.pumpAndSettle();
      // Leading-0 fix: το 0 κόβεται (σε test env device locale US → +1,
      // το +30 καλύπτεται στο unit test). Χωρίς fix θα έβγαινε +10069...
      verify(() => repo.sendPhoneOtp('+1691234567')).called(1);
      expect(find.text('Κωδικός Επαλήθευσης'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('κοντό OTP → invalid-code, χωρίς repo call', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenReturn(false);
      when(() => repo.sendPhoneOtp(any())).thenAnswer((_) async => 'vid-1');
      final c = _container(repo, _verifiedUser());
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.enterText(find.byType(TextFormField), '691234567');
      await tester.tap(find.text('Αποστολή Κωδικού'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '12');
      await tester.tap(find.text('Επαλήθευση'));
      await tester.pumpAndSettle();
      expect(find.text('Λάθος κωδικός επαλήθευσης'), findsOneWidget);
      verifyNever(() => repo.verifyPhoneOtp(any(), any()));
      await _settleTimer(tester);
    });

    testWidgets('σωστό OTP → verified', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenReturn(false);
      when(() => repo.sendPhoneOtp(any())).thenAnswer((_) async => 'vid-1');
      when(() => repo.verifyPhoneOtp(any(), any())).thenAnswer((_) async {});
      final c = _container(repo, _verifiedUser());
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.enterText(find.byType(TextFormField), '691234567');
      await tester.tap(find.text('Αποστολή Κωδικού'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Επαλήθευση'));
      await tester.pumpAndSettle();
      verify(() => repo.verifyPhoneOtp('vid-1', '123456')).called(1);
      expect(find.text('Το τηλέφωνο επαληθεύτηκε!'), findsOneWidget);
      await _settleTimer(tester);
    });
  });
}
