import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
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
