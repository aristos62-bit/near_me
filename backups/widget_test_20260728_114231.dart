import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:near_me/main.dart';
import 'package:near_me/core/utils/app_messenger.dart';

void main() {
  testWidgets('NearMeApp renders MaterialApp without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NearMeApp(dbReady: true, firebaseReady: true)),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('AppMessenger with MaterialApp.builder context — P2 fix', (WidgetTester tester) async {
    BuildContext? builderCtx;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          builderCtx = context;
          return child!;
        },
        home: Scaffold(
          body: Center(child: Text('Home')),
        ),
      ),
    );
    await tester.pump();

    // 1. Verify builder context HAS ScaffoldMessenger ancestor (core of P2 fix)
    expect(ScaffoldMessenger.maybeOf(builderCtx!), isNotNull,
      reason: 'MaterialApp.builder context must have ScaffoldMessenger ancestor');

    // 2. Show snackbar via AppMessenger using builder context (like _onFcmForeground does)
    AppMessenger.showInfo(builderCtx!, 'Test FCM notification');
    await tester.pump();

    // 3. Verify snackbar is visible (no "skipping snackbar" warn)
    expect(find.byType(SnackBar), findsOneWidget,
      reason: 'AppMessenger.showInfo must render SnackBar with builder context');
    expect(find.text('Test FCM notification'), findsOneWidget);

    // 4. Verify no "no ScaffoldMessenger available" warning was emitted
    // (We just verify snackbar appeared, proving findAncestor succeeded)
  });
}
