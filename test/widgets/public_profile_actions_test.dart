import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/auth/providers/auth_provider.dart';
import 'package:near_me/features/block/providers/block_provider.dart';
import 'package:near_me/features/chat/providers/chat_provider.dart';
import 'package:near_me/features/discovery/widgets/public_profile_actions.dart';
import 'package:near_me/features/report/providers/report_provider.dart';
import 'package:near_me/repositories/block_repository.dart';
import 'package:near_me/repositories/report_repository.dart';
import 'package:near_me/shared/models/public_profile.dart';

// --- Mocks (mocktail) ---
class _MockUser extends Mock implements User {}

class _MockReportRepository extends Mock implements ReportRepository {}

class _MockBlockRepository extends Mock implements BlockRepository {}

class _FakeChatActionsNotifier extends ChatActionsNotifier {
  bool addParticipantCalled = false;
  bool addParticipantResult = true;
  String? lastChatId;
  String? lastUid;

  @override
  ChatActionState build() => const ChatActionState();

  @override
  Future<bool> addParticipant(String chatId, String newUid) async {
    addParticipantCalled = true;
    lastChatId = chatId;
    lastUid = newUid;
    if (!addParticipantResult) {
      state = const ChatActionState(
          status: ChatActionStatus.error, errorMessage: 'test-error');
    }
    return addParticipantResult;
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

PublicProfile _profile({
  required String uid,
  bool allowDirectChat = true,
  bool allowVideoCall = false,
}) {
  return PublicProfile(
    uid: uid,
    allowDirectChat: allowDirectChat,
    allowVideoCall: allowVideoCall,
  );
}

ChatCacheTableData _groupChat({
  required String chatId,
  required String groupName,
  int participantCount = 3,
}) {
  return ChatCacheTableData(
    id: 1,
    chatId: chatId,
    unreadCount: 0,
    hasUnread: false,
    isGroupChat: true,
    participantCount: participantCount,
    groupName: groupName,
    messageExpiry: 'never',
  );
}

/// Τυλίγει το ήδη-φτιαγμένο ProviderScope σε MaterialApp+Scaffold
/// (ίδιο πρότυπο με το `_localized` του public_profile_widgets_refactor_test.dart).
Widget _harness(Widget providerScopedChild) {
  return MaterialApp(
    locale: const Locale('el'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('el'), Locale('en')],
    home: Scaffold(body: SingleChildScrollView(child: providerScopedChild)),
  );
}

void main() {
  group('Ορατότητα κουμπιών βάσει auth state', () {
    testWidgets('Κρύβει όλα τα κουμπιά όταν ο χρήστης δεν είναι συνδεδεμένος',
            (tester) async {
          final profile = _profile(uid: 'other-uid');
          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(null)),
            ],
            child: PublicProfileActions(uid: 'other-uid', profile: profile),
          )));
          await tester.pump();

          expect(find.text('Αποστολή Αιτήματος'), findsNothing);
          expect(find.text('Πρόσκληση σε Ομάδα'), findsNothing);
          expect(find.text('Αναφορά'), findsNothing);
          expect(find.text('Μπλοκάρισμα'), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });

    testWidgets('Κρύβει όλα τα κουμπιά όταν το προφίλ είναι το δικό μου',
            (tester) async {
          final me = _verifiedUser(uid: 'my-uid');
          final profile = _profile(uid: 'my-uid');
          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              blockedUidsProvider('my-uid').overrideWith((ref) => Stream.value({})),
            ],
            child: PublicProfileActions(uid: 'my-uid', profile: profile),
          )));
          await tester.pump();

          expect(find.text('Αποστολή Αιτήματος'), findsNothing);
          expect(find.text('Πρόσκληση σε Ομάδα'), findsNothing);
          expect(find.text('Αναφορά'), findsNothing);
          expect(find.text('Μπλοκάρισμα'), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });

    testWidgets(
        'Εμφανίζει Invite/Report/Block για verified χρήστη σε ξένο προφίλ',
            (tester) async {
          final me = _verifiedUser(uid: 'my-uid');
          final profile = _profile(uid: 'other-uid');
          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              blockedUidsProvider('my-uid').overrideWith((ref) => Stream.value({})),
            ],
            child: PublicProfileActions(uid: 'other-uid', profile: profile),
          )));
          await tester.pump();

          expect(find.text('Αποστολή Αιτήματος'), findsOneWidget);
          expect(find.text('Πρόσκληση σε Ομάδα'), findsOneWidget);
          expect(find.text('Αναφορά'), findsOneWidget);
          expect(find.text('Μπλοκάρισμα'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });

    testWidgets(
        'Κρύβει το κουμπί αιτήματος όταν δεν επιτρέπεται καμία επικοινωνία',
            (tester) async {
          final me = _verifiedUser(uid: 'my-uid');
          final profile = _profile(
            uid: 'other-uid',
            allowDirectChat: false,
            allowVideoCall: false,
          );
          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              blockedUidsProvider('my-uid').overrideWith((ref) => Stream.value({})),
            ],
            child: PublicProfileActions(uid: 'other-uid', profile: profile),
          )));
          await tester.pump();

          expect(find.text('Αποστολή Αιτήματος'), findsNothing);
          // Τα άλλα 3 κουμπιά δεν εξαρτώνται από allowDirectChat/allowVideoCall
          expect(find.text('Πρόσκληση σε Ομάδα'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });
  });

  group('Block / Unblock', () {
    testWidgets('Πατώντας Μπλοκάρισμα → confirm dialog → block() καλείται',
            (tester) async {
          final me = _verifiedUser(uid: 'my-uid');
          final profile = _profile(uid: 'other-uid');
          final mockBlockRepo = _MockBlockRepository();
          when(() => mockBlockRepo.blockUser('my-uid', 'other-uid', reason: any(named: 'reason')))
              .thenAnswer((_) async {});

          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              blockedUidsProvider('my-uid').overrideWith((ref) => Stream.value({})),
              blockRepositoryProvider.overrideWithValue(mockBlockRepo),
            ],
            child: PublicProfileActions(uid: 'other-uid', profile: profile),
          )));
          await tester.pump();

          await tester.tap(find.text('Μπλοκάρισμα'));
          await tester.pumpAndSettle();

          // Confirm dialog εμφανίζεται
          expect(find.text('Μπλοκάρισμα Χρήστη'), findsOneWidget);
          await tester.tap(find.widgetWithText(FilledButton, 'Μπλοκάρισμα'));
          await tester.pumpAndSettle();

          verify(() => mockBlockRepo.blockUser('my-uid', 'other-uid', reason: any(named: 'reason')))
              .called(1);
          expect(find.text('Μπλοκαρίστηκε'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });

    testWidgets('Ακύρωση στο confirm dialog → block() ΔΕΝ καλείται',
            (tester) async {
          final me = _verifiedUser(uid: 'my-uid');
          final profile = _profile(uid: 'other-uid');
          final mockBlockRepo = _MockBlockRepository();

          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              blockedUidsProvider('my-uid').overrideWith((ref) => Stream.value({})),
              blockRepositoryProvider.overrideWithValue(mockBlockRepo),
            ],
            child: PublicProfileActions(uid: 'other-uid', profile: profile),
          )));
          await tester.pump();

          await tester.tap(find.text('Μπλοκάρισμα'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ακύρωση'));
          await tester.pumpAndSettle();

          verifyNever(() => mockBlockRepo.blockUser(any(), any(), reason: any(named: 'reason')));
          expect(find.text('Μπλοκάρισμα'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });

    testWidgets('Ήδη μπλοκαρισμένος → δείχνει Ξεμπλοκάρισμα, tap → unblock() χωρίς dialog',
            (tester) async {
          final me = _verifiedUser(uid: 'my-uid');
          final profile = _profile(uid: 'other-uid');
          final mockBlockRepo = _MockBlockRepository();
          when(() => mockBlockRepo.unblockUser('my-uid', 'other-uid'))
              .thenAnswer((_) async {});

          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              blockedUidsProvider('my-uid')
                  .overrideWith((ref) => Stream.value({'other-uid'})),
              blockRepositoryProvider.overrideWithValue(mockBlockRepo),
            ],
            child: PublicProfileActions(uid: 'other-uid', profile: profile),
          )));
          await tester.pumpAndSettle();

          expect(find.text('Ξεμπλοκάρισμα'), findsOneWidget);
          await tester.tap(find.text('Ξεμπλοκάρισμα'));
          await tester.pumpAndSettle();

          verify(() => mockBlockRepo.unblockUser('my-uid', 'other-uid')).called(1);
          expect(find.text('Ξεμπλοκαρίστηκε'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });
  });

  group('Πρόσκληση σε Ομάδα', () {
    testWidgets('Χωρίς ομάδες → μήνυμα info, δεν ανοίγει bottom sheet',
            (tester) async {
          final me = _verifiedUser(uid: 'my-uid');
          final profile = _profile(uid: 'other-uid');

          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              blockedUidsProvider('my-uid').overrideWith((ref) => Stream.value({})),
              chatsProvider.overrideWith((ref) => Stream.value(const [])),
            ],
            child: PublicProfileActions(uid: 'other-uid', profile: profile),
          )));
          await tester.pump();

          await tester.tap(find.text('Πρόσκληση σε Ομάδα'));
          await tester.pumpAndSettle();

          expect(find.text('Δεν υπάρχουν διαθέσιμες ομάδες για πρόσκληση'),
              findsOneWidget);
          expect(find.text('Επιλογή Ομάδας'), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });

    testWidgets('Με ομάδες → επιλογή ομάδας καλεί addParticipant και δείχνει επιτυχία',
            (tester) async {
          final me = _verifiedUser(uid: 'my-uid');
          final profile = _profile(uid: 'other-uid');
          final fakeNotifier = _FakeChatActionsNotifier();

          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              blockedUidsProvider('my-uid').overrideWith((ref) => Stream.value({})),
              chatsProvider.overrideWith((ref) => Stream.value([
                _groupChat(chatId: 'chat-1', groupName: 'Παρέα Δρομέων'),
              ])),
              chatActionsProvider.overrideWith(() => fakeNotifier),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                // «Ζεστός» Listener: χωρίς watch ο chatsProvider (StreamProvider) δεν
                // έχει ξεκινήσει και το ref.read(...).asData στο sheet θα ήταν null.
                ref.watch(chatsProvider);
                return PublicProfileActions(uid: 'other-uid', profile: profile);
              },
            ),
          )));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Πρόσκληση σε Ομάδα'));
          await tester.pumpAndSettle();

          expect(find.text('Επιλογή Ομάδας'), findsOneWidget);
          expect(find.text('Παρέα Δρομέων'), findsOneWidget);

          await tester.tap(find.text('Παρέα Δρομέων'));
          await tester.pumpAndSettle();

          expect(fakeNotifier.addParticipantCalled, isTrue);
          expect(fakeNotifier.lastChatId, 'chat-1');
          expect(fakeNotifier.lastUid, 'other-uid');
          expect(find.text('Προσκλήθηκες στην ομάδα'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });
  });

  group('Αναφορά Χρήστη', () {
    testWidgets('Επιλογή λόγου → confirm → submitReport καλείται με σωστά στοιχεία',
            (tester) async {
          final me = _verifiedUser(uid: 'my-uid');
          final profile = _profile(uid: 'other-uid');
          final mockReportRepo = _MockReportRepository();
          when(() => mockReportRepo.submitReport(
            reporterUid: any(named: 'reporterUid'),
            reportedUid: any(named: 'reportedUid'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});

          await tester.pumpWidget(_harness(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(me)),
              blockedUidsProvider('my-uid').overrideWith((ref) => Stream.value({})),
              reportRepositoryProvider.overrideWithValue(mockReportRepo),
            ],
            child: PublicProfileActions(uid: 'other-uid', profile: profile),
          )));
          await tester.pump();

          await tester.tap(find.text('Αναφορά'));
          await tester.pumpAndSettle();

          expect(find.text('Αναφορά Χρήστη'), findsOneWidget);
          // reportReasons() = ['spam', 'harassment', ...] → πρώτο radio = 'spam'
          await tester.tap(find.text('Ανεπιθύμητη επικοινωνία (Spam)'));
          await tester.pumpAndSettle();

          // Confirm dialog
          expect(find.text('Επιβεβαίωση Αναφοράς'), findsOneWidget);
          await tester.tap(find.text('Υποβολή'));
          await tester.pumpAndSettle();

          verify(() => mockReportRepo.submitReport(
            reporterUid: 'my-uid',
            reportedUid: 'other-uid',
            reason: any(named: 'reason'),
          )).called(1);
          expect(find.text('Η αναφορά υποβλήθηκε'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });
  });
}