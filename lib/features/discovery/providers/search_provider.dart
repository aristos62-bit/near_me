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
        DebugConfig.log(DebugConfig.repositoryFilter,
            '_computeDistances: uid=${p.uid} geoHash=${p.geoHash} city=${p.city} distance=${d.toStringAsFixed(1)}km');
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

  Future<void> search() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        DebugConfig.log(DebugConfig.networkConnectivity,
            'SearchNotifier.search: no connectivity');
        state = const SearchState(
            status: SearchStatus.error, errorMessage: 'search/no-connectivity');
        return;
      }
    } catch (_) {}

    final filters = ref.read(searchFiltersProvider);
    DebugConfig.log(DebugConfig.repositoryCall, 'SearchNotifier.search: $filters');

    _resetPagination();
    _lastType = _SearchType.filters;
    _lastFilters = filters;

    state = const SearchState(status: SearchStatus.loading);
    try {
      final result = await _repo.search(filters);
      final filtered = _excludeSelf(_excludeBlocked(result.results));
      _cursor = result.cursor;
      final lat = filters.latitude;
      final lng = filters.longitude;
      final distances = (lat != null && lng != null)
          ? _computeDistances(filtered, lat, lng)
          : const <String, double>{};
      DebugConfig.log(DebugConfig.repositoryResult,
          'SearchNotifier.search: ${filtered.length} results, hasMore=${result.hasMore}, distances=${distances.length}');
      state = SearchState(
        status: SearchStatus.success,
        results: filtered,
        hasMore: result.hasMore,
        searchCenterLat: lat,
        searchCenterLng: lng,
        distances: distances,
      );
    } catch (e, s) {
      DebugConfig.error('SearchNotifier.search failed', data: e, exception: s);
      state = SearchState(status: SearchStatus.error, errorMessage: _friendlyError(e));
    }
  }

  Future<void> searchNearby(double lat, double lng, double radiusKm) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        DebugConfig.log(DebugConfig.networkConnectivity,
            'SearchNotifier.searchNearby: no connectivity');
        state = const SearchState(
            status: SearchStatus.error, errorMessage: 'search/no-connectivity');
        return;
      }
    } catch (_) {}

    DebugConfig.log(DebugConfig.repositoryCall,
        'SearchNotifier.searchNearby: ($lat, $lng) r=$radiusKm');

    _resetPagination();
    _lastType = _SearchType.nearby;
    _lastLat = lat;
    _lastLng = lng;
    _lastRadius = radiusKm;

    state = const SearchState(status: SearchStatus.loading);
    try {
      final result = await _repo.searchNearby(lat, lng, radiusKm);
      final filtered = _excludeSelf(_excludeBlocked(result.results));
      _cursor = result.cursor;
      final distances = _computeDistances(filtered, lat, lng);
      DebugConfig.log(DebugConfig.repositoryResult,
          'SearchNotifier.searchNearby: ${filtered.length} results, hasMore=${result.hasMore}, distances=${distances.length}');
      state = SearchState(
        status: SearchStatus.success,
        results: filtered,
        hasMore: result.hasMore,
        searchCenterLat: lat,
        searchCenterLng: lng,
        distances: distances,
      );
    } catch (e, s) {
      DebugConfig.error('SearchNotifier.searchNearby failed', data: e, exception: s);
      state = SearchState(status: SearchStatus.error, errorMessage: _friendlyError(e));
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
      DebugConfig.log(DebugConfig.repositoryResult,
          'SearchNotifier.loadMore: +${filtered.length} = ${all.length} total, hasMore=${result.hasMore}, +${newDistances.length} distances = ${allDistances.length} total');

      state = SearchState(
        status: SearchStatus.success,
        results: all,
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
        errorMessage: _friendlyError(e),
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

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('permission-denied')) {
      return 'search/permission-denied';
    }
    if (error is AppException) {
      return error.code;
    }
    DebugConfig.warn('search _friendlyError unhandled: $raw');
    return 'search/unknown-error';
  }

  void clearResults() {
    _resetPagination();
    state = const SearchState();
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
