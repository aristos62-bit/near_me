import 'dart:math';
import '../debug/debug_config.dart';

class GeoHashUtils {
  GeoHashUtils._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static final Map<String, double> _distanceCache = {};

  static void clearDistanceCache() {
    _distanceCache.clear();
    DebugConfig.log(DebugConfig.repositoryCall,
        'GeoHashUtils.clearDistanceCache');
  }

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

    return buffer.toString();
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

  /// Returns neighbouring geohash cells around [geohash] within [range].
  /// [range]=1 → 9 cells (center + 8 immediate neighbours).
  /// [range]=2 → 25 cells, κλπ.
  static List<String> getNeighbours(String geohash, {int range = 1}) {
    if (geohash.isEmpty) return [];
    if (range < 1) return [geohash];
    try {
      final (centerLat, centerLng) = decode(geohash);
      final precision = geohash.length;

      // Cell dimensions in degrees — first bit = lon, so ceil/floor split
      final lngBits = (precision * 5 + 1) ~/ 2;
      final latBits = precision * 5 - lngBits;
      final latStep = 180.0 / pow(2, latBits);   // cell height
      final lngStep = 360.0 / pow(2, lngBits);   // cell width

      final neighbours = <String>{geohash};

      for (int dLat = -range; dLat <= range; dLat++) {
        for (int dLng = -range; dLng <= range; dLng++) {
          if (dLat == 0 && dLng == 0) continue;
          final nLat = (centerLat + dLat * latStep).clamp(-90.0, 90.0);
          final nLng = centerLng + dLng * lngStep;
          final wrappedLng = nLng < -180
              ? nLng + 360
              : nLng > 180
              ? nLng - 360
              : nLng;
          neighbours.add(encode(nLat, wrappedLng, precision: precision));
        }
      }

      DebugConfig.log(DebugConfig.gpsGeoHash,
          'getNeighbours: "$geohash" range=$range → ${neighbours.length} cells');
      return neighbours.toList();
    } catch (e) {
      DebugConfig.warn('getNeighbours failed for "$geohash": $e');
      return [geohash];
    }
  }

  /// Cell dimensions in km for given [precision] at [latitude].
  static ({double hKm, double wKm}) _cellDimensions(int precision, double latitude) {
    final lngBits = (precision * 5 + 1) ~/ 2;
    final latBits = precision * 5 - lngBits;
    const degKm = 111.32;
    final hKm = 180.0 / pow(2, latBits) * degKm;
    final wKm = 360.0 / pow(2, lngBits) * degKm * cos(latitude * pi / 180);
    return (hKm: hKm, wKm: wKm);
  }

  /// Επιλέγει optimal geohash precision ώστε 9 cells να καλύπτουν
  /// πλήρως κύκλο ακτίνας [radiusKm] στο γεωγραφικό πλάτος [latitude].
  /// Conservative bound: min(cellW, cellH) ≥ radiusKm (χρήστης στο χείλος
  /// του center cell → τουλάχιστον 1 full neighbor cell προς κάθε κατεύθυνση).
  ///
  /// ΣΗΜΕΙΩΣΗ (fix): το κάτω όριο άλλαξε από precision=3 σε precision=1.
  /// Πριν, για radius > ~120-150km (Ελλάδα) ο βρόχος δεν έβρισκε κελί
  /// αρκετά μεγάλο και έπεφτε σε fallback=3 ΑΝΕΞΑΡΤΗΤΑ από την πραγματική
  /// ακτίνα — αποτέλεσμα: profiles πέρα από ~120-150km ποτέ δεν έμπαιναν
  /// καν στο query (silent data loss, όχι σφάλμα). Το precision=2 δίνει
  /// κελιά ~600-1250km — αρκετά για να καλύψουν έως 500km με το ΙΔΙΟ
  /// 9-cell (3×3) query pattern, χωρίς επιπλέον Firestore reads.
  static int searchPrecision(double radiusKm, double latitude) {
    if (radiusKm <= 0) return 4;
    for (int p = 7; p >= 1; p--) {
      final d = _cellDimensions(p, latitude);
      if (d.hKm < radiusKm || d.wKm < radiusKm) {
        continue;
      }
      DebugConfig.log(DebugConfig.gpsGeoHash,
          'searchPrecision: radius=${radiusKm}km lat=${latitude.toStringAsFixed(1)}° → precision=$p (${d.hKm.toStringAsFixed(2)}×${d.wKm.toStringAsFixed(2)} km/cell, 9 cells=${(d.hKm*3).toStringAsFixed(1)}×${(d.wKm*3).toStringAsFixed(1)} km)');
      return p;
    }
    // Ακραία περίπτωση: ούτε precision=1 (~5000km/κελί καθ' ύψος) δεν αρκεί.
    // Συμβαίνει ΜΟΝΟ πολύ κοντά στους πόλους (πλάτος >~85°) με πολύ μεγάλη
    // ακτίνα, λόγω συστολής του γεωγραφικού μήκους (cos(lat)→0). Δεν είναι
    // ρεαλιστικό σενάριο γι' αυτή την εφαρμογή, αλλά καταγράφεται ως error
    // (όχι απλό log) ώστε να είναι ορατό αν συμβεί ποτέ.
    DebugConfig.error(
      'searchPrecision: ΑΚΡΑΙΟ σενάριο — precision=1 δεν επαρκεί για '
          'radius=${radiusKm}km στο lat=${latitude.toStringAsFixed(1)}°. '
          'Χρησιμοποιείται precision=1 ως πιο χοντρό διαθέσιμο (πιθανή '
          'ελλιπής κάλυψη κοντά στους πόλους).',
    );
    return 1;
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
    return (lat, lng);
  }

  /// Compute distance from [centerLat]/[centerLon] to the NEAREST point
  /// on the geohash cell boundary. For interior points, returns distance
  /// to the nearest cell edge (not 0, avoiding centerDist fallback).
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

    if (centerLat >= latMin && centerLat <= latMax &&
        centerLon >= lonMin && centerLon <= lonMax) {
      final dNorth = haversineDistance(centerLat, centerLon, latMax, centerLon);
      final dSouth = haversineDistance(centerLat, centerLon, latMin, centerLon);
      final dEast  = haversineDistance(centerLat, centerLon, centerLat, lonMax);
      final dWest  = haversineDistance(centerLat, centerLon, centerLat, lonMin);
      return min(dNorth, min(dSouth, min(dEast, dWest)));
    }

    final nearestLat = centerLat.clamp(latMin, latMax);
    final nearestLon = centerLon.clamp(lonMin, lonMax);
    return haversineDistance(centerLat, centerLon, nearestLat, nearestLon);
  }

  /// Returns effective distance from (centerLat, centerLon) to the profile
  /// represented by [geoHash], using hybrid approach:
  ///   edgeDist > 0 → nearest edge distance (outside cell, Session 108)
  ///   edgeDist = 0 → haversine center-to-center (inside cell fallback)
  static double distanceToPoint(String geoHash, double centerLat, double centerLon) {
    final key = '$geoHash|${centerLat.toStringAsFixed(4)}|${centerLon.toStringAsFixed(4)}';
    final cached = _distanceCache[key];
    if (cached != null) return cached;

    final edgeDist = distanceToNearestEdge(geoHash, centerLat, centerLon);
    final (cellLat, cellLng) = decode(geoHash);
    final centerDist = haversineDistance(centerLat, centerLon, cellLat, cellLng);
    final result = edgeDist > 0 ? edgeDist : centerDist;
    if (result.isFinite) {
      _distanceCache[key] = result;
    }
    return result;
  }

  /// Check if [centerLat]/[centerLon] is within [radiusKm] of the geoHash cell.
  static bool isWithinRadius(
      String geoHash,
      double centerLat,
      double centerLon,
      double radiusKm,
      ) {
    final distance = distanceToPoint(geoHash, centerLat, centerLon);
    return distance <= radiusKm;
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
    return earthRadiusKm * c;
  }
}

class GeoBounds {
  final String lower;
  final String upper;
  const GeoBounds({required this.lower, required this.upper});
}