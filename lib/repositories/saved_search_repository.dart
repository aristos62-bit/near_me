import 'package:drift/drift.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';
import '../data/local/database.dart';
import '../data/local/database_service.dart';
import 'search_repository.dart';

abstract class SavedSearchRepository {
  Future<void> save(SearchFilters filters, String label);
  Future<List<SavedSearchTableData>> getAll();
  Future<void> delete(int id);
  SearchFilters toFilters(SavedSearchTableData s);
}

class SavedSearchRepositoryImpl implements SavedSearchRepository {
  final AppDatabase _db;

  SavedSearchRepositoryImpl({AppDatabase? db})
      : _db = db ?? DatabaseService.instance;

  @override
  Future<void> save(SearchFilters filters, String label) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'SavedSearch.save: $label');
    try {
      await _db.into(_db.savedSearchTable).insert(
        SavedSearchTableCompanion.insert(
          label: Value(label),
          city: Value(filters.city),
          country: Value(filters.country),
          minAge: Value(filters.minAge),
          maxAge: Value(filters.maxAge),
          gender: Value(filters.gender),
          interests: Value(filters.interests),
          lookingFor: Value(filters.lookingFor),
          radiusKm: Value(filters.radiusKm),
          allowVideoCall: Value(filters.allowVideoCall),
          allowDirectChat: Value(filters.allowDirectChat),
          onlineOnly: Value(filters.isOnlineNow),
        ),
      );
      DebugConfig.log(DebugConfig.repositoryResult,
          'SavedSearch saved: $label '
          '(allowVideoCall=${filters.allowVideoCall}, '
          'allowDirectChat=${filters.allowDirectChat}, '
          'onlineOnly=${filters.isOnlineNow})');
    } catch (e, s) {
      DebugConfig.error('SavedSearch.save failed', data: e, exception: s);
      throw AppException.database('SavedSearch.save', e, s);
    }
  }

  @override
  Future<List<SavedSearchTableData>> getAll() async {
    DebugConfig.log(DebugConfig.repositoryCall, 'SavedSearch.getAll');
    try {
      final list = await (_db.select(_db.savedSearchTable)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ).get();
      DebugConfig.log(DebugConfig.repositoryResult, 'SavedSearch.getAll: ${list.length} items');
      return list;
    } catch (e, s) {
      DebugConfig.error('SavedSearch.getAll failed', data: e, exception: s);
      throw AppException.database('SavedSearch.getAll', e, s);
    }
  }

  @override
  Future<void> delete(int id) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'SavedSearch.delete: $id');
    try {
      await (_db.delete(_db.savedSearchTable)..where((t) => t.id.equals(id))).go();
      DebugConfig.log(DebugConfig.repositoryResult, 'SavedSearch deleted: $id');
    } catch (e, s) {
      DebugConfig.error('SavedSearch.delete failed', data: e, exception: s);
      throw AppException.database('SavedSearch.delete', e, s);
    }
  }

  @override
  SearchFilters toFilters(SavedSearchTableData s) {
    DebugConfig.log(DebugConfig.repositoryCall, 'SavedSearch.toFilters: id=${s.id}');
    final filters = SearchFilters(
      city: s.city,
      country: s.country,
      minAge: s.minAge,
      maxAge: s.maxAge,
      gender: s.gender,
      interests: s.interests,
      lookingFor: s.lookingFor,
      radiusKm: s.radiusKm,
      allowVideoCall: s.allowVideoCall,
      allowDirectChat: s.allowDirectChat,
      isOnlineNow: s.onlineOnly,
    );
    DebugConfig.log(DebugConfig.repositoryResult,
        'SavedSearch.toFilters: $filters');
    return filters;
  }
}
