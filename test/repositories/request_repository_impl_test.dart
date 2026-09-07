import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/repositories/auth_repository.dart';
import 'package:near_me/repositories/request_repository_impl.dart';

import '../helpers/failing_firestore.dart';
import '../helpers/request_repository_test_base.dart';

void main() {
  late RequestRepoHarness h;

  setUp(() async {
    h = await RequestRepoHarness.create();
    resetSigningOut();
  });

  tearDown(() async {
    resetSigningOut();
    await h.close();
  });

  Future<void> seedRequest({
    String docId = 'req1',
    String? fromUid,
    String? toUid,
    String type = 'chat',
    String status = 'pending',
    String? chatId,
    bool allowDirectChat = false,
    bool allowVideoCall = false,
  }) async {
    await h.firestore.collection('requests').doc(docId).set({
      'fromUid': fromUid ?? kReqOtherUid,
      'toUid': toUid ?? kReqTestUid,
      'type': type,
      'status': status,
      'createdAt': DateTime.now(),
      'chatId': chatId,
    });
  }

  group('sendRequest', () {
    test('no user → auth_error', () async {
      await expectLater(
        h.repoNoUser.sendRequest(kReqOtherUid, 'chat'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('unverified → auth_error (guard)', () async {
      final r = h.repoUnverified();
      await expectLater(
        r.sendRequest(kReqOtherUid, 'chat'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('rate-limited → request_rate_limited', () async {
      await expectLater(
        h.repoRateLimited().sendRequest(kReqOtherUid, 'chat'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'request_rate_limited')),
      );
    });

    test('blocked by target → auth_error', () async {
      await h.seedBlocked(kReqOtherUid, kReqTestUid);
      await h.seedPublicProfile(kReqOtherUid);
      await expectLater(
        h.repo.sendRequest(kReqOtherUid, 'chat'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('target χωρίς public profile → auth_error', () async {
      await expectLater(
        h.repo.sendRequest(kReqOtherUid, 'chat'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('type=chat & allowDirectChat=false → auth_error', () async {
      await h.seedPublicProfile(kReqOtherUid, allowDirectChat: false);
      await expectLater(
        h.repo.sendRequest(kReqOtherUid, 'chat'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('type=video & allowVideoCall=false → auth_error', () async {
      await h.seedPublicProfile(kReqOtherUid, allowVideoCall: false);
      await expectLater(
        h.repo.sendRequest(kReqOtherUid, 'video'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('επιτυχία → requests doc + consent log', () async {
      await h.seedPublicProfile(kReqOtherUid, allowDirectChat: true);
      await h.repo.sendRequest(kReqOtherUid, 'chat', message: 'Γεια');

      final snapshot = await h.firestore.collection('requests').get();
      expect(snapshot.docs, hasLength(1));
      final data = snapshot.docs.single.data();
      expect(data['fromUid'], kReqTestUid);
      expect(data['toUid'], kReqOtherUid);
      expect(data['type'], 'chat');
      expect(data['status'], 'pending');
      expect(data['message'], 'Γεια');

      final logs = await (h.db.select(h.db.consentLogTable)).get();
      expect(logs.map((l) => l.action), contains('sent_request'));
    });

    test('Firestore write fail → firestore_error', () async {
      final failing = RequestRepositoryImpl(
        firestore: failingRequestsFirestore(),
        auth: h.auth,
        db: h.db,
        chatRepo: h.realChatRepo,
        rateLimitCheck: () async => true,
      );
      await expectLater(
        failing.sendRequest(kReqOtherUid, 'chat'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'firestore_error')),
      );
    });
  });

  group('getIncomingRequests / getOutgoingRequests', () {
    test('no user → []', () async {
      expect(await h.repoNoUser.getIncomingRequests(), isEmpty);
      expect(await h.repoNoUser.getOutgoingRequests(), isEmpty);
    });

    test('getIncomingRequests → list με id', () async {
      await seedRequest(docId: 'req1', toUid: kReqTestUid);
      await seedRequest(docId: 'req2', toUid: kReqOtherUid);

      final results = await h.repo.getIncomingRequests();
      expect(results, hasLength(1));
      expect(results.single['id'], 'req1');
    });

    test('getOutgoingRequests → list με id', () async {
      await seedRequest(docId: 'req1', fromUid: kReqTestUid);
      await seedRequest(docId: 'req2', fromUid: kReqOtherUid);

      final results = await h.repo.getOutgoingRequests();
      expect(results, hasLength(1));
      expect(results.single['id'], 'req1');
    });

    RequestRepositoryImpl failingRepo() => RequestRepositoryImpl(
          firestore: failingRequestsFirestore(),
          auth: h.auth,
          db: h.db,
          chatRepo: h.realChatRepo,
          rateLimitCheck: () async => true,
        );

    test('getIncomingRequests Firestore read fail → firestore_error', () async {
      await expectLater(
        failingRepo().getIncomingRequests(),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'firestore_error')),
      );
    });

    test('getOutgoingRequests Firestore read fail → firestore_error', () async {
      await expectLater(
        failingRepo().getOutgoingRequests(),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'firestore_error')),
      );
    });
  });

  group('streamIncomingRequests / streamOutgoingRequests', () {
    test('signing-out → Stream.empty()', () async {
      AuthRepository.setSigningOut(true);
      expect(await h.repo.streamIncomingRequests().toList(), isEmpty);
      expect(await h.repo.streamOutgoingRequests().toList(), isEmpty);
    });

    test('no user → Stream.empty()', () async {
      expect(await h.repoNoUser.streamIncomingRequests().toList(), isEmpty);
      expect(await h.repoNoUser.streamOutgoingRequests().toList(), isEmpty);
    });

    test('κανονικό → emits request lists', () async {
      await seedRequest(docId: 'req1', toUid: kReqTestUid);
      final incoming =
          await h.repo.streamIncomingRequests().first;
      expect(incoming.single['id'], 'req1');

      await seedRequest(docId: 'req2', fromUid: kReqTestUid);
      final outgoing =
          await h.repo.streamOutgoingRequests().first;
      expect(outgoing.single['id'], 'req2');
    });
  });

  group('respondToRequest', () {
    test('invalid status → validation_error', () async {
      await expectLater(
        h.repo.respondToRequest('req1', 'weird'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('no user → auth_error', () async {
      await expectLater(
        h.repoNoUser.respondToRequest('req1', 'accepted'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('unverified → auth_error (guard)', () async {
      final r = h.repoUnverified();
      await expectLater(
        r.respondToRequest('req1', 'accepted'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('not found → not_found', () async {
      await expectLater(
        h.repo.respondToRequest('missing', 'accepted'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'not_found')),
      );
    });

    test('already responded → conflict', () async {
      await seedRequest(docId: 'req1', status: 'accepted');
      await expectLater(
        h.repo.respondToRequest('req1', 'declined'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'conflict')),
      );
    });

    test('unauthorized (toUid mismatch) → auth_error', () async {
      await seedRequest(docId: 'req1', toUid: kReqOtherUid);
      await expectLater(
        h.repo.respondToRequest('req1', 'accepted'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('accepted + type=chat + no chatId → δημιουργεί chat + update',
        () async {
      await h.seedPublicProfile(kReqTestUid);
      await h.seedPublicProfile(kReqOtherUid);
      await seedRequest(
        docId: 'req1',
        fromUid: kReqOtherUid,
        toUid: kReqTestUid,
        type: 'chat',
      );

      final chatId = await h.repo.respondToRequest('req1', 'accepted');
      expect(chatId, isNotNull);

      final doc = await h.firestore.collection('requests').doc('req1').get();
      expect(doc.data()!['status'], 'accepted');
      expect(doc.data()!['chatId'], chatId);

      final chat = await h.firestore.collection('chats').doc(chatId!).get();
      expect(chat.exists, isTrue);
    });

    test('accepted + ήδη chatId → update με chatId', () async {
      await seedRequest(
        docId: 'req1',
        chatId: 'existing_chat',
      );
      final chatId = await h.repo.respondToRequest('req1', 'accepted');
      expect(chatId, 'existing_chat');
      final doc = await h.firestore.collection('requests').doc('req1').get();
      expect(doc.data()!['chatId'], 'existing_chat');
    });

    test('declined → update χωρίς chatId', () async {
      await seedRequest(docId: 'req1');
      final chatId = await h.repo.respondToRequest('req1', 'declined');
      expect(chatId, isNull);
      final doc = await h.firestore.collection('requests').doc('req1').get();
      expect(doc.data()!['status'], 'declined');
      expect(doc.data()!['chatId'], isNull);
    });

    test('Firestore read fail → firestore_error', () async {
      final failing = RequestRepositoryImpl(
        firestore: failingRequestsFirestore(),
        auth: h.auth,
        db: h.db,
        chatRepo: h.realChatRepo,
        rateLimitCheck: () async => true,
      );
      await expectLater(
        failing.respondToRequest('req1', 'accepted'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'firestore_error')),
      );
    });
  });

  group('deleteRequest', () {
    test('no user → auth_error', () async {
      await expectLater(
        h.repoNoUser.deleteRequest('req1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('unverified → auth_error', () async {
      final r = h.repoUnverified();
      await expectLater(
        r.deleteRequest('req1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('not found → no-op', () async {
      await h.repo.deleteRequest('missing');
      final snapshot = await h.firestore.collection('requests').get();
      expect(snapshot.docs, isEmpty);
    });

    test('unauthorized → auth_error', () async {
      await seedRequest(docId: 'req1', fromUid: 'someoneelse', toUid: 'someoneelse2');
      await expectLater(
        h.repo.deleteRequest('req1'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('επιτυχία → deleted', () async {
      await seedRequest(docId: 'req1', fromUid: kReqTestUid);
      await h.repo.deleteRequest('req1');
      final doc = await h.firestore.collection('requests').doc('req1').get();
      expect(doc.exists, isFalse);
    });
  });

  group('markRequestAsSeen', () {
    test('no user → no-op', () async {
      await h.repoNoUser.markRequestAsSeen('req1');
      final snapshot = await h.firestore.collection('requests').get();
      expect(snapshot.docs, isEmpty);
    });

    test('επιτυχία → readAt updated', () async {
      await seedRequest(docId: 'req1');
      await h.repo.markRequestAsSeen('req1');
      final doc = await h.firestore.collection('requests').doc('req1').get();
      expect(doc.data()!['readAt'], isNotNull);
    });
  });
}