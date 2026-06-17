import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:near_me/main.dart';

void main() {
  testWidgets('NearMeApp renders MaterialApp without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NearMeApp(dbReady: true, firebaseReady: true)),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
