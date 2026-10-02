import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/settings/providers/delete_account_provider.dart';
import 'package:near_me/repositories/auth_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Unit tests για `DeleteAccountNotifier` (offline-gate, reauth branch).
class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

ProviderContainer _container(_MockAuthRepository repo) => ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  group('DeleteAccountNotifier.delete', () {
    test('offline → error, χωρίς repo call', () async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(deleteAccountProvider.notifier).delete();
      final s = c.read(deleteAccountProvider);
      expect(s.status, DeleteState.error);
      expect(s.errorMessage, 'network/no-connectivity');
      verifyNever(() => repo.deleteAccount());
    });

    test('επιτυχία → success', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.deleteAccount()).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(deleteAccountProvider.notifier).delete();
      expect(c.read(deleteAccountProvider).status, DeleteState.success);
    });

    test('requires-recent-login → needsReauth με email', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final user = _MockUser();
      when(() => user.email).thenReturn('a@b.gr');
      final repo = _MockAuthRepository();
      when(() => repo.deleteAccount()).thenThrow(
          FirebaseAuthException(code: 'requires-recent-login'));
      when(() => repo.currentUser).thenReturn(user);
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(deleteAccountProvider.notifier).delete();
      final s = c.read(deleteAccountProvider);
      expect(s.status, DeleteState.needsReauth);
      expect(s.email, 'a@b.gr');
    });

    test('άλλο FirebaseAuthException → error', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.deleteAccount())
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(deleteAccountProvider.notifier).delete();
      final s = c.read(deleteAccountProvider);
      expect(s.status, DeleteState.error);
      expect(s.errorMessage, 'delete/unknown-error');
    });

    test('generic throw → error + reset', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.deleteAccount()).thenThrow(Exception('boom'));
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(deleteAccountProvider.notifier);
      await n.delete();
      expect(c.read(deleteAccountProvider).status, DeleteState.error);
      n.reset();
      expect(c.read(deleteAccountProvider).status, DeleteState.idle);
    });
  });

  group('DeleteAccountNotifier.deleteWithPassword', () {
    test('offline → error · επιτυχία → success', () async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(deleteAccountProvider.notifier);
      await n.deleteWithPassword('pw');
      expect(c.read(deleteAccountProvider).status, DeleteState.error);
      verifyNever(() => repo.deleteAccount(password: any(named: 'password')));
      await mockConnectivityOnline();
      when(() => repo.deleteAccount(password: any(named: 'password')))
          .thenAnswer((_) async {});
      await n.deleteWithPassword('pw');
      expect(c.read(deleteAccountProvider).status, DeleteState.success);
    });
  });
}
