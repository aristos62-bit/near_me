import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:near_me/main.dart';

void main() {
  testWidgets('App renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NearMeApp(dbReady: true, firebaseReady: true)),
    );
    expect(find.text('NearMe'), findsOneWidget);
  });
}
