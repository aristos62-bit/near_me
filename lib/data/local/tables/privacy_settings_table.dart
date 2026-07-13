import 'package:drift/drift.dart';

class PrivacySettingsTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uid => text().nullable()();

  BoolColumn get showNickname =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showFullName =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showAge => boolean().withDefault(const Constant(true))();
  BoolColumn get showGender => boolean().withDefault(const Constant(true))();
  BoolColumn get showCity => boolean().withDefault(const Constant(true))();
  BoolColumn get showExactLocation =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showPhone =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showEmail =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showInterests =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showOccupation =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showBio => boolean().withDefault(const Constant(true))();
  BoolColumn get showLookingFor =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showAvatar =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showPhotos =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showCountry =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get allowVideoCall =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get allowDirectChat =>
      boolean().withDefault(const Constant(false))();
  TextColumn get geoPrecision =>
      text().withDefault(const Constant('neighborhood'))();
}
