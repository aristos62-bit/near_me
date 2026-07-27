import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/utils/app_exception.dart';
import '../../../repositories/auth_repository.dart';
import 'auth_provider.dart';

enum PhoneVerifyStatus { idle, loading, otpSent, verified, error, autoVerified }

class PhoneVerifyState {
  final PhoneVerifyStatus status;
  final String? errorMessage;
  final String? verificationId;

  const PhoneVerifyState({
    this.status = PhoneVerifyStatus.idle,
    this.errorMessage,
    this.verificationId,
  });
}

class PhoneVerifyNotifier extends Notifier<PhoneVerifyState> {
  @override
  PhoneVerifyState build() {
    DebugConfig.log(DebugConfig.providerCreate, 'PhoneVerifyNotifier built');
    return const PhoneVerifyState();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  void checkIfAlreadyVerified() {
    try {
      final verified = _auth.isPhoneVerified;
      if (verified) {
        DebugConfig.log(DebugConfig.authPhone, 'PhoneVerify: already verified');
        state = const PhoneVerifyState(status: PhoneVerifyStatus.verified);
      }
    } catch (e) {
      DebugConfig.warn('PhoneVerify: checkIfAlreadyVerified failed', data: e);
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    DebugConfig.log(DebugConfig.authPhone, 'PhoneVerify: sendOtp $phoneNumber');
    state = const PhoneVerifyState(status: PhoneVerifyStatus.loading);
    try {
      final result = await _auth.sendPhoneOtp(phoneNumber);
      if (result == 'AUTO_VERIFIED') {
        DebugConfig.log(DebugConfig.authPhone, 'PhoneVerify: auto-verified');
        state = const PhoneVerifyState(status: PhoneVerifyStatus.autoVerified);
      } else {
        DebugConfig.log(DebugConfig.authPhone, 'PhoneVerify: OTP sent, vId=$result');
        state = PhoneVerifyState(status: PhoneVerifyStatus.otpSent, verificationId: result);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('provider-already-linked')) {
        DebugConfig.log(DebugConfig.authPhone, 'PhoneVerify: already linked');
        state = const PhoneVerifyState(status: PhoneVerifyStatus.verified);
        return;
      }
      DebugConfig.warn('PhoneVerify: sendOtp failed', data: e);
      state = PhoneVerifyState(status: PhoneVerifyStatus.error, errorMessage: _friendlyError(e));
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    final currentState = state;
    if (currentState.verificationId == null || currentState.verificationId!.isEmpty) {
      DebugConfig.warn('PhoneVerify: verifyOtp called without verificationId');
      state = PhoneVerifyState(status: PhoneVerifyStatus.error, errorMessage: 'auth/invalid-verification');
      return;
    }
    DebugConfig.log(DebugConfig.authPhone, 'PhoneVerify: verifyOtp');
    state = const PhoneVerifyState(status: PhoneVerifyStatus.loading);
    try {
      await _auth.verifyPhoneOtp(currentState.verificationId!, smsCode);
      DebugConfig.log(DebugConfig.authPhone, 'PhoneVerify: verified!');
      state = const PhoneVerifyState(status: PhoneVerifyStatus.verified);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('provider-already-linked')) {
        DebugConfig.log(DebugConfig.authPhone, 'PhoneVerify: already linked (verify)');
        state = const PhoneVerifyState(status: PhoneVerifyStatus.verified);
        return;
      }
      DebugConfig.warn('PhoneVerify: verifyOtp failed', data: e);
      state = PhoneVerifyState(status: PhoneVerifyStatus.error, errorMessage: _friendlyError(e));
    }
  }

  void reset() {
    DebugConfig.log(DebugConfig.authPhone, 'PhoneVerify: reset');
    state = const PhoneVerifyState();
  }

  String _friendlyError(Object error) {
    if (error is AppException) return error.code;
    return 'auth/unknown-error';
  }
}

final phoneVerifyProvider = NotifierProvider<PhoneVerifyNotifier, PhoneVerifyState>(
  PhoneVerifyNotifier.new,
);
