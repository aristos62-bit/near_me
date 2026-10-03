import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/profile/providers/consent_log_provider.dart';
import 'package:near_me/features/profile/screens/consent_log_screen.dart';
import 'package:near_me/providers/database_provider.dart';

/// Widget tests για `ConsentLogScreen` (Γ7).
/// In-memory Drift + DI hook (pattern `consent_log_provider_test`).
const _uid = 'test-uid';

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<AppDatabase> _openDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<void> _seed(AppDatabase db, int count,
    {String uid = _uid, String action = 'publish'}) async {
  final base = DateTime(2026, 1, 1);
  for (var i = 0; i < count; i++) {
    await db.into(db.consentLogTable).insert(
          ConsentLogTableCompanion.insert(
            uid: Value(uid),
            action: Value(action),
            dataType: Value('profile'),
            timestamp: Value(base.add(Duration(minutes: i))),
          ),
        );
  }
}

Future<ProviderContainer> _container(AppDatabase db) async {
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  final notifier = container.read(consentLogProvider.notifier);
  notifier.consentUidProvider = () => _uid;
  await notifier.refresh();
  return container;
}

Future<void> _pump(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        locale: Locale('el'),
        supportedLocales: [Locale('el'), Locale('en')],
        localizationsDelegates: _delegates,
        home: ConsentLogScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('ConsentLogScreen render', () {
    testWidgets('entries με labels + dataType', (tester) async {
      final db = await _openDb();
      await _seed(db, 3, action: 'published');
      final c = await _container(db);
      await _pump(tester, c);
      expect(find.text('Δημοσίευση προφίλ'), findsNWidgets(3));
      expect(find.text('Δεδομένα: Προφίλ'), findsNWidgets(3));
      await _settleTimer(tester);
    });

    testWidgets('άδειο → EmptyView', (tester) async {
      final db = await _openDb();
      final c = await _container(db);
      await _pump(tester, c);
      expect(find.textContaining('Δεν υπάρχουν καταχωρήσεις'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('φίλτρο αποκλείει άλλες ενέργειες', (tester) async {
      final db = await _openDb();
      await _seed(db, 2, action: 'publish');
      await _seed(db, 1, action: 'sent_request');
      final c = await _container(db);
      await _pump(tester, c);
      expect(find.text('Δεδομένα: Προφίλ'), findsNWidgets(3));
      final chip = find.descendant(
          of: find.byType(FilterChip),
          matching: find.text('Αποστολή αιτήματος'));
      await _tapVisible(tester, chip);
      expect(find.text('Δεδομένα: Προφίλ'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('55 rows → loadMore', (tester) async {
      final db = await _openDb();
      await _seed(db, 55);
      final c = await _container(db);
      await _pump(tester, c);
      await tester.scrollUntilVisible(find.text('Φόρτωση παλαιότερων'), 500,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Φόρτωση παλαιότερων'));
      await tester.pumpAndSettle();
      expect(find.text('Φόρτωση παλαιότερων'), findsNothing);
      await _settleTimer(tester);
    });
  });
}
