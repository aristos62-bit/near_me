import 'dart:math';
import '../debug/debug_config.dart';

class GeoHashUtils {
  GeoHashUtils._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encode [latitude]/[longitude] to a geohash with given [precision] chars.
  static String encode(double latitude, double longitude, {int precision = 5}) {
    precision = precision.clamp(1, 12);
    double latMin = -90, latMax = 90;
    double lonMin = -180, lonMax = 180;
    final buffer = StringBuffer();
    int hash = 0, bits = 0;
    bool isLon = true;

    while (buffer.length < precision) {
      if (isLon) {
        final mid = (lonMin + lonMax) / 2;
        if (longitude >= mid) {
          hash = (hash << 1) | 1;
          lonMin = mid;
        } else {
          hash = hash << 1;
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          hash = (hash << 1) | 1;
          latMin = mid;
        } else {
          hash = hash << 1;
          latMax = mid;
        }
      }
      bits++;
      isLon = !isLon;
      if (bits == 5) {
        buffer.write(_base32[hash]);
        hash = 0;
        bits = 0;
      }
    }

    final result = buffer.toString();
    DebugConfig.log(DebugConfig.gpsGeoHash,
        'encode: ($latitude, $longitude) @$precision → $result');
    return result;
  }

  /// Returns geohash char count for a PrivacySettings.geoPrecision value.
  /// Returns 0 for 'hidden' (no geohash in Firestore).
  static int precisionFromSetting(String geoPrecision) {
    int result;
    switch (geoPrecision) {
      case 'city':
        result = 3;
        break;
      case 'neighborhood':
        result = 5;
        break;
      case 'street':
        result = 7;
        break;
      case 'hidden':
        result = 0;
        break;
      default:
        result = 5;
    }
    DebugConfig.log(DebugConfig.gpsGeoHash,
        'precisionFromSetting: "$geoPrecision" → $result');
    return result;
  }

  /// Human-readable label for a geoPrecision setting.
  static String precisionLabel(String geoPrecision) {
    final label = switch (geoPrecision) {
      'city'         => 'Πόλη (~100km²)',
      'neighborhood' => 'Συνοικία (~2.5km²)',
      'street'       => 'Περιοχή (~0.02km²)',
      'hidden'       => 'Κρυφό',
      _              => geoPrecision,
    };
    DebugConfig.log(DebugConfig.gpsGeoHash,
        'precisionLabel: "$geoPrecision" → "$label"');
    return label;
  }

  /// Lower/upper geohash bounds that cover a circular area.
  static GeoBounds getBounds(
      double latitude,
      double longitude,
      double radiusKm, {
        int precision = 5,
      }) {
    const double kmPerDeg = 111.32;
    final latDelta = radiusKm / kmPerDeg;
    final lngDelta =
        radiusKm / (kmPerDeg * cos(latitude * pi / 180));
    final minLat = (latitude - latDelta).clamp(-90.0, 90.0);
    final maxLat = (latitude + latDelta).clamp(-90.0, 90.0);
    final minLng = (longitude - lngDelta).clamp(-180.0, 180.0);
    final maxLng = (longitude + lngDelta).clamp(-180.0, 180.0);
    final sw = encode(minLat, minLng, precision: precision);
    final ne = encode(maxLat, maxLng, precision: precision);
    DebugConfig.log(DebugConfig.gpsGeoHash,
        'getBounds: ($latitude,$longitude) r=$radiusKm → $sw / $ne');
    return GeoBounds(lower: sw, upper: ne);
  }

  /// Returns the 8 neighbouring geohash cells + the center cell itself.
  /// Total: 9 cells covering the full area around [geohash].
  /// This prevents missing profiles that are in adjacent cells but within radius.
  static List<String> getNeighbours(String geohash) {
    if (geohash.isEmpty) return [];
    try {
      final (centerLat, centerLng) = decode(geohash);
      final precision = geohash.length;

      // Cell dimensions in degrees for this precision
      // Each geohash char encodes 5 bits, alternating lon/lat
      // Total bits: precision * 5, split roughly 60/40 lon/lat
      final latBits = (precision * 5) ~/ 2;
      final lngBits = precision * 5 - latBits;
      final latErr = 180.0 / pow(2, latBits);
      final lngErr = 360.0 / pow(2, lngBits);

      final neighbours = <String>{geohash};

      for (int dLat = -1; dLat <= 1; dLat++) {
        for (int dLng = -1; dLng <= 1; dLng++) {
          if (dLat == 0 && dLng == 0) continue;
          final nLat = (centerLat + dLat * latErr * 2).clamp(-90.0, 90.0);
          final nLng = centerLng + dLng * lngErr * 2;
          // Handle antimeridian wrap-around
          final wrappedLng = nLng < -180
              ? nLng + 360
              : nLng > 180
              ? nLng - 360
              : nLng;
          neighbours.add(encode(nLat, wrappedLng, precision: precision));
        }
      }

      DebugConfig.log(DebugConfig.gpsGeoHash,
          'getNeighbours: $geohash → ${neighbours.length} cells: $neighbours');
      return neighbours.toList();
    } catch (e) {
      DebugConfig.warn('getNeighbours failed for $geohash: $e');
      return [geohash];
    }
  }

  /// Decode a geohash to the center point of its cell.
  static (double lat, double lng) decode(String geohash) {
    double latMin = -90, latMax = 90;
    double lonMin = -180, lonMax = 180;
    bool isLon = true;

    for (int i = 0; i < geohash.length; i++) {
      final value = _base32.indexOf(geohash[i]);
      if (value < 0) {
        throw ArgumentError('Invalid geohash character: ${geohash[i]}');
      }
      for (int bit = 4; bit >= 0; bit--) {
        final b = (value >> bit) & 1;
        if (isLon) {
          final mid = (lonMin + lonMax) / 2;
          if (b == 1) {
            lonMin = mid;
          } else {
            lonMax = mid;
          }
        } else {
          final mid = (latMin + latMax) / 2;
          if (b == 1) {
            latMin = mid;
          } else {
            latMax = mid;
          }
        }
        isLon = !isLon;
      }
    }
    final lat = (latMin + latMax) / 2;
    final lng = (lonMin + lonMax) / 2;
    DebugConfig.log(DebugConfig.gpsGeoHash,
        'decode: "$geohash" → ($lat, $lng)');
    return (lat, lng);
  }

  /// Compute distance from [centerLat]/[centerLon] to the NEAREST point
  /// on the geohash cell boundary. Returns 0 if inside the cell.
  static double distanceToNearestEdge(
      String geoHash,
      double centerLat,
      double centerLon,
      ) {
    double latMin = -90, latMax = 90;
    double lonMin = -180, lonMax = 180;
    bool isLon = true;

    for (int i = 0; i < geoHash.length; i++) {
      final value = _base32.indexOf(geoHash[i]);
      if (value < 0) {
        throw ArgumentError('Invalid geohash character: ${geoHash[i]}');
      }
      for (int bit = 4; bit >= 0; bit--) {
        final b = (value >> bit) & 1;
        if (isLon) {
          final mid = (lonMin + lonMax) / 2;
          if (b == 1) {
            lonMin = mid;
          } else {
            lonMax = mid;
          }
        } else {
          final mid = (latMin + latMax) / 2;
          if (b == 1) {
            latMin = mid;
          } else {
            latMax = mid;
          }
        }
        isLon = !isLon;
      }
    }

    final nearestLat = centerLat.clamp(latMin, latMax);
    final nearestLon = centerLon.clamp(lonMin, lonMax);
    final distance =
    haversineDistance(centerLat, centerLon, nearestLat, nearestLon);

    DebugConfig.log(
      DebugConfig.gpsGeoHash,
      'distanceToNearestEdge: geoHash=$geoHash '
          'cell=[$latMin..$latMax, $lonMin..$lonMax] '
          'nearest=($nearestLat,$nearestLon) '
          'distance=${distance.toStringAsFixed(1)}km',
    );
    return distance;
  }

  /// Check if [centerLat]/[centerLon] is within [radiusKm] of the geoHash cell.
  /// Uses distanceToNearestEdge to avoid code duplication.
  static bool isWithinRadius(
      String geoHash,
      double centerLat,
      double centerLon,
      double radiusKm,
      ) {
    final distance = distanceToNearestEdge(geoHash, centerLat, centerLon);
    final result = distance <= radiusKm;
    DebugConfig.log(
      DebugConfig.gpsGeoHash,
      'isWithinRadius: geoHash=$geoHash '
          'distance=${distance.toStringAsFixed(1)}km ≤ ${radiusKm}km = $result',
    );
    return result;
  }

  /// Haversine distance between two points in km.
  static double haversineDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const double earthRadiusKm = 6371;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadiusKm * c;

    DebugConfig.log(
      DebugConfig.gpsGeoHash,
      'haversine: ($lat1,$lon1) → ($lat2,$lon2) = '
          '${distance.toStringAsFixed(2)} km',
    );
    return distance;
  }
}

class GeoBounds {
  final String lower;
  final String upper;
  const GeoBounds({required this.lower, required this.upper});
}