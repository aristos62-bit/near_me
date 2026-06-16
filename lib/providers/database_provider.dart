import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database.dart';
import '../data/local/database_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return DatabaseService.instance;
});
