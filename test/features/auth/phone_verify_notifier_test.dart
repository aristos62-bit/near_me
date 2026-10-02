import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/auth/providers/phone_verify_provider.dart';
import 'package:near_me/repositories/auth_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Unit tests για `PhoneVerifyNotifier` (κλάδοι OTP).
/// Κανόνας mocktail: users/mocks φτιάχνονται πριν τα stubs.
class _MockAuthRepository extends Mock implements AuthRepository {}

ProviderContainer _container(_MockAuthRepository repo) => ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  group('PhoneVerifyNotifier.checkIfAlreadyVerified/reset', () {
    test('ήδη verified → verified', () {
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenReturn(true);
      final c = _container(repo);
      addTearDown(c.dispose);
      c.read(phoneVerifyProvider.notifier).checkIfAlreadyVerified();
      expect(c.read(phoneVerifyProvider).status, PhoneVerifyStatus.verified);
    });

    test('όχι verified → μένει idle', () {
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenReturn(false);
      final c = _container(repo);
      addTearDown(c.dispose);
      c.read(phoneVerifyProvider.notifier).checkIfAlreadyVerified();
      expect(c.read(phoneVerifyProvider).status, PhoneVerifyStatus.idle);
    });

    test('repo throw → μένει idle (warn-only)', () {
      final repo = _MockAuthRepository();
      when(() => repo.isPhoneVerified).thenThrow(Exception('boom'));
      final c = _container(repo);
      addTearDown(c.dispose);
      c.read(phoneVerifyProvider.notifier).checkIfAlreadyVerified();
      expect(c.read(phoneVerifyProvider).status, PhoneVerifyStatus.idle);
    });

    test('reset → idle', () {
      final repo = _MockAuthRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      c.read(phoneVerifyProvider.notifier).reset();
      expect(c.read(phoneVerifyProvider).status, PhoneVerifyStatus.idle);
    });
  });

  group('PhoneVerifyNotifier.sendOtp', () {
    test('offline → error, χωρίς repo call', () async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(phoneVerifyProvider.notifier).sendOtp('+306911111111');
      final s = c.read(phoneVerifyProvider);
      expect(s.status, PhoneVerifyStatus.error);
      expect(s.errorMessage, 'network/no-connectivity');
      verifyNever(() => repo.sendPhoneOtp(any()));
    });

    test('AUTO_VERIFIED → autoVerified', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.sendPhoneOtp(any()))
          .thenAnswer((_) async => 'AUTO_VERIFIED');
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(phoneVerifyProvider.notifier).sendOtp('+306911111111');
      expect(
          c.read(phoneVerifyProvider).status, PhoneVerifyStatus.autoVerified);
    });

    test('vId → otpSent + verificationId', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.sendPhoneOtp(any())).thenAnswer((_) async => 'vid-1');
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(phoneVerifyProvider.notifier).sendOtp('+306911111111');
      final s = c.read(phoneVerifyProvider);
      expect(s.status, PhoneVerifyStatus.otpSent);
      expect(s.verificationId, 'vid-1');
    });

    test('provider-already-linked → verified', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.sendPhoneOtp(any()))
          .thenThrow(Exception('provider-already-linked'));
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(phoneVerifyProvider.notifier).sendOtp('+306911111111');
      expect(c.read(phoneVerifyProvider).status, PhoneVerifyStatus.verified);
    });

    // ΣΗΜΕΙΩΣΗ: ο notifier περνάει το raw error στο toFriendlyMessage
    // (όχι στο _mapPhoneError του repo) → βγαίνει unknown-error.
    // Κλειδώνουμε την πραγματική συμπεριφορά, χωρίς αλλαγή.
    test('άλλο σφάλμα → error auth/unknown-error', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.sendPhoneOtp(any()))
          .thenThrow(Exception('invalid-phone-number'));
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(phoneVerifyProvider.notifier).sendOtp('+306911111111');
      final s = c.read(phoneVerifyProvider);
      expect(s.status, PhoneVerifyStatus.error);
      expect(s.errorMessage, 'auth/unknown-error');
    });
  });

  group('PhoneVerifyNotifier.verifyOtp', () {
    test('χωρίς verificationId → invalid-verification (πριν το gate)',
        () async {
      final repo = _MockAuthRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(phoneVerifyProvider.notifier).verifyOtp('123456');
      final s = c.read(phoneVerifyProvider);
      expect(s.status, PhoneVerifyStatus.error);
      expect(s.errorMessage, 'auth/invalid-verification');
      verifyNever(() => repo.verifyPhoneOtp(any(), any()));
    });

    test('offline → error', () async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(phoneVerifyProvider.notifier);
      n.state = const PhoneVerifyState(
          status: PhoneVerifyStatus.otpSent, verificationId: 'vid-1');
      await n.verifyOtp('123456');
      expect(c.read(phoneVerifyProvider).status, PhoneVerifyStatus.error);
      verifyNever(() => repo.verifyPhoneOtp(any(), any()));
    });

    test('επιτυχία → verified', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.verifyPhoneOtp(any(), any()))
          .thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(phoneVerifyProvider.notifier);
      n.state = const PhoneVerifyState(
          status: PhoneVerifyStatus.otpSent, verificationId: 'vid-1');
      await n.verifyOtp('123456');
      expect(c.read(phoneVerifyProvider).status, PhoneVerifyStatus.verified);
      verify(() => repo.verifyPhoneOtp('vid-1', '123456')).called(1);
    });

    test('αποτυχία → error auth/unknown-error (ίδια σημείωση)', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockAuthRepository();
      when(() => repo.verifyPhoneOtp(any(), any()))
          .thenThrow(Exception('invalid-verification-code'));
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(phoneVerifyProvider.notifier);
      n.state = const PhoneVerifyState(
          status: PhoneVerifyStatus.otpSent, verificationId: 'vid-1');
      await n.verifyOtp('000000');
      final s = c.read(phoneVerifyProvider);
      expect(s.status, PhoneVerifyStatus.error);
      expect(s.errorMessage, 'auth/unknown-error');
    });
  });
}
