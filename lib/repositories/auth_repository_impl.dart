import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/local/database.dart';
import '../data/local/database_service.dart';
import 'auth_repository.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';
import '../core/notifications/fcm_service.dart';
import '../core/services/presence_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl(this._auth, {AppDatabase? db, FirebaseFirestore? firestore})
      : _db = db ?? DatabaseService.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<User> signInAnonymously() async {
    DebugConfig.log(DebugConfig.authFlow, 'Signing in anonymously');
    final result = await _auth.signInAnonymously();
    DebugConfig.log(DebugConfig.authAnonymous, 'Anonymous sign-in: ${result.user?.uid}');
    return result.user!;
  }

  @override
  Future<void> signOut() async {
    DebugConfig.log(DebugConfig.authFlow, 'Signing out');
    await PresenceService.setOffline();
    PresenceService.reset();
    await FcmService.clearTokens();
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;
    DebugConfig.log(DebugConfig.authFlow, 'deleteAccount started: $uid');

    try {
      final result = await FirebaseFunctions.instance.httpsCallable('deleteUserData').call({'uid': uid});
      DebugConfig.log(DebugConfig.cloudFunctions, 'deleteAccount: CF deleteUserData success: ${result.data}');
    } catch (e) {
      DebugConfig.warn('deleteAccount: CF deleteUserData failed, continuing with local cleanup', data: e);
    }

    await FcmService.clearTokens();

    try {
      await _logConsent(uid);
    } catch (_) {}

    try {
      await _firestore.collection('users').doc(uid).collection('public').doc('profile').delete();
      await _firestore.collection('users').doc(uid).collection('status').doc('status').delete();
      DebugConfig.log(DebugConfig.firestoreWrite, 'deleteAccount: Firestore data cleared');
    } catch (e) {
      DebugConfig.warn('deleteAccount: Firestore cleanup failed', data: e);
    }

    try {
      await _db.clearAllTables();
      DebugConfig.log(DebugConfig.databaseLocal, 'deleteAccount: database cleared');
    } catch (e) {
      DebugConfig.warn('deleteAccount: database cleanup failed', data: e);
    }

    try {
      await user.delete();
      DebugConfig.log(DebugConfig.authFlow, 'deleteAccount: Firebase Auth user deleted');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (password != null && user.email != null) {
          DebugConfig.log(DebugConfig.authFlow, 'deleteAccount: reauthenticating');
          final credential = EmailAuthProvider.credential(email: user.email!, password: password);
          await user.reauthenticateWithCredential(credential);
          await user.delete();
          DebugConfig.log(DebugConfig.authFlow, 'deleteAccount: deleted after reauth');
        } else {
          DebugConfig.warn('deleteAccount: requires-recent-login, no password provided');
          rethrow;
        }
      } else {
        rethrow;
      }
    } catch (e) {
      DebugConfig.error('deleteAccount: Auth deletion failed', data: e);
      rethrow;
    }
  }

  @override
  Future<void> linkWithEmailAndPassword(String email, String password) async {
    DebugConfig.log(DebugConfig.authFlow, 'Linking anonymous with email: $email');
    final user = _auth.currentUser;
    if (user == null) throw AppException.auth('link_user', 'No authenticated user');
    final credential = EmailAuthProvider.credential(email: email, password: password);
    await user.linkWithCredential(credential);
    DebugConfig.log(DebugConfig.authFlow, 'Anonymous linked to email: ${user.uid}');
  }

  @override
  Future<void> sendEmailVerification() async {
    DebugConfig.log(DebugConfig.authFlow, 'Sending email verification');
    final user = _auth.currentUser;
    if (user == null) throw AppException.auth('send_verification', 'No authenticated user');
    await user.sendEmailVerification();
    DebugConfig.log(DebugConfig.authFlow, 'Verification email sent');
  }

  @override
  bool get isEmailVerified {
    final verified = _auth.currentUser?.emailVerified ?? false;
    DebugConfig.log(DebugConfig.authFlow, 'isEmailVerified: $verified');
    return verified;
  }

  @override
  Future<void> reloadUser() async {
    DebugConfig.log(DebugConfig.authFlow, 'Reloading user');
    await _auth.currentUser?.reload();
    DebugConfig.log(DebugConfig.authFlow, 'User reloaded, emailVerified: ${_auth.currentUser?.emailVerified}');
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    DebugConfig.log(DebugConfig.authFlow, 'Sending password reset email: $email');
    await _auth.sendPasswordResetEmail(email: email);
    DebugConfig.log(DebugConfig.authFlow, 'Password reset email sent');
  }

  Future<void> _logConsent(String uid) async {
    await _db.logConsent(uid, 'deleted_account', 'profile',
        details: 'Πλήρης διαγραφή λογαριασμού / Full account deletion');
    DebugConfig.log(DebugConfig.consentLogWrite, 'deleteAccount consent logged');
  }

  @override
  Future<User> signInWithEmailAndPassword(String email, String password) async {
    DebugConfig.log(DebugConfig.authFlow, 'Signing in with email: $email');
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    DebugConfig.log(DebugConfig.authFlow, 'Email sign-in success: ${result.user?.uid}');
    return result.user!;
  }

  @override
  Future<User> createUserWithEmailAndPassword(String email, String password) async {
    DebugConfig.log(DebugConfig.authFlow, 'Creating account with email: $email');
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    DebugConfig.log(DebugConfig.authFlow, 'Account created: ${result.user?.uid}');
    return result.user!;
  }

  @override
  Stream<User?> authStateChanges() {
    DebugConfig.log(DebugConfig.authFlow, 'Subscribing to authStateChanges');
    return _auth.authStateChanges().map((user) {
      DebugConfig.log(DebugConfig.authFlow,
          'authStateChanges emitted: uid=${user?.uid ?? "null"} anon=${user?.isAnonymous}');
      return user;
    });
  }

  @override
  User? get currentUser {
    final user = _auth.currentUser;
    DebugConfig.log(DebugConfig.authFlow, 'currentUser: ${user?.uid ?? "null"}');
    return user;
  }

  @override
  bool get isAnonymous {
    final anon = _auth.currentUser?.isAnonymous ?? false;
    DebugConfig.log(DebugConfig.authFlow, 'isAnonymous: $anon');
    return anon;
  }
}
