import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/repositories/auth_repository.dart';
import 'package:near_me/repositories/chat_repository_impl.dart';
import 'package:near_me/repositories/request_repository_impl.dart';

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

const kReqTestUid = 'u_test';
const kReqOtherUid = 'u_other';

/// Shared setup για RequestRepositoryImpl tests: local Drift db + fake
/// Firestore + stubbed auth user + ζωντανό ChatRepositoryImpl (για το
/// accepted+chat path του respondToRequest).
class RequestRepoHarness {
  RequestRepoHarness._(this.db, this.firestore, this.auth, this.user);

  final AppDatabase db;
  final FakeFirebaseFirestore firestore;
  final MockAuth auth;
  final MockUser user;

  late final RequestRepositoryImpl repo = RequestRepositoryImpl(
    firestore: firestore,
    auth: auth,
    db: db,
    chatRepo: realChatRepo,
    rateLimitCheck: () async => true,
  );

  late final ChatRepositoryImpl realChatRepo = ChatRepositoryImpl(
    firestore: firestore,
    auth: auth,
    db: db,
  );

  static Future<RequestRepoHarness> create() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final firestore = FakeFirebaseFirestore();
    final auth = MockAuth();
    final user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn(kReqTestUid);
    stubVerified(user, verified: true);
    return RequestRepoHarness._(db, firestore, auth, user);
  }

  /// Repo χωρίς authenticated user (με rateLimitCheck pass-granting).
  late final RequestRepositoryImpl repoNoUser = RequestRepositoryImpl(
    firestore: firestore,
    auth: _noUserAuth,
    db: db,
    chatRepo: realChatRepo,
    rateLimitCheck: () async => true,
  );

  late final MockAuth _noUserAuth = () {
    final a = MockAuth();
    when(() => a.currentUser).thenReturn(null);
    return a;
  }();

  RequestRepositoryImpl repoUnverified() {
    final u = MockUser();
    when(() => u.uid).thenReturn(kReqTestUid);
    stubVerified(u, verified: false);
    final a = MockAuth();
    when(() => a.currentUser).thenReturn(u);
    return RequestRepositoryImpl(
      firestore: firestore,
      auth: a,
      db: db,
      chatRepo: realChatRepo,
      rateLimitCheck: () async => true,
    );
  }

  /// Repo με rate-limit που μπλοκάρει (για το blocked path).
  RequestRepositoryImpl repoRateLimited() => RequestRepositoryImpl(
        firestore: firestore,
        auth: auth,
        db: db,
        chatRepo: realChatRepo,
        rateLimitCheck: () async => false,
      );

  Future<void> seedPublicProfile(String uid,
      {bool allowDirectChat = false, bool allowVideoCall = false}) async {
    await firestore
        .collection('users')
        .doc(uid)
        .collection('public')
        .doc('profile')
        .set({
      'uid': uid,
      'nickname': uid == kReqTestUid ? 'Me' : 'Other',
      'allowDirectChat': allowDirectChat,
      'allowVideoCall': allowVideoCall,
    });
  }

  Future<void> seedBlocked(String byUid, String blockedUid) async {
    await firestore
        .collection('users')
        .doc(byUid)
        .collection('blocked')
        .doc(blockedUid)
        .set({'blockedAt': DateTime.now()});
  }

  Future<void> close() => db.close();
}

/// Reset του static signing-out state (αντικαθιστά τυχόν pollution).
void resetSigningOut() {
  AuthRepository.setSigningOut(false);
}

void stubVerified(MockUser user, {required bool verified}) {
  when(() => user.isAnonymous).thenReturn(false);
  when(() => user.emailVerified).thenReturn(verified);
  when(() => user.phoneNumber).thenReturn(null);
}