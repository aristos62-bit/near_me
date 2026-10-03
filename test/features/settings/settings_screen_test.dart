import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/settings/providers/app_settings_provider.dart';
import 'package:near_me/features/settings/screens/settings_screen.dart';
import 'package:near_me/repositories/auth_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Widget tests για `SettingsScreen` (499 γρ., πλήρης ανάγνωση).
/// Fake notifier (record + local state — ποτέ real DB/channel).
/// Το phone-section είναι flag-off (const) → assert απουσίας.
class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

_MockUser _user({bool anon = false, bool verified = true}) {
  final u = _MockUser();
  when(() => u.uid).thenReturn('me');
  when(() => u.isAnonymous).thenReturn(anon);
  when(() => u.emailVerified).thenReturn(verified);
  when(() => u.phoneNumber).thenReturn(null);
  return u;
}

AppSettingsTableData _settings({
  bool biometric = false,
  bool blur = true,
  double sigma = 12.0,
  bool screenshot = false,
  bool crash = false,
}) =>
    AppSettingsTableData(
      id: 0,
      locale: 'el',
      themeMode: 'system',
      notificationsEnabled: true,
      biometricLockEnabled: biometric,
      screenshotPreventionEnabled: screenshot,
      crashReportsEnabled: crash,
      blurExplicitEnabled: blur,
      blurSigma: sigma,
      autoLockMinutes: 5,
      searchRadiusKm: 10.0,
      updatedAt: DateTime(2026, 1, 1),
    );

class _FakeAppSettingsNotifier extends AppSettingsNotifier {
  _FakeAppSettingsNotifier(AppSettingsTableData initial)
      : _state = AsyncValue.data(initial);
  AsyncValue<AppSettingsTableData> _state;
  final List<String> calls = [];

  @override
  AsyncValue<AppSettingsTableData> build() => _state;

  void _apply(AppSettingsTableData next, String call) {
    calls.add(call);
    _state = AsyncValue.data(next);
    state = _state;
  }

  @override
  Future<void> setScreenshotPrevention(bool v) async {
    final cur = _state.value;
    if (cur == null) return;
    _apply(cur.copyWith(screenshotPreventionEnabled: v), 'screenshot:$v');
  }

  @override
  Future<void> setBiometricLock(bool v) async {
    final cur = _state.value;
    if (cur == null) return;
    _apply(cur.copyWith(biometricLockEnabled: v), 'biometric:$v');
  }

  @override
  Future<void> setCrashReports(bool v) async {
    final cur = _state.value;
    if (cur == null) return;
    _apply(cur.copyWith(crashReportsEnabled: v), 'crash:$v');
  }

  @override
  Future<void> setBlurExplicit(bool v) async {
    final cur = _state.value;
    if (cur == null) return;
    _apply(cur.copyWith(blurExplicitEnabled: v), 'blur:$v');
  }

  @override
  Future<void> setBlurSigma(double v) async {
    final cur = _state.value;
    if (cur == null) return;
    _apply(cur.copyWith(blurSigma: v), 'sigma:$v');
  }

  @override
  Future<void> setAutoLockMinutes(int v) async {
    final cur = _state.value;
    if (cur == null) return;
    _apply(cur.copyWith(autoLockMinutes: v), 'autolock:$v');
  }
}

class _LoadingAppSettingsNotifier extends AppSettingsNotifier {
  @override
  AsyncValue<AppSettingsTableData> build() =>
      const AsyncValue.loading();
}

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required User? user,
  required AppSettingsNotifier Function() appSettings,
  _MockAuthRepository? authRepo,
  GoRouter? router,
}) async {
  final repo = authRepo ?? _MockAuthRepository();
  // Το initState + ο authState-listener καλούν πάντα isPhoneVerified
  // για μη-anon user — default stub για να μην πετάξει null-bool.
  when(() => repo.isPhoneVerified).thenReturn(false);
  // Ψηλό viewport: η ListView χτίζει τεμπέλικα — τα κάτω tiles
  // (blocked/signout/delete) δεν υπάρχουν καν χωρίς scroll.
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      appSettingsProvider.overrideWith(appSettings),
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
          home: Scaffold(body: SettingsScreen()),
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
            path: '/settings',
            builder: (_, _) => const SettingsScreen()),
      ],
    );

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// ensureVisible + tap (η λίστα ξεπερνάει τα 600px — taps χωρίς scroll
/// χάνουν, όπως στο delete_account_screen_test).
Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsScreen δομή', () {
    testWidgets('anonymous → verify tile, όχι signout/delete', (tester) async {
      await _pump(tester,
          user: _user(anon: true),
          appSettings: () => _FakeAppSettingsNotifier(_settings()));
      expect(find.text('Επαλήθευση Λογαριασμού'), findsOneWidget);
      expect(find.text('Αποσύνδεση'), findsNothing);
      expect(find.text('Διαγραφή Λογαριασμού'), findsNothing);
      await _settleTimer(tester);
    });

    testWidgets('verified → tiles signout/delete/blocked/privacy',
        (tester) async {
      await _pump(tester,
          user: _user(),
          appSettings: () => _FakeAppSettingsNotifier(_settings()));
      expect(find.text('Αποσύνδεση'), findsOneWidget);
      expect(find.text('Διαγραφή Λογαριασμού'), findsWidgets);
      expect(find.text('Μπλοκαρισμένοι Χρήστες'), findsOneWidget);
      expect(find.text('Πολιτική Απορρήτου'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('phone section απουσιάζει (flag const off)', (tester) async {
      await _pump(tester,
          user: _user(),
          appSettings: () => _FakeAppSettingsNotifier(_settings()));
      expect(find.text('Επαλήθευση Τηλεφώνου'), findsNothing);
      expect(find.text('Αφαίρεση Τηλεφώνου'), findsNothing);
      await _settleTimer(tester);
    });

    testWidgets('appSettings loading → σκελετός', (tester) async {
      await _pump(tester,
          user: _user(),
          appSettings: () => _LoadingAppSettingsNotifier());
      expect(find.text('...'), findsWidgets);
      await _settleTimer(tester);
    });

    testWidgets('biometric on → auto-lock tile', (tester) async {
      await _pump(tester,
          user: _user(),
          appSettings: () =>
              _FakeAppSettingsNotifier(_settings(biometric: true)));
      expect(find.text('Αυτόματο κλείδωμα'), findsOneWidget);
      await _settleTimer(tester);
    });
  });

  group('SettingsScreen toggles', () {
    testWidgets('screenshot toggle → record + snackbar', (tester) async {
      final fake = _FakeAppSettingsNotifier(_settings());
      await _pump(tester, user: _user(), appSettings: () => fake);
      await _tapText(tester, 'Αποτροπή Screenshot');
      await tester.pumpAndSettle();
      expect(fake.calls, contains('screenshot:true'));
      expect(find.text('Η προστασία screenshot ενεργοποιήθηκε'),
          findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('biometric ON χωρίς υλικό → no-biometric error', (tester) async {
      // Ντετερμινιστικό false (με ή χωρίς σωστό channel, βγαίνει false).
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/local_auth'),
        (call) async => false,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/local_auth'), null));
      final fake = _FakeAppSettingsNotifier(_settings(biometric: false));
      await _pump(tester, user: _user(), appSettings: () => fake);
      await _tapText(tester, 'Biometric Lock');
      await tester.pumpAndSettle();
      expect(find.text('Δεν υπάρχει διαθέσιμο βιομετρικό'), findsOneWidget);
      expect(fake.calls, isEmpty);
      await _settleTimer(tester);
    });

    testWidgets('biometric OFF → record', (tester) async {
      final fake = _FakeAppSettingsNotifier(_settings(biometric: true));
      await _pump(tester, user: _user(), appSettings: () => fake);
      await _tapText(tester, 'Biometric Lock');
      await tester.pumpAndSettle();
      expect(fake.calls, contains('biometric:false'));
      await _settleTimer(tester);
    });

    testWidgets('crash toggle → record + snackbar', (tester) async {
      final fake = _FakeAppSettingsNotifier(_settings());
      await _pump(tester, user: _user(), appSettings: () => fake);
      await _tapText(tester, 'Αναφορές Σφαλμάτων');
      await tester.pumpAndSettle();
      expect(fake.calls, contains('crash:true'));
      expect(find.text('Οι αναφορές σφαλμάτων ενεργοποιήθηκαν'),
          findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('blur toggle off → record + snackbar', (tester) async {
      final fake = _FakeAppSettingsNotifier(_settings(blur: true));
      await _pump(tester, user: _user(), appSettings: () => fake);
      await _tapText(tester, 'Θάμπωμα ακατάλληλου περιεχομένου');
      await tester.pumpAndSettle();
      expect(fake.calls, contains('blur:false'));
      expect(find.text('Το θάμπωμα απενεργοποιήθηκε'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('blur slider drag → setBlurSigma + tier snackbar',
        (tester) async {
      final fake = _FakeAppSettingsNotifier(_settings(blur: true, sigma: 12));
      await _pump(tester, user: _user(), appSettings: () => fake);
      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);
      await tester.ensureVisible(sliders.first);
      await tester.pumpAndSettle();
      await tester.drag(sliders.first, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(fake.calls.any((e) => e.startsWith('sigma:')), isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
      await _settleTimer(tester);
    });
  });

  group('SettingsScreen signout/πλοήγηση', () {
    testWidgets('signout confirm → repo.signOut', (tester) async {
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenReturn(false);
      when(() => repo.signOut()).thenAnswer((_) async {});
      await _pump(tester,
          user: _user(), appSettings: () => _FakeAppSettingsNotifier(_settings()),
          authRepo: repo);
      await _tapText(tester, 'Αποσύνδεση');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Αποσύνδεση')));
      await tester.pumpAndSettle();
      verify(() => repo.signOut()).called(1);
      await _settleTimer(tester);
    });

    testWidgets('signout fail → error snackbar', (tester) async {
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenReturn(false);
      when(() => repo.signOut()).thenThrow(Exception('boom'));
      await _pump(tester,
          user: _user(), appSettings: () => _FakeAppSettingsNotifier(_settings()),
          authRepo: repo);
      await _tapText(tester, 'Αποσύνδεση');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Αποσύνδεση')));
      await tester.pumpAndSettle();
      expect(find.text('Αποτυχία αποσύνδεσης'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('close → pop στο home (router stack)', (tester) async {
      final router = _router();
      await _pump(tester,
          user: _user(),
          appSettings: () => _FakeAppSettingsNotifier(_settings()),
          router: router);
      router.go('/home');
      await tester.pumpAndSettle();
      router.push('/settings');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('privacy tile → offline guard snackbar', (tester) async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      await _pump(tester,
          user: _user(),
          appSettings: () => _FakeAppSettingsNotifier(_settings()));
      await _tapText(tester, 'Πολιτική Απορρήτου');
      await tester.pumpAndSettle();
      expect(find.text('Δεν υπάρχει σύνδεση στο διαδίκτυο'), findsOneWidget);
      await _settleTimer(tester);
    });
  });
}
