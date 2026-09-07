import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/profile/providers/location_service.dart';
import 'package:near_me/shared/widgets/consent_badge.dart';
import 'package:near_me/shared/widgets/gps_strength_indicator.dart';
import 'package:near_me/shared/widgets/online_indicator.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('el'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('el'), Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('OnlineIndicator', () {
    testWidgets('isOnline=true → πράσινο', (tester) async {
      await tester.pumpWidget(_wrap(const OnlineIndicator(isOnline: true)));
      final box = tester.widget<Container>(
        find.byType(Container).first,
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, const Color(0xFF4CAF50));
    });

    testWidgets('isOnline=false → γκρι', (tester) async {
      await tester.pumpWidget(_wrap(const OnlineIndicator(isOnline: false)));
      final box = tester.widget<Container>(
        find.byType(Container).first,
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, Colors.grey);
    });

    testWidgets('custom size εφαρμόζεται', (tester) async {
      await tester.pumpWidget(_wrap(const OnlineIndicator(isOnline: true, size: 20)));
      final box = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(box.constraints?.maxWidth, 20);
      expect(box.constraints?.maxHeight, 20);
    });
  });

  group('ConsentBadge', () {
    testWidgets('ελληνικά: εμφανίζει el label + timestamp', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        ConsentBadge(
          action: 'published',
          dataType: 'profile',
          timestamp: now.subtract(const Duration(minutes: 5)),
        ),
      ));
      expect(find.text('Δημοσίευση προφίλ'), findsOneWidget);
      expect(find.text('5λ πριν'), findsOneWidget);
    });

    testWidgets('αγγλικό locale → en label', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('el')],
        home: Scaffold(
          body: ConsentBadge(
            action: 'published',
            dataType: 'profile',
            timestamp: now.subtract(const Duration(minutes: 5)),
          ),
        ),
      ));
      expect(find.text('Published profile'), findsOneWidget);
    });

    testWidgets('με details → εμφανίζεται chevron', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        ConsentBadge(
          action: 'published',
          dataType: 'profile',
          timestamp: now,
          details: 'extra',
        ),
      ));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('χωρίς details → όχι chevron', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        ConsentBadge(
          action: 'published',
          dataType: 'profile',
          timestamp: now,
        ),
      ));
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('άγνωστο action → εμφανίζει το raw action string',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        ConsentBadge(
          action: 'unknown_action',
          dataType: 'profile',
          timestamp: now,
        ),
      ));
      expect(find.text('unknown_action'), findsOneWidget);
    });

    testWidgets('timestamp: 30 δευτερόλεπτα → Μόλις τώρα', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        ConsentBadge(
          action: 'published',
          dataType: 'profile',
          timestamp: now.subtract(const Duration(seconds: 30)),
        ),
      ));
      expect(find.text('Μόλις τώρα'), findsOneWidget);
    });

    testWidgets('timestamp: 10 ώρες → 10ω πριν', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        ConsentBadge(
          action: 'published',
          dataType: 'profile',
          timestamp: now.subtract(const Duration(hours: 10)),
        ),
      ));
      expect(find.text('10ω πριν'), findsOneWidget);
    });

    testWidgets('timestamp: 3 ημέρες → 3η πριν', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        ConsentBadge(
          action: 'published',
          dataType: 'profile',
          timestamp: now.subtract(const Duration(days: 3)),
        ),
      ));
      expect(find.text('3η πριν'), findsOneWidget);
    });

    testWidgets('timestamp: 60 ημέρες → 2μ πριν', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        ConsentBadge(
          action: 'published',
          dataType: 'profile',
          timestamp: now.subtract(const Duration(days: 60)),
        ),
      ));
      expect(find.text('2μ πριν'), findsOneWidget);
    });

    testWidgets('timestamp: 2 χρόνια → 2χ πριν', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(
        ConsentBadge(
          action: 'published',
          dataType: 'profile',
          timestamp: now.subtract(const Duration(days: 730)),
        ),
      ));
      expect(find.text('2χ πριν'), findsOneWidget);
    });
  });

  group('GpsStrengthIndicator', () {
    testWidgets('render χωρίς cached accuracy → location_on + tap δείχνει χωρίς σήμα',
        (tester) async {
      LocationService.clearSession();
      await tester.pumpWidget(_wrap(const GpsStrengthIndicator()));
      expect(find.byIcon(Icons.location_on), findsOneWidget);

      await tester.tap(find.byType(GpsStrengthIndicator));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Αναμενόμενο μήνυμα hardcoded όταν _accuracyMeters == null
      // (βλ. _showInfo). Πιθανόν να εμφανιστεί ως SnackBar.
      expect(
        find.textContaining(RegExp('GPS')),
        findsWidgets,
      );

      // dispose → ακυρώνει τον poll timer (periodic 60s)
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 7));
    });
  });
}