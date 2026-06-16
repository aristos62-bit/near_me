import 'package:drift/drift.dart';

class BlockedUserTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uid => text().withDefault(const Constant(''))();
  TextColumn get blockedUid => text().withDefault(const Constant(''))();
  DateTimeColumn get blockedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get reason => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {uid, blockedUid},
  ];
}