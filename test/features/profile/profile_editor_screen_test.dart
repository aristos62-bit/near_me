import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/chat/providers/chat_provider.dart';
import 'package:near_me/features/profile/providers/profile_provider.dart';
import 'package:near_me/features/profile/screens/profile_editor_screen.dart';
import 'package:near_me/repositories/chat_repository.dart';
import 'package:near_me/repositories/profile_repository.dart';
import '../../helpers/connectivity_mocks.dart';
import '../../helpers/fake_firestore_helpers.dart';

/// Widget tests για `ProfileEditorScreen` (Γ7).
/// GoRouter harness: το success-pop θέλει router.
class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockChatRepository extends Mock implements ChatRepository {}

ProviderContainer _container(
  _MockProfileRepository profileRepo,
  _MockChatRepository chatRepo,
) =>
    ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profileRepo),
        chatRepositoryProvider.overrideWithValue(chatRepo),
      ],
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
          path: '/edit', builder: (_, _) => const ProfileEditorScreen()),
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
  router.push('/edit');
  await tester.pumpAndSettle();
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// Scroll τη σελίδα (ListView) μέχρι να χτιστεί ο στόχος + tap.
/// Ρητό drag-loop: το page-Scrollable δεν ξεχωρίζει από το bio-field
/// με finders (2 vertical Scrollables).
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  for (var i = 0;
      i < 12 && finder.evaluate().isEmpty;
      i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0;
      i < 12 && finder.evaluate().isEmpty;
      i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

/// Εισαγωγή κειμένου μέσω label (τα TextFormFields χτίζονται τεμπέλικα).
Future<void> _enterByLabel(
    WidgetTester tester, String label, String text) async {
  final labelFinder = find.text(label);
  for (var i = 0;
      i < 12 && labelFinder.evaluate().isEmpty;
      i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  final field = find.ancestor(
      of: labelFinder, matching: find.byType(TextFormField));
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(profileTableData());
  });

  group('ProfileEditorScreen render', () {
    testWidgets('φορτώνει nickname + sections', (tester) async {
      final profileRepo = _MockProfileRepository();
      when(() => profileRepo.getProfile()).thenAnswer(
          (_) async => profileTableData(nickname: 'Nikos', city: 'Athens'));
      final c = _container(profileRepo, _MockChatRepository());
      addTearDown(c.dispose);
      await _pumpRouter(tester, c);
      expect(find.text('Nikos'), findsWidgets);
      expect(find.text('Βασικά Στοιχεία'), findsOneWidget);
      await _scrollTo(tester, find.text('Τοποθεσία'));
      await _scrollTo(tester, find.text('Επικοινωνία'));
      await _settleTimer(tester);
    });
  });

  group('ProfileEditorScreen validation (E1)', () {
    testWidgets('κενό nickname → required, χωρίς save', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final profileRepo = _MockProfileRepository();
      when(() => profileRepo.getProfile()).thenAnswer(
          (_) async => profileTableData(nickname: 'Nikos', birthYear: 1990));
      final c = _container(profileRepo, _MockChatRepository());
      addTearDown(c.dispose);
      await _pumpRouter(tester, c);
      await _enterByLabel(tester, 'Ψευδώνυμο', '');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Αποθήκευση'));
      expect(find.text('Υποχρεωτικό πεδίο'), findsOneWidget);
      verifyNever(() => profileRepo.saveProfile(any()));
      await _settleTimer(tester);
    });

    testWidgets('άκυρο email → invalid-email, χωρίς save', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final profileRepo = _MockProfileRepository();
      when(() => profileRepo.getProfile()).thenAnswer(
          (_) async => profileTableData(nickname: 'Nikos', birthYear: 1990));
      final c = _container(profileRepo, _MockChatRepository());
      addTearDown(c.dispose);
      await _pumpRouter(tester, c);
      await _enterByLabel(tester, 'Ηλ. Ταχυδρομείο', 'bad');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Αποθήκευση'));
      expect(find.text('Μη έγκυρο email'), findsOneWidget);
      verifyNever(() => profileRepo.saveProfile(any()));
      await _settleTimer(tester);
    });

    testWidgets('κενό email (προαιρετικό) → save περνά', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final profileRepo = _MockProfileRepository();
      when(() => profileRepo.getProfile()).thenAnswer((_) async =>
          profileTableData(nickname: 'Nikos', birthYear: 1990, city: 'Athens'));
      when(() => profileRepo.saveProfile(any())).thenAnswer((_) async {});
      when(() => profileRepo.isPublished).thenAnswer((_) async => false);
      when(() => profileRepo.streamProfile()).thenAnswer(
          (_) => Stream.value(profileTableData(nickname: 'Nikos')));
      final chatRepo = _MockChatRepository();
      when(() => chatRepo.syncMyProfileAcrossChats(
          nickname: any(named: 'nickname'),
          avatarUrl: any(named: 'avatarUrl'))).thenAnswer((_) async {});
      final c = _container(profileRepo, chatRepo);
      addTearDown(c.dispose);
      await _pumpRouter(tester, c);
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Αποθήκευση'));
      verify(() => profileRepo.saveProfile(any())).called(1);
      verify(() => chatRepo.syncMyProfileAcrossChats(
          nickname: 'Nikos', avatarUrl: any(named: 'avatarUrl'))).called(1);
      expect(find.text('home'), findsOneWidget);
      await _settleTimer(tester);
    });
  });
}
