import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/profile/utils/publish_payload.dart';

import '../../helpers/fake_firestore_helpers.dart';

void main() {
  group('buildPublicProfileForPublish', () {
    final profile = profileTableData(
      uid: 'u1',
      nickname: 'Σωτήρης',
      birthYear: 1995,
      gender: 'male',
      city: 'Athens',
      country: 'GR',
      bio: 'Γεια!',
      avatarUrl: 'https://img/a.png',
      photoUrls: ['https://img/p1.png'],
      interests: ['μουσική', 'ταξίδια'],
      email: 'sotiris@example.com',
      phone: '6900000000',
      latitudeExact: 37.9838,
      longitudeExact: 23.7275,
    );

    test('defaults privacy → όλα τα πεδία εμφανίζονται, manual=false', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final pub = buildPublicProfileForPublish(
        uid: 'u1',
        profile: profile,
        privacy: privacySettingsData(showEmail: true, showPhone: true),
        now: now,
      );
      expect(pub.nickname, 'Σωτήρης');
      expect(pub.age, 31);
      expect(pub.gender, 'male');
      expect(pub.city, 'Athens');
      expect(pub.country, 'GR');
      expect(pub.bio, 'Γεια!');
      expect(pub.avatarUrl, 'https://img/a.png');
      expect(pub.photoUrls, ['https://img/p1.png']);
      expect(pub.interests, ['μουσική', 'ταξίδια']);
      expect(pub.email, 'sotiris@example.com');
      expect(pub.phone, '6900000000');
      expect(pub.allowVideoCall, isFalse);
      expect(pub.allowDirectChat, isFalse);
      expect(pub.isVisible, isTrue);
      expect(pub.isManualLocation, isFalse);
      expect(pub.updatedAt, now);
      expect(pub.lang, isNotEmpty);
    });

    test('privacy toggles off → nulls όσα πρέπει', () {
      final now = DateTime(2026);
      final pub = buildPublicProfileForPublish(
        uid: 'u1',
        profile: profile,
        privacy: privacySettingsData(
          showNickname: false,
          showAge: false,
          showGender: false,
          showCity: false,
          showCountry: false,
          showBio: false,
          showAvatar: false,
          showPhotos: false,
          showInterests: false,
          showEmail: false,
          showPhone: false,
        ),
        now: now,
      );
      expect(pub.nickname, isNull);
      expect(pub.age, isNull);
      expect(pub.gender, isNull);
      expect(pub.city, isNull);
      expect(pub.country, isNull);
      expect(pub.bio, isNull);
      expect(pub.avatarUrl, isNull);
      expect(pub.photoUrls, isNull);
      expect(pub.interests, isNull);
      expect(pub.email, isNull);
      expect(pub.phone, isNull);
      expect(pub.isManualLocation, isFalse);
    });

    test('null privacy (defensive branch) → όλα κρυφά, isVisible=true', () {
      final pub = buildPublicProfileForPublish(
        uid: 'u1',
        profile: profile,
        privacy: null,
        now: DateTime(2026),
      );
      expect(pub.nickname, isNull);
      expect(pub.age, isNull);
      expect(pub.allowVideoCall, isFalse);
      expect(pub.allowDirectChat, isFalse);
      expect(pub.isVisible, isTrue);
    });

    test('null birthYear → age null (χωρίς crash)', () {
      final pub = buildPublicProfileForPublish(
        uid: 'u1',
        profile: profileTableData(uid: 'u1', birthYear: null),
        privacy: privacySettingsData(),
        now: DateTime(2026),
      );
      expect(pub.age, isNull);
    });

    test('manual location (lat/lng null) → isManualLocation=true', () {
      final pub = buildPublicProfileForPublish(
        uid: 'u1',
        profile: profileTableData(uid: 'u1'),
        privacy: privacySettingsData(),
        now: DateTime(2026),
      );
      expect(pub.isManualLocation, isTrue);
    });
  });

  group('publicProfileToPayloadJson', () {
    test('κλείνει nulls, βγάζει isOnline, βάζει normalized fields', () {
      final pub = buildPublicProfileForPublish(
        uid: 'u1',
        profile: profileTableData(
          uid: 'u1',
          nickname: 'Σωτήρης',
          city: 'ATHENS',
          country: ' Greece ',
          bio: 'Γεια!',
        ),
        privacy: privacySettingsData(showBio: false),
        now: DateTime(2026),
      );
      final json = publicProfileToPayloadJson(pub);
      expect(json['nickname'], 'Σωτήρης');
      expect(json['city'], 'ATHENS');
      expect(json['cityNormalized'], 'athens');
      expect(json['countryNormalized'], 'greece');
      expect(json['nicknameLowercase'], 'σωτήρης');
      expect(json['isOnline'], isNull);
      expect(json['bio'], isNull);
      expect(json.containsKey('avatarRacyLevel'), isFalse);
    });
  });

  group('applyPublishPreserves', () {
    test('χωρίς υπάρχον doc → no-op', () {
      final json = <String, dynamic>{'nickname': 'x'};
      applyPublishPreserves(json,
          existing: null, canCommunicate: true);
      expect(json.length, 1);
    });

    test('preserve isOnline + geoHash, drop helpRequest χωρίς verification', () {
      final json = <String, dynamic>{};
      applyPublishPreserves(
        json,
        existing: {
          'isOnline': true,
          'geoHash': 's9v3',
          'helpRequest': {'active': true},
        },
        canCommunicate: false,
      );
      expect(json['isOnline'], isTrue);
      expect(json['geoHash'], 's9v3');
      expect(json.containsKey('helpRequest'), isFalse);
    });

    test('verified user → helpRequest preserved too', () {
      final json = <String, dynamic>{};
      applyPublishPreserves(
        json,
        existing: {
          'isOnline': false,
          'geoHash': 's9v3',
          'helpRequest': {'active': true, 'message': 'help'},
        },
        canCommunicate: true,
      );
      expect(json['isOnline'], isFalse);
      expect(json['geoHash'], 's9v3');
      expect(json['helpRequest'], {'active': true, 'message': 'help'});
    });

    test('υπάρχον helpRequest αλλά χωρίς geoHash → μόνο όσα υπάρχουν', () {
      final json = <String, dynamic>{};
      applyPublishPreserves(
        json,
        existing: {
          'helpRequest': {'active': true},
        },
        canCommunicate: true,
      );
      expect(json.containsKey('isOnline'), isFalse);
      expect(json.containsKey('geoHash'), isFalse);
      expect(json['helpRequest'], isNotNull);
    });
  });
}