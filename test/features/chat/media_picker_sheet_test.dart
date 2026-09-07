import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/media_picker_sheet.dart';

Widget wrapLocalized(String locale) {
  return MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('el'), Locale('en')],
    home: const Scaffold(body: SizedBox()),
  );
}

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  Future<void> pumpHost(WidgetTester tester, String locale) async {
    await tester.pumpWidget(wrapLocalized(locale));
    await tester.pump();
  }

  group('showMediaPickerSheet', () {
    testWidgets('shows all 7 action tiles with current feature flags',
        (tester) async {
      await pumpHost(tester, 'el');
      showMediaPickerSheet(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      final expected = [
        MediaAction.emoji,
        MediaAction.gif,
        MediaAction.photo,
        MediaAction.camera,
        MediaAction.record,
        MediaAction.videoGallery,
        MediaAction.videoCamera,
      ];
      for (final action in expected) {
        expect(find.text(_labelFor(action, greek: true)), findsOneWidget);
      }
      await _settleTimer(tester);
    });

    testWidgets('shows English labels when locale is en', (tester) async {
      await pumpHost(tester, 'en');
      showMediaPickerSheet(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('GIF'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('tapping a tile returns the matching MediaAction and closes',
        (tester) async {
      await pumpHost(tester, 'el');
      final future = showMediaPickerSheet(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Φωτογραφία'));
      await tester.pumpAndSettle();
      final result = await future;
      expect(result, MediaAction.photo);
      await _settleTimer(tester);
    });

    testWidgets('each tile maps to its own action', (tester) async {
      final cases = <String, MediaAction>{
        'Emoji': MediaAction.emoji,
        'GIF': MediaAction.gif,
        'Photo': MediaAction.photo,
        'Camera': MediaAction.camera,
        'Record': MediaAction.record,
        'Video': MediaAction.videoGallery,
        'Record Video': MediaAction.videoCamera,
      };
      for (final entry in cases.entries) {
        await pumpHost(tester, 'en');
        final future =
            showMediaPickerSheet(tester.element(find.byType(Scaffold)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(await future, entry.value, reason: 'for ${entry.key}');
      }
      await _settleTimer(tester);
    });

    testWidgets('dismiss without selection returns null', (tester) async {
      await pumpHost(tester, 'el');
      final future = showMediaPickerSheet(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(await future, isNull);
      await _settleTimer(tester);
    });

    testWidgets('renders safe area and list tiles', (tester) async {
      await pumpHost(tester, 'el');
      showMediaPickerSheet(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(7));
      await _settleTimer(tester);
    });

    testWidgets('no overflow and scrollable on a short viewport',
        (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapLocalized('el'));
      await tester.pump();

      showMediaPickerSheet(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(find.byType(ListTile), findsNWidgets(7));
      await _settleTimer(tester);
    });
  });
}

String _labelFor(MediaAction action, {required bool greek}) {
  switch (action) {
    case MediaAction.emoji:
      return 'Emoji';
    case MediaAction.gif:
      return 'GIF';
    case MediaAction.photo:
      return greek ? 'Φωτογραφία' : 'Photo';
    case MediaAction.camera:
      return greek ? 'Κάμερα' : 'Camera';
    case MediaAction.record:
      return greek ? 'Ηχογράφηση' : 'Record';
    case MediaAction.videoGallery:
      return greek ? 'Βίντεο' : 'Video';
    case MediaAction.videoCamera:
      return greek ? 'Εγγραφή βίντεο' : 'Record Video';
  }
}