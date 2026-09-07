import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/widgets/app_state_widget.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('ErrorView', () {
    testWidgets('εμφανίζει μήνυμα + error icon', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorView(message: 'Κάτι πήγε στραβά')));
      expect(find.text('Κάτι πήγε στραβά'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('εμφανίζει details όταν δίνονται', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorView(message: 'err', details: 'Λεπτομέρειες σφάλματος'),
      ));
      expect(find.text('Λεπτομέρειες σφάλματος'), findsOneWidget);
    });

    testWidgets('ΜΗΝ εμφανίζει retry όταν onRetry είναι null', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorView(message: 'err')));
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('retry: καλεί την callback όταν πατηθεί', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        ErrorView(message: 'err', onRetry: () => tapped++),
      ));
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      // Ο DebugConfig.log δημιουργεί έναν static 1s flush timer → τον
      // προχωράμε ώστε να ολοκληρωθεί και να μην μείνει pending.
      await tester.pump(const Duration(seconds: 2));
      expect(tapped, 1);
    });
  });

  group('LoadingView', () {
    testWidgets('εμφανίζει CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('εμφανίζει μήνυμα όταν δίνεται', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView(message: 'Φόρτωση...')));
      expect(find.text('Φόρτωση...'), findsOneWidget);
    });

    testWidgets('ΜΗΝ εμφανίζει μήνυμα όταν είναι null', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView()));
      expect(find.text('Φόρτωση...'), findsNothing);
    });
  });

  group('EmptyView', () {
    testWidgets('εμφανίζει μήνυμα + default icon', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyView(message: 'Τίποτα εδώ')));
      expect(find.text('Τίποτα εδώ'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('χρησιμοποιεί custom icon', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyView(icon: Icons.search_off, message: 'empty'),
      ));
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('ΜΗΝ εμφανίζει action button όταν δεν δίνονται δράσεις',
        (tester) async {
      await tester.pumpWidget(_wrap(const EmptyView(message: 'empty')));
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('action: καλεί την callback + εμφανίζει label',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        EmptyView(message: 'empty', actionLabel: 'Πρόσθεσε', onAction: () => tapped++),
      ));
      expect(find.text('Πρόσθεσε'), findsOneWidget);
      await tester.tap(find.text('Πρόσθεσε'));
      // idem: για τον static 1s flush timer του DebugConfig.log
      await tester.pump(const Duration(seconds: 2));
      expect(tapped, 1);
    });
  });
}