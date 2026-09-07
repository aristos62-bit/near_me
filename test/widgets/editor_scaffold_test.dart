import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:near_me/shared/widgets/editor_scaffold.dart';

void main() {
  Future<GoRouter> buildRouter(Widget Function(BuildContext) editorBuilder) async {
    return GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/editor'),
                child: const Text('GO_EDITOR'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/editor',
          builder: (context, state) => editorBuilder(context),
        ),
      ],
    );
  }

  Widget appWidget(GoRouter router) {
    return MaterialApp.router(
      routerConfig: router,
      locale: const Locale('el'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('el'), Locale('en')],
    );
  }

  Future<void> openEditor(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(appWidget(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GO_EDITOR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> openEditorSettled(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(appWidget(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GO_EDITOR'));
    await tester.pumpAndSettle();
  }

  group('EditorScaffold', () {
    testWidgets('βλέπουμε τον τίτλο και το body', (tester) async {
      final router = await buildRouter(
        (context) => EditorScaffold(
          title: 'Επεξεργασία',
          screenName: 'editor',
          isDirty: () => false,
          isSaving: () => false,
          isLoading: false,
          onSave: () async {},
          body: const Text('BODY_TEXT'),
        ),
      );
      await openEditorSettled(tester, router);

      expect(find.text('Επεξεργασία'), findsOneWidget);
      expect(find.text('BODY_TEXT'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('isLoading=true → LoadingView', (tester) async {
      final router = await buildRouter(
        (context) => EditorScaffold(
          title: 'Επεξεργασία',
          screenName: 'editor',
          isDirty: () => false,
          isSaving: () => false,
          isLoading: true,
          onSave: () async {},
          body: const Text('BODY_TEXT'),
        ),
      );
      await openEditor(tester, router);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('BODY_TEXT'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('isLoading=true → custom loadingBody', (tester) async {
      final router = await buildRouter(
        (context) => EditorScaffold(
          title: 'Επεξεργασία',
          screenName: 'editor',
          isDirty: () => false,
          isSaving: () => false,
          isLoading: true,
          onSave: () async {},
          body: const Text('BODY_TEXT'),
          loadingBody: const Text('LOADING_CUSTOM'),
        ),
      );
      await openEditor(tester, router);

      expect(find.text('LOADING_CUSTOM'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('μη dirty + close → pop (χωρίς dialog)', (tester) async {
      final router = await buildRouter(
        (context) => EditorScaffold(
          title: 'Επεξεργασία',
          screenName: 'editor',
          isDirty: () => false,
          isSaving: () => false,
          isLoading: false,
          onSave: () async {},
          body: const Text('BODY_TEXT'),
        ),
      );
      await openEditorSettled(tester, router);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Μετά το pop πάμε στο /home (κανένα αρχείο χωρίς route /home...)
      // Έλεγχος ότι το dialog ΔΕΝ εμφανίστηκε.
      expect(find.text('Αποθήκευση αλλαγών;'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('dirty + close → εμφανίζει confirm dialog', (tester) async {
      final router = await buildRouter(
        (context) => EditorScaffold(
          title: 'Επεξεργασία',
          screenName: 'editor',
          isDirty: () => true,
          isSaving: () => false,
          isLoading: false,
          onSave: () async {},
          body: const Text('BODY_TEXT'),
        ),
      );
      await openEditorSettled(tester, router);

      expect(find.text('Επεξεργασία'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byType(IconButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Αποθήκευση αλλαγών;'), findsOneWidget);
      expect(find.text('Αποθήκευση'), findsOneWidget);
      expect(find.text('Απόρριψη'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('dirty + discard → pop χωρίς onSave', (tester) async {
      var saveCalled = false;
      final router = await buildRouter(
        (context) => EditorScaffold(
          title: 'Επεξεργασία',
          screenName: 'editor',
          isDirty: () => true,
          isSaving: () => false,
          isLoading: false,
          onSave: () async => saveCalled = true,
          body: const Text('BODY_TEXT'),
        ),
      );
      await openEditorSettled(tester, router);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Απόρριψη'));
      await tester.pumpAndSettle();

      expect(saveCalled, isFalse);
    });

    testWidgets('dirty + save → καλεί onSave', (tester) async {
      var saveCalled = false;
      final router = await buildRouter(
        (context) => EditorScaffold(
          title: 'Επεξεργασία',
          screenName: 'editor',
          isDirty: () => true,
          isSaving: () => false,
          isLoading: false,
          onSave: () async => saveCalled = true,
          body: const Text('BODY_TEXT'),
        ),
      );
      await openEditorSettled(tester, router);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Αποθήκευση'));
      await tester.pumpAndSettle();

      expect(saveCalled, isTrue);
    });

    testWidgets('isSaving=true + close → δεν κάνει τίποτα', (tester) async {
      var saveCalled = false;
      final router = await buildRouter(
        (context) => EditorScaffold(
          title: 'Επεξεργασία',
          screenName: 'editor',
          isDirty: () => true,
          isSaving: () => true,
          isLoading: false,
          onSave: () async => saveCalled = true,
          body: const Text('BODY_TEXT'),
        ),
      );
      await openEditorSettled(tester, router);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // No dialog since saving
      expect(find.text('Αποθήκευση αλλαγών;'), findsNothing);
      expect(saveCalled, isFalse);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
