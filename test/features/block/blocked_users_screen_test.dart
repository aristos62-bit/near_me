import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/block/providers/block_provider.dart';
import 'package:near_me/features/block/screens/blocked_users_screen.dart';
import 'package:near_me/features/profile/providers/profile_provider.dart';
import 'package:near_me/repositories/block_repository.dart';
import 'package:near_me/repositories/profile_repository.dart';
import 'package:near_me/shared/models/public_profile.dart';

/// Widget tests για `BlockedUsersScreen` (135 γρ., πλήρης ανάγνωση).
/// Overrides: authState + blockedUids(family) + profileRepo(Mock) +
/// blockRepo(Mock). Προφίλ με κενό avatarUrl (initial-branch).
class _MockBlockRepository extends Mock implements BlockRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

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

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  User? user,
  Set<String> blocked = const {},
  bool blockedError = false,
  PublicProfile? Function(String uid)? profileOf,
  _MockBlockRepository? blockRepo,
}) async {
  final profileRepo = _MockProfileRepository();
  when(() => profileRepo.getPublicProfile(any()))
      .thenAnswer((inv) async => profileOf?.call(inv.positionalArguments[0] as String));
  final c = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      blockedUidsProvider('me').overrideWith((ref) =>
          blockedError ? Stream.error(Exception('boom')) : Stream.value(blocked)),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      if (blockRepo != null)
        blockRepositoryProvider.overrideWithValue(blockRepo),
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
        home: BlockedUsersScreen(),
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
  group('BlockedUsersScreen καταστάσεις', () {
    testWidgets('χωρίς user → not-logged-in EmptyView', (tester) async {
      await _pump(tester, user: null);
      expect(find.text('Δεν έχεις συνδεθεί / Not logged in'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('κενή λίστα → empty view', (tester) async {
      await _pump(tester, user: _verifiedUser());
      // localizedMessage split (όχι full bilingual).
      expect(find.text('Δεν έχεις μπλοκάρει κανέναν χρήστη'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('λίστα με null προφίλ → fallback uid + αρχικό', (tester) async {
      await _pump(tester, user: _verifiedUser(), blocked: {'b1'});
      expect(find.text('b1'), findsWidgets);
      expect(find.text('Ξεμπλοκάρισμα'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('λίστα με προφίλ → nickname + πόλη', (tester) async {
      await _pump(tester,
          user: _verifiedUser(),
          blocked: {'b1'},
          profileOf: (uid) => PublicProfile(
              uid: uid, nickname: 'Nikos', city: 'Athens'));
      expect(find.text('Nikos'), findsOneWidget);
      expect(find.text('Athens'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('error → ErrorView + retry', (tester) async {
      await _pump(tester, user: _verifiedUser(), blockedError: true);
      expect(find.text('Σφάλμα φόρτωσης'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await _settleTimer(tester);
    });
  });

  group('BlockedUsersScreen unblock', () {
    testWidgets('tap → repo.unblock + success snackbar', (tester) async {
      final blockRepo = _MockBlockRepository();
      when(() => blockRepo.unblockUser(any(), any()))
          .thenAnswer((_) async {});
      await _pump(tester,
          user: _verifiedUser(), blocked: {'b1'}, blockRepo: blockRepo);
      await tester.tap(find.text('Ξεμπλοκάρισμα'));
      await tester.pumpAndSettle();
      verify(() => blockRepo.unblockUser('me', 'b1')).called(1);
      expect(find.text('Ξεμπλοκαρίστηκε'), findsOneWidget);
      await _settleTimer(tester);
    });

    // ΣΗΜΕΙΩΣΗ: το tile δεν έχει try/catch γύρω από το unblock —
    // αποτυχία repo διαρρέει ως unhandled (παρατήρηση, όχι αλλαγή).
  });
}
