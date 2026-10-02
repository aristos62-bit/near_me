import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/repositories/auth_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Unit tests για VerifyAccount/Welcome notifiers (πραγματική λογική).
/// Mock AuthRepository (abstract → mockable) + connectivity channel mock.
/// Κανόνας mocktail: ΚΑΝΕΝΑ `when` μέσα σε stub — όλοι οι users φτιάχνονται
/// πρώτα σε locals και μετά περνάνε στα stubs.
class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

_MockUser _makeUser({
  String uid = 'u1',
  bool anon = false,
  bool verified = true,
  String? phone,
}) {
  final u = _MockUser();
  when(() => u.uid).thenReturn(uid);
  when(() => u.isAnonymous).thenReturn(anon);
  when(() => u.emailVerified).thenReturn(verified);
  when(() => u.phoneNumber).thenReturn(phone);
  return u;
}

ProviderContainer _container(_MockAuthRepository repo) => ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  group('VerifyAccountNotifier.verify', () {
    test('offline → error network/no-connectivity, χωρίς repo call', () async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(verifyAccountProvider.notifier).verify('a@b.gr', 'pw12345');
      final s = c.read(verifyAccountProvider);
      expect(s.status, VerifyStatus.error);
      expect(s.errorMessage, 'network/no-connectivity');
      verifyNever(() => repo.linkWithEmailAndPassword(any(), any()));
    });

    test('ήδη linked → μόνο resend verification', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final me = _makeUser(anon: false);
      final repo = _MockAuthRepository();
      when(() => repo.currentUser).thenReturn(me);
      when(() => repo.sendEmailVerification()).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(verifyAccountProvider.notifier).verify('a@b.gr', 'pw12345');
      expect(c.read(verifyAccountProvider).status, VerifyStatus.emailSent);
      verifyNever(() => repo.linkWithEmailAndPassword(any(), any()));
      verify(() => repo.sendEmailVerification()).called(1);
    });

    test('anonymous → link + send → emailSent', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final anon = _makeUser(anon: true);
      final repo = _MockAuthRepository();
      when(() => repo.currentUser).thenReturn(anon);
      when(() => repo.linkWithEmailAndPassword(any(), any()))
          .thenAnswer((_) async {});
      when(() => repo.sendEmailVerification()).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(verifyAccountProvider.notifier).verify('a@b.gr', 'pw12345');
      expect(c.read(verifyAccountProvider).status, VerifyStatus.emailSent);
    });

    test('email-already-in-use → signIn fallback → emailSent', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final anon = _makeUser(anon: true);
      final signedIn = _makeUser(anon: false);
      final repo = _MockAuthRepository();
      when(() => repo.currentUser).thenReturn(anon);
      when(() => repo.linkWithEmailAndPassword(any(), any()))
          .thenThrow(Exception('email-already-in-use'));
      when(() => repo.signInWithEmailAndPassword(any(), any()))
          .thenAnswer((_) async => signedIn);
      when(() => repo.sendEmailVerification()).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(verifyAccountProvider.notifier).verify('a@b.gr', 'pw12345');
      expect(c.read(verifyAccountProvider).status, VerifyStatus.emailSent);
      verify(() => repo.signInWithEmailAndPassword(any(), any())).called(1);
    });

    test('άλλο link error → error με friendly code', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final anon = _makeUser(anon: true);
      final repo = _MockAuthRepository();
      when(() => repo.currentUser).thenReturn(anon);
      when(() => repo.linkWithEmailAndPassword(any(), any()))
          .thenThrow(Exception('weak-password'));
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(verifyAccountProvider.notifier).verify('a@b.gr', 'pw12345');
      final s = c.read(verifyAccountProvider);
      expect(s.status, VerifyStatus.error);
      expect(s.errorMessage, 'auth/weak-password');
    });

    test('checkVerification verified/not-yet + silent/reset', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.reloadUser()).thenAnswer((_) async {});
      when(() => repo.isEmailVerified).thenReturn(true);
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(verifyAccountProvider.notifier);
      await n.checkVerification();
      expect(c.read(verifyAccountProvider).status, VerifyStatus.verified);
      when(() => repo.isEmailVerified).thenReturn(false);
      await n.checkVerification();
      expect(c.read(verifyAccountProvider).status, VerifyStatus.emailSent);
      n.showEmailSent();
      expect(c.read(verifyAccountProvider).status, VerifyStatus.emailSent);
      n.reset();
      expect(c.read(verifyAccountProvider).status, VerifyStatus.idle);
    });

    test('sendPasswordReset success → idle, offline → error', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.sendPasswordResetEmail(any())).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(verifyAccountProvider.notifier);
      await n.sendPasswordReset('a@b.gr');
      expect(c.read(verifyAccountProvider).status, VerifyStatus.idle);
      await mockConnectivityOffline();
      await n.sendPasswordReset('a@b.gr');
      expect(c.read(verifyAccountProvider).status, VerifyStatus.error);
    });
  });

  group('WelcomeNotifier', () {
    test('offline signIn → error, χωρίς repo call', () async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(welcomeProvider.notifier).signIn('a@b.gr', 'pw');
      expect(c.read(welcomeProvider).status, WelcomeStatus.error);
      verifyNever(() => repo.signInWithEmailAndPassword(any(), any()));
    });

    test('signIn success → success+signedIn', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final signedIn = _makeUser();
      final repo = _MockAuthRepository();
      when(() => repo.signInWithEmailAndPassword(any(), any()))
          .thenAnswer((_) async => signedIn);
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(welcomeProvider.notifier).signIn('a@b.gr', 'pw');
      final s = c.read(welcomeProvider);
      expect(s.status, WelcomeStatus.success);
      expect(s.isSignedIn, isTrue);
    });

    test('signIn fail → error με friendly code', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.signInWithEmailAndPassword(any(), any()))
          .thenThrow(Exception('wrong-password'));
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(welcomeProvider.notifier).signIn('a@b.gr', 'pw');
      final s = c.read(welcomeProvider);
      expect(s.status, WelcomeStatus.error);
      expect(s.errorMessage, 'auth/wrong-password');
    });

    test('signUp success → create + verification → success', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final created = _makeUser(anon: false, verified: false);
      final repo = _MockAuthRepository();
      when(() => repo.createUserWithEmailAndPassword(any(), any()))
          .thenAnswer((_) async => created);
      when(() => repo.sendEmailVerification()).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(welcomeProvider.notifier).signUp('n@b.gr', 'pw12345');
      expect(c.read(welcomeProvider).status, WelcomeStatus.success);
      verify(() => repo.sendEmailVerification()).called(1);
    });

    test('browseAnonymously success + reset', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final anon = _makeUser(anon: true);
      final repo = _MockAuthRepository();
      when(() => repo.signInAnonymously()).thenAnswer((_) async => anon);
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(welcomeProvider.notifier);
      await n.browseAnonymously();
      expect(c.read(welcomeProvider).isSignedIn, isTrue);
      n.reset();
      expect(c.read(welcomeProvider).status, WelcomeStatus.idle);
    });
  });
}
