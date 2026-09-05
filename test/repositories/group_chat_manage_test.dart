import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/repositories/chat_repository.dart';

import '../helpers/chat_repository_test_base.dart';

void main() {
  late ChatRepoHarness h;

  setUp(() async {
    h = await ChatRepoHarness.create();
  });

  tearDown(() async {
    await h.close();
  });

  Future<void> seedProfile(String uid, String nickname) async {
    await h.firestore
        .collection('users').doc(uid).collection('public').doc('profile')
        .set({'nickname': nickname});
  }

  /// Seed group document με τον kTestUid σε συγκεκριμένο role.
  Future<void> seedGroup({
    String chatId = 'g1',
    String uidRole = 'creator',
    String otherRole = 'member',
    String? groupName = 'Ομάδα',
    Map<String, dynamic>? extra,
    List<String>? participants,
  }) async {
    await h.seedChatDoc(
      chatId: chatId,
      isGroupChat: true,
      participants: participants ?? [kTestUid, kTestOther],
      extra: {
        'groupName': groupName,
        'participantRoles': {kTestUid: uidRole, kTestOther: otherRole},
        'createdBy': kTestUid,
        'maxParticipants': 10,
        'messageExpiry': 'off',
        ...?extra,
      },
    );
  }

  group('createGroupChat', () {
    test('no user → auth_error', () async {
      await expectLater(
        h.repoNoUser().createGroupChat([kTestOther]),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('κενό participants → auth_error', () async {
      await expectLater(
        h.repo.createGroupChat([]),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('πάνω από 9 άτομα → auth_error', () async {
      final many = List.generate(10, (i) => 'u$i');
      await expectLater(
        h.repo.createGroupChat(many),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('περιέχει τον εαυτό μου → auth_error', () async {
      await expectLater(
        h.repo.createGroupChat([kTestOther, kTestUid]),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('duplicate participants → auth_error', () async {
      await expectLater(
        h.repo.createGroupChat([kTestOther, kTestOther]),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('success → σωστό group doc + role + system group_created + consent',
        () async {
      await seedProfile(kTestUid, 'Εγώ');
      await seedProfile(kTestOther, 'Άλλος');

      final chatId = await h.repo.createGroupChat([kTestOther]);

      final doc = await h.firestore.collection('chats').doc(chatId).get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['isGroupChat'], isTrue);
      expect(data['participants'], [kTestUid, kTestOther]);
      expect(data['participantRoles'], {kTestUid: 'creator', kTestOther: 'member'});
      expect(data['participantNicknames'], {kTestUid: 'Εγώ', kTestOther: 'Άλλος'});
      expect(data['groupName'], 'Εγώ, Άλλος');
      expect(data['maxParticipants'], 10);
      expect(data['messageExpiry'], 'off');
      expect(data['permissionOverrides'], isEmpty);

      final msgs = await h.firestore
          .collection('chats').doc(chatId).collection('messages').get();
      final sysMsg = msgs.docs.single.data()['content'] as String;
      expect(sysMsg, contains('Εγώ δημιούργησε την ομάδα'));

      final consent = await h.db.select(h.db.consentLogTable).get();
      expect(consent, isNotEmpty);
      expect(consent.first.action, 'group_created');
    });

    test('custom groupName + isPublic → groupName + public profile', () async {
      await seedProfile(kTestUid, 'Εγώ');
      await seedProfile(kTestOther, 'Άλλος');

      final chatId = await h.repo
          .createGroupChat([kTestOther], groupName: 'Ταξιδιώτες', isPublic: true);

      final doc = await h.firestore.collection('chats').doc(chatId).get();
      expect(doc.data()!['groupName'], 'Ταξιδιώτες');
      expect(doc.data()!['isPublic'], isTrue);

      final pub = await h.firestore.collection('groups').doc(chatId).get();
      expect(pub.exists, isTrue);
      expect(pub.data()!['groupName'], 'Ταξιδιώτες');
    });
  });

  group('updateGroupName', () {
    test('χωρίς δικαίωμα (member) → auth_error', () async {
      await seedGroup(uidRole: 'member', otherRole: 'creator');
      await expectLater(
        h.repo.updateGroupName('g1', 'Νέο'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('κενό όνομα → auth_error', () async {
      await seedGroup();
      await expectLater(
        h.repo.updateGroupName('g1', '   '),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('creator → ενημέρωση + system name_changed + cache sync', () async {
      await seedGroup();
      await h.seedCacheRow(chatId: 'g1');

      await h.repo.updateGroupName('g1', 'Νέα Ομάδα');

      final doc = await h.firestore.collection('chats').doc('g1').get();
      expect(doc.data()!['groupName'], 'Νέα Ομάδα');

      final msgs = await h.firestore
          .collection('chats').doc('g1').collection('messages').get();
      expect(
        msgs.docs.single.data()['content'],
        'Νέα Ομάδα: Me άλλαξε το όνομα σε Νέα Ομάδα',
      );

      final rows = await h.db.select(h.db.chatCacheTable).get();
      expect(rows.first.groupName, 'Νέα Ομάδα');
    });
  });

  group('updateParticipantRole', () {
    test('χωρίς δικαίωμα (member) → auth_error', () async {
      await seedGroup(uidRole: 'member', otherRole: 'creator');
      await expectLater(
        h.repo.updateParticipantRole('g1', kTestOther, 'admin'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('αλλαγή δικού μου ρόλου → auth_error', () async {
      await seedGroup();
      await expectLater(
        h.repo.updateParticipantRole('g1', kTestUid, 'admin'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('αλλαγή ρόλου creator → auth_error', () async {
      await seedGroup(uidRole: 'admin', otherRole: 'creator');
      await expectLater(
        h.repo.updateParticipantRole('g1', kTestOther, 'member'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('creator/admin → member γίνεται admin + audit + system message',
        () async {
      await seedGroup();
      await h.repo.updateParticipantRole('g1', kTestOther, 'admin');

      final doc = await h.firestore.collection('chats').doc('g1').get();
      expect(
        (doc.data()!['participantRoles'] as Map)[kTestOther],
        'admin',
      );

      final audit = await h.firestore
          .collection('chats').doc('g1').collection('audit_log').get();
      expect(audit.docs.single.data()['action'], 'role_changed');

      final msgs = await h.firestore
          .collection('chats').doc('g1').collection('messages').get();
      expect(
        msgs.docs.single.data()['content'],
        'Ομάδα: Me όρισε τον/την Other ως Διαχειριστή',
      );
    });
  });

  group('updateMaxParticipants', () {
    test('member → auth_error', () async {
      await seedGroup(uidRole: 'member', otherRole: 'creator');
      await expectLater(
        h.repo.updateMaxParticipants('g1', 20),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('εκτός εύρους (<2 ή >100) → auth_error', () async {
      await seedGroup();
      await expectLater(
        h.repo.updateMaxParticipants('g1', 1),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
      await expectLater(
        h.repo.updateMaxParticipants('g1', 101),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('μικρότερο από τα τρέχοντα μέλη → auth_error', () async {
      await seedGroup();
      await expectLater(
        h.repo.updateMaxParticipants('g1', 1),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('creator → ενημέρωση + audit + system message', () async {
      await seedGroup();
      await h.repo.updateMaxParticipants('g1', 50);

      final doc = await h.firestore.collection('chats').doc('g1').get();
      expect(doc.data()!['maxParticipants'], 50);

      final msgs = await h.firestore
          .collection('chats').doc('g1').collection('messages').get();
      expect(
        msgs.docs.single.data()['content'],
        'Ομάδα: Me άλλαξε το όριο μελών σε 50',
      );
    });
  });

  group('updateMessageExpiry', () {
    test('μη-creator → chat/message-expiry-creator-only', () async {
      await seedGroup(uidRole: 'admin', otherRole: 'creator');
      await expectLater(
        h.repo.updateMessageExpiry('g1', '24h'),
        throwsA(isA<AppException>().having(
            (e) => e.code, 'code', 'chat/message-expiry-creator-only')),
      );
    });

    test('μη έγκυρη τιμή → chat/message-expiry-invalid-value', () async {
      await seedGroup();
      await expectLater(
        h.repo.updateMessageExpiry('g1', 'bogus'),
        throwsA(isA<AppException>().having(
            (e) => e.code, 'code', 'chat/message-expiry-invalid-value')),
      );
    });

    test('creator → ενημέρωση + system message', () async {
      await seedGroup();
      await h.repo.updateMessageExpiry('g1', '24h');

      final doc = await h.firestore.collection('chats').doc('g1').get();
      expect(doc.data()!['messageExpiry'], '24h');

      final msgs = await h.firestore
          .collection('chats').doc('g1').collection('messages').get();
      expect(
        msgs.docs.single.data()['content'],
        'Ομάδα: Me όρισε αυτόματη διαγραφή μηνυμάτων',
      );
    });
  });

  group('deleteGroup', () {
    test('όχι group chat → auth_error', () async {
      await h.seedChatDoc();
      await expectLater(
        h.repo.deleteGroup('chat1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('member → auth_error', () async {
      await seedGroup(uidRole: 'member', otherRole: 'creator');
      await expectLater(
        h.repo.deleteGroup('g1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('creator → πλήρης διαγραφή (doc, subcollections, cache)', () async {
      await seedGroup();
      await h.seedCacheRow(chatId: 'g1');
      await h.seedMessage('g1', 'm1', senderId: kTestOther);
      await h.firestore
          .collection('chats').doc('g1').collection('audit_log').doc('a1')
          .set({'action': 'group_created'});

      await h.repo.deleteGroup('g1');

      final doc = await h.firestore.collection('chats').doc('g1').get();
      expect(doc.exists, isFalse);
      final msgs = await h.firestore
          .collection('chats').doc('g1').collection('messages').get();
      expect(msgs.docs, isEmpty);
      final audit = await h.firestore
          .collection('chats').doc('g1').collection('audit_log').get();
      expect(audit.docs, isEmpty);
      final rows = await h.db.select(h.db.chatCacheTable).get();
      expect(rows, isEmpty);
    });
  });

  group('getParticipantUids', () {
    test('φιλτράρει τους ανενεργούς', () async {
      await seedGroup(participants: [kTestUid, kTestOther, 'u3'], extra: {
        'participantIsActive': {kTestUid: true, kTestOther: false, 'u3': true},
      });

      final uids = await h.repo.getParticipantUids('g1');

      expect(uids, containsAll([kTestUid, 'u3']));
      expect(uids, isNot(contains(kTestOther)));
    });
  });

  group('hasPermission', () {
    test('member: false · creator: true', () async {
      await seedGroup();
      expect(await h.repo.hasPermission('g1', GroupPermission.deleteMessages), isTrue);

      await seedGroup(chatId: 'g2', uidRole: 'member', otherRole: 'creator');
      expect(await h.repo.hasPermission('g2', GroupPermission.deleteMessages),
          isFalse);
    });
  });
}