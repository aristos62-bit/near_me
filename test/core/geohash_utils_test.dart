import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/geohash_utils.dart';

void main() {
  group('encode', () {
    test('known geohash for London (51.5074, -0.1278)', () {
      expect(GeoHashUtils.encode(51.5074, -0.1278, precision: 5), 'gcpvj');
    });

    test('known geohash for Athens (37.9838, 23.7275)', () {
      // Athens should start with "s" (Southern Europe band on the grid)
      final h = GeoHashUtils.encode(37.9838, 23.7275, precision: 5);
      expect(h.length, 5);
      expect(h[0], 's');
    });

    test('precision is respected', () {
      final h3 = GeoHashUtils.encode(37.9838, 23.7275, precision: 3);
      final h7 = GeoHashUtils.encode(37.9838, 23.7275, precision: 7);
      expect(h3.length, 3);
      expect(h7.length, 7);
    });

    test('precision is clamped to 1..12', () {
      expect(GeoHashUtils.encode(0, 0, precision: 0).length, 1);
      expect(GeoHashUtils.encode(0, 0, precision: 99).length, 12);
    });

    test('same coordinates produce same geohash (deterministic)', () {
      expect(GeoHashUtils.encode(40.0, -3.0),
          GeoHashUtils.encode(40.0, -3.0));
    });
  });

  group('decode round-trip', () {
    test('decode(encode(p)) is within the cell of p', () {
      const lat = 37.9838;
      const lng = 23.7275;
      final hash = GeoHashUtils.encode(lat, lng, precision: 5);
      final (dLat, dLng) = GeoHashUtils.decode(hash);
      // cell ~ (11.2km x 4.9km) at precision 5 — center within a couple km
      expect((dLat - lat).abs(), lessThan(12));
      expect((dLng - lng).abs(), lessThan(12));
    });

    test('decode throws on invalid character', () {
      expect(() => GeoHashUtils.decode('zz!'), throwsArgumentError);
    });
  });

  group('precisionFromSetting', () {
    test('maps settings to precision', () {
      expect(GeoHashUtils.precisionFromSetting('city'), 3);
      expect(GeoHashUtils.precisionFromSetting('neighborhood'), 5);
      expect(GeoHashUtils.precisionFromSetting('street'), 7);
      expect(GeoHashUtils.precisionFromSetting('hidden'), 0);
      expect(GeoHashUtils.precisionFromSetting('unknown'), 5);
    });
  });

  group('haversineDistance', () {
    test('zero distance', () {
      expect(GeoHashUtils.haversineDistance(40.0, 20.0, 40.0, 20.0), 0.0);
    });

    test('~111km per degree of latitude', () {
      final d = GeoHashUtils.haversineDistance(0, 0, 1, 0);
      expect(d, closeTo(111.32, 2));
    });

    test('distance is symmetric', () {
      final a = GeoHashUtils.haversineDistance(40.0, 20.0, 38.0, 23.0);
      final b = GeoHashUtils.haversineDistance(38.0, 23.0, 40.0, 20.0);
      expect(a, closeTo(b, 0.001));
    });
  });

  group('getBounds', () {
    test('bounds are ordered lower..upper', () {
      final b = GeoHashUtils.getBounds(37.9, 23.7, 5);
      expect(b.lower.compareTo(b.upper), lessThanOrEqualTo(0));
    });
  });

  group('getNeighbours', () {
    test('empty geohash returns empty list', () {
      expect(GeoHashUtils.getNeighbours(''), isEmpty);
    });

    test('range=1 returns 9 cells including center', () {
      final n = GeoHashUtils.getNeighbours('gcpvj');
      expect(n.length, 9);
      expect(n, contains('gcpvj'));
    });

    test('range=2 returns 25 cells', () {
      final n = GeoHashUtils.getNeighbours('gcpvj', range: 2);
      expect(n.length, 25);
    });

    test('neighbours are unique', () {
      final n = GeoHashUtils.getNeighbours('gcpvj');
      expect(n.toSet().length, n.length);
    });
  });

  group('getNeighbours boundary', () {
    test('south pole area does not crash (latitude clamped)', () {
      final h = GeoHashUtils.encode(-89.9, 0, precision: 5);
      final n = GeoHashUtils.getNeighbours(h);
      expect(n.length, 9);
    });
  });

  group('searchPrecision', () {
    test('small radius picks high precision', () {
      final p = GeoHashUtils.searchPrecision(2, 37.9);
      expect(p, greaterThanOrEqualTo(4));
    });

    test('large radius picks lower precision (min 1)', () {
      final p = GeoHashUtils.searchPrecision(500, 37.9);
      expect(p, greaterThanOrEqualTo(1));
      expect(p, lessThanOrEqualTo(7));
    });

    test('non-positive radius returns 4 (default)', () {
      expect(GeoHashUtils.searchPrecision(0, 37.9), 4);
      expect(GeoHashUtils.searchPrecision(-5, 37.9), 4);
    });
  });

  group('isWithinRadius', () {
    test('point at exact center is within radius', () {
      final hash = GeoHashUtils.encode(37.9838, 23.7275, precision: 5);
      expect(GeoHashUtils.isWithinRadius(hash, 37.9838, 23.7275, 5), isTrue);
    });

    test('far point is outside radius', () {
      final hash = GeoHashUtils.encode(40.6, 22.9, precision: 5);
      expect(GeoHashUtils.isWithinRadius(hash, 37.9838, 23.7275, 5), isFalse);
    });
  });
}
