import 'package:drift/drift.dart';

class ConsentLogTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uid => text().nullable()();
  TextColumn get action => text().withDefault(const Constant(''))();
  TextColumn get dataType => text().withDefault(const Constant(''))();
  TextColumn get details => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}
