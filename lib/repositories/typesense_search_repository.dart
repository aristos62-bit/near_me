import 'search_repository.dart';

class TypesenseSearchRepository implements SearchRepository {
  const TypesenseSearchRepository();

  @override
  Future<SearchResult> search(SearchFilters filters, {SearchCursor? cursor}) {
    throw UnimplementedError('Typesense search not implemented yet — Phase 4');
  }

  @override
  Future<SearchResult> searchNearby(double lat, double lng, double radiusKm,
      {SearchCursor? cursor}) {
    throw UnimplementedError('Typesense search not implemented yet — Phase 4');
  }
}
