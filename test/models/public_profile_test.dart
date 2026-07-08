import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/models/public_profile.dart';

void main() {
  group('PublicProfile — country serialization', () {
    test('toJson includes country when set', () {
      final profile = PublicProfile(
        uid: 'test-uid',
        nickname: 'Test',
        country: 'Ελλάδα',
      );
      final json = profile.toJson();
      expect(json['country'], 'Ελλάδα');
    });

    test('toJson includes country as null when not set', () {
      final profile = PublicProfile(
        uid: 'test-uid',
        nickname: 'Test',
      );
      final json = profile.toJson();
      expect(json['country'], isNull);
    });

    test('fromJson parses country correctly', () {
      final json = {
        'uid': 'test-uid',
        'country': 'Ελλάδα',
        'nickname': 'Test',
      };
      final profile = PublicProfile.fromJson(json);
      expect(profile.country, 'Ελλάδα');
    });

    test('fromJson handles missing country as null', () {
      final json = {
        'uid': 'test-uid',
        'nickname': 'Test',
      };
      final profile = PublicProfile.fromJson(json);
      expect(profile.country, isNull);
    });

    test('fromJson handles null country as null', () {
      final json = {
        'uid': 'test-uid',
        'nickname': 'Test',
        'country': null,
      };
      final profile = PublicProfile.fromJson(json);
      expect(profile.country, isNull);
    });

    test('country survives round-trip toJson/fromJson', () {
      final original = PublicProfile(
        uid: 'test-uid',
        nickname: 'Test',
        country: 'Ελλάδα',
      );
      final json = original.toJson();
      final restored = PublicProfile.fromJson(json);
      expect(restored.country, 'Ελλάδα');
      expect(restored.uid, original.uid);
    });
  });

  group('City + Country display formatting', () {
    String formatLocation(String? city, String? country) {
      return [city, country]
          .where((e) => e != null && e.isNotEmpty)
          .join(', ');
    }

    test('both city and country present', () {
      expect(formatLocation('Αθήνα', 'Ελλάδα'), 'Αθήνα, Ελλάδα');
    });

    test('only city present', () {
      expect(formatLocation('Αθήνα', null), 'Αθήνα');
    });

    test('only country present', () {
      expect(formatLocation(null, 'Ελλάδα'), 'Ελλάδα');
    });

    test('both empty strings', () {
      expect(formatLocation('', ''), '');
    });

    test('both null', () {
      expect(formatLocation(null, null), '');
    });

    test('empty city, present country', () {
      expect(formatLocation('', 'Ελλάδα'), 'Ελλάδα');
    });

    test('present city, empty country', () {
      expect(formatLocation('Αθήνα', ''), 'Αθήνα');
    });
  });
}
