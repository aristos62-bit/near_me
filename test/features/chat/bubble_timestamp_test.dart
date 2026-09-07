import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/message_bubble/bubble_timestamp.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('BubbleTimestamp', () {
    testWidgets('displays timeStr text', (tester) async {
      await tester.pumpWidget(wrap(
        const BubbleTimestamp(timeStr: '14:30', isMe: false),
      ));
      expect(find.text('14:30'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('displays lock icon', (tester) async {
      await tester.pumpWidget(wrap(
        const BubbleTimestamp(timeStr: '10:00', isMe: true),
      ));
      expect(find.byIcon(Icons.lock), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('pads left when isMe=false', (tester) async {
      await tester.pumpWidget(wrap(
        const BubbleTimestamp(timeStr: '09:15', isMe: false),
      ));
      final padding = tester.widget<Padding>(find.byType(Padding));
      final edge = padding.padding as EdgeInsets;
      expect(edge.left, 14);
      expect(edge.right, 0);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('pads right when isMe=true', (tester) async {
      await tester.pumpWidget(wrap(
        const BubbleTimestamp(timeStr: '09:15', isMe: true),
      ));
      final padding = tester.widget<Padding>(find.byType(Padding));
      final edge = padding.padding as EdgeInsets;
      expect(edge.left, 0);
      expect(edge.right, 14);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
