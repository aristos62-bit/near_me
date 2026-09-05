import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/chat/providers/chat_provider.dart';
import 'package:near_me/features/chat/widgets/chat_input_bar.dart';

// --- Mocks (mocktail) ---
class _MockUser extends Mock implements User {}

class _FakeChatActionsNotifier extends ChatActionsNotifier {
  bool sendCalled = false;
  bool editCalled = false;
  String? lastChatId;
  String? lastContent;
  String? lastMessageId;
  Map<String, dynamic>? lastReplyTo;

  @override
  ChatActionState build() => const ChatActionState();

  @override
  Future<bool> sendMessage(String chatId, String content, {Map<String, dynamic>? replyTo}) async {
    sendCalled = true;
    lastChatId = chatId;
    lastContent = content;
    lastReplyTo = replyTo;
    return true;
  }

  @override
  Future<bool> editMessage(String chatId, String messageId, String newContent) async {
    editCalled = true;
    lastChatId = chatId;
    lastMessageId = messageId;
    lastContent = newContent;
    return true;
  }
}

// --- Fixtures ---
_MockUser _verifiedUser({required String uid}) {
  final user = _MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.isAnonymous).thenReturn(false);
  when(() => user.emailVerified).thenReturn(true);
  when(() => user.phoneNumber).thenReturn(null);
  return user;
}

_MockUser _anonymousUser({required String uid}) {
  final user = _MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.isAnonymous).thenReturn(true);
  when(() => user.emailVerified).thenReturn(false);
  when(() => user.phoneNumber).thenReturn(null);
  return user;
}

Widget _localized(Widget child) {
  return MaterialApp(
    locale: const Locale('el'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('el'), Locale('en')],
    home: Scaffold(body: child),
  );
}

Future<_FakeChatActionsNotifier> _pumpInput(
  WidgetTester tester, {
  required _MockUser user,
  _FakeChatActionsNotifier? actions,
  TextEditingController? controller,
  String chatId = 'chat-1',
  bool emojiPickerVisible = false,
  VoidCallback? onEmojiDismiss,
}) async {
  final fake = actions ?? _FakeChatActionsNotifier();
  final ctrl = controller ?? TextEditingController();
  final container = ProviderContainer(overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(user)),
    chatActionsProvider.overrideWith(() => fake),
  ]);
  addTearDown(container.dispose);
  // «Ζεστή» εκκίνηση: το ChatInputBar build κάνει `.value ?? FirebaseAuth.instance`
  // (χωρίς Firebase app στα tests → [core/no-app]). Ο provider πρέπει να έχει
  // data ΠΡΙΝ το build: listener + pumps ώστε το Stream.value να ολοκληρωθεί.
  await tester.pumpWidget(_localized(const SizedBox()));
  final warmSub = container.listen(authStateProvider, (_, _) {});
  addTearDown(warmSub.close);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(container.read(authStateProvider).value, isNotNull,
      reason: 'authStateProvider warm-up απέτυχε — ο fallback FirebaseAuth θα έπεφτε');
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: _localized(ChatInputBar(
      chatId: chatId,
      textController: ctrl,
      emojiPickerVisible: emojiPickerVisible,
      onEmojiToggle: () {},
      onEmojiDismiss: onEmojiDismiss ?? () {},
    )),
  ));
  await tester.pump();
  return fake;
}

/// Ξεφορτώνει το δέντρο και ακυρώνει το 1s Timer του DebugConfig.log.
Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('ChatInputBar', () {
    testWidgets('verified user → πλήρες πεδίο (text + send + add)', (tester) async {
      await _pumpInput(tester, user: _verifiedUser(uid: 'u1'));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.text('Γράψε ένα μήνυμα...'), findsOneWidget);

      await _settleTimer(tester);
    });

    testWidgets('anonymous → prompt επαλήθευσης, χωρίς send/add', (tester) async {
      await _pumpInput(tester, user: _anonymousUser(uid: 'u1'));

      expect(find.textContaining('Πρέπει να επαληθεύσεις'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);

      await _settleTimer(tester);
    });

    testWidgets('edit banner: εμφάνιση + περιεχόμενο στο text field',
        (tester) async {
      await _pumpInput(tester, user: _verifiedUser(uid: 'u1'));

      final container =
          ProviderScope.containerOf(tester.element(find.byType(ChatInputBar)));
      container.read(editingMessageProvider.notifier).setEdit('chat-1', {
        'id': 'm1',
        'content': 'Hello world',
        'type': 'text',
      });
      await tester.pumpAndSettle();

      expect(find.text('Επεξεργασία μηνύματος'), findsOneWidget);
      // Το "Hello world" εμφανίζεται 2 φορές: στο banner preview + στο TextField.
      expect(find.text('Hello world'), findsNWidgets(2));
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'Hello world');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Επεξεργασία μηνύματος'), findsNothing);
      expect(textField.controller!.text, isEmpty);

      await _settleTimer(tester);
    });

    testWidgets('reply banner: εμφάνιση + κλείσιμο', (tester) async {
      await _pumpInput(tester, user: _verifiedUser(uid: 'u1'));

      final container =
          ProviderScope.containerOf(tester.element(find.byType(ChatInputBar)));
      container.read(replyToMessageProvider.notifier).setReply('chat-1', {
        'id': 'r1',
        'senderId': 'other',
        'content': 'Nice!',
        'type': 'text',
      });
      await tester.pumpAndSettle();

      expect(find.text('Nice!'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Nice!'), findsNothing);

      await _settleTimer(tester);
    });

    testWidgets('send κειμένου → sendMessage με σωστά args + clear',
        (tester) async {
      final fake = await _pumpInput(tester, user: _verifiedUser(uid: 'u1'));

      await tester.enterText(find.byType(TextField), 'Γεια σου');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(fake.sendCalled, isTrue);
      expect(fake.lastChatId, 'chat-1');
      expect(fake.lastContent, 'Γεια σου');
      expect(fake.lastReplyTo, isNull);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);

      await _settleTimer(tester);
    });

    testWidgets('send με quote → replyTo σωστό στο sendMessage', (tester) async {
      final fake = await _pumpInput(tester, user: _verifiedUser(uid: 'u1'));

      final container =
          ProviderScope.containerOf(tester.element(find.byType(ChatInputBar)));
      container.read(replyToMessageProvider.notifier).setReply('chat-1', {
        'id': 'r1',
        'senderId': 'other',
        'content': 'φωτο',
        'type': 'image',
      });
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'νέο μήνυμα');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(fake.sendCalled, isTrue);
      expect(fake.lastReplyTo, isNotNull);
      expect(fake.lastReplyTo!['messageId'], 'r1');
      expect(fake.lastReplyTo!['senderId'], 'other');
      expect(fake.lastReplyTo!['type'], 'image');
      expect(fake.lastReplyTo!['contentPreview'], '📷 Photo');
      expect(fake.lastReplyTo!['senderNickname'], 'other');

      await _settleTimer(tester);
    });

    testWidgets('edit send → editMessage (όχι sendMessage)', (tester) async {
      final fake = await _pumpInput(tester, user: _verifiedUser(uid: 'u1'));

      final container =
          ProviderScope.containerOf(tester.element(find.byType(ChatInputBar)));
      container.read(editingMessageProvider.notifier).setEdit('chat-1', {
        'id': 'm1',
        'content': 'παλιό',
        'type': 'text',
      });
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'νέο κείμενο');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(fake.editCalled, isTrue);
      expect(fake.sendCalled, isFalse);
      expect(fake.lastChatId, 'chat-1');
      expect(fake.lastMessageId, 'm1');
      expect(fake.lastContent, 'νέο κείμενο');

      await _settleTimer(tester);
    });

    testWidgets('emojiPickerVisible + focus → onEmojiDismiss', (tester) async {
      var dismissed = false;
      await _pumpInput(
        tester,
        user: _verifiedUser(uid: 'u1'),
        emojiPickerVisible: true,
        onEmojiDismiss: () => dismissed = true,
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(dismissed, isTrue);

      await _settleTimer(tester);
    });
  });
}