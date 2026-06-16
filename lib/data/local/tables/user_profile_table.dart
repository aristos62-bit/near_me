import 'package:drift/drift.dart';
import 'converters.dart';

class UserProfileTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uid => text().nullable()();

  TextColumn get nickname => text().nullable()();
  TextColumn get fullName => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get bio => text().nullable()();
  IntColumn get birthYear => integer().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get interests =>
      text().map(const StringListConverter()).nullable()();
  TextColumn get occupations =>
      text().map(const StringListConverter()).nullable()();
  TextColumn get lookingFor => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get country => text().nullable()();
  RealColumn get latitudeExact => real().nullable()();
  RealColumn get longitudeExact => real().nullable()();
  TextColumn get manualLocationText => text().nullable()();

  TextColumn get avatarUrl => text().nullable()();
  TextColumn get photoUrls =>
      text().map(const StringListConverter()).nullable()();

  BoolColumn get allowVideoCall =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get allowDirectChat =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isPublished =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
