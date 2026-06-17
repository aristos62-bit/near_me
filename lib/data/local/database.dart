import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/user_profile_table.dart';
import 'tables/privacy_settings_table.dart';
import 'tables/consent_log_table.dart';
import 'tables/chat_cache_table.dart';
import 'tables/saved_search_table.dart';
import 'tables/app_settings_table.dart';
import 'tables/blocked_user_table.dart';
import 'tables/converters.dart';
import '../../core/debug/debug_config.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  UserProfileTable,
  PrivacySettingsTable,
  ConsentLogTable,
  ChatCacheTable,
  SavedSearchTable,
  AppSettingsTable,
  BlockedUserTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'nearme_db');
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(chatCacheTable, chatCacheTable.otherAvatarUrl);
      }
      if (from < 3) {
        await m.addColumn(chatCacheTable, chatCacheTable.lastMessage);
        await m.addColumn(chatCacheTable, chatCacheTable.lastMessageSender);
        await m.addColumn(chatCacheTable, chatCacheTable.lastMessageType);
        await m.addColumn(chatCacheTable, chatCacheTable.unreadCount);
        DebugConfig.log(DebugConfig.databaseLocal, 'Migration v2->v3: added chat preview columns');
      }
      if (from < 4) {
        await m.addColumn(privacySettingsTable, privacySettingsTable.showPhotos);
        DebugConfig.log(DebugConfig.databaseLocal, 'Migration v3->v4: added showPhotos column');
      }
    },
  );

  Future<void> clearAllTables() async {
    await delete(userProfileTable).go();
    await delete(privacySettingsTable).go();
    await delete(consentLogTable).go();
    await delete(chatCacheTable).go();
    await delete(savedSearchTable).go();
    await delete(appSettingsTable).go();
    await delete(blockedUserTable).go();
  }

  Future<int> logConsent(
      String uid,
      String action,
      String dataType, {
        String? details,
      }) async {
    return into(consentLogTable).insert(
      ConsentLogTableCompanion.insert(
        uid: Value(uid),
        action: Value(action),
        dataType: Value(dataType),
        details: Value(details),
      ),
    );
  }
}