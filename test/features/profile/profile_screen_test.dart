import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/profile/providers/profile_provider.dart';
import 'package:near_me/features/profile/screens/profile_screen.dart';
import 'package:near_me/features/requests/providers/requests_provider.dart';
import 'package:near_me/repositories/profile_repository.dart';
import 'package:near_me/repositories/request_repository.dart';
import '../../helpers/connectivity_mocks.dart';
import '../../helpers/fake_firestore_helpers.dart';

/// Widget tests για `ProfileScreen` (Γ7).
/// Mocks: ProfileRepository (publish/unpublish) + RequestRepository (streams)
/// + authState override. currentProfileProvider override με Stream.
class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockRequestRepository extends Mock implements RequestRepository {}

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

ProviderContainer _container({
  required _MockProfileRepository profileRepo,
  required _MockRequestRepository requestRepo,
  User? user,
  UserProfileTableData? profile,
}) {
  when(() => requestRepo.streamIncomingRequests())
      .thenAnswer((_) => Stream.value(const []));
  when(() => requestRepo.streamOutgoingRequests())
      .thenAnswer((_) => Stream.value(const []));
  return ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepo),
      requestRepositoryProvider.overrideWithValue(requestRepo),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      currentProfileProvider.overrideWith((ref) => Stream.value(profile)),
    ],
  );
}

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
        home: ProfileScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('ProfileScreen render', () {
    testWidgets('προφίλ → nickname + πόλη + menu', (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
        profile: profileTableData(
            nickname: 'Nikos', city: 'Athens', birthYear: 1990),
      );
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Nikos'), findsOneWidget);
      expect(find.textContaining('Athens'), findsOneWidget);
      expect(find.text('Επεξεργασία'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('χωρίς προφίλ → empty CTA', (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
      );
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Δημιουργία Προφίλ'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('anonymous → verify banner (χωρίς publish toggle)',
        (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _anonUser(),
        profile: profileTableData(nickname: 'Nikos'),
      );
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Απαιτείται επαλήθευση'), findsOneWidget);
      expect(find.text('Δημοσιευμένο'), findsNothing);
      expect(find.text('Μη δημοσιευμένο'), findsNothing);
      await _settleTimer(tester);
    });
  });

  group('ProfileScreen publish toggle', () {
    testWidgets('unpublished → tap → publish + snackbar', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final profileRepo = _MockProfileRepository();
      when(() => profileRepo.publish()).thenAnswer((_) async {});
      final c = _container(
        profileRepo: profileRepo,
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
        profile: profileTableData(nickname: 'Nikos'),
      );
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Μη δημοσιευμένο'), findsOneWidget);
      await _tapVisible(tester, find.byType(SwitchListTile));
      verify(() => profileRepo.publish()).called(1);
      expect(find.text('Το προφίλ δημοσιεύτηκε'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('offline → χωρίς repo call', (tester) async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final profileRepo = _MockProfileRepository();
      final c = _container(
        profileRepo: profileRepo,
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
        profile: profileTableData(nickname: 'Nikos'),
      );
      addTearDown(c.dispose);
      await _pump(tester, c);
      await _tapVisible(tester, find.byType(SwitchListTile));
      verifyNever(() => profileRepo.publish());
      verifyNever(() => profileRepo.unpublish());
      await _settleTimer(tester);
    });
  });

  group('ProfileScreen signOut', () {
    testWidgets('cancel στο confirm → διάλογος κλείνει', (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
        profile: profileTableData(nickname: 'Nikos'),
      );
      addTearDown(c.dispose);
      await _pump(tester, c);
      await _tapVisible(
          tester, find.widgetWithText(ListTile, 'Αποσύνδεση'));
      expect(find.text('Θέλεις σίγουρα να αποσυνδεθείς;'), findsOneWidget);
      await tester.tap(find.text('Ακύρωση'));
      await tester.pumpAndSettle();
      expect(find.text('Θέλεις σίγουρα να αποσυνδεθείς;'), findsNothing);
      await _settleTimer(tester);
    });
  });
}
