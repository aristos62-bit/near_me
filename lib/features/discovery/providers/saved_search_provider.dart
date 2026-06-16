import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../data/local/database.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/saved_search_repository.dart';
import '../../../repositories/search_repository.dart';
import 'filters_provider.dart';
import 'search_provider.dart';

final savedSearchRepositoryProvider = Provider<SavedSearchRepository>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'savedSearchRepositoryProvider created');
  final db = ref.watch(databaseProvider);
  return SavedSearchRepositoryImpl(db: db);
});

final savedSearchesProvider = FutureProvider<List<SavedSearchTableData>>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'savedSearchesProvider created');
  final repo = ref.watch(savedSearchRepositoryProvider);
  return repo.getAll();
});

final savedSearchActionsProvider = Provider<SavedSearchActions>((ref) {
  return SavedSearchActions(ref);
});

class SavedSearchActions {
  final Ref _ref;
  SavedSearchActions(this._ref);

  Future<void> save(SearchFilters filters, String label) async {
    await _ref.read(savedSearchRepositoryProvider).save(filters, label);
    _ref.invalidate(savedSearchesProvider);
  }

  Future<void> delete(int id) async {
    await _ref.read(savedSearchRepositoryProvider).delete(id);
    _ref.invalidate(savedSearchesProvider);
  }

  void apply(SavedSearchTableData s) {
    final filters = _ref.read(savedSearchRepositoryProvider).toFilters(s);
    final fn = _ref.read(searchFiltersProvider.notifier);
    fn.updateAge(filters.minAge, filters.maxAge);
    fn.updateGender(filters.gender);
    fn.updateInterests(filters.interests);
    fn.updateLookingFor(filters.lookingFor);
    fn.updateCity(filters.city);
    fn.updateRadius(filters.radiusKm);
    _ref.read(searchProvider.notifier).search();
  }
}
