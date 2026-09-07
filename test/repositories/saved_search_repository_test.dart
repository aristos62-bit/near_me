import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/repositories/saved_search_repository.dart';
import 'package:near_me/repositories/search_repository.dart';

import '../helpers/failing_drift.dart';

void main() {
  late AppDatabase db;
  late SavedSearchRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SavedSearchRepositoryImpl(db: db);
  });

  setUpAll(() {
    registerDriftFallbacks();
  });

  tearDown(() async {
    await db.close();
  });

  SearchFilters fullFilters() => const SearchFilters(
        city: 'Athens',
        country: 'Greece',
        minAge: 18,
        maxAge: 40,
        gender: 'female',
        interests: ['music', 'travel'],
        lookingFor: 'friends',
        radiusKm: 15,
        allowVideoCall: true,
        allowDirectChat: false,
        isOnlineNow: true,
        limit: 20,
      );

  group('save / getAll', () {
    test('save → γράφει row με σωστά πεδία', () async {
      await repo.save(fullFilters(), 'My search');

      final rows = await (db.select(db.savedSearchTable)).get();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.label, 'My search');
      expect(row.city, 'Athens');
      expect(row.country, 'Greece');
      expect(row.minAge, 18);
      expect(row.maxAge, 40);
      expect(row.gender, 'female');
      expect(row.interests, ['music', 'travel']);
      expect(row.lookingFor, 'friends');
      expect(row.radiusKm, 15);
      expect(row.allowVideoCall, isTrue);
      expect(row.allowDirectChat, isFalse);
      expect(row.onlineOnly, isTrue);
    });

    test('getAll → ταξινομημένα createdAt DESC', () async {
      await db.into(db.savedSearchTable).insert(
        SavedSearchTableCompanion.insert(
          label: const Value('older'),
          city: const Value('Athens'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.into(db.savedSearchTable).insert(
        SavedSearchTableCompanion.insert(
          label: const Value('newer'),
          city: const Value('Athens'),
          createdAt: Value(DateTime(2026, 2, 1)),
        ),
      );

      final rows = await repo.getAll();
      expect(rows.map((r) => r.label).toList(), ['newer', 'older']);
    });

    test('save Drift λάθος → database_error', () async {
      final failingDb = AppDatabase.forTesting(failingDriftExecutor());
      final failingRepo = SavedSearchRepositoryImpl(db: failingDb);
      await expectLater(
        failingRepo.save(fullFilters(), 'My search'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'database_error')),
      );
    });

    test('getAll Drift λάθος → database_error', () async {
      final failingDb = AppDatabase.forTesting(failingDriftExecutor());
      final failingRepo = SavedSearchRepositoryImpl(db: failingDb);
      await expectLater(
        failingRepo.getAll(),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'database_error')),
      );
    });
  });

  group('delete', () {
    test('delete → σβήνει τη γραμμή', () async {
      await repo.save(fullFilters(), 'My search');
      final rows = await repo.getAll();
      await repo.delete(rows.single.id);

      expect(await repo.getAll(), isEmpty);
    });

    test('delete Drift λάθος → database_error', () async {
      final failingDb = AppDatabase.forTesting(failingDriftExecutor());
      final failingRepo = SavedSearchRepositoryImpl(db: failingDb);
      await expectLater(
        failingRepo.delete(1),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'database_error')),
      );
    });
  });

  group('toFilters', () {
    test('round-trip: save → getAll → toFilters ισοδυναμεί με το SearchFilters',
        () async {
      await repo.save(fullFilters(), 'My search');
      final rows = await repo.getAll();
      final filters = repo.toFilters(rows.single);

      expect(filters, fullFilters());
    });

    test('null/optional πεδία διατηρούνται ως null', () async {
      await repo.save(const SearchFilters(city: 'Athens'), 'partial');
      final rows = await repo.getAll();
      final filters = repo.toFilters(rows.single);

      expect(filters.city, 'Athens');
      expect(filters.minAge, isNull);
      expect(filters.interests, isNull);
      expect(filters.isOnlineNow, isNull);
    });
  });
}
