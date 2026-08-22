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

  /// Try/catch ανά έγγραφο (sos.md §9.1 / Εύρημα #4): ένα malformed δημόσιο
  /// προφίλ (π.χ. κατεστραμμένο nested `helpRequest`) skip-άρεται με warn αντί
  /// να ρίξει ΟΛΗ την αναζήτηση. Χωρίς side effect σε hasMore/cursor (raw docs).
  PublicProfile? _tryParsePublicProfile(Map<String, dynamic> data) {
    try {
      return PublicProfile.fromJson(data);
    } catch (e) {
      DebugConfig.warn(
          'FirestoreSearchRepository: skipped malformed public profile (uid=${data['uid']}): $e');
      return null;
    }
  }

  @override
  Future<SearchResult> search(SearchFilters filters,
      {SearchCursor? cursor}) async {
    DebugConfig.log(
      DebugConfig.repositoryCall,
      'FirestoreSearchRepository.search: requested=${filters.limit}, '
          'cursor=${cursor?.docId}',
    );

    GeoHashUtils.clearDistanceCache();

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

    // TEMP [SEARCH-PERF]: μέτρηση διάρκειας παράλληλων cell queries
    DebugConfig.log(DebugConfig.repositoryCall,
        '[SEARCH-PERF] _geoSearch: fetch starting (${allCells.length} cells)...');
    final fetchSw = Stopwatch()..start();
    final snapshots = await Future.wait(futures);
    DebugConfig.log(
      DebugConfig.repositoryCall,
      '[SEARCH-PERF] _geoSearch: Future.wait=${fetchSw.elapsedMilliseconds}ms, '
          'cells=${allCells.length}, docs/cell=[${snapshots.map((s) => s.docs.length).join(",")}]',
    );

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
        final parsed = _tryParsePublicProfile(data);
        if (parsed != null) all.add(parsed);
      }
    }

    DebugConfig.log(
      DebugConfig.repositoryCall,
      '_geoSearch: raw results=${all.length} (from ${allCells.length} cells)',
    );

    final filtered = _filterAndLog(all, filters, '_geoSearch');

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
      final parsed = _tryParsePublicProfile(data);
      if (parsed != null) all.add(parsed);
    }

    final filtered = _filterAndLog(all, filters, '_generalSearch');
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

    GeoHashUtils.clearDistanceCache();

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

      // TEMP [SEARCH-PERF]: μέτρηση διάρκειας παράλληλων cell queries
      DebugConfig.log(DebugConfig.repositoryCall,
          '[SEARCH-PERF] searchNearby: fetch starting (${allCells.length} cells)...');
      final fetchSw = Stopwatch()..start();
      final snapshots = await Future.wait(futures);
      DebugConfig.log(
        DebugConfig.repositoryCall,
        '[SEARCH-PERF] searchNearby: Future.wait=${fetchSw.elapsedMilliseconds}ms, '
            'cells=${allCells.length}, docs/cell=[${snapshots.map((s) => s.docs.length).join(",")}]',
      );

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
          final parsed = _tryParsePublicProfile(data);
          if (parsed != null) results.add(parsed);
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

  /// Φιλτράρει τα candidates πελάτη-side με ένα summary log ΑΝΤΙ πλήθος
  /// per-user γραμμών: `X/Y candidates passed filters (rejected: reason=N, ...)`.
  /// Τα rejection reasons ταξινομούνται σε ομάδες (gender, age, radius...),
  /// ώστε το «γιατί βγάζει 0 αποτελέσματα» να διαγιγνώσκεται σε μία γραμμή.
  List<PublicProfile> _filterAndLog(
      List<PublicProfile> all, SearchFilters f, String label) {
    final rejected = <String, int>{};
    final passed = <PublicProfile>[];
    for (final p in all) {
      final r = _passesFilters(p, f);
      if (r.$1) {
        passed.add(p);
      } else {
        final reason = r.$2 ?? 'unknown';
        rejected[reason] = (rejected[reason] ?? 0) + 1;
      }
    }
    final rejectDesc = rejected.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    DebugConfig.log(
      DebugConfig.repositoryFilter,
      rejectDesc.isEmpty
          ? '$label: ${passed.length}/${all.length} candidates passed filters'
          : '$label: ${passed.length}/${all.length} candidates passed filters (rejected: $rejectDesc)',
    );
    return passed;
  }

  /// Επιστρέφει (passed, reason) — ο λόγος απόρριψης ομαδοποιημένος
  /// ώστε να συγκεντρώνεται στο [DebugConfig.repositoryFilter] summary.
  (bool, String?) _passesFilters(PublicProfile p, SearchFilters f) {
    // City: case-insensitive (fallback αν δεν υπάρχει cityNormalized)
    if (f.city != null && f.city!.isNotEmpty) {
      if (p.city == null ||
          p.city!.toLowerCase() != f.city!.toLowerCase()) {
        return (false, 'city');
      }
    }
    if (f.country != null && f.country!.isNotEmpty) {
      if (p.country == null ||
          p.country!.toLowerCase() != f.country!.toLowerCase()) {
        return (false, 'country');
      }
    }
    if (f.minAge != null && (p.age == null || p.age! < f.minAge!)) {
      return (false, 'age');
    }
    if (f.maxAge != null && (p.age == null || p.age! > f.maxAge!)) {
      return (false, 'age');
    }
    if (f.allowVideoCall == true && !p.allowVideoCall) {
      return (false, 'videoCall');
    }
    if (f.allowDirectChat == true && !p.allowDirectChat) {
      return (false, 'directChat');
    }
    if (f.isOnlineNow == true && !p.isOnline) {
      return (false, 'online');
    }
    if (f.lookingFor != null) {
      if (p.lookingFor == null ||
          p.lookingFor!.toLowerCase() != f.lookingFor!.toLowerCase()) {
        return (false, 'lookingFor');
      }
    }
    if (f.interests != null && f.interests!.isNotEmpty) {
      if (p.interests == null || p.interests!.isEmpty) {
        return (false, 'interests');
      }
      if (!p.interests!.any(
            (i) => f.interests!.any((fi) => fi.toLowerCase() == i.toLowerCase()),
      )) {
        return (false, 'interests');
      }
    }
    if (f.gender != null && f.gender != 'all') {
      if (p.gender == null || p.gender != f.gender) {
        return (false, 'gender');
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
          return (false, 'radius');
        }
      }
    }
    return (true, null);
  }
}