import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/widgets/gradient_header.dart';
import 'package:near_me/shared/widgets/save_button.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('GradientHeader', () {
    testWidgets('εμφανίζει title, subtitle και default icon', (tester) async {
      await tester.pumpWidget(_wrap(
        const GradientHeader(icon: Icons.person, title: 'Προφίλ', subtitle: 'Υπότιτλος'),
      ));
      expect(find.text('Προφίλ'), findsOneWidget);
      expect(find.text('Υπότιτλος'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('χρησιμοποιεί custom child αντί για default icon',
        (tester) async {
      await tester.pumpWidget(_wrap(
        GradientHeader(
          icon: Icons.person,
          title: 'Προφίλ',
          subtitle: 'Υπότιτλος',
          child: const Text('CUSTOM CHILD'),
        ),
      ));
      expect(find.text('CUSTOM CHILD'), findsOneWidget);
      // Default icon ΔΕΝ εμφανίζεται όταν δίνεται custom child
      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets('εφαρμόζει custom padding', (tester) async {
      const padding = EdgeInsets.fromLTRB(10, 20, 30, 40);
      await tester.pumpWidget(_wrap(
        GradientHeader(
          icon: Icons.person,
          title: 'Προφίλ',
          subtitle: 'Υπότιτλος',
          padding: padding,
        ),
      ));

      final container = tester.widget<Container>(
        find.ancestor(of: find.text('Προφίλ'), matching: find.byType(Container)).first,
      );
      expect(container.padding, padding);
    });
  });

  group('SaveButton', () {
    testWidgets('normal state: label + icon, onPressed ενεργό', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        SaveButton(
          isSaving: false,
          label: 'Αποθήκευση',
          onPressed: () => tapped++,
        ),
      ));

      expect(find.text('Αποθήκευση'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('Αποθήκευση'));
      expect(tapped, 1);
    });

    testWidgets('saving state: savingLabel + spinner, onPressed απενεργοποιημένο',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        SaveButton(
          isSaving: true,
          label: 'Αποθήκευση',
          onPressed: () => tapped++,
        ),
      ));

      expect(find.text('Αποθήκευση...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Απενεργοποιημένο → το tap δεν καλεί την callback
      await tester.tap(find.byType(SaveButton), warnIfMissed: false);
      expect(tapped, 0);
    });

    testWidgets('custom savingLabel χρησιμοποιείται', (tester) async {
      await tester.pumpWidget(_wrap(
        SaveButton(
          isSaving: true,
          label: 'Αποθήκευση',
          savingLabel: 'Γίνεται αποθήκευση...',
          onPressed: null,
        ),
      ));
      expect(find.text('Γίνεται αποθήκευση...'), findsOneWidget);
    });

    testWidgets('custom icon χρησιμοποιείται στο normal state', (tester) async {
      await tester.pumpWidget(_wrap(
        SaveButton(
          isSaving: false,
          label: 'Αποθήκευση',
          icon: Icons.favorite,
          onPressed: null,
        ),
      ));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });
}