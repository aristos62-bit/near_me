import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/core/utils/encryption_utils.dart';
import 'package:near_me/data/local/database.dart';

import '../helpers/chat_repository_test_base.dart';
import '../helpers/fake_firestore_helpers.dart';

void main() {
  late ChatRepoHarness h;

  setUp(() async {
    h = await ChatRepoHarness.create();
  });

  tearDown(() async {
    await h.close();
  });

  group('χωρίς authenticated user / unverified', () {
    test('getChats → [] χωρίς user', () async {
      expect(await h.repoNoUser().getChats(), isEmpty);
    });

    test('markAsRead → no-op χωρίς user (κανένα exception)', () async {
      await h.repoNoUser().markAsRead('chat1');
    });

    test('createChat → auth_error χωρίς user', () async {
      await expectLater(
        h.repoNoUser().createChat(kTestOther),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('sendMessage → auth_error χωρίς user', () async {
      await expectLater(
        h.repoNoUser().sendMessage('chat1', 'γεια'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('addReaction/removeReaction → auth_error χωρίς user', () async {
      await expectLater(
        h.repoNoUser().addReaction('chat1', 'm1', '🔥'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
      await expectLater(
        h.repoNoUser().removeReaction('chat1', 'm1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('createChat/sendMessage → blocked unverified user', () async {
      await expectLater(
        h.repoUnverified().createChat(kTestOther),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
      await expectLater(
        h.repoUnverified().sendMessage('chat1', 'γεια'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });
  });

  group('getChats', () {
    test('ordering desc lastMessageAt + πεδία cache', () async {
      await h.seedCacheRow(
        chatId: 'old',
        otherNickname: 'Παλιό',
        lastMessage: 'πρώτο μήνυμα',
        lastMessageAt: DateTime(2026, 1, 1),
      );
      await h.seedCacheRow(
        chatId: 'new',
        otherNickname: 'Νέο',
        lastMessage: 'τελευταίο',
        lastMessageAt: DateTime(2026, 6, 1),
      );

      final chats = await h.repo.getChats();

      expect(chats, hasLength(2));
      expect(chats.first.chatId, 'new');
      expect(chats.first.otherNickname, 'Νέο');
      expect(chats.first.lastMessage, 'τελευταίο');
    });
  });

  group('updateChatCache', () {
    test('δεν κάνει τίποτα όταν δεν υπάρχει row', () async {
      await h.repo.updateChatCache('ghost', hasUnread: false);
      final rows = await h.db.select(h.db.chatCacheTable).get();
      expect(rows, isEmpty);
    });

    test('duplicate rows (ίδιο chatId) → guard cleanup σβήνει ΚΑΙ ΤΑ ΔΥΟ',
        () async {
      await h.seedCacheRow(
          chatId: 'c1', otherNickname: 'A', lastMessageAt: DateTime(2026, 1, 1));
      await h.db.into(h.db.chatCacheTable).insert(ChatCacheTableCompanion.insert(
            chatId: const Value('c1'),
            ownerUid: const Value(kTestUid),
            otherUid: const Value(kTestOther),
            otherNickname: const Value('A2'),
            lastMessageAt: Value(DateTime(2026, 2, 1)),
          ));

      await h.repo.updateChatCache('c1', otherNickname: 'B');

      final rows = await h.db.select(h.db.chatCacheTable).get();
      expect(rows, isEmpty);
    });

    test('groupAvatarUrl κενό → null (no change)', () async {
      await h.seedCacheRow(chatId: 'c1', groupAvatarUrl: null);
      await h.repo.updateChatCache('c1', groupAvatarUrl: '');
      final row = await (h.db.select(h.db.chatCacheTable)
            ..where((t) => t.chatId.equals('c1')))
          .getSingle();
      expect(row.groupAvatarUrl, isNull);
    });
  });

  group('createChat', () {
    test('Tier 1: cache hit → επιστρέφει πριν χωρίς Firestore write', () async {
      await h.seedCacheRow(
          chatId: 'existing_1',
          ownerUid: kTestUid,
          otherUid: kTestOther);

      final chatId = await h.repo.createChat(kTestOther);

      expect(chatId, 'existing_1');
      final chats = await h.firestore.collection('chats').get();
      expect(chats.docs, isEmpty);
    });

    test('Tier 2: Firestore scan βρίσκει υπάρχον 1-1 chat', () async {
      await h.firestore.collection('chats').doc('existing_2').set({
        'participants': [kTestUid, kTestOther],
        'isGroupChat': false,
      });

      final chatId = await h.repo.createChat(kTestOther);

      expect(chatId, 'existing_2');
    });

    test('blocked από τον άλλο χρήστη → auth_error', () async {
      await h.firestore
          .collection('users').doc(kTestOther).collection('blocked').doc(kTestUid)
          .set({});
      await expectLater(
        h.repo.createChat(kTestOther),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('success: νέο chat + encrypted key + consent log', () async {
      await seedPublicProfile(
          h.firestore, publicProfileDoc(uid: kTestUid, nickname: 'Me'));
      await seedPublicProfile(
          h.firestore, publicProfileDoc(uid: kTestOther, nickname: 'Other'));

      final chatId = await h.repo.createChat(kTestOther);

      final doc = await h.firestore.collection('chats').doc(chatId).get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['isGroupChat'], isFalse);
      expect((data['participants'] as List).toSet(), {kTestUid, kTestOther});
      expect(data['unreadCount'], {kTestUid: 0, kTestOther: 0});

      final logs = await h.db.select(h.db.consentLogTable).get();
      expect(logs.map((l) => l.action), contains('sent_request'));
      expect(logs.first.dataType, 'chat');
    });
  });

  group('sendMessage', () {
    test('chat not found → firestore_error', () async {
      await expectLater(
        h.repo.sendMessage('missing', 'γεια'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'firestore_error')),
      );
    });

    test('blocked από τον άλλο → auth_error', () async {
      await h.seedChatDoc();
      await h.firestore
          .collection('users').doc(kTestOther).collection('blocked').doc(kTestUid)
          .set({});
      await expectLater(
        h.repo.sendMessage('chat1', 'γεια'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('success: κρυπτογραφημένο μήνυμα + unreadCount + chat update',
        () async {
      await h.seedChatDoc();
      await h.seedCacheRow(chatId: 'chat1', hasUnread: true, unreadCount: 2);

      await h.repo.sendMessage('chat1', 'γεια σου');

      final msgs = await h.firestore
          .collection('chats').doc('chat1').collection('messages').get();
      expect(msgs.docs, hasLength(1));
      final data = msgs.docs.first.data();
      expect(data['senderId'], kTestUid);
      expect(data['type'], 'text');
      expect(data['isRead'], isFalse);
      final decrypted = EncryptionUtils.decryptMessage(
          EncryptionUtils.deriveKey('chat1'), data['content'] as String);
      expect(decrypted, 'γεια σου');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      final chatData = chat.data()!;
      final unread = chatData['unreadCount'] as Map<String, dynamic>;
      expect(unread[kTestOther], 1);
      expect(unread.containsKey(kTestUid), isFalse);
      expect(chatData['lastMessageType'], 'text');
      expect(
          EncryptionUtils.decryptMessage(EncryptionUtils.deriveKey('chat1'),
              chatData['lastMessage'] as String),
          'γεια σου');

      final row = await (h.db.select(h.db.chatCacheTable)
            ..where((t) => t.chatId.equals('chat1')))
          .getSingle();
      expect(row.hasUnread, isFalse);
    });

    test('replyTo + messageExpiry 24h → replyTo field + expiresAt', () async {
      await h.seedChatDoc(messageExpiry: '24h');

      await h.repo.sendMessage('chat1', 'γεια',
          replyTo: {'id': 'm0', 'nickname': 'Other'});

      final msgs = await h.firestore
          .collection('chats').doc('chat1').collection('messages').get();
      final data = msgs.docs.first.data();
      expect(data['replyTo'], {'id': 'm0', 'nickname': 'Other'});
      expect(data['expiresAt'], isNotNull);

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect(chat.data()!['unreadCount'], {kTestOther: 1});
    });

    test('messageExpiry off → χωρίς expiresAt', () async {
      await h.seedChatDoc();
      await h.repo.sendMessage('chat1', 'γεια');
      final msgs = await h.firestore
          .collection('chats').doc('chat1').collection('messages').get();
      expect(msgs.docs.first.data().containsKey('expiresAt'), isFalse);
    });
  });

  group('messagesStream', () {
    test('decrypt ζωντανά τα μηνύματα', () async {
      final key = EncryptionUtils.deriveKey('chat1');
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1',
          content: EncryptionUtils.encryptMessage(key, 'φιλάκι'));

      final first = await h.repo.messagesStream('chat1').first;
      expect(first, hasLength(1));
      expect(first.single['content'], 'φιλάκι');
      expect(first.single['senderId'], kTestOther);
      expect(first.single['type'], 'text');
    });

    test('system και media types περνάνε ως-έχουν', () async {
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1', type: 'system', content: 'Ο Βαγγέλης μπήκε');
      await h.seedMessage('chat1', 'm2', type: 'gif', content: 'https://giphy/x.gif');

      final first = await h.repo.messagesStream('chat1').first;
      expect(first, hasLength(2));
      expect(first.map((m) => m['content']),
          containsAll(['Ο Βαγγέλης μπήκε', 'https://giphy/x.gif']));
    });

    test('corrupt ciphertext → fallback "[Μη αναγνώσιμο μήνυμα...]"', () async {
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1', content: 'not-a-valid-format');

      final first = await h.repo.messagesStream('chat1').first;
      expect(first.single['content'], '[Μη αναγνώσιμο μήνυμα / Unreadable message]');
    });

    test('χωρίς μηνύματα → []', () async {
      await h.seedChatDoc();
      expect(await h.repo.messagesStream('chat1').first, isEmpty);
    });
  });

  group('fetchOlderMessages', () {
    test('επιστρέφει μόνο τα πριν το beforeTimestamp (decrypted)', () async {
      final key = EncryptionUtils.deriveKey('chat1');
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1',
          content: EncryptionUtils.encryptMessage(key, 'παλιό'),
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 1)));
      await h.seedMessage('chat1', 'm2',
          content: EncryptionUtils.encryptMessage(key, 'νέο'),
          timestamp: Timestamp.fromDate(DateTime(2026, 6, 2)));

      final older = await h.repo.fetchOlderMessages('chat1',
          beforeTimestamp: DateTime(2026, 6, 1, 12));

      expect(older, hasLength(1));
      expect(older.single['content'], 'παλιό');
    });
  });

  group('markAsRead', () {
    test('unreadCount=0 → skip firestore write', () async {
      await h.seedChatDoc();
      await h.seedCacheRow(chatId: 'chat1', unreadCount: 0, hasUnread: false);

      await h.repo.markAsRead('chat1');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect(chat.data()!.containsKey('lastReadTimestamps'), isFalse);
    });

    test('1-1: σημαδεύει μόνο τα μηνύματα του άλλου + cache 0', () async {
      await h.seedChatDoc(extra: {
        'unreadCount': {kTestUid: 1, kTestOther: 0},
      });
      await h.seedCacheRow(chatId: 'chat1', unreadCount: 1, hasUnread: true);
      await h.seedMessage('chat1', 'other_msg', senderId: kTestOther, isRead: false);
      await h.seedMessage('chat1', 'my_msg', senderId: kTestUid, isRead: false);

      await h.repo.markAsRead('chat1');

      final otherMsg = await h.firestore
          .collection('chats').doc('chat1').collection('messages').doc('other_msg').get();
      final myMsg = await h.firestore
          .collection('chats').doc('chat1').collection('messages').doc('my_msg').get();
      expect(otherMsg.data()!['isRead'], isTrue);
      expect(myMsg.data()!['isRead'], isFalse);

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      final data = chat.data()!;
      expect(data['lastReadTimestamps'], contains(kTestUid));
      expect((data['unreadCount'] as Map)[kTestUid], 0);

      final row = await (h.db.select(h.db.chatCacheTable)
            ..where((t) => t.chatId.equals('chat1')))
          .getSingle();
      expect(row.unreadCount, 0);
    });
  });

  group('reactions', () {
    test('addReaction με κενό emoji → validation_error', () async {
      await expectLater(
        h.repo.addReaction('chat1', 'm1', ''),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('addReaction blocked → auth_error', () async {
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1', senderId: kTestOther);
      await h.firestore
          .collection('users').doc(kTestOther).collection('blocked').doc(kTestUid)
          .set({});

      await expectLater(
        h.repo.addReaction('chat1', 'm1', '🔥'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('addReaction success → reactions.uid', () async {
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1', senderId: kTestOther);

      await h.repo.addReaction('chat1', 'm1', '🔥');

      final msg = await h.firestore
          .collection('chats').doc('chat1').collection('messages').doc('m1').get();
      expect(msg.data()!['reactions'], {kTestUid: '🔥'});
    });

    test('removeReaction success → reactions.uid σβήνεται', () async {
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1',
          senderId: kTestOther, reactions: {kTestUid: '🔥'});

      await h.repo.removeReaction('chat1', 'm1');

      final msg = await h.firestore
          .collection('chats').doc('chat1').collection('messages').doc('m1').get();
      expect((msg.data()!['reactions'] as Map<String, dynamic>).containsKey(kTestUid),
          isFalse);
    });
  });
}