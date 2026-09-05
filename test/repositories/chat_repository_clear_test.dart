import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/core/utils/encryption_utils.dart';

import '../helpers/chat_repository_test_base.dart';

void main() {
  late ChatRepoHarness h;

  setUp(() async {
    h = await ChatRepoHarness.create();
  });

  tearDown(() async {
    await h.close();
  });

  group('clearMessages', () {
    test('no user → auth_error', () async {
      await expectLater(
        h.repoNoUser().clearMessages('chat1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('1-1 → σβήνει όλα τα μηνύματα (media non-fatal σε VM)', () async {
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1', senderId: kTestOther);
      await h.seedMessage('chat1', 'm2', senderId: kTestUid);

      await h.repo.clearMessages('chat1');

      final msgs = await h.firestore
          .collection('chats').doc('chat1').collection('messages').get();
      expect(msgs.docs, isEmpty);
    });

    test('group χωρίς ρόλο (default member) → auth_error', () async {
      await h.seedChatDoc(
        isGroupChat: true,
        extra: {
          'groupName': 'Ομάδα',
          'participantRoles': {kTestOther: 'creator'},
        },
      );

      await expectLater(
        h.repo.clearMessages('chat1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('group με ρόλο admin → περνάει, μηνύματα σβήνονται', () async {
      await h.seedChatDoc(
        isGroupChat: true,
        extra: {
          'groupName': 'Ομάδα',
          'participantRoles': {kTestUid: 'admin', kTestOther: 'member'},
        },
      );
      await h.seedMessage('chat1', 'm1', senderId: kTestOther);

      await h.repo.clearMessages('chat1');

      final msgs = await h.firestore
          .collection('chats').doc('chat1').collection('messages').get();
      expect(msgs.docs, isEmpty);
    });
  });

  group('clearMessageCaches', () {
    test('smoke: δεν ρίχνει', () {
      h.repo.clearMessageCaches('chat1');
    });
  });

  group('editMessage', () {
    test('no user → auth_error', () async {
      await expectLater(
        h.repoNoUser().editMessage('chat1', 'm1', 'νέο'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('unverified → auth_error', () async {
      await expectLater(
        h.repoUnverified().editMessage('chat1', 'm1', 'νέο'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('μήνυμα δεν υπάρχει → firestore_error', () async {
      await h.seedChatDoc();
      await expectLater(
        h.repo.editMessage('chat1', 'ghost', 'νέο'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'firestore_error')),
      );
    });

    test('μήνυμα άλλου → auth_error', () async {
      await h.seedChatDoc();
      await h.seedMessage('chat1', 'm1', senderId: kTestOther);

      await expectLater(
        h.repo.editMessage('chat1', 'm1', 'νέο'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('μήνυμα μη-text → validation_error', () async {
      await h.seedChatDoc();
      await h.seedMessage(
        'chat1',
        'm1',
        senderId: kTestUid,
        type: 'image',
      );

      await expectLater(
        h.repo.editMessage('chat1', 'm1', 'νέο'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('δικό μου text → encrypted + edited=true, decryptable', () async {
      await h.seedChatDoc();
      await h.seedMessage(
        'chat1',
        'm1',
        senderId: kTestUid,
        content: EncryptionUtils.encryptMessage(
            EncryptionUtils.deriveKey('chat1'), 'παλιό'),
      );

      await h.repo.editMessage('chat1', 'm1', 'νέο κείμενο');

      final doc = await h.firestore
          .collection('chats').doc('chat1').collection('messages').doc('m1').get();
      final data = doc.data()!;
      expect(data['edited'], isTrue);
      expect(data['editedAt'], isA<Timestamp>());
      final decrypted = EncryptionUtils.decryptMessage(
          EncryptionUtils.deriveKey('chat1'), data['content'] as String);
      expect(decrypted, 'νέο κείμενο');
    });
  });
}