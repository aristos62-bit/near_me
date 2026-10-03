import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/profile/providers/profile_provider.dart';
import 'package:near_me/features/requests/providers/requests_provider.dart';
import 'package:near_me/features/requests/screens/requests_dashboard_screen.dart';
import 'package:near_me/repositories/profile_repository.dart';
import 'package:near_me/repositories/request_repository.dart';

/// Highlight-scroll (`highlightRequestId`) — found + unknown id.
/// Το scroll-offset ΔΕΝ assertάρεται (private controller)· ελέγχεται
/// no-crash + απόδοση κάρτας.
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

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> _pump(
  WidgetTester tester, {
  String? highlightId,
  required List<Map<String, dynamic>> incoming,
}) async {
  final profileRepo = _MockProfileRepository();
  when(() => profileRepo.getPublicProfile(any()))
      .thenAnswer((_) async => null);
  final repo = _MockRequestRepository();
  when(() => repo.markRequestAsSeen(any())).thenAnswer((_) async {});
  final c = ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepo),
      requestRepositoryProvider.overrideWithValue(repo),
      authStateProvider
          .overrideWith((ref) => Stream.value(_verifiedUser())),
      incomingRequestsProvider
          .overrideWith((ref) => Stream.value(incoming)),
      outgoingRequestsProvider
          .overrideWith((ref) => Stream.value(const [])),
      publicProfileStreamProvider
          .overrideWith((ref, uid) => Stream.value(null)),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: const Locale('el'),
        supportedLocales: const [Locale('el'), Locale('en')],
        localizationsDelegates: _delegates,
        home: RequestsDashboardScreen(highlightRequestId: highlightId),
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
  group('RequestsDashboardScreen highlight', () {
    testWidgets('found id → κάρτα ορατή, χωρίς crash', (tester) async {
      await _pump(tester, highlightId: 'q1', incoming: [
        {
          'id': 'q1',
          'fromUid': 'from-q1',
          'toUid': 'me',
          'type': 'chat',
          'status': 'pending',
        },
        {
          'id': 'q2',
          'fromUid': 'from-q2',
          'toUid': 'me',
          'type': 'chat',
          'status': 'pending',
        },
      ]);
      expect(find.text('from-q1'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('unknown id → λίστα κανονικά, χωρίς crash', (tester) async {
      await _pump(tester, highlightId: 'ghost', incoming: [
        {
          'id': 'q1',
          'fromUid': 'from-q1',
          'toUid': 'me',
          'type': 'chat',
          'status': 'pending',
        },
      ]);
      expect(find.text('from-q1'), findsOneWidget);
      await _settleTimer(tester);
    });
  });
}
