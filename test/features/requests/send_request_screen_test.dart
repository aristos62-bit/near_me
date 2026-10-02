import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/profile/providers/profile_provider.dart';
import 'package:near_me/features/requests/providers/requests_provider.dart';
import 'package:near_me/features/requests/screens/send_request_screen.dart';
import 'package:near_me/repositories/profile_repository.dart';
import 'package:near_me/repositories/request_repository.dart';
import 'package:near_me/shared/models/public_profile.dart';
import '../../helpers/connectivity_mocks.dart';

/// Widget tests για `SendRequestScreen` (327 γρ., πλήρης ανάγνωση).
/// Overrides: profileRepo (Mock) + authState (Stream) + requestRepo (Mock).
/// GoRouter harness ΜΟΝΟ για το success-pop (το `context.pop()` θέλει router).
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

PublicProfile _profile({bool chat = true, bool video = false}) =>
    PublicProfile(
      uid: 'other',
      nickname: 'Nikos',
      allowDirectChat: chat,
      allowVideoCall: video,
    );

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> _pumpPlain(
  WidgetTester tester,
  ProviderContainer c, {
  PublicProfile? profile,
}) async {
  final repo = c.read(profileRepositoryProvider) as _MockProfileRepository;
  when(() => repo.getPublicProfile('other'))
      .thenAnswer((_) async => profile);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        locale: Locale('el'),
        supportedLocales: [Locale('el'), Locale('en')],
        localizationsDelegates: _delegates,
        home: SendRequestScreen(uid: 'other'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _container({
  required _MockProfileRepository profileRepo,
  required _MockRequestRepository requestRepo,
  User? user,
}) =>
    ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profileRepo),
        requestRepositoryProvider.overrideWithValue(requestRepo),
        authStateProvider.overrideWith((ref) => Stream.value(user)),
      ],
    );

/// Ξεφόρτωμα δέντρου + flush του DebugConfig 1s Timer (pattern S264/S270) —
/// κάθε build logάρει, οπότε το pumpAndSettle μόνο του δεν αρκεί.
Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('SendRequestScreen φόρτωση/επιλογές', () {
    testWidgets('profile null → fallback uid + 2 disabled chips',
        (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
      );
      addTearDown(c.dispose);
      await _pumpPlain(tester, c);
      expect(find.text('other'), findsWidgets);
      expect(find.text('Συνομιλία (μη διαθέσιμη)'), findsOneWidget);
      expect(find.text('Βιντεοκλήση (μη διαθέσιμη)'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('chat-only προφίλ → chat enabled, video disabled',
        (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
      );
      addTearDown(c.dispose);
      await _pumpPlain(tester, c,
          profile: _profile(chat: true, video: false));
      expect(find.text('Συνομιλία'), findsOneWidget);
      expect(find.text('Βιντεοκλήση (μη διαθέσιμη)'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('video-only προφίλ → video enabled, chat disabled',
        (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
      );
      addTearDown(c.dispose);
      await _pumpPlain(tester, c,
          profile: _profile(chat: false, video: true));
      expect(find.text('Βιντεοκλήση'), findsOneWidget);
      expect(find.text('Συνομιλία (μη διαθέσιμη)'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('tap chip → επιλεγμένο (check icon)', (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
      );
      addTearDown(c.dispose);
      await _pumpPlain(tester, c,
          profile: _profile(chat: true, video: false));
      await tester.tap(find.text('Συνομιλία'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('verified χωρίς επιλογή → κουμπί disabled', (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
      );
      addTearDown(c.dispose);
      await _pumpPlain(tester, c,
          profile: _profile(chat: true, video: false));
      final btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Αποστολή Αιτήματος'));
      expect(btn.onPressed, isNull);
      await _settleTimer(tester);
    });

    testWidgets('anonymous + επιλογή → banner + disabled', (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _anonUser(),
      );
      addTearDown(c.dispose);
      await _pumpPlain(tester, c,
          profile: _profile(chat: true, video: false));
      await tester.tap(find.text('Συνομιλία'));
      await tester.pumpAndSettle();
      expect(
          find.text('Πρέπει να επαληθεύσεις τον λογαριασμό σου'),
          findsOneWidget);
      final btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Αποστολή Αιτήματος'));
      expect(btn.onPressed, isNull);
      await _settleTimer(tester);
    });

    testWidgets('message field δέχεται κείμενο', (tester) async {
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: _MockRequestRepository(),
        user: _verifiedUser(),
      );
      addTearDown(c.dispose);
      await _pumpPlain(tester, c,
          profile: _profile(chat: true, video: false));
      await tester.enterText(find.byType(TextField), 'γεια σου');
      await tester.pumpAndSettle();
      expect(find.text('γεια σου'), findsOneWidget);
      await _settleTimer(tester);
    });
  });

  group('SendRequestScreen αποστολή', () {
    testWidgets('offline → μένει στην οθόνη, χωρίς repo call',
        (tester) async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final requestRepo = _MockRequestRepository();
      final c = _container(
        profileRepo: _MockProfileRepository(),
        requestRepo: requestRepo,
        user: _verifiedUser(),
      );
      addTearDown(c.dispose);
      await _pumpPlain(tester, c,
          profile: _profile(chat: true, video: false));
      await tester.tap(find.text('Συνομιλία'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Αποστολή Αιτήματος'));
      await tester.pumpAndSettle();
      // AppBar + κουμπί μοιράζονται το κείμενο → assert στο snackbar offline.
      expect(find.text('Δεν υπάρχει σύνδεση στο διαδίκτυο'), findsOneWidget);
      final btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Αποστολή Αιτήματος'));
      expect(btn.onPressed, isNotNull);
      verifyNever(() => requestRepo.sendRequest(any(), any(),
          message: any(named: 'message')));
      await _settleTimer(tester);
    });

    testWidgets('online success → pop + invalidate + σωστά args',
        (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final profileRepo = _MockProfileRepository();
      when(() => profileRepo.getPublicProfile('other'))
          .thenAnswer((_) async => _profile(chat: true, video: false));
      final requestRepo = _MockRequestRepository();
      String? gotUid;
      String? gotType;
      String? gotMsg;
      when(() => requestRepo.sendRequest(any(), any(),
              message: any(named: 'message')))
          .thenAnswer((inv) async {
        gotUid = inv.positionalArguments[0] as String;
        gotType = inv.positionalArguments[1] as String;
        gotMsg = inv.namedArguments[#message] as String?;
      });
      when(() => requestRepo.streamOutgoingRequests())
          .thenAnswer((_) => Stream.value(const []));
      final c = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepo),
          requestRepositoryProvider.overrideWithValue(requestRepo),
          authStateProvider.overrideWith((ref) => Stream.value(_verifiedUser())),
        ],
      );
      addTearDown(c.dispose);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('home'))),
          GoRoute(
              path: '/send',
              builder: (_, _) => const SendRequestScreen(uid: 'other')),
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
      router.go('/home');
      await tester.pumpAndSettle();
      router.push('/send');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Συνομιλία'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'έλα για καφέ');
      await tester.tap(find.widgetWithText(FilledButton, 'Αποστολή Αιτήματος'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(gotUid, 'other');
      expect(gotType, 'chat');
      expect(gotMsg, 'έλα για καφέ');
      await _settleTimer(tester);
    });

    testWidgets('online failure → error snackbar, κουμπί ξανα-ενεργό',
        (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final profileRepo = _MockProfileRepository();
      when(() => profileRepo.getPublicProfile('other'))
          .thenAnswer((_) async => _profile(chat: true, video: false));
      final requestRepo = _MockRequestRepository();
      when(() => requestRepo.sendRequest(any(), any(),
              message: any(named: 'message')))
          .thenThrow(Exception('network-request-failed'));
      final c = _container(
        profileRepo: profileRepo,
        requestRepo: requestRepo,
        user: _verifiedUser(),
      );
      addTearDown(c.dispose);
      await _pumpPlain(tester, c,
          profile: _profile(chat: true, video: false));
      await tester.tap(find.text('Συνομιλία'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Αποστολή Αιτήματος'));
      await tester.pumpAndSettle();
      // Plain Exception (όχι AppException) → code 'request/send-failed'.
      expect(find.text('Αποτυχία αποστολής'), findsOneWidget);
      final btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Αποστολή Αιτήματος'));
      expect(btn.onPressed, isNotNull);
      await _settleTimer(tester);
    });
  });
}
