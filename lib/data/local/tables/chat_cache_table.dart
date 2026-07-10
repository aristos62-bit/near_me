import 'package:drift/drift.dart';

class ChatCacheTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Firebase uid του κατόχου της τοπικής εγγραφής (ο χρήστης της
  /// συσκευής, ΟΧΙ ο συνομιλητής). Χρησιμοποιείται για να αποτρέψει
  /// διαρροή cached συνομιλιών μεταξύ διαφορετικών λογαριασμών στην
  /// ίδια συσκευή. Nullable μόνο για συμβατότητα με παλιές εγγραφές
  /// πριν το migration v7 (καθαρίζονται αυτόματα, βλ. database.dart).
  TextColumn get ownerUid => text().nullable()();

  TextColumn get chatId => text().nullable()();
  TextColumn get otherUid => text().nullable()();
  TextColumn get otherNickname => text().nullable()();
  TextColumn get otherAvatarUrl => text().nullable()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  TextColumn get lastMessage => text().nullable()();
  TextColumn get lastMessageSender => text().nullable()();
  TextColumn get lastMessageType => text().nullable()();
  IntColumn get unreadCount =>
      integer().withDefault(const Constant(0))();
  BoolColumn get hasUnread =>
      boolean().withDefault(const Constant(false))();

  /// Group chat flags (schema v9)
  BoolColumn get isGroupChat =>
      boolean().withDefault(const Constant(false))();
  IntColumn get participantCount =>
      integer().withDefault(const Constant(2))();
  TextColumn get participantUids => text().nullable()();
  TextColumn get groupName => text().nullable()();

  /// Group avatar URL (schema v10)
  TextColumn get groupAvatarUrl => text().nullable()();
}