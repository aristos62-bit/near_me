import 'package:drift/drift.dart';

class ChatCacheTable extends Table {
  IntColumn get id => integer().autoIncrement()();

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
}
