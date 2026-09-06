import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/l10n/l10n.dart';
import 'package:near_me/features/chat/widgets/message_bubble/text_message_bubble.dart';

void main() {
  const validToken = '0123456789abcdef0123456789abcdef';
  const plainText = 'just a normal hello message';

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> tapThenVerifyClipboard(
    WidgetTester tester,
    String content, {
    required bool expectCopyVisible,
    String? expectedToken,
  }) async {
    final log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        log.add(call);
        return null;
      },
    );

    await tester.pumpWidget(
      wrap(
        TextMessageBubble(
          content: content,
          bubbleMaxWidth: 300,
          timeStr: '12:00',
          isMe: false,
          currentUid: 'me',
          messageId: 'm1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final finder = find.byIcon(Icons.copy);
    if (!expectCopyVisible) {
      expect(finder, findsNothing);
      return;
    }
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();

    final setData = log.where((c) => c.method == 'Clipboard.setData');
    expect(setData, hasLength(1));
    final data = setData.single.arguments as Map<dynamic, dynamic>;
    expect(data['text'], expectedToken);

    // Flush DebugConfig 1s log-buffer timer + snackbar auto-dismiss timers.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('no token in content → no copy icon', (WidgetTester tester) async {
    await tapThenVerifyClipboard(
      tester,
      plainText,
      expectCopyVisible: false,
    );
  });

  testWidgets('invite message with token → copy icon visible + copies token', (WidgetTester tester) async {
    final msg = L10n.inviteInvitationMessage(
      groupName: 'Παρέα',
      token: validToken,
      isGreek: true,
    );
    await tapThenVerifyClipboard(
      tester,
      msg,
      expectCopyVisible: true,
      expectedToken: validToken,
    );
  });

  testWidgets('token-only content → copy icon + copies exact token', (WidgetTester tester) async {
    await tapThenVerifyClipboard(
      tester,
      validToken,
      expectCopyVisible: true,
      expectedToken: validToken,
    );
  });

  testWidgets('sent bubble (isMe) → copy icon rendered on white text color', (WidgetTester tester) async {
    final msg = L10n.inviteInvitationMessage(
      groupName: 'Friends',
      token: validToken,
      isGreek: false,
    );
    await tester.pumpWidget(
      wrap(
        TextMessageBubble(
          content: msg,
          bubbleMaxWidth: 300,
          timeStr: '12:00',
          isMe: true,
          currentUid: 'me',
          messageId: 'm1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });
}
