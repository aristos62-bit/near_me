import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/utils/emoji_picker_config.dart';

/// `EmojiPickerConfig` — theme/locale mapping + responsive ύψος.
/// Χωρίς δίκτυο/Firebase (καθαρό Config object).
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  Brightness brightness = Brightness.light,
  String locale = 'el',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('el'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(brightness: brightness),
      home: const SizedBox(),
    ),
  );
}

/// Flush DebugConfig 1s Timer (το create()/breakpoint logάρουν).
Future<void> _flushTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('EmojiPickerConfig.create', () {
    testWidgets('el locale → ελληνικά hint + locale', (tester) async {
      await _pump(tester, size: const Size(400, 800));
      final ctx = tester.element(find.byType(SizedBox).first);
      final config = EmojiPickerConfig.create(ctx);
      expect(config.checkPlatformCompatibility, isTrue);
      expect(config.searchViewConfig.hintText, 'Αναζήτηση emoji...');
      await _flushTimers(tester);
    });

    testWidgets('en locale → αγγλικό hint', (tester) async {
      await _pump(tester, size: const Size(400, 800), locale: 'en');
      final ctx = tester.element(find.byType(SizedBox).first);
      final config = EmojiPickerConfig.create(ctx);
      expect(config.searchViewConfig.hintText, 'Search emoji...');
      await _flushTimers(tester);
    });

    testWidgets('dark/light → χτίζεται χωρίς throw', (tester) async {
      await _pump(tester,
          size: const Size(400, 800), brightness: Brightness.dark);
      final ctx = tester.element(find.byType(SizedBox).first);
      final config = EmojiPickerConfig.create(ctx);
      expect(config.emojiViewConfig.emojiSizeMax, 28.0);
      await _flushTimers(tester);
    });
  });

  group('EmojiPickerConfig.responsiveHeight', () {
    testWidgets('mobile portrait 400x800 → 35%', (tester) async {
      await _pump(tester, size: const Size(400, 800));
      final ctx = tester.element(find.byType(SizedBox).first);
      expect(EmojiPickerConfig.responsiveHeight(ctx), 800 * 0.35);
      await _flushTimers(tester);
    });

    testWidgets('tablet portrait 700x1000 → 30%', (tester) async {
      await _pump(tester, size: const Size(700, 1000));
      final ctx = tester.element(find.byType(SizedBox).first);
      expect(EmojiPickerConfig.responsiveHeight(ctx), 1000 * 0.30);
      await _flushTimers(tester);
    });

    testWidgets('landscape 1200x600 → 55%', (tester) async {
      await _pump(tester, size: const Size(1200, 600));
      final ctx = tester.element(find.byType(SizedBox).first);
      expect(EmojiPickerConfig.responsiveHeight(ctx), 600 * 0.55);
      await _flushTimers(tester);
    });
  });
}
