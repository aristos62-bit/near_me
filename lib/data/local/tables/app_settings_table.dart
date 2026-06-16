import 'package:drift/drift.dart';

class AppSettingsTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get locale =>
      text().withDefault(const Constant('el'))();
  TextColumn get themeMode =>
      text().withDefault(const Constant('system'))();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get biometricLockEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get screenshotPreventionEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get autoLockMinutes =>
      integer().withDefault(const Constant(5))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
