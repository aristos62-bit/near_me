import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/firestore_cleanup.dart';

void main() {
  group('deleteChatSubcollection', () {
    test('deletes all docs in the subcollection', () async {
      final firestore = FakeFirebaseFirestore();
      const chatId = 'chat_1';
      const sub = 'messages';

      for (var i = 0; i < 10; i++) {
        await firestore
            .collection('chats').doc(chatId).collection(sub).doc('m$i')
            .set({'n': i});
      }

      await deleteChatSubcollection(firestore, chatId, sub);

      final remaining = await firestore
          .collection('chats').doc(chatId).collection(sub).get();
      expect(remaining.docs, isEmpty);
    });

    test('deletes more than 500 docs using multiple batches (pagination)', () async {
      final firestore = FakeFirebaseFirestore();
      const chatId = 'chat_big';
      const sub = 'messages';
      const total = 1200;

      for (var i = 0; i < total; i++) {
        await firestore
            .collection('chats').doc(chatId).collection(sub).doc('m$i')
            .set({'n': i});
      }

      await deleteChatSubcollection(firestore, chatId, sub);

      final remaining = await firestore
          .collection('chats').doc(chatId).collection(sub).get();
      expect(remaining.docs, isEmpty);
    });

    test('leaves the chat document untouched', () async {
      final firestore = FakeFirebaseFirestore();
      const chatId = 'chat_keep';

      await firestore.collection('chats').doc(chatId).set({'groupName': 'G'});
      await firestore
          .collection('chats').doc(chatId).collection('audit_log')
          .doc('a1').set({'action': 'x'});

      await deleteChatSubcollection(firestore, chatId, 'audit_log');

      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      expect(chatDoc.exists, isTrue);
      expect(chatDoc.data()?['groupName'], 'G');
    });

    test('non-fatal: does not throw when subcollection is missing (fatal=false)', () async {
      final firestore = FakeFirebaseFirestore();
      const chatId = 'chat_empty';

      await expectLater(
        deleteChatSubcollection(firestore, chatId, 'messages', fatal: false),
        completes,
      );
    });

    test('fatal: is harmless on an empty subcollection (default fatal=true)', () async {
      final firestore = FakeFirebaseFirestore();
      const chatId = 'chat_empty_fatal';

      await expectLater(
        deleteChatSubcollection(firestore, chatId, 'messages'),
        completes,
      );
    });

    test('deletes exactly the targeted subcollection, not siblings', () async {
      final firestore = FakeFirebaseFirestore();
      const chatId = 'chat_siblings';

      await firestore
          .collection('chats').doc(chatId).collection('invites')
          .doc('i1').set({'token': 't1'});
      await firestore
          .collection('chats').doc(chatId).collection('messages')
          .doc('m1').set({'n': 1});

      await deleteChatSubcollection(firestore, chatId, 'messages');

      final invites = await firestore
          .collection('chats').doc(chatId).collection('invites').get();
      final messages = await firestore
          .collection('chats').doc(chatId).collection('messages').get();

      expect(invites.docs, hasLength(1));
      expect(messages.docs, isEmpty);
    });
  });
}
