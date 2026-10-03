import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/chat/providers/chat_provider.dart';
import 'package:near_me/features/chat/screens/chat_list_screen.dart';
import 'package:near_me/features/settings/providers/app_settings_provider.dart';
import 'package:near_me/repositories/chat_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Widget tests για `ChatListScreen` (389 γρ., πλήρης ανάγνωση).
/// Προαπαιτούμενο: try/catch guard γύρω από `FirebaseAuth.instance`
/// (build:28, tile:221) — χωρίς app πετάει σύγχρονα σε VM.
/// Tiles με κενό avatarUrl (initial-branch, όχι CachedNetworkImage).
class _MockChatRepository extends Mock implements ChatRepository {}

class _MockUser extends Mock implements User {}

_MockUser _user({bool anon = false, bool verified = true}) {
  final u = _MockUser();
  when(() => u.uid).thenReturn('me');
  when(() => u.isAnonymous).thenReturn(anon);
  when(() => u.emailVerified).thenReturn(verified);
  when(() => u.phoneNumber).thenReturn(null);
  return u;
}

ChatCacheTableData _chat({
  required String chatId,
  String? nickname,
  bool group = false,
  String? groupName,
  String? groupCreatedBy,
  int unread = 0,
  String type = 'text',
  String? lastMessage,
  String? sender,
}) =>
    ChatCacheTableData(
      id: 0,
      chatId: chatId,
      ownerUid: 'me',
      otherUid: group ? null : 'other-$chatId',
      otherNickname: nickname,
      lastMessageAt: DateTime(2026, 5, 1, 12, 0),
      lastMessage: lastMessage,
      lastMessageSender: sender,
      lastMessageType: type,
      unreadCount: unread,
      hasUnread: unread > 0,
      isGroupChat: group,
      groupName: groupName,
      groupCreatedBy: groupCreatedBy,
      participantCount: group ? 3 : 2,
      messageExpiry: 'off',
    );

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Στατικό appSettings (χωρίς real DB) — τα tiles δεν έχουν avatar URLs,
// οπότε blur τιμές αδιάφορες.
class _FakeAppSettingsNotifier extends AppSettingsNotifier {
  @override
  AsyncValue<AppSettingsTableData> build() => AsyncValue.data(
        AppSettingsTableData(
          id: 0,
          locale: 'el',
          themeMode: 'system',
          notificationsEnabled: true,
          biometricLockEnabled: false,
          screenshotPreventionEnabled: false,
          crashReportsEnabled: false,
          blurExplicitEnabled: false,
          blurSigma: 12.0,
          autoLockMinutes: 5,
          searchRadiusKm: 10.0,
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required User? user,
  List<ChatCacheTableData> chats = const [],
  _MockChatRepository? repo,
  GoRouter? router,
}) async {
  final r = repo ?? _MockChatRepository();
  final c = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      chatRepositoryProvider.overrideWithValue(r),
      chatsProvider.overrideWith((ref) => Stream.value(chats)),
      appSettingsProvider.overrideWith(() => _FakeAppSettingsNotifier()),
    ],
  );
  addTearDown(c.dispose);
  if (router != null) {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('el'),
          supportedLocales: const [Locale('el'), Locale('en')],
          localizationsDelegates: _delegates,
        ),
      ),
    );
  } else {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('el'),
          supportedLocales: [Locale('el'), Locale('en')],
          localizationsDelegates: _delegates,
          home: ChatListScreen(),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
  return c;
}

GoRouter _router() => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('home'))),
        GoRoute(
            path: '/chats', builder: (_, _) => const ChatListScreen()),
        GoRoute(
            path: '/join',
            builder: (_, state) => Scaffold(
                body: Text(
                    'join:${state.uri.queryParameters['token'] ?? ''}'))),
      ],
    );

Future<void> _settleTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('ChatListScreen καταστάσεις', () {
    testWidgets('anonymous → verify banner', (tester) async {
      await _pump(tester, user: _user(anon: true));
      expect(find.text('Τα μηνύματα είναι κλειδωμένα'), findsOneWidget);
      expect(find.text('Επαλήθευση Λογαριασμού'), findsOneWidget);
      // FAB κρυμμένο χωρίς canComm.
      expect(find.byType(FloatingActionButton), findsNothing);
      await _settleTimer(tester);
    });

    testWidgets('κενή λίστα → empty + invite action', (tester) async {
      await _pump(tester, user: _user());
      expect(find.text('Δεν υπάρχουν συνομιλίες'), findsOneWidget);
      expect(find.text('Έχεις κωδικό πρόσκλησης;'), findsWidgets);
      await _settleTimer(tester);
    });

    testWidgets('λίστα → τίτλοι + unread badge', (tester) async {
      await _pump(tester, user: _user(), chats: [
        _chat(chatId: 'c1', nickname: 'Aris', unread: 3),
        _chat(
            chatId: 'g1',
            group: true,
            groupName: 'Παρέα',
            groupCreatedBy: 'creator-x',
            type: 'image',
            lastMessage: 'x'),
      ]);
      expect(find.text('Aris'), findsOneWidget);
      expect(find.text('Παρέα'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('📷 Φωτογραφία'), findsOneWidget);
      expect(find.text('3 μέλη'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('preview κείμενο Εσύ:/τίτλος + 99+', (tester) async {
      await _pump(tester, user: _user(), chats: [
        _chat(
            chatId: 'c1',
            nickname: 'Aris',
            lastMessage: 'γεια',
            sender: 'me'),
        _chat(chatId: 'c2', nickname: 'Bob', unread: 150),
      ]);
      expect(find.text('Εσύ: γεια'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      await _settleTimer(tester);
    });
  });

  group('ChatListScreen invite dialog', () {
    testWidgets('άκυρος κωδικός → error snackbar, μένει', (tester) async {
      await _pump(tester, user: _user());
      await tester.tap(find.byIcon(Icons.vpn_key));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'όχι-token!!!');
      await tester.tap(find.widgetWithText(FilledButton, 'Συνέχεια'));
      await tester.pumpAndSettle();
      expect(find.text('Μη έγκυρος κωδικός πρόσκλησης.'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('ακύρωση → κλείνει χωρίς πλοήγηση', (tester) async {
      final router = _router();
      await _pump(tester, user: _user(), router: router);
      router.go('/chats');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.vpn_key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ακύρωση'));
      await tester.pumpAndSettle();
      expect(find.text('Συνομιλίες'), findsOneWidget);
      await _settleTimer(tester);
    });

    testWidgets('έγκυρο token → push /join', (tester) async {
      const token = '013ab7930b2b43d9bb8365f404559d79';
      final router = _router();
      await _pump(tester, user: _user(), router: router);
      router.go('/chats');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.vpn_key));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), token);
      await tester.tap(find.widgetWithText(FilledButton, 'Συνέχεια'));
      await tester.pumpAndSettle();
      expect(find.text('join:$token'), findsOneWidget);
      await _settleTimer(tester);
    });
  });

  group('ChatListScreen delete', () {
    testWidgets('confirm → repo.deleteChat', (tester) async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockChatRepository();
      when(() => repo.deleteChat(any())).thenAnswer((_) async {});
      await _pump(tester,
          user: _user(),
          chats: [_chat(chatId: 'c1', nickname: 'Aris')],
          repo: repo);
      await tester.tap(find.byIcon(Icons.delete_forever));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Διαγραφή')));
      await tester.pumpAndSettle();
      verify(() => repo.deleteChat('c1')).called(1);
      await _settleTimer(tester);
    });
  });
}
