import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/profile/providers/profile_provider.dart';
import 'package:near_me/features/profile/screens/privacy_editor_screen.dart';
import 'package:near_me/repositories/profile_repository.dart';
import '../../helpers/connectivity_mocks.dart';
import '../../helpers/fake_firestore_helpers.dart';

/// Widget tests για `PrivacyEditorScreen` (Γ7).
/// GoRouter harness: το success-pop θέλει router (pattern send_request).
class _MockProfileRepository extends Mock implements ProfileRepository {}

ProviderContainer _container(_MockProfileRepository repo) => ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    );

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> _pumpRouter(WidgetTester tester, ProviderContainer c) async {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(
          path: '/privacy',
          builder: (_, _) => const PrivacyEditorScreen()),
    ],
  );
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
  await tester.pumpAndSettle();
  router.push('/privacy');
  await tester.pumpAndSettle();
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 400);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(privacySettingsData());
  });

  group('PrivacyEditorScreen render', () {
    testWidgets('toggles + geo precision φορτώνουν', (tester) async {
      final repo = _MockProfileRepository();
      when(() => repo.getPrivacySettings())
          .thenAnswer((_) async => privacySettingsData());
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pumpRouter(tester, c);
      expect(find.text('Ψευδώνυμο'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ακρίβεια Τοποθεσίας'), 400);
      await tester.pumpAndSettle();
      expect(find.text('Συνοικία'), findsOneWidget);
      await _settleTimer(tester);
    });
  });

  group('PrivacyEditorScreen save', () {
    testWidgets('toggle flip → save με σωστή τιμή', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockProfileRepository();
      when(() => repo.getPrivacySettings())
          .thenAnswer((_) async => privacySettingsData());
      when(() => repo.savePrivacySettings(any())).thenAnswer((_) async {});
      when(() => repo.isPublished).thenAnswer((_) async => false);
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pumpRouter(tester, c);
      await _tapVisible(tester, find.widgetWithText(SwitchListTile, 'Ψευδώνυμο'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Αποθήκευση'));
      final saved = verify(() => repo.savePrivacySettings(captureAny()))
          .captured
          .single;
      expect(saved.showNickname, isFalse);
      expect(find.text('home'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('geo precision → Σ street → save', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockProfileRepository();
      when(() => repo.getPrivacySettings())
          .thenAnswer((_) async => privacySettingsData());
      when(() => repo.savePrivacySettings(any())).thenAnswer((_) async {});
      when(() => repo.isPublished).thenAnswer((_) async => false);
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pumpRouter(tester, c);
      await _tapVisible(tester, find.text('Περιοχή'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Αποθήκευση'));
      final saved = verify(() => repo.savePrivacySettings(captureAny()))
          .captured
          .single;
      expect(saved.geoPrecision, 'street');
      await _settleTimer(tester);
    });

    testWidgets('offline → χωρίς repo call', (tester) async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final repo = _MockProfileRepository();
      when(() => repo.getPrivacySettings())
          .thenAnswer((_) async => privacySettingsData());
      final c = _container(repo);
      addTearDown(c.dispose);
      await _pumpRouter(tester, c);
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Αποθήκευση'));
      verifyNever(() => repo.savePrivacySettings(any()));
      await _settleTimer(tester);
    });
  });
}
