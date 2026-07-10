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
  int get schemaVersion => 9;

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
      if (from < 5) {
        await m.addColumn(privacySettingsTable, privacySettingsTable.showCountry);
        DebugConfig.log(DebugConfig.databaseLocal, 'Migration v4->v5: added showCountry column');
      }
      if (from < 6) {
        await m.addColumn(appSettingsTable, appSettingsTable.searchRadiusKm);
        DebugConfig.log(DebugConfig.databaseLocal, 'Migration v5->v6: added searchRadiusKm column');
      }
      if (from < 7) {
        await m.addColumn(chatCacheTable, chatCacheTable.ownerUid);
        // Παλιές εγγραφές (πριν το v7) δεν έχουν ownerUid, άρα δεν
        // μπορούμε να ξέρουμε με ασφάλεια σε ποιον χρήστη ανήκουν.
        // Καθαρίζουμε ΟΛΟΚΛΗΡΟ τον πίνακα cache — θα ξανασυγχρονιστεί
        // αυτόματα και αβλαβώς από το Firestore στο επόμενο streamChats().
        // Αυτό είναι το οριστικό fix του cross-account cache leak.
        await delete(chatCacheTable).go();
        DebugConfig.log(DebugConfig.databaseLocal,
            'Migration v6->v7: added ownerUid column, cleared legacy chat cache (θα ξανασυγχρονιστεί από Firestore)');
      }
      if (from < 8) {
        await m.addColumn(savedSearchTable, savedSearchTable.allowVideoCall);
        await m.addColumn(savedSearchTable, savedSearchTable.allowDirectChat);
        await m.addColumn(savedSearchTable, savedSearchTable.onlineOnly);
        DebugConfig.log(DebugConfig.databaseLocal,
            'Migration v7->v8: added allowVideoCall, allowDirectChat, onlineOnly columns to savedSearchTable');
      }
      if (from < 9) {
        await m.addColumn(chatCacheTable, chatCacheTable.isGroupChat);
        await m.addColumn(chatCacheTable, chatCacheTable.participantCount);
        await m.addColumn(chatCacheTable, chatCacheTable.participantUids);
        await m.addColumn(chatCacheTable, chatCacheTable.groupName);
        DebugConfig.log(DebugConfig.databaseLocal,
            'Migration v8->v9: added group chat columns to ChatCacheTable');
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