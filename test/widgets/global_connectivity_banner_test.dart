import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:near_me/providers/connectivity_provider.dart';
import 'package:near_me/shared/widgets/global_connectivity_banner.dart';

void main() {
  Future<void> pumpBanner(
    WidgetTester tester,
    StreamController<bool> controller,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((_) => controller.stream),
        ],
        child: MaterialApp(
          locale: const Locale('el'),
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('el'), Locale('en')],
          home: const Scaffold(
            body: Stack(
              children: [GlobalConnectivityBanner()],
            ),
          ),
        ),
      ),
    );
    // Σιγουρεύουμε ότι ο StreamProvider εγγράφηκε στον stream πριν τα add,
    // ώστε κανένα event να μην χαθεί.
    await tester.pump();
  }

  Future<void> setOnline(WidgetTester tester, StreamController<bool> c,
      bool online) async {
    c.add(online);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('banner is hidden when online', (tester) async {
    final controller = StreamController<bool>();
    await pumpBanner(tester, controller);
    await setOnline(tester, controller, true);

    expect(find.byType(MaterialBanner), findsNothing);
    await controller.close();
    // Άφησε τον static flush timer του DebugConfig.log να τρέξει.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('banner appears when offline', (tester) async {
    final controller = StreamController<bool>();
    await pumpBanner(tester, controller);
    await setOnline(tester, controller, false);

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text('Εκτός σύνδεσης'), findsOneWidget);
    await controller.close();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('OK dismisses the banner until the next online period',
      (tester) async {
    final controller = StreamController<bool>();
    await pumpBanner(tester, controller);
    await setOnline(tester, controller, false);
    expect(find.byType(MaterialBanner), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.byType(MaterialBanner), findsNothing,
        reason: 'after tapping OK the banner must be dismissed');

    // Εκτός σύνδεσης χωρίς ενδιάμεσο online → παραμένει κρυμμένο (dismissed).
    await setOnline(tester, controller, false);
    expect(find.byType(MaterialBanner), findsNothing,
        reason: 'dismiss persists while still offline');

    // Μόλις επανέλθει το online, το _dismissed resets.
    await setOnline(tester, controller, true);
    await setOnline(tester, controller, false);
    expect(find.byType(MaterialBanner), findsOneWidget,
        reason: '_dismissed resets after an online period, banner can show again');

    await controller.close();
    await tester.pump(const Duration(seconds: 2));
  });
}
