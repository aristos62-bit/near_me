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
  BoolColumn get crashReportsEnabled =>
      boolean().withDefault(const Constant(false))();
  /// Blur explicit content toggle (schema v16) — default `true`· το FeatureFlag
  /// εφαρμόζεται στο provider layer (app_settings_provider) ως fallback.
  BoolColumn get blurExplicitEnabled =>
      boolean().withDefault(const Constant(true))();
  /// Blur sigma (schema v17) — 0=off, 8/12/20 intensity (reuse _AutoLockTile pattern)
  RealColumn get blurSigma =>
      real().withDefault(const Constant(12.0))();
  IntColumn get autoLockMinutes =>
      integer().withDefault(const Constant(5))();
  RealColumn get searchRadiusKm =>
      real().withDefault(const Constant(10.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
