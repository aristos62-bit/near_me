import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/repositories/chat_repository_impl.dart';

import '../helpers/chat_repository_test_base.dart';

void main() {
  late ChatRepoHarness h;

  setUp(() async {
    h = await ChatRepoHarness.create();
  });

  tearDown(() async {
    await h.close();
  });

  group('deleteMessage', () {
    test('no user → auth_error', () async {
      await expectLater(
        h.repoNoUser().deleteMessage('chat1', 'm1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('unverified → auth_error', () async {
      await expectLater(
        h.repoUnverified().deleteMessage('chat1', 'm1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('μήνυμα δεν υπάρχει → no-op', () async {
      await h.seedChatDoc();
      await h.repo.deleteMessage('chat1', 'ghost');
    });

    test('δικό μου μήνυμα → διαγράφεται', () async {
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1', senderId: kTestUid, content: 'enc');

      await h.repo.deleteMessage('chat1', 'm1');

      final doc =
          await h.firestore.collection('chats').doc('chat1').collection('messages').doc('m1').get();
      expect(doc.exists, isFalse);
    });

    test('μήνυμα άλλου σε 1-1 → auth_error', () async {
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1', senderId: kTestOther);

      await expectLater(
        h.repo.deleteMessage('chat1', 'm1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });
  });

  group('requestDeleteChat / deleteChat', () {
    test('no user → auth_error', () async {
      await expectLater(
        h.repoNoUser().requestDeleteChat('chat1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('chat δεν υπάρχει → no-op', () async {
      await h.repo.requestDeleteChat('chat1');
    });

    test('1-1 με ενεργό άλλο → system delete_request, chat παραμένει',
        () async {
      await h.seedChatDoc();
      await h.seedCacheRow();

      await h.repo.requestDeleteChat('chat1');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect(chat.exists, isTrue);
      final data = chat.data()!;
      expect(data['pendingDelete'], isTrue);
      expect(data.containsKey('deleteResponseNeeded'), isFalse);
      expect(data['lastMessageType'], 'system');
      expect(data['systemMessage'], 'delete_request');
      expect(data['lastMessageBy'], kTestUid);
      expect((data['unreadCount'] as Map)[kTestOther], 1);

      final msgs = await h.firestore
          .collection('chats').doc('chat1').collection('messages').get();
      expect(msgs.docs, hasLength(1));
      final sys = msgs.docs.single.data();
      expect(sys['type'], 'system');
      expect(sys['action'], 'delete_request');
      expect(sys['senderId'], kTestUid);
    });

    test('1-1 χωρίς ενεργό άλλο → πλήρης διαγραφή', () async {
      await h.seedChatDoc(extra: {
        'participantIsActive': {kTestOther: false},
      });
      await h.seedCacheRow();
      await h.seedMessage('chat1', 'm1', senderId: kTestOther);

      await h.repo.requestDeleteChat('chat1');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect(chat.exists, isFalse);
      final msgs = await h.firestore
          .collection('chats').doc('chat1').collection('messages').get();
      expect(msgs.docs, isEmpty);
      final rows = await h.db.select(h.db.chatCacheTable).get();
      expect(rows, isEmpty);
    });

    test('deleteChat → delegate σε requestDeleteChat (1-1 με active other)',
        () async {
      await h.seedChatDoc();
      await h.seedCacheRow();

      await h.repo.deleteChat('chat1');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect(chat.exists, isTrue);
      expect(chat.data()!['pendingDelete'], isTrue);
      expect(chat.data()!['systemMessage'], 'delete_request');
    });
  });

  group('approveDeleteChat', () {
    test('1-1 → system delete_approved + πλήρης διαγραφή', () async {
      await h.seedChatDoc();
      await h.seedCacheRow();
      await h.seedMessage('chat1', 'm1', senderId: kTestOther);

      await h.repo.approveDeleteChat('chat1');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect(chat.exists, isFalse);
      final rows = await h.db.select(h.db.chatCacheTable).get();
      expect(rows, isEmpty);
    });
  });

  group('rejectDeleteChat', () {
    test('system delete_rejected + deleteResponseNeeded=true, chat παραμένει',
        () async {
      await h.seedChatDoc(extra: {'pendingDelete': true});
      await h.seedCacheRow();

      await h.repo.rejectDeleteChat('chat1');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect(chat.exists, isTrue);
      final data = chat.data()!;
      expect(data['deleteResponseNeeded'], isTrue);
      expect(data.containsKey('pendingDelete'), isFalse);
      expect((data['unreadCount'] as Map)[kTestOther], 1);

      final msgs = await h.firestore
          .collection('chats').doc('chat1').collection('messages').get();
      expect(msgs.docs.single.data()['action'], 'delete_rejected');
    });
  });

  group('cancelDeleteRequest', () {
    test('system delete_cancelled + pendingDelete/ResponseNeeded σβήνονται',
        () async {
      await h.seedChatDoc(extra: {
        'pendingDelete': true,
        'deleteResponseNeeded': true,
      });

      await h.repo.cancelDeleteRequest('chat1');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      final data = chat.data()!;
      expect(data.containsKey('pendingDelete'), isFalse);
      expect(data.containsKey('deleteResponseNeeded'), isFalse);
      expect(data['systemMessage'], 'delete_cancelled');
    });
  });

  group('deleteChatForMe', () {
    test('με ενεργό άλλο → απομακρύνομαι, chat παραμένει', () async {
      await h.seedChatDoc();
      await h.seedCacheRow();

      await h.repo.deleteChatForMe('chat1');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect(chat.exists, isTrue);
      final data = chat.data()!;
      expect(data['participants'], [kTestOther]);
      expect((data['participantIsActive'] as Map)[kTestUid], isFalse);

      final rows = await h.db.select(h.db.chatCacheTable).get();
      expect(rows, isEmpty);

      final msgs = await h.firestore
          .collection('chats').doc('chat1').collection('messages').get();
      expect(msgs.docs.single.data()['action'], 'delete_local');
    });

    test('χωρίς ενεργό άλλο → πλήρης διαγραφή', () async {
      await h.seedChatDoc(extra: {
        'participantIsActive': {kTestOther: false},
      });
      await h.seedCacheRow();

      await h.repo.deleteChatForMe('chat1');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect(chat.exists, isFalse);
      final rows = await h.db.select(h.db.chatCacheTable).get();
      expect(rows, isEmpty);
    });
  });

  group('deleteAllChatMedia', () {
    test('VM χωρίς FirebaseStorage → δεν ρίχνει (non-fatal)', () async {
      await deleteAllChatMedia('chatVoid');
    });
  });
}