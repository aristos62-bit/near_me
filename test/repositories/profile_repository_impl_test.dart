import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/repositories/profile_repository_impl.dart';

import '../helpers/fake_firestore_helpers.dart';

class _MockUser extends Mock implements User {}

void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late ProfileRepositoryImpl repo;
  late _MockUser user;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    user = _MockUser();
    when(() => user.uid).thenReturn('u_test');
    repo = ProfileRepositoryImpl(
      firestore: firestore,
      db: db,
      userProvider: () => user,
    );
  });

  tearDown(() async {
    await db.close();
  });

  ProfileRepositoryImpl repoWithoutUser() => ProfileRepositoryImpl(
        firestore: firestore,
        db: db,
        userProvider: () => null,
      );

  group('χωρίς authenticated user', () {
    test('getProfile → null, saveProfile → auth_required, publish → auth_required',
        () async {
      final r = repoWithoutUser();
      expect(await r.getProfile(), isNull);
      await expectLater(
        r.saveProfile(profileTableData(uid: 'u_test', nickname: 'X')),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_required')),
      );
      await expectLater(
        r.publish(),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_required')),
      );
    });

    test('unpublish/deleteProfile/syncLocation/setHelpRequest → no-op ή auth_required',
        () async {
      final r = repoWithoutUser();
      await r.unpublish(); // no-op χωρίς throw
      await r.deleteProfile(); // no-op
      expect(await r.syncLocation(37.9, 23.7), isNull);
      await expectLater(
        r.setHelpRequest(active: true),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_required')),
      );
      expect(await r.isPublished, isFalse);
    });
  });

  group('saveProfile', () {
    test('valid → εγγραφή local + privacy settings auto-seeded', () async {
      await repo.saveProfile(profileTableData(uid: 'u_test', nickname: 'Nick'));
      final rows = await (db.select(db.userProfileTable)).get();
      expect(rows, hasLength(1));
      expect(rows.first.nickname, 'Nick');
      expect(rows.first.isPublished, isFalse);
      final privacy = await (db.select(db.privacySettingsTable)).get();
      expect(privacy, hasLength(1));
      expect(privacy.first.uid, 'u_test');
      expect(privacy.first.showNickname, isTrue);
    });

    test('invalid birthYear → validation_error', () async {
      await expectLater(
        repo.saveProfile(profileTableData(uid: 'u_test', birthYear: 2015)),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('update (υπάρχον) → id/createdAt κρατούνται, updatedAt = now', () async {
      await repo.saveProfile(profileTableData(uid: 'u_test', nickname: 'A'));
      await repo.saveProfile(profileTableData(uid: 'u_test', nickname: 'B'));
      final rows = await (db.select(db.userProfileTable)).get();
      expect(rows, hasLength(1));
      expect(rows.first.nickname, 'B');
      expect(rows.first.createdAt, isNotNull);
    });
  });

  group('getProfile', () {
    test('local-only → επιστρέφει το local', () async {
      await repo.saveProfile(profileTableData(uid: 'u_test', nickname: 'Local'));
      final p = await repo.getProfile();
      expect(p, isNotNull);
      expect(p!.nickname, 'Local');
    });

    test('restore από Firestore (χωρίς local) → δημιουργεί local + privacy', () async {
      await seedPublicProfile(
        firestore,
        publicProfileDoc(
          uid: 'u_test',
          nickname: 'Remote',
          age: 30,
          city: 'Athens',
        )..['updatedAt'] = DateTime.utc(2026, 9, 5).toIso8601String(),
      );
      final p = await repo.getProfile();
      expect(p, isNotNull);
      expect(p!.nickname, 'Remote');
      expect(p.birthYear, DateTime.now().year - 30);
      expect(p.isPublished, isTrue);
      final privacy = await (db.select(db.privacySettingsTable)).get();
      expect(privacy, hasLength(1));
    });

    test('merge: νεότερο Firestore avatarUrl → ενημερώνει το local', () async {
      await repo.saveProfile(
        profileTableData(uid: 'u_test', nickname: 'Nick'),
      );
      await seedPublicProfile(
        firestore,
        publicProfileDoc(
          uid: 'u_test',
          nickname: 'Nick',
        )..addAll({
            'avatarUrl': 'https://img/new.png',
            'updatedAt': DateTime.now()
                .toUtc()
                .add(const Duration(seconds: 1))
                .toIso8601String(),
          }),
      );
      final p = await repo.getProfile();
      expect(p, isNotNull);
      expect(p!.avatarUrl, 'https://img/new.png');
    });
  });

  group('publish / unpublish', () {
    Future<void> saveValidProfile() async {
      await repo.saveProfile(profileTableData(
        uid: 'u_test',
        nickname: 'Νίκος',
        city: 'Athens',
        bio: 'Γεια',
      ));
    }

    test('publish → doc στο Firestore + isPublished local + consent log',
        () async {
      await saveValidProfile();
      await repo.publish();

      final doc = await firestore
          .collection('users')
          .doc('u_test')
          .collection('public')
          .doc('profile')
          .get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['uid'], 'u_test');
      expect(data['nickname'], 'Νίκος');
      expect(data['cityNormalized'], 'athens');
      expect(data['isManualLocation'], isTrue);
      expect(data.containsKey('isOnline'), isFalse);
      expect(data.containsKey('avatarRacyLevel'), isFalse);

      final local = await (db.select(db.userProfileTable)).get();
      expect(local.single.isPublished, isTrue);
      final logs = await (db.select(db.consentLogTable)).get();
      expect(logs.map((l) => l.action), contains('publish'));
    });

    test('publish → preserve isOnline/geoHash/helpRequest όταν verified', () async {
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.emailVerified).thenReturn(true);
      when(() => user.phoneNumber).thenReturn(null);

      await saveValidProfile();
      var existing = publicProfileDoc(uid: 'u_test', nickname: 'Νίκος', isOnline: true);
      existing.addAll({
        'geoHash': 's9v3',
        'helpRequest': {'active': true, 'message': 'help'},
      });
      await seedPublicProfile(firestore, existing);

      await repo.publish();

      final doc = await firestore
          .collection('users')
          .doc('u_test')
          .collection('public')
          .doc('profile')
          .get();
      final data = doc.data()!;
      expect(data['isOnline'], isTrue);
      expect(data['geoHash'], 's9v3');
      expect(data['helpRequest'], {'active': true, 'message': 'help'});
    });

    test('unpublish → doc διαγράφεται + isPublished false + consent log',
        () async {
      await saveValidProfile();
      await repo.publish();
      await repo.unpublish();

      final doc = await firestore
          .collection('users')
          .doc('u_test')
          .collection('public')
          .doc('profile')
          .get();
      expect(doc.exists, isFalse);
      final local = await (db.select(db.userProfileTable)).get();
      expect(local.single.isPublished, isFalse);
      final logs = await (db.select(db.consentLogTable)).get();
      expect(logs.map((l) => l.action), contains('unpublish'));
    });
  });

  group('privacy settings', () {
    test('savePrivacySettings → local + geoPrecision sync στο Firestore',
        () async {
      await repo.savePrivacySettings(
        privacySettingsData(uid: 'u_test', geoPrecision: 'city'),
      );
      final privacy = await (db.select(db.privacySettingsTable)).get();
      expect(privacy, hasLength(1));
      expect(privacy.first.geoPrecision, 'city');

      final doc = await firestore
          .collection('users')
          .doc('u_test')
          .collection('privacy')
          .doc('settings')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['geoPrecision'], 'city');
    });

    test('no user → getPrivacySettings null, savePrivacySettings auth_required',
        () async {
      final r = repoWithoutUser();
      expect(await r.getPrivacySettings(), isNull);
      await expectLater(
        r.savePrivacySettings(privacySettingsData(uid: 'u_test')),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_required')),
      );
    });
  });

  group('SOS helpRequest', () {
    test('activate → nested helpRequest γράφεται + consent log', () async {
      await seedPublicProfile(firestore, publicProfileDoc(uid: 'u_test'));
      await repo.setHelpRequest(active: true, message: 'Χρειάζομαι βοήθεια');

      final doc = await firestore
          .collection('users')
          .doc('u_test')
          .collection('public')
          .doc('profile')
          .get();
      final hr = doc.data()!['helpRequest'] as Map<String, dynamic>;
      expect(hr['active'], isTrue);
      expect(hr['message'], 'Χρειάζομαι βοήθεια');
      expect(hr['radiusKm'], 10.0);
      expect(hr['updatedAt'], isNotNull);
      final logs = await (db.select(db.consentLogTable)).get();
      expect(logs.map((l) => l.action), contains('help_request_activate'));
    });

    test('message πάνω από 80 χαρακτήρες → help/message-too-long', () async {
      await expectLater(
        repo.setHelpRequest(active: true, message: 'x' * 81),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'help/message-too-long')),
      );
      final logs = await (db.select(db.consentLogTable)).get();
      expect(logs, isEmpty);
    });

    test('deactivate → helpRequest διαγράφεται από το doc', () async {
      await seedPublicProfile(firestore, publicProfileDoc(uid: 'u_test'));
      await repo.setHelpRequest(active: true, message: 'test');
      await repo.setHelpRequest(active: false);

      final doc = await firestore
          .collection('users')
          .doc('u_test')
          .collection('public')
          .doc('profile')
          .get();
      expect(doc.data()!.containsKey('helpRequest'), isFalse);
      final logs = await (db.select(db.consentLogTable)).get();
      expect(logs.map((l) => l.action), contains('help_request_deactivate'));
    });
  });

  group('getPublicProfile / deleteProfile', () {
    test('getPublicProfile valid + empty uid + missing doc → ασφαλή null',
        () async {
      await seedPublicProfile(
        firestore,
        publicProfileDoc(uid: 'u_remote', nickname: 'Remote'),
      );
      final found = await repo.getPublicProfile('u_remote');
      expect(found, isNotNull);
      expect(found!.nickname, 'Remote');
      expect(await repo.getPublicProfile(''), isNull);
      expect(await repo.getPublicProfile('u_missing'), isNull);
    });

    test('deleteProfile → local row σβήνεται', () async {
      await repo.saveProfile(profileTableData(uid: 'u_test', nickname: 'Nick'));
      await repo.deleteProfile();
      final rows = await (db.select(db.userProfileTable)).get();
      expect(rows, isEmpty);
    });
  });
}