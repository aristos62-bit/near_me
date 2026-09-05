import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';

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

  Future<void> seedGroup({
    String chatId = 'g1',
    String uidRole = 'creator',
    String otherRole = 'member',
    String? groupName = 'Ομάδα',
    bool isPublic = false,
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
        if (isPublic) 'isPublic': true,
        ...?extra,
      },
    );
  }

  Future<void> seedInvite(
    String chatId,
    String inviteId, {
    String? token,
    Timestamp? expiresAt,
    int? maxUses,
    int useCount = 0,
    bool isRevoked = false,
  }) async {
    await h.firestore
        .collection('chats').doc(chatId).collection('invites').doc(inviteId)
        .set({
      'token': token ?? 'tok_$inviteId',
      'createdBy': kTestUid,
      'expiresAt': expiresAt ?? Timestamp.fromDate(DateTime(2027, 1, 1)),
      'maxUses': maxUses ?? 10,
      'usedBy': const [],
      'useCount': useCount,
      'isRevoked': isRevoked,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  }

  group('addParticipant', () {
    test('χωρίς δικαίωμα (member) → auth_error πριν CF', () async {
      await seedGroup(uidRole: 'member', otherRole: 'creator');
      await expectLater(
        h.repo.addParticipant('g1', 'u_new'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('προσθήκη του εαυτού μου → auth_error πριν CF', () async {
      await seedGroup();
      await expectLater(
        h.repo.addParticipant('g1', kTestUid),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('creator + έγκυρο → CF unavailable σε VM → firestore_error', () async {
      await seedGroup();
      // Το addGroupParticipant τρέχει σε Cloud Function (europe-west1).
      // Σε unit test χωρίς emulator η κλήση αποτυγχάνει με AppException.firestore.
      await expectLater(
        h.repo.addParticipant('g1', 'u_new'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'firestore_error')),
      );
    });
  });

  group('removeParticipant', () {
    test('member δεν μπορεί να αφαιρέσει άλλον → auth_error', () async {
      await seedGroup(uidRole: 'member', otherRole: 'creator');
      await expectLater(
        h.repo.removeParticipant('g1', 'u3'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('admin αφαιρεί member → χωρίς local CF, πλήρης ροή', () async {
      await seedGroup(uidRole: 'admin', otherRole: 'member');
      await h.firestore.collection('chats').doc('g1').update({
        'participantRoles.u3': 'member',
        'participants': FieldValue.arrayUnion(['u3']),
      });

      await h.repo.removeParticipant('g1', 'u3');

      final doc = await h.firestore.collection('chats').doc('g1').get();
      final data = doc.data()!;
      expect(data['participants'], isNot(contains('u3')));
      expect((data['participantIsActive'] as Map)['u3'], isFalse);

      final msgs = await h.firestore
          .collection('chats').doc('g1').collection('messages').get();
      expect(
        msgs.docs.single.data()['content'],
        contains('αφαίρεσε τον/την'),
      );

      final audit = await h.firestore
          .collection('chats').doc('g1').collection('audit_log').get();
      expect(audit.docs.single.data()['action'], 'participant_removed');
    });

    test('admin αφαιρεί creator → creator μεταφέρεται στον admin', () async {
      await seedGroup(uidRole: 'admin', otherRole: 'creator');

      await h.repo.removeParticipant('g1', kTestOther);

      final doc = await h.firestore.collection('chats').doc('g1').get();
      final roles = (doc.data()!['participantRoles'] as Map)
          .cast<String, dynamic>();
      expect(roles[kTestUid], 'creator');
      expect(roles.containsKey(kTestOther), isFalse);
    });

    test('self-removal → πάει μέσω CF, στο VM ρίχνει (καμία τοπική αλλαγή)',
        () async {
      await seedGroup();
      // leaveGroup τρέχει σε Cloud Function — χωρίς emulator αποτυγχάνει.
      // Κρίσιμο: ΔΕΝ εφαρμόζονται τοπικές αλλαγές (χρήστης παραμένει).
      await expectLater(
        h.repo.removeParticipant('g1', kTestUid),
        throwsA(isA<Object>()),
      );

      final doc = await h.firestore.collection('chats').doc('g1').get();
      expect(doc.data()!['participants'], contains(kTestUid));
    });
  });

  group('joinPublicGroup', () {
    test('ιδιωτική ομάδα → auth_error join_public', () async {
      await seedGroup(participants: [kTestOther, 'u3']);
      await expectLater(
        h.repo.joinPublicGroup('g1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('ήδη μέλος → auth_error join_public', () async {
      await seedGroup(isPublic: true);
      await expectLater(
        h.repo.joinPublicGroup('g1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('γεμάτη ομάδα → auth_error join_public', () async {
      await seedGroup(
        isPublic: true,
        participants: [kTestOther, 'u3'],
        extra: {'maxParticipants': 2},
      );
      await expectLater(
        h.repo.joinPublicGroup('g1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('success → προσθήκη + nickname + role member + system + consent',
        () async {
      await seedGroup(isPublic: true, participants: [kTestOther, 'u3']);
      await seedProfile(kTestUid, 'Εγώ');

      await h.repo.joinPublicGroup('g1');

      final doc = await h.firestore.collection('chats').doc('g1').get();
      final data = doc.data()!;
      expect(data['participants'], contains(kTestUid));
      expect((data['participantNicknames'] as Map)[kTestUid], 'Εγώ');
      expect((data['participantRoles'] as Map)[kTestUid], 'member');

      final msgs = await h.firestore
          .collection('chats').doc('g1').collection('messages').get();
      expect(
        msgs.docs.single.data()['content'],
        contains('Εγώ εντάχθηκε στην ομάδα'),
      );

      final consent = await h.db.select(h.db.consentLogTable).get();
      expect(consent.first.action, 'group_joined');
    });
  });

  group('invites', () {
    test('createInviteLink χωρίς δικαίωμα → auth_error', () async {
      await seedGroup(uidRole: 'member', otherRole: 'creator');
      await expectLater(
        h.repo.createInviteLink('g1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('createInviteLink creator → token + invite doc', () async {
      await seedGroup();
      final token = await h.repo.createInviteLink('g1');

      expect(token, isNotEmpty);
      final invites = await h.firestore
          .collection('chats').doc('g1').collection('invites').get();
      expect(invites.docs, hasLength(1));
      expect(invites.docs.single.data()['token'], token);
      expect(invites.docs.single.data()['maxUses'], 10);
      expect(invites.docs.single.data()['isRevoked'], isFalse);
    });

    test('getActiveInvites φιλτράρει τα revoked', () async {
      await seedGroup();
      await seedInvite('g1', 'a', token: 'tok_a');
      await seedInvite('g1', 'b', token: 'tok_b', isRevoked: true);

      final active = await h.repo.getActiveInvites('g1');

      expect(active, hasLength(1));
      expect(active.single.token, 'tok_a');
    });

    test('revokeInvite → isRevoked=true', () async {
      await seedGroup();
      await seedInvite('g1', 'a', token: 'tok_a');

      await h.repo.revokeInvite('g1', 'a');

      final invite = await h.firestore
          .collection('chats').doc('g1').collection('invites').doc('a').get();
      expect(invite.data()!['isRevoked'], isTrue);
    });

    test('getInviteInfo valid → πληροφορίες + groupName', () async {
      await seedGroup();
      await seedInvite('g1', 'a', token: 'tok_a');

      final info = await h.repo.getInviteInfo('tok_a');

      expect(info, isNotNull);
      expect(info!.token, 'tok_a');
      expect(info.groupName, 'Ομάδα');
      expect(info.maxUses, 10);
    });

    test('redeemInviteLink invalid → null', () async {
      await seedGroup();
      final chatId = await h.repo.redeemInviteLink('δεν-υπάρχει');
      expect(chatId, isNull);
    });

    test('redeemInviteLink expired → null', () async {
      await seedGroup();
      await seedInvite('g1', 'a',
          token: 'tok_exp',
          expiresAt: Timestamp.fromDate(DateTime(2020, 1, 1)));

      final chatId = await h.repo.redeemInviteLink('tok_exp');

      expect(chatId, isNull);
    });

    test('redeemInviteLink max uses reached → null', () async {
      await seedGroup();
      await seedInvite('g1', 'a', token: 'tok_full', maxUses: 1, useCount: 1);

      final chatId = await h.repo.redeemInviteLink('tok_full');

      expect(chatId, isNull);
    });

    test('redeemInviteLink valid → addParticipant απορρίπτει τον εαυτό (auth_error)',
        () async {
      await seedGroup();
      await seedInvite('g1', 'a', token: 'tok_ok');

      // Το redeem καλεί addParticipant(chatId, user.uid) — προσθήκη του
      // ίδιου χρήστη → auth_error πριν καν την Cloud Function.
      await expectLater(
        h.repo.redeemInviteLink('tok_ok'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });
  });

  group('removeGroupAvatar', () {
    test('storage unavailable σε VM → non-fatal, δεν ρίχνει', () async {
      await seedGroup(extra: {'groupAvatarUrl': 'https://x/avatar.jpg'});

      await h.repo.removeGroupAvatar('g1');

      final doc = await h.firestore.collection('chats').doc('g1').get();
      expect(doc.data()!['groupAvatarUrl'], 'https://x/avatar.jpg');
    });
  });
}