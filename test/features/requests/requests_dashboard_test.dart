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

/// Widget tests για `RequestsDashboardScreen` (366 γρ., πλήρης ανάγνωση).
/// Canned maps (χωρίς createdAt → κρύβεται η ημερομηνία).
/// Προφίλ με κενό avatarUrl (initial-branch, όχι CachedNetworkImage).
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

Map<String, dynamic> _incoming(String id,
        {String status = 'pending', bool read = false}) =>
    {
      'id': id,
      'fromUid': 'from-$id',
      'toUid': 'me',
      'type': 'chat',
      'status': status,
      if (read) 'readAt': 'seen',
    };

Map<String, dynamic> _outgoing(String id, {String status = 'pending'}) => {
      'id': id,
      'fromUid': 'me',
      'toUid': 'to-$id',
      'type': 'chat',
      'status': status,
    };

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required User? user,
  List<Map<String, dynamic>> incoming = const [],
  List<Map<String, dynamic>> outgoing = const [],
  _MockRequestRepository? requestRepo,
  bool incomingError = false,
}) async {
  final profileRepo = _MockProfileRepository();
  when(() => profileRepo.getPublicProfile(any()))
      .thenAnswer((_) async => null);
  final repo = requestRepo ?? _MockRequestRepository();
  when(() => repo.markRequestAsSeen(any())).thenAnswer((_) async {});
  final c = ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(profileRepo),
      requestRepositoryProvider.overrideWithValue(repo),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      incomingRequestsProvider.overrideWith((ref) =>
          incomingError ? Stream.error(Exception('boom')) : Stream.value(incoming)),
      outgoingRequestsProvider.overrideWith((ref) => Stream.value(outgoing)),
      publicProfileStreamProvider.overrideWith((ref, uid) => Stream.value(null)),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        locale: Locale('el'),
        supportedLocales: [Locale('el'), Locale('en')],
        localizationsDelegates: _delegates,
        home: RequestsDashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('RequestsDashboardScreen locked/καταστάσεις', () {
    testWidgets('anonymous → locked οθόνη + κουμπί επαλήθευσης',
        (tester) async {
      await _pump(tester, user: _anonUser());
      expect(find.text('Τα αιτήματα είναι κλειδωμένα'), findsOneWidget);
      expect(find.text('Επαλήθευση Λογαριασμού'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('άδεια tabs → EmptyViews', (tester) async {
      await _pump(tester, user: _verifiedUser());
      expect(find.text('Δεν έχεις εισερχόμενα αιτήματα'), findsOneWidget);
      await tester.tap(find.text('Εξερχόμενα'));
      await tester.pumpAndSettle();
      expect(find.text('Δεν έχεις στείλει αιτήματα'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('λίστες → nicknames fallback + badges', (tester) async {
      await _pump(tester,
          user: _verifiedUser(),
          incoming: [_incoming('q1'), _incoming('q2', status: 'accepted')],
          outgoing: [_outgoing('o1', status: 'declined')]);
      expect(find.text('from-q1'), findsOneWidget);
      expect(find.text('Αποδοχή'), findsOneWidget);
      expect(find.text('Απόρριψη'), findsOneWidget);
      await tester.tap(find.text('Εξερχόμενα'));
      await tester.pumpAndSettle();
      expect(find.text('to-o1'), findsOneWidget);
      expect(find.text('Απορρίφθηκε'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('error → ErrorView + retry', (tester) async {
      await _pump(tester, user: _verifiedUser(), incomingError: true);
      // Μήνυμα από localizedMessage split (χωρίς τελεία).
      expect(find.text('Σφάλμα φόρτωσης'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await _settleTimer(tester);
    });
  });

  group('RequestsDashboardScreen φίλτρα/επιλογή', () {
    testWidgets('φίλτρο Ενεργά κρύβει τα accepted', (tester) async {
      await _pump(tester,
          user: _verifiedUser(),
          incoming: [_incoming('q1'), _incoming('q2', status: 'accepted')]);
      expect(find.text('from-q1'), findsOneWidget);
      expect(find.text('from-q2'), findsOneWidget);
      await tester.tap(find.text('Ενεργά'));
      await tester.pumpAndSettle();
      expect(find.text('from-q1'), findsOneWidget);
      expect(find.text('from-q2'), findsNothing);
      await _settleTimer(tester);
    });

    testWidgets('long-press → selection bar + select-all + close',
        (tester) async {
      await _pump(tester,
          user: _verifiedUser(), incoming: [_incoming('q1'), _incoming('q2')]);
      await tester.longPress(find.text('from-q1'));
      await tester.pumpAndSettle();
      expect(find.text('1 επιλεγμένα'), findsOneWidget);
      await tester.tap(find.text('Επιλογή όλων'));
      await tester.pumpAndSettle();
      expect(find.text('2 επιλεγμένα'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Εισερχόμενα'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('tap unread card → markAsSeen', (tester) async {
      final repo = _MockRequestRepository();
      when(() => repo.markRequestAsSeen(any())).thenAnswer((_) async {});
      await _pump(tester,
          user: _verifiedUser(), incoming: [_incoming('q1')], requestRepo: repo);
      await tester.tap(find.text('from-q1'));
      await tester.pumpAndSettle();
      verify(() => repo.markRequestAsSeen('q1')).called(1);
      await _settleTimer(tester);
    });

    testWidgets('Αποδοχή → respondToRequest + success snackbar', (tester) async {
      final repo = _MockRequestRepository();
      when(() => repo.markRequestAsSeen(any())).thenAnswer((_) async {});
      when(() => repo.respondToRequest(any(), any()))
          .thenAnswer((_) async => null);
      await _pump(tester,
          user: _verifiedUser(), incoming: [_incoming('q1')], requestRepo: repo);
      await tester.tap(find.text('Αποδοχή'));
      await tester.pumpAndSettle();
      verify(() => repo.respondToRequest('q1', 'accepted')).called(1);
      expect(find.text('Το αίτημα έγινε αποδεκτό'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('bulk delete → confirm → repo calls + success', (tester) async {
      final repo = _MockRequestRepository();
      when(() => repo.markRequestAsSeen(any())).thenAnswer((_) async {});
      when(() => repo.deleteRequest(any())).thenAnswer((_) async {});
      await _pump(tester,
          user: _verifiedUser(),
          incoming: [_incoming('q1'), _incoming('q2')],
          requestRepo: repo);
      await tester.longPress(find.text('from-q1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Επιλογή όλων'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Διαγραφή'));
      await tester.pumpAndSettle();
      // Τίτλος + confirm μοιράζονται το κείμενο → το confirm FilledButton.
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Διαγραφή')));
      await tester.pumpAndSettle();
      verify(() => repo.deleteRequest('q1')).called(1);
      verify(() => repo.deleteRequest('q2')).called(1);
      expect(find.text('Διαγράφηκαν 2 αιτήματα'), findsOneWidget);
      await _settleTimer(tester);
    });
  });
}
