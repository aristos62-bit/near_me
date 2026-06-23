import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/geohash_utils.dart';
import '../shared/models/public_profile.dart';
import 'search_repository.dart';

class FirestoreSearchRepository implements SearchRepository {
  final FirebaseFirestore _firestore;

  FirestoreSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<SearchResult> search(SearchFilters filters, {SearchCursor? cursor}) async {
    DebugConfig.log(DebugConfig.repositoryCall,
        'FirestoreSearchRepository.search: requested=${filters.limit}, cap=300, cursor=${cursor?.docId}');

    try {
      Query query = _firestore.collectionGroup('public').where('isVisible', isEqualTo: true);

      final cityFilterActive = filters.city != null && filters.city!.isNotEmpty;
      final countryFilterActive = filters.country != null && filters.country!.isNotEmpty;
      final hasLocationFilter = cityFilterActive || countryFilterActive;
      DebugConfig.log(DebugConfig.repositoryCall,
          'search: cityFilterActive=$cityFilterActive, countryFilterActive=$countryFilterActive, '
          'hasLocationFilter=$hasLocationFilter, city=${filters.city}, '
          'country=${filters.country}, lat=${filters.latitude}, lng=${filters.longitude}');

      if (cityFilterActive) {
        query = query.where('city', isEqualTo: filters.city);
      }
      if (countryFilterActive) {
        query = query.where('country', isEqualTo: filters.country);
      }

      final hasGeoHash = filters.latitude != null || filters.geoHash != null;

      if (filters.latitude != null && filters.longitude != null && filters.radiusKm != null
          && !hasLocationFilter) {
        // FIX: coarsest precision (= geoPrecision 'city', 3 chars) ώστε τα bounds
        // να συμπεριλαμβάνουν ΚΑΙ geoPrecision='city' (3 chars) ΚΑΙ 'neighborhood'
        // (5 chars) προφίλ. Χωρίς αυτό, ένα 3-char geoHash είναι πάντα
        // λεξικογραφικά < bounds.lower (5-char) και αποκλείεται πάντα.
        final searchPrecision = GeoHashUtils.precisionFromSetting('city');
        final bounds = GeoHashUtils.getBounds(
          filters.latitude!,
          filters.longitude!,
          filters.radiusKm!,
          precision: searchPrecision,
        );
        // '~' sentinel στο upper bound: επιτρέπει σε μεγαλύτερα (πιο ακριβή)
        // geoHash strings που ξεκινούν με το ίδιο prefix με το upper cell να
        // περάσουν το <= έλεγχο (ίδιο trick με το branch ακριβώς από κάτω).
        final upperBound = '${bounds.upper}~';
        DebugConfig.log(DebugConfig.repositoryCall,
            'FirestoreSearchRepository.search: geoBounds precision=$searchPrecision '
                'lower=${bounds.lower} upper=$upperBound');
        query = query
            .where('geoHash', isGreaterThanOrEqualTo: bounds.lower)
            .where('geoHash', isLessThanOrEqualTo: upperBound);
      } else if (filters.geoHash != null && !hasLocationFilter) {
        final upper = '${filters.geoHash!}~';
        query = query
            .where('geoHash', isGreaterThanOrEqualTo: filters.geoHash)
            .where('geoHash', isLessThanOrEqualTo: upper);
      }

      if (!hasGeoHash) {
        if (filters.minAge != null) {
          query = query.where('age', isGreaterThanOrEqualTo: filters.minAge);
        }
        if (filters.maxAge != null) {
          query = query.where('age', isLessThanOrEqualTo: filters.maxAge);
        }
      }
      if (filters.gender != null && filters.gender != 'all') {
        query = query.where('gender', isEqualTo: filters.gender);
      }
      final orderByGeoHash = hasGeoHash && !hasLocationFilter;
      DebugConfig.log(DebugConfig.repositoryCall,
          'orderByGeoHash=$orderByGeoHash (hasGeoHash=$hasGeoHash, '
          'cityFilterActive=$cityFilterActive, countryFilterActive=$countryFilterActive)');
      if (orderByGeoHash) {
        query = query.orderBy('geoHash').orderBy('__name__');
      } else {
        query = query.orderBy('__name__');
      }

      final effectiveLimit = filters.limit > 300 ? 300 : filters.limit;
      query = query.limit(effectiveLimit);

      if (cursor != null) {
        query = orderByGeoHash
            ? query.startAfter([cursor.sortValue, cursor.docId])
            : query.startAfter([cursor.docId]);
      }

      DebugConfig.log(DebugConfig.repositoryCall,
          'FirestoreSearchRepository.search QUERY: cityFilterActive=$cityFilterActive, '
          'countryFilterActive=$countryFilterActive, hasLocationFilter=$hasLocationFilter, '
          'hasGeoHash=$hasGeoHash, orderByGeoHash=$orderByGeoHash, '
          'city=${filters.city}, country=${filters.country}, '
          'lat=${filters.latitude}, lng=${filters.longitude}, '
          'geoHash=${filters.geoHash}, radiusKm=${filters.radiusKm}');

      final snapshot = await query.get();
      final all = <PublicProfile>[];
      for (final d in snapshot.docs) {
        final data = d.data() as Map<String, dynamic>;
        data['uid'] ??= d.reference.parent.parent?.id;
        all.add(PublicProfile.fromJson(data));
      }

      final filtered = all.where((p) => _passesFilters(p, filters)).toList();
      final hasMore = snapshot.docs.length >= effectiveLimit;
      final cursorOut = hasMore && snapshot.docs.isNotEmpty
          ? SearchCursor(snapshot.docs.last.id, (snapshot.docs.last.data() as Map<String, dynamic>)['geoHash'] as String?)
          : null;

      DebugConfig.log(DebugConfig.repositoryResult,
          'FirestoreSearchRepository.search: ${filtered.length} results (raw ${all.length}), hasMore=$hasMore');

      return SearchResult(filtered, hasMore, cursorOut);
    } catch (e, s) {
      DebugConfig.error('FirestoreSearchRepository.search failed', data: e, exception: s);
      throw AppException.firestore('search', e, s);
    }
  }

  @override
  Future<SearchResult> searchNearby(double lat, double lng, double radiusKm, {SearchCursor? cursor}) async {
    DebugConfig.log(DebugConfig.repositoryCall,
        'FirestoreSearchRepository.searchNearby: ($lat, $lng) r=$radiusKm, cursor=${cursor?.docId}');

    try {
      // FIX: ίδια λογική με search() — coarsest precision + '~' sentinel.
      final searchPrecision = GeoHashUtils.precisionFromSetting('city');
      final bounds = GeoHashUtils.getBounds(lat, lng, radiusKm, precision: searchPrecision);
      final upperBound = '${bounds.upper}~';
      DebugConfig.log(DebugConfig.repositoryCall,
          'FirestoreSearchRepository.searchNearby: geoBounds precision=$searchPrecision '
              'lower=${bounds.lower} upper=$upperBound');
      Query query = _firestore
          .collectionGroup('public')
          .where('isVisible', isEqualTo: true)
          .where('geoHash', isGreaterThanOrEqualTo: bounds.lower)
          .where('geoHash', isLessThanOrEqualTo: upperBound)
          .orderBy('geoHash')
          .orderBy('__name__')
          .limit(50);

      if (cursor != null) {
        query = query.startAfter([cursor.sortValue, cursor.docId]);
      }

      final snapshot = await query.get();

      final results = <PublicProfile>[];
      for (final d in snapshot.docs) {
        final data = d.data() as Map<String, dynamic>;
        data['uid'] ??= d.reference.parent.parent?.id;
        results.add(PublicProfile.fromJson(data));
      }

      final hasMore = snapshot.docs.length >= 50;
      final cursorOut = hasMore && snapshot.docs.isNotEmpty
          ? SearchCursor(snapshot.docs.last.id, (snapshot.docs.last.data() as Map<String, dynamic>)['geoHash'] as String?)
          : null;

      DebugConfig.log(DebugConfig.repositoryResult,
          'FirestoreSearchRepository.searchNearby: ${results.length} results, hasMore=$hasMore');

      return SearchResult(results, hasMore, cursorOut);
    } catch (e, s) {
      DebugConfig.error('FirestoreSearchRepository.searchNearby failed', data: e, exception: s);
      throw AppException.firestore('searchNearby', e, s);
    }
  }

  /// Client-side safety net for filters Firestore cannot handle exactly:
  /// - city: case-insensitive match
  /// - age: when geoHash range is active (Firestore limitation: single range per query)
  bool _passesFilters(PublicProfile p, SearchFilters f) {
    if (f.city != null && f.city!.isNotEmpty) {
      if (p.city == null || p.city!.toLowerCase() != f.city!.toLowerCase()) return false;
    }
    if (f.country != null && f.country!.isNotEmpty) {
      if (p.country == null || p.country!.toLowerCase() != f.country!.toLowerCase()) return false;
    }
    if (f.minAge != null && (p.age == null || p.age! < f.minAge!)) return false;
    if (f.maxAge != null && (p.age == null || p.age! > f.maxAge!)) return false;
    if (f.allowVideoCall == true && !p.allowVideoCall) return false;
    if (f.allowDirectChat == true && !p.allowDirectChat) return false;
    if (f.isOnlineNow == true && !p.isOnline) return false;
    if (f.lookingFor != null) {
      if (p.lookingFor == null || p.lookingFor!.toLowerCase() != f.lookingFor!.toLowerCase()) return false;
    }
    if (f.interests != null && f.interests!.isNotEmpty) {
      if (p.interests == null || p.interests!.isEmpty) return false;
      if (!p.interests!.any((i) => f.interests!.any((fi) => fi.toLowerCase() == i.toLowerCase()))) return false;
    }
    return true;
  }
}