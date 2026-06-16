import 'dart:math';
import '../debug/debug_config.dart';

class GeoHashUtils {
  GeoHashUtils._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encode [latitude]/[longitude] to a geohash with given [precision] chars.
  /// [precision] is clamped 1-12. Default 5 = ~2.5km² (neighborhood).
  /// Raw lat/lng NEVER leave the device. Only geohash goes to Firestore.
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
    DebugConfig.log(DebugConfig.gpsGeoHash, 'encode: ($latitude, $longitude) @$precision → $result');
    return result;
  }

  /// Returns geohash char count for a PrivacySettings.geoPrecision value.
  /// Returns 0 for 'hidden' (no geohash in Firestore).
  static int precisionFromSetting(String geoPrecision) {
    switch (geoPrecision) {
      case 'city':
        return 3;
      case 'neighborhood':
        return 5;
      case 'hidden':
        return 0;
      default:
        return 5;
    }
  }

  /// Human-readable label for a geoPrecision setting.
  static String precisionLabel(String geoPrecision) {
    switch (geoPrecision) {
      case 'city':
        return 'Πόλη (~100km²)';
      case 'neighborhood':
        return 'Συνοικία (~2.5km²)';
      case 'hidden':
        return 'Κρυφό';
    default:
      return geoPrecision;
  }
  }

  /// Lower/upper geohash bounds that cover a circular area.
  static GeoBounds getBounds(double latitude, double longitude, double radiusKm, {int precision = 5}) {
    const double kmPerDeg = 111.32;
    final latDelta = radiusKm / kmPerDeg;
    final lngDelta = radiusKm / (kmPerDeg * cos(latitude * pi / 180));
    final minLat = (latitude - latDelta).clamp(-90.0, 90.0);
    final maxLat = (latitude + latDelta).clamp(-90.0, 90.0);
    final minLng = (longitude - lngDelta).clamp(-180.0, 180.0);
    final maxLng = (longitude + lngDelta).clamp(-180.0, 180.0);
    final sw = encode(minLat, minLng, precision: precision);
    final ne = encode(maxLat, maxLng, precision: precision);
    DebugConfig.log(DebugConfig.gpsGeoHash, 'getBounds: ($latitude,$longitude) r=$radiusKm → $sw / $ne');
    return GeoBounds(lower: sw, upper: ne);
  }
}

class GeoBounds {
  final String lower;
  final String upper;
  const GeoBounds({required this.lower, required this.upper});
}
