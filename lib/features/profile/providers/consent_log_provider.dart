import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../data/local/database.dart';
import '../../../providers/database_provider.dart';

class ConsentLogNotifier extends Notifier<AsyncValue<List<ConsentLogTableData>>> {
  static const int _pageSize = 50;
  int _page = 0;
  bool hasMore = true;
  bool _isLoading = false;

  @override
  AsyncValue<List<ConsentLogTableData>> build() {
    DebugConfig.log(DebugConfig.consentLogRead, 'consentLogProvider built');
    _page = 0;
    hasMore = true;
    _loadInitial();
    return const AsyncValue.loading();
  }

  Future<void> _loadInitial() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final db = ref.read(databaseProvider);
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null || uid.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }
      final rows = await (db.select(db.consentLogTable)
        ..where((t) => t.uid.equals(uid))
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
        ..limit(_pageSize)
      ).get();

      if (rows.length < _pageSize) hasMore = false;
      _page = 1;
      state = AsyncValue.data(rows);
      DebugConfig.log(DebugConfig.consentLogRead,
          'consentLog loaded: ${rows.length} entries, hasMore=$hasMore');
    } catch (e, s) {
      DebugConfig.error('consentLog load failed', data: e, exception: s);
      state = AsyncValue.error(e, s);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || _isLoading) return;
    _isLoading = true;
    try {
      final db = ref.read(databaseProvider);
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null || uid.isEmpty) return;

      final rows = await (db.select(db.consentLogTable)
        ..where((t) => t.uid.equals(uid))
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
        ..limit(_pageSize, offset: _page * _pageSize)
      ).get();

      if (rows.length < _pageSize) hasMore = false;
      final existing = state.asData?.value ?? [];
      state = AsyncValue.data([...existing, ...rows]);
      _page++;
      DebugConfig.log(DebugConfig.consentLogRead,
          'consentLog loadMore: ${rows.length} entries, '
          'total=${existing.length + rows.length}, hasMore=$hasMore');
    } catch (e, s) {
      DebugConfig.error('consentLog loadMore failed', data: e, exception: s);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() async {
    _page = 0;
    hasMore = true;
    state = const AsyncValue.loading();
    await _loadInitial();
  }
}

final consentLogProvider =
    NotifierProvider<ConsentLogNotifier, AsyncValue<List<ConsentLogTableData>>>(
  ConsentLogNotifier.new,
);
