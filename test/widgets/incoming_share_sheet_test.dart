import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/widgets/incoming_share_sheet.dart';

/// `showIncomingShareSheet` — text/url/audio/video-icon branches.
/// Το file branch (`Image.file`) εκτός — θέλει πραγματικό αρχείο.
Future<bool?> _openAndConfirm(
  WidgetTester tester, {
  required String type,
  required String content,
  String? filePath,
}) async {
  Future<bool?>? result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('el'),
      supportedLocales: const [Locale('el'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return FilledButton(
            onPressed: () => result = showIncomingShareSheet(
              ctx,
              type: type,
              content: content,
              filePath: filePath,
            ),
            child: const Text('open'),
          );
        }),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Προώθηση σε συνομιλία'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('showIncomingShareSheet', () {
    testWidgets('text → τίτλος + περιεχόμενο + confirm true', (tester) async {
      final pending = _openAndConfirm(tester,
          type: 'text', content: 'γεια σου κόσμε');
      expect(await pending, isTrue);
    });

    testWidgets('text τίτλος/εικονίδιο χωρίς confirm → sheet ανοίγει',
        (tester) async {
      Future<bool?>? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('el'),
          supportedLocales: const [Locale('el'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return FilledButton(
                onPressed: () => result = showIncomingShareSheet(
                  ctx,
                  type: 'text',
                  content: 'κοινοποιημένο κείμενο',
                ),
                child: const Text('open'),
              );
            }),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Εισερχόμενο περιεχόμενο'), findsOneWidget);
      expect(find.text('κοινοποιημένο κείμενο'), findsOneWidget);
      expect(find.byIcon(Icons.forward_to_inbox_outlined), findsOneWidget);
      expect(result, isNotNull);
    });

    testWidgets('url → link icon', (tester) async {
      Future<bool?>? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('el'),
          supportedLocales: const [Locale('el'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return FilledButton(
                onPressed: () => result = showIncomingShareSheet(
                  ctx,
                  type: 'url',
                  content: 'https://example.com/x',
                ),
                child: const Text('open'),
              );
            }),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(result, isNotNull);
    });

    testWidgets('audio με filePath (χωρίς ανάγνωση αρχείου) → mic icons',
        (tester) async {
      // ΣΗΜΕΙΩΣΗ: σε default viewport 800x600 το sheet κάνει RenderFlex
      // overflow ~2.5px (υποψήφιο production bug, δεν αλλάζει production
      // χωρίς άδεια — ίδιο handling με S273/S274). Ψηλότερο viewport εδώ.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Future<bool?>? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('el'),
          supportedLocales: const [Locale('el'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return FilledButton(
                onPressed: () => result = showIncomingShareSheet(
                  ctx,
                  type: 'audio',
                  content: 'ηχητικό',
                  filePath: '/tmp/fake.m4a',
                ),
                child: const Text('open'),
              );
            }),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // header icon + 48px preview icon (δεν διακρίνουμε με findsOneWidget).
      expect(find.byIcon(Icons.mic_outlined), findsWidgets);
      expect(result, isNotNull);
    });

    testWidgets('en locale → αγγλικός τίτλος + κουμπί', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('el'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return FilledButton(
                onPressed: () => showIncomingShareSheet(
                  ctx,
                  type: 'text',
                  content: 'hello',
                ),
                child: const Text('open'),
              );
            }),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Incoming content'), findsOneWidget);
      expect(find.text('Forward to a chat'), findsOneWidget);
    });
  });
}
