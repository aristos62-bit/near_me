import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod/riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../data/local/database_service.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/auth_repository_impl.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'authRepositoryProvider created');
  return AuthRepositoryImpl(
    FirebaseAuth.instance,
    db: DatabaseService.instance,
    firestore: FirebaseFirestore.instance,
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'authStateProvider created');
  final auth = ref.watch(authRepositoryProvider);
  return auth.authStateChanges();
});

enum VerifyStatus { idle, loading, emailSent, verified, error }

class VerifyAccountState {
  final VerifyStatus status;
  final String? errorMessage;
  const VerifyAccountState({this.status = VerifyStatus.idle, this.errorMessage});
}

class VerifyAccountNotifier extends Notifier<VerifyAccountState> {
  @override
  VerifyAccountState build() {
    DebugConfig.log(DebugConfig.providerCreate, 'VerifyAccountNotifier built');
    return const VerifyAccountState();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<void> verify(String email, String password) async {
    DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: starting');
    state = VerifyAccountState(status: VerifyStatus.loading);
    try {
      final user = _auth.currentUser;
      if (user != null && !user.isAnonymous) {
        // Ήδη linked με email → απλή επαναποστολή verification
        DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: resending verification (already linked)');
        await _auth.sendEmailVerification();
      } else {
        // Anonymous user → προσπάθεια link
        try {
          await _auth.linkWithEmailAndPassword(email, password);
          DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: linked successfully');
        } catch (linkError) {
          final msg = linkError.toString();
          if (msg.contains('email-already-in-use') || msg.contains('credential-already-in-use')) {
            // Το email υπάρχει ήδη → sign in με αυτά τα credentials
            DebugConfig.log(DebugConfig.authFlow,
                'VerifyAccount: email-already-in-use → attempting signIn');
            await _auth.signInWithEmailAndPassword(email, password);
            DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: signIn success after link fail');
          } else {
            rethrow;
          }
        }
        await _auth.sendEmailVerification();
        DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: verification email sent');
      }
      DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: email sent');
      state = const VerifyAccountState(status: VerifyStatus.emailSent);
    } catch (e) {
      DebugConfig.warn('VerifyAccount: failed', data: e);
      state = VerifyAccountState(status: VerifyStatus.error, errorMessage: _friendlyError(e));
    }
  }

  void showEmailSent() {
    DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: email already sent (post-registration)');
    state = const VerifyAccountState(status: VerifyStatus.emailSent);
  }

  Future<void> checkVerification() async {
    DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: checking verification');
    state = VerifyAccountState(status: VerifyStatus.loading);
    try {
      await _auth.reloadUser();
      if (_auth.isEmailVerified) {
        DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: verified!');
        state = const VerifyAccountState(status: VerifyStatus.verified);
      } else {
        DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: not yet verified');
        state = const VerifyAccountState(status: VerifyStatus.emailSent);
      }
    } catch (e) {
      DebugConfig.warn('VerifyAccount: check failed', data: e);
      state = VerifyAccountState(status: VerifyStatus.emailSent);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: password reset for $email');
    state = VerifyAccountState(status: VerifyStatus.loading);
    try {
      await _auth.sendPasswordResetEmail(email);
      state = const VerifyAccountState(status: VerifyStatus.idle);
      DebugConfig.log(DebugConfig.authFlow, 'VerifyAccount: reset email sent');
    } catch (e) {
      DebugConfig.warn('VerifyAccount: password reset failed', data: e);
      state = VerifyAccountState(status: VerifyStatus.error, errorMessage: _friendlyError(e));
    }
  }

  String _friendlyError(Object error) {
    final msg = error.toString();
    if (msg.contains('email-already-in-use')) return 'auth/email-already-in-use';
    if (msg.contains('invalid-email')) return 'auth/invalid-email';
    if (msg.contains('weak-password')) return 'auth/weak-password';
    if (msg.contains('user-not-found')) return 'auth/user-not-found';
    if (msg.contains('wrong-password')) return 'auth/wrong-password';
    if (msg.contains('too-many-requests')) return 'auth/too-many-requests';
    if (msg.contains('network-request-failed')) return 'auth/network-error';
    return 'auth/unknown-error';
  }

  void reset() {
    state = const VerifyAccountState();
  }
}

final verifyAccountProvider = NotifierProvider<VerifyAccountNotifier, VerifyAccountState>(
  VerifyAccountNotifier.new,
);

enum WelcomeStatus { idle, loading, success, error }

class WelcomeState {
  final WelcomeStatus status;
  final String? errorMessage;
  final bool isSignedIn;
  const WelcomeState({
    this.status = WelcomeStatus.idle,
    this.errorMessage,
    this.isSignedIn = false,
  });
}

class WelcomeNotifier extends Notifier<WelcomeState> {
  @override
  WelcomeState build() {
    DebugConfig.log(DebugConfig.providerCreate, 'WelcomeNotifier built');
    return const WelcomeState();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<void> signIn(String email, String password) async {
    DebugConfig.log(DebugConfig.authFlow, 'Welcome: signIn started');
    state = WelcomeState(status: WelcomeStatus.loading);
    try {
      await _auth.signInWithEmailAndPassword(email, password);
      DebugConfig.log(DebugConfig.authFlow, 'Welcome: signIn success');
      state = const WelcomeState(status: WelcomeStatus.success, isSignedIn: true);
    } catch (e) {
      DebugConfig.warn('Welcome: signIn failed', data: e);
      state = WelcomeState(status: WelcomeStatus.error, errorMessage: _friendlyError(e));
    }
  }

  Future<void> signUp(String email, String password) async {
    DebugConfig.log(DebugConfig.authFlow, 'Welcome: signUp started');
    state = WelcomeState(status: WelcomeStatus.loading);
    try {
      final user = await _auth.createUserWithEmailAndPassword(email, password);
      DebugConfig.log(DebugConfig.authFlow, 'Welcome: account created ${user.uid}');
      await _auth.sendEmailVerification();
      DebugConfig.log(DebugConfig.authFlow, 'Welcome: verification email sent');
      state = const WelcomeState(status: WelcomeStatus.success, isSignedIn: true);
    } catch (e) {
      DebugConfig.warn('Welcome: signUp failed', data: e);
      state = WelcomeState(status: WelcomeStatus.error, errorMessage: _friendlyError(e));
    }
  }

  Future<void> browseAnonymously() async {
    DebugConfig.log(DebugConfig.authFlow, 'Welcome: browseAnonymously');
    state = WelcomeState(status: WelcomeStatus.loading);
    try {
      await _auth.signInAnonymously();
      DebugConfig.log(DebugConfig.authFlow, 'Welcome: anonymous sign-in success');
      state = const WelcomeState(status: WelcomeStatus.success, isSignedIn: true);
    } catch (e) {
      DebugConfig.warn('Welcome: anonymous sign-in failed', data: e);
      state = WelcomeState(status: WelcomeStatus.error, errorMessage: _friendlyError(e));
    }
  }

  String _friendlyError(Object error) {
    final msg = error.toString();
    if (msg.contains('email-already-in-use')) return 'auth/email-already-in-use';
    if (msg.contains('invalid-email')) return 'auth/invalid-email';
    if (msg.contains('weak-password')) return 'auth/weak-password';
    if (msg.contains('user-not-found')) return 'auth/user-not-found';
    if (msg.contains('wrong-password')) return 'auth/wrong-password';
    if (msg.contains('too-many-requests')) return 'auth/too-many-requests';
    if (msg.contains('network-request-failed')) return 'auth/network-error';
    return 'auth/unknown-error';
  }

  void reset() {
    state = const WelcomeState();
  }
}

final welcomeProvider = NotifierProvider<WelcomeNotifier, WelcomeState>(
  WelcomeNotifier.new,
);
