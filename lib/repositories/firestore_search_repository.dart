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
  Future<SearchResult> search(SearchFilters filters,
      {SearchCursor? cursor}) async {
    DebugConfig.log(
      DebugConfig.repositoryCall,
      'FirestoreSearchRepository.search: requested=${filters.limit}, '
          'cursor=${cursor?.docId}',
    );

    try {
      final cityFilterActive =
          filters.city != null && filters.city!.isNotEmpty;
      final countryFilterActive =
          filters.country != null && filters.country!.isNotEmpty;
      final hasGeoSearch = filters.latitude != null ||
          filters.geoHash != null;
      DebugConfig.log(
        DebugConfig.repositoryCall,
        'search: city=$cityFilterActive, country=$countryFilterActive, '
            'lat=${filters.latitude}, lng=${filters.longitude}',
      );

      final effectiveLimit =
      filters.limit > 300 ? 300 : filters.limit;

      // ── City filter → general search (cityNormalized server-side) ──
      if (cityFilterActive) {
        return await _generalSearch(filters, cursor, effectiveLimit);
      }

      // ── Geo search με neighbouring cells ──────────────────────────
      if (hasGeoSearch) {
        return await _geoSearch(filters, cursor, effectiveLimit);
      }

      // ── General search (city/country server-side, age client-side) ─
      return await _generalSearch(filters, cursor, effectiveLimit);
    } catch (e, s) {
      DebugConfig.error('FirestoreSearchRepository.search failed',
          data: e, exception: s);
      throw AppException.firestore('search', e, s);
    }
  }

  /// Geo search χρησιμοποιώντας 9 neighbouring cells για ~97% accuracy.
  Future<SearchResult> _geoSearch(
      SearchFilters filters,
      SearchCursor? cursor,
      int effectiveLimit,
      ) async {
    // Υπολογισμός center geohash
    String centerHash;
    if (filters.latitude != null && filters.longitude != null) {
      final sp = GeoHashUtils.searchPrecision(
        filters.radiusKm ?? 10,
        filters.latitude!,
      );
      DebugConfig.log(DebugConfig.repositoryCall,
          '_geoSearch: adaptive precision=$sp');
      centerHash = GeoHashUtils.encode(
        filters.latitude!,
        filters.longitude!,
        precision: sp,
      );
    } else {
      centerHash = filters.geoHash!;
    }

    final neighbours = GeoHashUtils.getNeighbours(centerHash);

    final allCells = <String>{...neighbours};
    final basePrecision = centerHash.length;
    if (basePrecision > 3) {
      for (final cell in neighbours) {
        allCells.add(cell.substring(0, 3));
      }
      DebugConfig.log(
        DebugConfig.repositoryCall,
        '_geoSearch: added ${allCells.length - neighbours.length} unique '
            '3-char prefixes for city-precision profiles',
      );
    }
    DebugConfig.log(
      DebugConfig.repositoryCall,
      '_geoSearch: centerHash=$centerHash, '
          'baseCells=${neighbours.length}, '
          'expanded=${allCells.length} unique cells',
    );

    final futures = allCells.map((cell) {
      final upper = '$cell~';
      Query q = _firestore
          .collectionGroup('public')
          .where('isVisible', isEqualTo: true)
          .where('geoHash', isGreaterThanOrEqualTo: cell)
          .where('geoHash', isLessThanOrEqualTo: upper)
          .orderBy('geoHash')
          .orderBy('__name__')
          .limit(effectiveLimit);

      if (cursor != null) {
        q = q.startAfter([cursor.sortValue, cursor.docId]);
      }
      return q.get();
    }).toList();

    final snapshots = await Future.wait(futures);

    // Συγχώνευση αποτελεσμάτων - deduplication με uid
    final seen = <String>{};
    final all = <PublicProfile>[];
    for (final snapshot in snapshots) {
      for (final d in snapshot.docs) {
        final data = d.data() as Map<String, dynamic>;
        final uid =
            data['uid'] as String? ?? d.reference.parent.parent?.id ?? '';
        if (uid.isEmpty || seen.contains(uid)) continue;
        seen.add(uid);
        data['uid'] ??= uid;
        all.add(PublicProfile.fromJson(data));
      }
    }

    DebugConfig.log(
      DebugConfig.repositoryCall,
      '_geoSearch: raw results=${all.length} (from ${allCells.length} cells)',
    );

    final filtered =
    all.where((p) => _passesFilters(p, filters)).toList();

    // hasMore: αν ΟΠΟΙΟΔΗΠΟΤΕ snapshot επέστρεψε effectiveLimit docs
    final hasMore =
    snapshots.any((s) => s.docs.length >= effectiveLimit);

    // Cursor: από το τελευταίο doc του πρώτου non-empty snapshot
    QueryDocumentSnapshot? lastDoc;
    for (final s in snapshots) {
      if (s.docs.isNotEmpty) {
        lastDoc = s.docs.last;
        break;
      }
    }
    final cursorOut = hasMore && lastDoc != null
        ? SearchCursor(
      lastDoc.id,
      (lastDoc.data() as Map<String, dynamic>)['geoHash'] as String?,
    )
        : null;

    DebugConfig.log(
      DebugConfig.repositoryResult,
      '_geoSearch: ${filtered.length} results (raw ${all.length}), '
          'hasMore=$hasMore',
    );

    return SearchResult(filtered, hasMore, cursorOut);
  }

  /// General search — city/country server-side for narrowing; age
  /// and other filters applied client-side via [_passesFilters].
  Future<SearchResult> _generalSearch(
      SearchFilters filters,
      SearchCursor? cursor,
      int effectiveLimit,
      ) async {
    Query query = _firestore
        .collectionGroup('public')
        .where('isVisible', isEqualTo: true);

    // City/country: normalized lowercase για case-insensitive match
    // (age removed — range + orderBy('__name__') causes invalid-argument)
    if (filters.city != null && filters.city!.isNotEmpty) {
      query = query.where('cityNormalized',
          isEqualTo: filters.city!.toLowerCase().trim());
    }
    if (filters.country != null && filters.country!.isNotEmpty) {
      query = query.where('countryNormalized',
          isEqualTo: filters.country!.toLowerCase().trim());
    }
    DebugConfig.log(
      DebugConfig.repositoryFilter,
      '_generalSearch: city/country server-side, all other filters client-side',
    );

    query = query.orderBy('__name__').limit(effectiveLimit);

    if (cursor != null) {
      query = query.startAfter([cursor.docId]);
    }

    DebugConfig.log(
      DebugConfig.repositoryCall,
      '_generalSearch: city=${filters.city}, country=${filters.country}',
    );

    final snapshot = await query.get();
    final all = <PublicProfile>[];
    for (final d in snapshot.docs) {
      final data = d.data() as Map<String, dynamic>;
      data['uid'] ??= d.reference.parent.parent?.id;
      all.add(PublicProfile.fromJson(data));
    }

    final filtered =
    all.where((p) => _passesFilters(p, filters)).toList();
    final hasMore = snapshot.docs.length >= effectiveLimit;
    final cursorOut = hasMore && snapshot.docs.isNotEmpty
        ? SearchCursor(
      snapshot.docs.last.id,
      (snapshot.docs.last.data()
      as Map<String, dynamic>)['geoHash'] as String?,
    )
        : null;

    DebugConfig.log(
      DebugConfig.repositoryResult,
      '_generalSearch: ${filtered.length} results (raw ${all.length}), '
          'hasMore=$hasMore',
    );

    return SearchResult(filtered, hasMore, cursorOut);
  }

  @override
  Future<SearchResult> searchNearby(
      double lat,
      double lng,
      double radiusKm, {
        SearchCursor? cursor,
      }) async {
    DebugConfig.log(
      DebugConfig.repositoryCall,
      'searchNearby: ($lat, $lng) r=$radiusKm, cursor=${cursor?.docId}',
    );

    try {
      final sp = GeoHashUtils.searchPrecision(radiusKm, lat);
      DebugConfig.log(DebugConfig.repositoryCall,
          'searchNearby: adaptive precision=$sp');
      final centerHash =
      GeoHashUtils.encode(lat, lng, precision: sp);
      final neighbours = GeoHashUtils.getNeighbours(centerHash);

      final allCells = <String>{...neighbours};
      final basePrecision = centerHash.length;
      if (basePrecision > 3) {
        for (final cell in neighbours) {
          allCells.add(cell.substring(0, 3));
        }
        DebugConfig.log(
          DebugConfig.repositoryCall,
          'searchNearby: added ${allCells.length - neighbours.length} unique '
              '3-char prefixes for city-precision profiles',
        );
      }
      DebugConfig.log(
        DebugConfig.repositoryCall,
        'searchNearby: centerHash=$centerHash, '
            'baseCells=${neighbours.length}, '
            'expanded=${allCells.length} unique cells',
      );

      final futures = allCells.map((cell) {
        final upper = '$cell~';
        Query q = _firestore
            .collectionGroup('public')
            .where('isVisible', isEqualTo: true)
            .where('geoHash', isGreaterThanOrEqualTo: cell)
            .where('geoHash', isLessThanOrEqualTo: upper)
            .orderBy('geoHash')
            .orderBy('__name__')
            .limit(50);
        if (cursor != null) {
          q = q.startAfter([cursor.sortValue, cursor.docId]);
        }
        return q.get();
      }).toList();

      final snapshots = await Future.wait(futures);

      final seen = <String>{};
      final results = <PublicProfile>[];
      for (final snapshot in snapshots) {
        for (final d in snapshot.docs) {
          final data = d.data() as Map<String, dynamic>;
          final uid =
              data['uid'] as String? ?? d.reference.parent.parent?.id ?? '';
          if (uid.isEmpty || seen.contains(uid)) continue;
          seen.add(uid);
          data['uid'] ??= uid;
          results.add(PublicProfile.fromJson(data));
        }
      }

      final preFilterCount = results.length;

      // Haversine post-filter: κράτα μόνο εντός radius
      results.removeWhere((p) {
        if (p.geoHash == null || p.geoHash!.isEmpty) return false;
        final outside =
        !GeoHashUtils.isWithinRadius(p.geoHash!, lat, lng, radiusKm);
        if (outside) {
          DebugConfig.log(
            DebugConfig.gpsGeoHash,
            'searchNearby: filtered ${p.uid} (geoHash=${p.geoHash})',
          );
        }
        return outside;
      });

      if (preFilterCount != results.length) {
        DebugConfig.log(
          DebugConfig.repositoryResult,
          'searchNearby: haversine filtered '
              '${preFilterCount - results.length} profiles',
        );
      }

      final hasMore = snapshots.any((s) => s.docs.length >= 50);
      QueryDocumentSnapshot? lastDoc;
      for (final s in snapshots) {
        if (s.docs.isNotEmpty) {
          lastDoc = s.docs.last;
          break;
        }
      }
      final cursorOut = hasMore && lastDoc != null
          ? SearchCursor(
        lastDoc.id,
        (lastDoc.data() as Map<String, dynamic>)['geoHash'] as String?,
      )
          : null;

      DebugConfig.log(
        DebugConfig.repositoryResult,
        'searchNearby: ${results.length} results, hasMore=$hasMore',
      );

      return SearchResult(results, hasMore, cursorOut);
    } catch (e, s) {
      DebugConfig.error('searchNearby failed', data: e, exception: s);
      throw AppException.firestore('searchNearby', e, s);
    }
  }

  bool _passesFilters(PublicProfile p, SearchFilters f) {
    DebugConfig.log(
      DebugConfig.repositoryFilter,
      '_passesFilters: uid=${p.uid}, city=${p.city}, country=${p.country}, '
          'age=${p.age}, gender=${p.gender}, lookingFor=${p.lookingFor}',
    );

    // City: case-insensitive (fallback αν δεν υπάρχει cityNormalized)
    if (f.city != null && f.city!.isNotEmpty) {
      if (p.city == null ||
          p.city!.toLowerCase() != f.city!.toLowerCase()) {
        DebugConfig.log(DebugConfig.repositoryFilter,
            '_passesFilters: ❌ city: wanted="${f.city}", got="${p.city}"');
        return false;
      }
    }
    if (f.country != null && f.country!.isNotEmpty) {
      if (p.country == null ||
          p.country!.toLowerCase() != f.country!.toLowerCase()) {
        DebugConfig.log(DebugConfig.repositoryFilter,
            '_passesFilters: ❌ country: wanted="${f.country}", got="${p.country}"');
        return false;
      }
    }
    if (f.minAge != null && (p.age == null || p.age! < f.minAge!)) {
      DebugConfig.log(DebugConfig.repositoryFilter,
          '_passesFilters: ❌ minAge: wanted≥${f.minAge}, got=${p.age}');
      return false;
    }
    if (f.maxAge != null && (p.age == null || p.age! > f.maxAge!)) {
      DebugConfig.log(DebugConfig.repositoryFilter,
          '_passesFilters: ❌ maxAge: wanted≤${f.maxAge}, got=${p.age}');
      return false;
    }
    if (f.allowVideoCall == true && !p.allowVideoCall) {
      DebugConfig.log(DebugConfig.repositoryFilter,
          '_passesFilters: ❌ videoCall required but disabled');
      return false;
    }
    if (f.allowDirectChat == true && !p.allowDirectChat) {
      DebugConfig.log(DebugConfig.repositoryFilter,
          '_passesFilters: ❌ directChat required but disabled');
      return false;
    }
    if (f.isOnlineNow == true && !p.isOnline) {
      DebugConfig.log(DebugConfig.repositoryFilter,
          '_passesFilters: ❌ online required but offline');
      return false;
    }
    if (f.lookingFor != null) {
      if (p.lookingFor == null ||
          p.lookingFor!.toLowerCase() != f.lookingFor!.toLowerCase()) {
        DebugConfig.log(DebugConfig.repositoryFilter,
            '_passesFilters: ❌ lookingFor: wanted="${f.lookingFor}", got="${p.lookingFor}"');
        return false;
      }
    }
    if (f.interests != null && f.interests!.isNotEmpty) {
      if (p.interests == null || p.interests!.isEmpty) {
        DebugConfig.log(DebugConfig.repositoryFilter,
            '_passesFilters: ❌ interests required but profile has none');
        return false;
      }
      if (!p.interests!.any(
            (i) => f.interests!.any((fi) => fi.toLowerCase() == i.toLowerCase()),
      )) {
        DebugConfig.log(DebugConfig.repositoryFilter,
            '_passesFilters: ❌ interests mismatch: wanted=${f.interests}, got=${p.interests}');
        return false;
      }
    }
    if (f.gender != null && f.gender != 'all') {
      if (p.gender == null || p.gender != f.gender) {
        DebugConfig.log(DebugConfig.repositoryFilter,
            '_passesFilters: ❌ gender: wanted="${f.gender}", got="${p.gender}"');
        return false;
      }
    }
    // Haversine distance filter
    if (f.latitude != null &&
        f.longitude != null &&
        f.radiusKm != null &&
        f.radiusKm! > 0) {
      if (p.geoHash != null && p.geoHash!.isNotEmpty) {
        if (!GeoHashUtils.isWithinRadius(
          p.geoHash!,
          f.latitude!,
          f.longitude!,
          f.radiusKm!,
        )) {
          DebugConfig.log(
            DebugConfig.gpsGeoHash,
            '_passesFilters: ❌ haversine: uid=${p.uid} outside radius=${f.radiusKm}km',
          );
          return false;
        }
      }
    }
    DebugConfig.log(DebugConfig.repositoryFilter,
        '_passesFilters: ✅ passed uid=${p.uid}');
    return true;
  }
}