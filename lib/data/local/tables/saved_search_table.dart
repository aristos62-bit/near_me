import 'package:drift/drift.dart';
import 'converters.dart';

class SavedSearchTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get label => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get country => text().nullable()();
  IntColumn get minAge => integer().nullable()();
  IntColumn get maxAge => integer().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get interests =>
      text().map(const StringListConverter()).nullable()();
  TextColumn get lookingFor => text().nullable()();
  RealColumn get radiusKm => real().nullable()();
  BoolColumn get allowVideoCall => boolean().nullable()();
  BoolColumn get allowDirectChat => boolean().nullable()();
  BoolColumn get onlineOnly => boolean().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
