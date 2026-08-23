import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/utils/app_exception.dart';
import '../../../repositories/firestore_search_repository.dart';
import '../../../repositories/search_repository.dart';
import '../../../shared/models/public_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../block/providers/block_provider.dart';
import 'filters_provider.dart';
import '../../../core/utils/geohash_utils.dart';
import '../../../shared/utils/help_request_config.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'searchRepositoryProvider created');
  return FirestoreSearchRepository();
});

enum SearchStatus { idle, loading, success, error }

class SearchState {
  final SearchStatus status;
  final List<PublicProfile> results;
  final String? errorMessage;
  final bool hasMore;
  final double? searchCenterLat;
  final double? searchCenterLng;
  final Map<String, double> distances;

  const SearchState({
    this.status = SearchStatus.idle,
    this.results = const [],
    this.errorMessage,
    this.hasMore = false,
    this.searchCenterLat,
    this.searchCenterLng,
    this.distances = const {},
  });
}

enum _SearchType { filters, nearby }

class SearchNotifier extends Notifier<SearchState> {
  SearchCursor? _cursor;

  // Last search params for loadMore continuation
  _SearchType? _lastType;
  SearchFilters? _lastFilters;
  double? _lastLat;
  double? _lastLng;
  double? _lastRadius;

  @override
  SearchState build() {
    DebugConfig.log(DebugConfig.providerCreate, 'SearchNotifier built');
    return const SearchState();
  }

  SearchRepository get _repo => ref.read(searchRepositoryProvider);

  Set<String> _blockedUids() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return {};
    final blocked = ref.read(blockedUidsProvider(uid)).value ?? {};
    DebugConfig.log(DebugConfig.repositoryCall, 'SearchNotifier blockedUids: ${blocked.length}');
    return blocked;
  }

  List<PublicProfile> _excludeBlocked(List<PublicProfile> results) {
    final blocked = _blockedUids();
    if (blocked.isEmpty) return results;
    DebugConfig.log(DebugConfig.repositoryCall, 'SearchNotifier excluding ${blocked.length} blocked');
    return results.where((p) => !blocked.contains(p.uid)).toList();
  }

  List<PublicProfile> _excludeSelf(List<PublicProfile> results) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return results;
    return results.where((p) => p.uid != uid).toList();
  }

  Map<String, double> _computeDistances(List<PublicProfile> profiles, double centerLat, double centerLng) {
    final distances = <String, double>{};
    int computed = 0;
    int skipped = 0;
    for (final p in profiles) {
      if (p.geoHash == null || p.geoHash!.isEmpty) {
        skipped++;
        continue;
      }
      try {
        final d = GeoHashUtils.distanceToPoint(p.geoHash!, centerLat, centerLng);
        distances[p.uid] = d;
        computed++;
      } catch (e) {
        skipped++;
        DebugConfig.log(DebugConfig.repositoryCall,
            'SearchNotifier._computeDistances: failed uid=${p.uid}: $e');
      }
    }
    DebugConfig.log(DebugConfig.repositoryCall,
        'SearchNotifier._computeDistances: $computed computed, $skipped skipped, total=${profiles.length}');
    return distances;
  }

  void setError(String code) {
    _resetPagination();
    state = SearchState(status: SearchStatus.error, errorMessage: code);
  }

  /// Stable priority partition (sos.md §6.1): όσοι έχουν ενεργό SOS εντός TTL
  /// ΚΑΙ εντός του δικού τους radiusKm μπαίνουν πρώτοι, οι υπόλοιποι στην
  /// τωρινή σειρά. Καλείται με το φρέσκο distances map της τρέχουσας κλήσης —
  /// ΠΟΤΕ state.distances (BUG 1).
  List<PublicProfile> _prioritizeHelpRequests(
    List<PublicProfile> results,
    Map<String, double> distances,
  ) {
    final now = DateTime.now();
    final urgent = <PublicProfile>[];
    final rest = <PublicProfile>[];
    for (final p in results) {
      final h = p.helpRequest;
      final dist = distances[p.uid];
      final isUrgent = h != null &&
          h.active &&
          h.updatedAt != null &&
          now.difference(h.updatedAt!) <= HelpRequestConfig.ttl &&
          dist != null &&
          dist <= h.radiusKm;
      (isUrgent ? urgent : rest).add(p);
    }
    if (urgent.isEmpty) return results;
    DebugConfig.log(DebugConfig.helpRequest,
        'SearchNotifier: ${urgent.length}/${results.length} urgent SOS prioritized');
    return [...urgent, ...rest];
  }

  /// Πύλη ρυθμού πριν από κάθε ΝΕΟ search (όχι loadMore — απλή
  /// σελιδοποίηση, όχι νέο lat/lng probing). Fail-open: αν η ίδια η
  /// function αποτύχει (δίκτυο, cold start), επιτρέπουμε το search —
  /// ίδιο best-effort σκεπτικό με το computeGeoHash στο profile publish.
  Future<bool> _checkRateLimit() async {
    // Fail-fast: αν η σύνδεση χάθηκε μετά το αρχικό connectivity check του
    // καλούντος, αποφεύγουμε το άσκοπο 4s timeout της CF κλήσης.
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        DebugConfig.log(DebugConfig.networkConnectivity,
            'SearchNotifier._checkRateLimit: no connectivity — skip CF');
        state = const SearchState(
            status: SearchStatus.error, errorMessage: 'search/no-connectivity');
        return false;
      }
    } catch (_) {}
    // TEMP [SEARCH-PERF]: μέτρηση διάρκειας CF κλήσης (ύποπτο για hang)
    final cfSw = Stopwatch()..start();
    // TEMP [SEARCH-PERF]: watchdog — αν η CF δεν απαντήσει, καταγράφεται hang
    var cfDone = false;
    Timer(const Duration(seconds: 5), () {
      if (!cfDone) {
        DebugConfig.warn(
            '[SEARCH-PERF] ⚠️ rateLimit CF STILL PENDING after 5s (πιθανό zombie socket)');
      }
    });
    Timer(const Duration(seconds: 20), () {
      if (!cfDone) {
        DebugConfig.error(
            '[SEARCH-PERF] ⚠️⚠️ rateLimit CF STILL PENDING after 20s — επιβεβαιωμένο κόλλημα');
      }
    });
    try {
      DebugConfig.log(DebugConfig.cloudFunctions,
          'SearchNotifier: calling checkSearchRateLimit');
      final cfCall = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('checkSearchRateLimit')
          .call();
      // TEMP [SEARCH-PERF]: flag completion και σε error path — χωρίς unhandled exception
      unawaited(cfCall.then(
        (_) {
          cfDone = true;
        },
        onError: (Object _) {
          cfDone = true;
        },
      ));
      // FIX: timeout 4s — zombie socket κατά αλλαγή δικτύου κρεμούσε την
      // αναζήτηση έως ~45s. Σε λήξη: TimeoutException → fail-open (catch).
      await cfCall.timeout(const Duration(seconds: 4));
      DebugConfig.log(DebugConfig.cloudFunctions,
          '[SEARCH-PERF] rateLimit CF ok (${cfSw.elapsedMilliseconds}ms)');
      return true;
    } on FirebaseFunctionsException catch (e) {
      final code = e.code.replaceFirst('functions/', '');
      if (code == 'resource-exhausted') {
        DebugConfig.log(DebugConfig.repositoryCall,
            'SearchNotifier: rate limit exceeded (${cfSw.elapsedMilliseconds}ms)');
        state = const SearchState(
            status: SearchStatus.error, errorMessage: 'search/rate-limited');
        return false;
      }
      DebugConfig.warn(
          'SearchNotifier: rate limit check failed (fail-open, ${cfSw.elapsedMilliseconds}ms)',
          data: e);
      return true;
    } catch (e) {
      DebugConfig.warn(
          'SearchNotifier: rate limit check failed (fail-open, ${cfSw.elapsedMilliseconds}ms)',
          data: e);
      return true;
    }
  }

  Future<void> search() async {
    // TEMP [SEARCH-PERF]: διάγνωση καθυστέρησης εκκίνησης — αφαιρείται μετά
    final perfSw = Stopwatch()..start();
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        DebugConfig.log(DebugConfig.networkConnectivity,
            'SearchNotifier.search: no connectivity');
        state = const SearchState(
            status: SearchStatus.error, errorMessage: 'search/no-connectivity');
        return;
      }
      DebugConfig.log(DebugConfig.repositoryCall,
          '[SEARCH-PERF] provider.search: connectivity ok (+${perfSw.elapsedMilliseconds}ms)');
    } catch (_) {}

    if (!await _checkRateLimit()) return;
    DebugConfig.log(DebugConfig.repositoryCall,
        '[SEARCH-PERF] provider.search: rateLimit passed (+${perfSw.elapsedMilliseconds}ms)');

    final filters = ref.read(searchFiltersProvider);
    DebugConfig.log(DebugConfig.repositoryCall, 'SearchNotifier.search: $filters');

    _resetPagination();
    _lastType = _SearchType.filters;
    _lastFilters = filters;

    state = const SearchState(status: SearchStatus.loading);
    try {
      final repoSw = Stopwatch()..start();
      final result = await _repo.search(filters);
      DebugConfig.log(DebugConfig.repositoryCall,
          '[SEARCH-PERF] provider.search: repo=${repoSw.elapsedMilliseconds}ms (+${perfSw.elapsedMilliseconds}ms), raw=${result.results.length}');
      final filtered = _excludeSelf(_excludeBlocked(result.results));
      _cursor = result.cursor;
      final lat = filters.latitude;
      final lng = filters.longitude;
      final distances = (lat != null && lng != null)
          ? _computeDistances(filtered, lat, lng)
          : const <String, double>{};
      final prioritized = _prioritizeHelpRequests(filtered, distances);
      DebugConfig.log(DebugConfig.repositoryResult,
          'SearchNotifier.search: ${filtered.length} results, hasMore=${result.hasMore}, distances=${distances.length}');
      DebugConfig.log(DebugConfig.repositoryCall,
          '[SEARCH-PERF] provider.search: TOTAL=${perfSw.elapsedMilliseconds}ms, results=${prioritized.length}');
      state = SearchState(
        status: SearchStatus.success,
        results: prioritized,
        hasMore: result.hasMore,
        searchCenterLat: lat,
        searchCenterLng: lng,
        distances: distances,
      );
    } catch (e, s) {
      DebugConfig.error('SearchNotifier.search failed', data: e, exception: s);
      state = SearchState(status: SearchStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'search'));
    }
  }

  Future<void> searchNearby(double lat, double lng, double radiusKm) async {
    // TEMP [SEARCH-PERF]: διάγνωση καθυστέρησης εκκίνησης — αφαιρείται μετά
    final perfSw = Stopwatch()..start();
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        DebugConfig.log(DebugConfig.networkConnectivity,
            'SearchNotifier.searchNearby: no connectivity');
        state = const SearchState(
            status: SearchStatus.error, errorMessage: 'search/no-connectivity');
        return;
      }
      DebugConfig.log(DebugConfig.repositoryCall,
          '[SEARCH-PERF] provider.searchNearby: connectivity ok (+${perfSw.elapsedMilliseconds}ms)');
    } catch (_) {}

    if (!await _checkRateLimit()) return;

    DebugConfig.log(DebugConfig.repositoryCall,
        'SearchNotifier.searchNearby: ($lat, $lng) r=$radiusKm (+${perfSw.elapsedMilliseconds}ms)');

    _resetPagination();
    _lastType = _SearchType.nearby;
    _lastLat = lat;
    _lastLng = lng;
    _lastRadius = radiusKm;

    state = const SearchState(status: SearchStatus.loading);
    try {
      final repoSw = Stopwatch()..start();
      final result = await _repo.searchNearby(lat, lng, radiusKm);
      DebugConfig.log(DebugConfig.repositoryCall,
          '[SEARCH-PERF] provider.searchNearby: repo=${repoSw.elapsedMilliseconds}ms (+${perfSw.elapsedMilliseconds}ms), raw=${result.results.length}');
      final filtered = _excludeSelf(_excludeBlocked(result.results));
      _cursor = result.cursor;
      final distances = _computeDistances(filtered, lat, lng);
      final prioritized = _prioritizeHelpRequests(filtered, distances);
      DebugConfig.log(DebugConfig.repositoryResult,
          'SearchNotifier.searchNearby: ${filtered.length} results, hasMore=${result.hasMore}, distances=${distances.length}');
      DebugConfig.log(DebugConfig.repositoryCall,
          '[SEARCH-PERF] provider.searchNearby: TOTAL=${perfSw.elapsedMilliseconds}ms, results=${prioritized.length}');
      state = SearchState(
        status: SearchStatus.success,
        results: prioritized,
        hasMore: result.hasMore,
        searchCenterLat: lat,
        searchCenterLng: lng,
        distances: distances,
      );
    } catch (e, s) {
      DebugConfig.error('SearchNotifier.searchNearby failed', data: e, exception: s);
      state = SearchState(status: SearchStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'search'));
    }
  }

  Future<void> loadMore() async {
    if (state.status != SearchStatus.success || !state.hasMore || _cursor == null) {
      DebugConfig.log(DebugConfig.repositoryCall, 'SearchNotifier.loadMore: skipped (no more)');
      return;
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        DebugConfig.log(DebugConfig.networkConnectivity,
            'SearchNotifier.loadMore: no connectivity — skip');
        return;
      }
    } catch (_) {}

    DebugConfig.log(DebugConfig.repositoryCall,
        'SearchNotifier.loadMore: cursor=${_cursor!.docId}');

    DebugConfig.log(DebugConfig.repositoryCall,
        'SearchNotifier.loadMore: preserving ${state.distances.length} distances, searchCenter=(${state.searchCenterLat}, ${state.searchCenterLng})');
    state = SearchState(
      status: SearchStatus.loading,
      results: state.results,
      hasMore: state.hasMore,
      distances: state.distances,
      searchCenterLat: state.searchCenterLat,
      searchCenterLng: state.searchCenterLng,
    );

    try {
      final SearchResult result;
      switch (_lastType) {
        case _SearchType.filters:
          result = await _repo.search(_lastFilters!, cursor: _cursor);
        case _SearchType.nearby:
          result = await _repo.searchNearby(_lastLat!, _lastLng!, _lastRadius!, cursor: _cursor);
        case null:
          return;
      }

      final filtered = _excludeSelf(_excludeBlocked(result.results));
      _cursor = result.cursor;

      final all = [...state.results, ...filtered];
      final newDistances = (state.searchCenterLat != null && state.searchCenterLng != null)
          ? _computeDistances(filtered, state.searchCenterLat!, state.searchCenterLng!)
          : const <String, double>{};
      final allDistances = {...state.distances, ...newDistances};
      final prioritized = _prioritizeHelpRequests(all, allDistances);
      DebugConfig.log(DebugConfig.repositoryResult,
          'SearchNotifier.loadMore: +${filtered.length} = ${all.length} total, hasMore=${result.hasMore}, +${newDistances.length} distances = ${allDistances.length} total');

      state = SearchState(
        status: SearchStatus.success,
        results: prioritized,
        hasMore: result.hasMore,
        distances: allDistances,
        searchCenterLat: state.searchCenterLat,
        searchCenterLng: state.searchCenterLng,
      );
    } catch (e, s) {
      DebugConfig.error('SearchNotifier.loadMore failed', data: e, exception: s);
      DebugConfig.log(DebugConfig.repositoryCall,
          'SearchNotifier.loadMore error: preserving ${state.distances.length} distances');
      state = SearchState(
        status: SearchStatus.success,
        results: state.results,
        hasMore: state.hasMore,
        errorMessage: AppException.toFriendlyMessage(e, domain: 'search'),
        distances: state.distances,
        searchCenterLat: state.searchCenterLat,
        searchCenterLng: state.searchCenterLng,
      );
    }
  }

  void _resetPagination() {
    _cursor = null;
    _lastType = null;
    _lastFilters = null;
    _lastLat = null;
    _lastLng = null;
    _lastRadius = null;
  }

  void clearResults() {
    _resetPagination();
    state = const SearchState();
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
