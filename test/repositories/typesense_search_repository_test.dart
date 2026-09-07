import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/repositories/search_repository.dart';
import 'package:near_me/repositories/typesense_search_repository.dart';

void main() {
  const repo = TypesenseSearchRepository();

  test('search → UnimplementedError (Phase 4)', () {
    expect(
      () => repo.search(const SearchFilters()),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test('searchNearby → UnimplementedError (Phase 4)', () {
    expect(
      () => repo.searchNearby(37.9, 23.7, 10),
      throwsA(isA<UnimplementedError>()),
    );
  });
}
