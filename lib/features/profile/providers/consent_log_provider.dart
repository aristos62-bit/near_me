import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../data/local/database.dart';
import '../../../providers/database_provider.dart';

final consentLogStreamProvider = StreamProvider.autoDispose<List<ConsentLogTableData>>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'consentLogStreamProvider created');

  final db = ref.watch(databaseProvider);
  final user = FirebaseAuth.instance.currentUser;
  final uid = user?.uid;

  if (uid == null || uid.isEmpty) {
    DebugConfig.warn('consentLogStreamProvider: no authenticated user, returning empty stream');
    return Stream.empty();
  }

  DebugConfig.log(DebugConfig.consentLogRead, 'consentLogStreamProvider started for uid: $uid');

  try {
    return (db.select(db.consentLogTable)
      ..where((t) => t.uid.equals(uid))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
    ).watch().map((rows) {
      DebugConfig.log(DebugConfig.consentLogRead, 'consentLog emitted: ${rows.length} entries');
      return rows;
    });
  } catch (e, s) {
    DebugConfig.error('consentLogStreamProvider watch failed', data: e, exception: s);
    rethrow;
  }
});
