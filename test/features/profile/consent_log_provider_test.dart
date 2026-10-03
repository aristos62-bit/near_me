import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/profile/providers/consent_log_provider.dart';
import 'package:near_me/providers/database_provider.dart';

const _uid = 'test-uid';

Future<AppDatabase> _openDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<void> _seed(AppDatabase db, int count, {String uid = _uid}) async {
  final base = DateTime(2026, 1, 1);
  for (var i = 0; i < count; i++) {
    await db.into(db.consentLogTable).insert(
          ConsentLogTableCompanion.insert(
            uid: Value(uid),
            action: Value('publish'),
            dataType: Value('profile'),
            timestamp: Value(base.add(Duration(minutes: i))),
          ),
        );
  }
}

ProviderContainer _container(AppDatabase db) {
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('55 rows → first page 50 + hasMore, loadMore → 55 total', () async {
    final db = await _openDb();
    await _seed(db, 55);
    final container = _container(db);
    final sub = container.listen(consentLogProvider, (prev, next) {});
    addTearDown(sub.close);

    final notifier = container.read(consentLogProvider.notifier);
    notifier.consentUidProvider = () => _uid;
    await notifier.refresh();

    var state = container.read(consentLogProvider);
    expect(state.asData?.value.length, 50);
    expect(notifier.hasMore, isTrue);

    await notifier.loadMore();
    state = container.read(consentLogProvider);
    expect(state.asData?.value.length, 55);
    expect(notifier.hasMore, isFalse);
  });

  test('3 rows → all + hasMore false', () async {
    final db = await _openDb();
    await _seed(db, 3);
    final container = _container(db);

    final notifier = container.read(consentLogProvider.notifier);
    notifier.consentUidProvider = () => _uid;
    await notifier.refresh();

    expect(container.read(consentLogProvider).asData?.value.length, 3);
    expect(notifier.hasMore, isFalse);
  });

  test('rows ordered by timestamp desc', () async {
    final db = await _openDb();
    await _seed(db, 3);
    final container = _container(db);

    final notifier = container.read(consentLogProvider.notifier);
    notifier.consentUidProvider = () => _uid;
    await notifier.refresh();

    final rows = container.read(consentLogProvider).asData!.value;
    expect(rows.length, 3);
    for (var i = 0; i < rows.length - 1; i++) {
      expect(
        rows[i].timestamp.isAfter(rows[i + 1].timestamp) ||
            rows[i].timestamp.isAtSameMomentAs(rows[i + 1].timestamp),
        isTrue,
      );
    }
  });

  test('other uid rows are excluded', () async {
    final db = await _openDb();
    await _seed(db, 2, uid: 'other-uid');
    await _seed(db, 1);
    final container = _container(db);

    final notifier = container.read(consentLogProvider.notifier);
    notifier.consentUidProvider = () => _uid;
    await notifier.refresh();

    expect(container.read(consentLogProvider).asData?.value.length, 1);
  });

  test('hook returns null → empty list', () async {
    final db = await _openDb();
    await _seed(db, 2);
    final container = _container(db);

    final notifier = container.read(consentLogProvider.notifier);
    notifier.consentUidProvider = () => null;
    await notifier.refresh();

    expect(container.read(consentLogProvider).asData?.value, isEmpty);
  });

  test('refresh resets pagination', () async {
    final db = await _openDb();
    await _seed(db, 55);
    final container = _container(db);

    final notifier = container.read(consentLogProvider.notifier);
    notifier.consentUidProvider = () => _uid;
    await notifier.refresh();
    await notifier.loadMore();
    expect(container.read(consentLogProvider).asData?.value.length, 55);

    await notifier.refresh();
    expect(container.read(consentLogProvider).asData?.value.length, 50);
    expect(notifier.hasMore, isTrue);
  });

  test('db read throws → error state preserved', () async {
    final db = await _openDb();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) => throw StateError('db failure')),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final notifier = container.read(consentLogProvider.notifier);
    notifier.consentUidProvider = () => _uid;
    await notifier.refresh();

    expect(container.read(consentLogProvider).hasError, isTrue);
  });
}
