import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/repositories/chat_repository_impl.dart';

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

const kTestUid = 'u_test';
const kTestOther = 'u_other';

/// Shared setup για ChatRepositoryImpl tests: local Drift db + fake Firestore
/// + stubbed auth user. Οι seeder μέθοδοι γράφουν fixtures με default
/// τιμές σταθερά σε κοινούς identifiers.
class ChatRepoHarness {
  ChatRepoHarness._(this.db, this.firestore, this.auth, this.user);

  final AppDatabase db;
  final FakeFirebaseFirestore firestore;
  final MockAuth auth;
  final MockUser user;

  late final ChatRepositoryImpl repo = ChatRepositoryImpl(
    firestore: firestore,
    auth: auth,
    db: db,
  );

  static Future<ChatRepoHarness> create() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final firestore = FakeFirebaseFirestore();
    final auth = MockAuth();
    final user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn(kTestUid);
    stubUserVerified(user, verified: true);
    return ChatRepoHarness._(db, firestore, auth, user);
  }

  /// Repo χωρίς authenticated user.
  ChatRepositoryImpl repoNoUser() {
    final a = MockAuth();
    when(() => a.currentUser).thenReturn(null);
    return ChatRepositoryImpl(firestore: firestore, auth: a, db: db);
  }

  /// Repo με unverified user.
  ChatRepositoryImpl repoUnverified() {
    final u = MockUser();
    when(() => u.uid).thenReturn(kTestUid);
    stubUserVerified(u, verified: false);
    final a = MockAuth();
    when(() => a.currentUser).thenReturn(u);
    return ChatRepositoryImpl(firestore: firestore, auth: a, db: db);
  }

  Future<void> seedCacheRow({
    String chatId = 'chat1',
    String? ownerUid,
    String? otherUid,
    String? otherNickname,
    String? lastMessage,
    String? lastMessageSender,
    String? lastMessageType,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? hasUnread,
    String? groupAvatarUrl,
  }) async {
    await db.into(db.chatCacheTable).insert(ChatCacheTableCompanion.insert(
          chatId: Value(chatId),
          ownerUid: Value(ownerUid ?? kTestUid),
          otherUid: Value(otherUid ?? kTestOther),
          otherNickname: Value(otherNickname),
          lastMessage: Value(lastMessage),
          lastMessageSender: Value(lastMessageSender),
          lastMessageType: Value(lastMessageType),
          lastMessageAt: Value(lastMessageAt),
          unreadCount: unreadCount != null ? Value(unreadCount) : const Value.absent(),
          hasUnread: hasUnread != null ? Value(hasUnread) : const Value.absent(),
          groupAvatarUrl: Value(groupAvatarUrl),
        ));
  }

  Future<void> seedChatDoc({
    String chatId = 'chat1',
    List<String>? participants,
    bool isGroupChat = false,
    Map<String, dynamic>? extra,
    String messageExpiry = 'off',
  }) async {
    await firestore.collection('chats').doc(chatId).set({
      'participants': participants ?? [kTestUid, kTestOther],
      'isGroupChat': isGroupChat,
      'participantNicknames': {kTestUid: 'Me', kTestOther: 'Other'},
      'messageExpiry': messageExpiry,
      ...?extra,
    });
  }

  Future<void> seedMessage(
    String chatId,
    String docId, {
    String? senderId,
    String? content,
    String type = 'text',
    Timestamp? timestamp,
    bool isRead = false,
    Map<String, dynamic>? reactions,
    Map<String, dynamic>? extra,
  }) async {
    await firestore.collection('chats').doc(chatId).collection('messages').doc(docId).set({
      'senderId': senderId ?? kTestOther,
      'content': content ?? '',
      'type': type,
      'timestamp': timestamp ?? Timestamp.fromDate(DateTime(2026, 1, 1)),
      'isRead': isRead,
      'reactions': reactions,
      ...?extra,
    });
  }

  Future<void> close() => db.close();
}

void stubUserVerified(MockUser user, {required bool verified}) {
  when(() => user.isAnonymous).thenReturn(false);
  when(() => user.emailVerified).thenReturn(verified);
  when(() => user.phoneNumber).thenReturn(null);
}