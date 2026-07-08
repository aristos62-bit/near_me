import 'package:firebase_auth/firebase_auth.dart';
import '../core/debug/debug_config.dart';

abstract class AuthRepository {
  static bool _signingOut = false;
  static bool get isSigningOut => _signingOut;
  static void setSigningOut(bool v) => _signingOut = v;
  /// Single point of truth: can this user send messages, requests, publish, etc.?
  /// Requires: authenticated + NOT anonymous + (email verified OR phone linked).
  static bool canUserCommunicate(User? user) {
    if (user == null) {
      DebugConfig.log(DebugConfig.authGuard, 'canUserCommunicate: false (null user)');
      return false;
    }
    if (user.isAnonymous) {
      DebugConfig.log(DebugConfig.authGuard, 'canUserCommunicate: false (anonymous)');
      return false;
    }
    final hasPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    final result = user.emailVerified || hasPhone;
    DebugConfig.log(DebugConfig.authGuard,
        'canUserCommunicate: $result (emailVerified=${user.emailVerified}, hasPhone=$hasPhone)');
    return result;
  }
  Future<User> signInAnonymously();
  Future<void> signOut();
  Future<void> deleteAccount({String? password});
  Stream<User?> authStateChanges();
  User? get currentUser;
  bool get isAnonymous;
  Future<void> linkWithEmailAndPassword(String email, String password);
  Future<void> sendEmailVerification();
  bool get isEmailVerified;
  Future<void> reloadUser();
  Future<void> sendPasswordResetEmail(String email);
  Future<User> signInWithEmailAndPassword(String email, String password);
  Future<User> createUserWithEmailAndPassword(String email, String password);
  Future<String> sendPhoneOtp(String phoneNumber);
  Future<void> verifyPhoneOtp(String verificationId, String smsCode);
  bool get isPhoneVerified;
  Future<void> unlinkPhone();
}
