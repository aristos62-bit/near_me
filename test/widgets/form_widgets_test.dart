import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/widgets/chip_selector.dart';
import 'package:near_me/shared/widgets/form_section.dart';
import 'package:near_me/shared/widgets/form_toggle.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

void main() {
  group('FormSection', () {
    testWidgets('με icon: εμφανίζει title + icon + children', (tester) async {
      await tester.pumpWidget(_wrap(
        FormSection(
          title: 'Βασικά',
          icon: Icons.person,
          children: const [Text('Πεδίο 1'), Text('Πεδίο 2')],
        ),
      ));
      expect(find.text('Βασικά'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.text('Πεδίο 1'), findsOneWidget);
      expect(find.text('Πεδίο 2'), findsOneWidget);
    });

    testWidgets('χωρίς icon: εμφανίζει title + children, όχι icon',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FormSection(
          title: 'Βασικά',
          children: const [Text('Πεδίο 1')],
        ),
      ));
      expect(find.text('Βασικά'), findsOneWidget);
      expect(find.text('Πεδίο 1'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);
    });
  });

  group('FormToggle', () {
    testWidgets('εμφανίζει title, subtitle και icon', (tester) async {
      await tester.pumpWidget(_wrap(
        FormToggle(
          title: 'Ορατότητα',
          subtitle: 'Να φαίνεται το email',
          value: true,
          onChanged: (_) {},
          icon: Icons.visibility,
        ),
      ));
      expect(find.text('Ορατότητα'), findsOneWidget);
      expect(find.text('Να φαίνεται το email'), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('value=true → switch ON', (tester) async {
      await tester.pumpWidget(_wrap(
        FormToggle(
          title: 'T',
          subtitle: 'S',
          value: true,
          onChanged: (_) {},
        ),
      ));
      final sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(sw.value, isTrue);
    });

    testWidgets('tap καλεί την onChanged με την αντίθετη τιμή', (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(
        FormToggle(
          title: 'T',
          subtitle: 'S',
          value: false,
          onChanged: (v) => result = v,
        ),
      ));
      await tester.tap(find.byType(SwitchListTile));
      expect(result, isTrue);
    });

    testWidgets('χωρίς icon → δεν εμφανίζεται secondary icon',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FormToggle(
          title: 'T',
          subtitle: 'S',
          value: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.byIcon(Icons.visibility), findsNothing);
    });
  });

  group('ChipSelector', () {
    testWidgets('εμφανίζει όλα τα options (default labels)', (tester) async {
      await tester.pumpWidget(_wrap(
        ChipSelector(
          options: const ['a', 'b', 'c'],
          selectedValue: null,
          onSelected: (_) {},
        ),
      ));
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(3));
    });

    testWidgets('χρησιμοποιεί custom labels', (tester) async {
      await tester.pumpWidget(_wrap(
        ChipSelector(
          options: const ['a', 'b'],
          selectedValue: null,
          onSelected: (_) {},
          labels: const {'a': 'Άλφα', 'b': 'Βήτα'},
        ),
      ));
      expect(find.text('Άλφα'), findsOneWidget);
      expect(find.text('Βήτα'), findsOneWidget);
    });

    testWidgets('επιλεγμένο option → chip selected', (tester) async {
      await tester.pumpWidget(_wrap(
        ChipSelector(
          options: const ['a', 'b'],
          selectedValue: 'b',
          onSelected: (_) {},
        ),
      ));
      final chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .toList();
      expect(chips[0].selected, isFalse);
      expect(chips[1].selected, isTrue);
    });

    testWidgets('tap επιλέγει option → onSelected με τη τιμή', (tester) async {
      String? result;
      await tester.pumpWidget(_wrap(
        ChipSelector(
          options: const ['a', 'b'],
          selectedValue: null,
          onSelected: (v) => result = v,
        ),
      ));
      await tester.tap(find.text('a'));
      // DebugConfig.log δημιουργεί static 1s flush timer → τον προχωράμε
      await tester.pump(const Duration(seconds: 2));
      expect(result, 'a');
    });

    testWidgets('tap σε ήδη επιλεγμένο → deselect (null)', (tester) async {
      String? result = 'b';
      await tester.pumpWidget(_wrap(
        ChipSelector(
          options: const ['a', 'b'],
          selectedValue: 'b',
          onSelected: (v) => result = v,
        ),
      ));
      await tester.tap(find.byType(ChoiceChip).at(1), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));
      expect(result, isNull);
    });
  });
}