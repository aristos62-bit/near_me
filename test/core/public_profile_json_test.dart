import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/public_profile_json.dart';
import 'package:near_me/shared/models/public_profile.dart';

void main() {
  group('tryParsePublicProfile', () {
    final valid = {
      'uid': 'u1',
      'nickname': 'Nick',
      'age': 30,
      'city': 'Athens',
    };

    test('valid map → PublicProfile', () {
      final parsed = tryParsePublicProfile(valid);
      expect(parsed, isNotNull);
      expect(parsed!.uid, 'u1');
      expect(parsed.nickname, 'Nick');
      expect(parsed.age, 30);
      expect(parsed.city, 'Athens');
      expect(parsed.lang, 'el');
      expect(parsed.isOnline, isFalse);
      expect(parsed.isManualLocation, isFalse);
    });

    test('types normalized by fromJson (defaults εφαρμόζονται)', () {
      final parsed = tryParsePublicProfile({
        'uid': 'u2',
        'allowVideoCall': true,
        'allowDirectChat': true,
        'isVisible': false,
        'isOnline': true,
        'isManualLocation': true,
      });
      expect(parsed, isNotNull);
      expect(parsed!.allowVideoCall, isTrue);
      expect(parsed.isVisible, isFalse);
      expect(parsed.isOnline, isTrue);
      expect(parsed.isManualLocation, isTrue);
    });

    test('malformed nested helpRequest → null (δεν κάνει crash)', () {
      final parsed = tryParsePublicProfile({
        'uid': 'u3',
        'helpRequest': 'broken-not-a-map',
      });
      expect(parsed, isNull);
    });

    test('rollup round-trip μέσα από payload json (toJson→fromJson)', () {
      final pp = PublicProfile(
        uid: 'u4',
        nickname: 'Apostolos',
        city: 'Thessaloniki',
        country: 'GR',
        age: 28,
        allowVideoCall: true,
        updatedAt: DateTime.utc(2026, 9, 5),
      );
      final json = pp.toJson()
        ..removeWhere((_, v) => v == null);
      final parsed = tryParsePublicProfile(json);
      expect(parsed, isNotNull);
      expect(parsed!.uid, 'u4');
      expect(parsed.nickname, 'Apostolos');
      expect(parsed.city, 'Thessaloniki');
      expect(parsed.allowVideoCall, isTrue);
      expect(parsed.updatedAt, DateTime.utc(2026, 9, 5));
    });

    test('null-safe: map χωρίς required uid → null (parse error πιάστηκε)', () {
      expect(tryParsePublicProfile({'nickname': 'x'}), isNull);
    });
  });
}