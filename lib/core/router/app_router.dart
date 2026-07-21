import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_shell.dart';
import '../debug/debug_config.dart';
import '../l10n/l10n.dart';
import '../../repositories/auth_repository.dart';
import '../../features/discovery/screens/discovery_screen.dart';
import '../../features/discovery/screens/public_profile_view_screen.dart';
import '../../features/discovery/screens/saved_searches_screen.dart';
import '../../features/discovery/screens/search_filters_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/chat/screens/create_group_screen.dart';
import '../../features/chat/screens/group_call_screen.dart';
import '../../features/chat/screens/group_settings_screen.dart';
import '../../features/chat/screens/group_search_screen.dart';
import '../../features/chat/screens/group_invite_screen.dart';
import '../../features/chat/screens/group_info_screen.dart';
import '../../features/chat/screens/permissions_editor_screen.dart';
import '../../features/chat/screens/add_participant_screen.dart';
import '../../features/chat/screens/group_audit_log_screen.dart';
import '../../features/chat/screens/join_confirmation_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/profile_editor_screen.dart';
import '../../features/profile/screens/privacy_editor_screen.dart';
import '../../features/profile/screens/consent_log_screen.dart';
import '../../features/auth/screens/phone_verify_screen.dart';
import '../../features/auth/screens/verify_account_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/anonymous_info_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/delete_account_screen.dart';
import '../../features/requests/screens/requests_dashboard_screen.dart';
import '../../features/requests/screens/send_request_screen.dart';
import '../../features/block/screens/blocked_users_screen.dart';

class AppRouter {
  AppRouter._();

  static bool firebaseReady = false;
  static final _AuthChangeNotifier _authNotifier = _AuthChangeNotifier();
  static bool _verifyDismissed = false;
  static String? _lastUid;

  static void dismissVerify() {
    DebugConfig.log(DebugConfig.authFlow, 'AppRouter: verify dismissed by user');
    _verifyDismissed = true;
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      if (!firebaseReady) return null;
      final user = FirebaseAuth.instance.currentUser;
      final location = state.matchedLocation;
      final isWelcomeRoute = location == '/welcome';
      final isAuthRoute = location == '/auth';
      DebugConfig.log(DebugConfig.navigationRoute,
          'Redirect: location=$location, user=${user?.uid ?? "null"}, isAnonymous=${user?.isAnonymous}, emailVerified=${user?.emailVerified}, verifyDismissed=$_verifyDismissed');
      if (user == null && !isWelcomeRoute) return '/welcome';
      if (user != null) {
        if (isWelcomeRoute) {
          return user.isAnonymous
              ? '/anonymous-info'
              : (user.emailVerified ? '/' : '/auth?from=register');
        }
        if (isAuthRoute && !user.isAnonymous && user.emailVerified) return '/';
        if (location == '/' && !user.isAnonymous && !user.emailVerified && !_verifyDismissed) {
          return '/auth';
        }
        final canComm = AuthRepository.canUserCommunicate(user);
        if (!canComm) {
          final isCommPath = location == '/chats' || location == '/requests' ||
              location == '/groups' ||
              location.startsWith('/chat/') || location.startsWith('/requests/') ||
              location.startsWith('/groups/');
          if (isCommPath) {
            DebugConfig.log(DebugConfig.navigationRoute,
                'Redirect: communication path blocked (canComm=$canComm)');
            return '/auth';
          }
        }
      }
      return null;
    },
    errorBuilder: (context, state) {
      DebugConfig.warn('GoRouter: no route for ${state.uri}');
      return Material(
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('NearMe'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 72,
                      color: Theme.of(context).colorScheme.error.withAlpha(180)),
                  const SizedBox(height: 16),
                  Text(
                    L10n.localizedMessage(context, 'Η σελίδα δεν βρέθηκε / Page not found'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    L10n.localizedMessage(context,
                        'Η σελίδα που ζητήσατε δεν υπάρχει. / The page you requested does not exist.'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: Text(L10n.localizedMessage(context, 'Αρχική / Go Home')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const DiscoveryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chats', builder: (context, state) => const ChatListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/chat/:chatId', pageBuilder: (context, state) {
        final chatId = state.pathParameters['chatId']!;
        return _slideUp(ChatScreen(chatId: chatId));
      }),
      GoRoute(path: '/user/:uid', pageBuilder: (context, state) => _slideUp(const PublicProfileViewScreen())),
      GoRoute(path: '/discovery/filters', pageBuilder: (context, state) => _slideUp(const SearchFiltersScreen())),
      GoRoute(path: '/discovery/saved-searches', pageBuilder: (context, state) => _slideUp(const SavedSearchesScreen())),
      GoRoute(path: '/profile/edit', pageBuilder: (context, state) => _modal(const ProfileEditorScreen())),
      GoRoute(path: '/profile/privacy', pageBuilder: (context, state) => _modal(const PrivacyEditorScreen())),
      GoRoute(path: '/profile/consent-log', pageBuilder: (context, state) => _modal(const ConsentLogScreen())),
      GoRoute(path: '/profile/blocked', pageBuilder: (context, state) => _modal(const BlockedUsersScreen())),
      GoRoute(path: '/profile/delete', pageBuilder: (context, state) => _modal(const DeleteAccountScreen())),
      GoRoute(path: '/settings', pageBuilder: (context, state) => _modal(const SettingsScreen())),
      GoRoute(path: '/settings/phone-verify', pageBuilder: (context, state) => _modal(const PhoneVerifyScreen())),
      GoRoute(path: '/auth', pageBuilder: (context, state) => _modal(const VerifyAccountScreen())),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/anonymous-info', builder: (context, state) => const AnonymousInfoScreen()),
      GoRoute(path: '/requests', pageBuilder: (context, state) => _modal(const RequestsDashboardScreen())),
      GoRoute(path: '/requests/:requestId', pageBuilder: (context, state) {
        final requestId = state.pathParameters['requestId']!;
        return _modal(RequestsDashboardScreen(highlightRequestId: requestId));
      }),
      GoRoute(path: '/requests/send/:uid', pageBuilder: (context, state) {
        final uid = state.pathParameters['uid']!;
        return _modal(SendRequestScreen(uid: uid));
      }),
      // --- Group Chat Routes (Phase 7: replace Scaffold placeholders with real screens) ---
      GoRoute(
        path: '/groups',
        pageBuilder: (context, state) =>
            _slideUp(const Scaffold(body: Center(child: Text('Groups / GroupListScreen')))),
      ),
      GoRoute(
        path: '/groups/create',
        pageBuilder: (context, state) =>
            _modal(const CreateGroupScreen()),
      ),
      GoRoute(
        path: '/groups/:chatId/info',
        pageBuilder: (context, state) => _modal(GroupInfoScreen(
          chatId: state.pathParameters['chatId']!,
        )),
      ),
      GoRoute(
        path: '/groups/:chatId/invite',
        pageBuilder: (context, state) => _modal(GroupInviteScreen(
          chatId: state.pathParameters['chatId']!,
        )),
      ),
      GoRoute(
        path: '/groups/:chatId/call',
        pageBuilder: (context, state) => _slideUp(GroupCallScreen(
          chatId: state.pathParameters['chatId']!,
          groupName: state.extra as String?,
        )),
      ),
      GoRoute(
        path: '/groups/:chatId/settings',
        pageBuilder: (context, state) => _modal(GroupSettingsScreen(
          chatId: state.pathParameters['chatId']!,
        )),
      ),
      GoRoute(
        path: '/groups/search',
        pageBuilder: (context, state) =>
            _slideUp(const GroupSearchScreen()),
      ),
      GoRoute(
        path: '/groups/:chatId',
        pageBuilder: (context, state) => _slideUp(Scaffold(
          body: Center(child: Text('GroupChatScreen: ${state.pathParameters['chatId']}')),
        )),
      ),
      GoRoute(
        path: '/groups/:chatId/add',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _modal(AddParticipantScreen(
            chatId: state.pathParameters['chatId']!,
            currentParticipantUids:
                (extra?['currentParticipantUids'] as List<dynamic>?)?.cast<String>() ?? [],
            maxParticipants: (extra?['maxParticipants'] as int?) ?? 8,
          ));
        },
      ),
      GoRoute(
        path: '/groups/:chatId/audit-log',
        pageBuilder: (context, state) => _modal(GroupAuditLogScreen(
          chatId: state.pathParameters['chatId']!,
        )),
      ),
      GoRoute(
        path: '/groups/:chatId/permissions/:targetUid',
        pageBuilder: (context, state) => _modal(PermissionsEditorScreen(
          chatId: state.pathParameters['chatId']!,
          targetUid: state.pathParameters['targetUid']!,
        )),
      ),
      GoRoute(
        path: '/join',
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return _slideUp(JoinConfirmationScreen(token: token));
        },
      ),
    ],
  );

  static Page<Object?> _slideUp(Widget child) {
    return CustomTransitionPage(
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  static Page<Object?> _modal(Widget child) {
    return CustomTransitionPage(
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  static void init() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      final t0 = DateTime.now();
      DebugConfig.log(DebugConfig.authFlow,
          'AppRouter: init callback fired uid=${user?.uid}');
      if (user != null) {
        try {
          DebugConfig.log(DebugConfig.authFlow,
              'AppRouter: user.reload() starting uid=${user.uid}');
          await user.reload();
          final elapsed = DateTime.now().difference(t0).inMilliseconds;
          DebugConfig.log(DebugConfig.authFlow,
              'AppRouter: user.reload() completed in ${elapsed}ms uid=${user.uid}');
        } catch (_) {
          DebugConfig.warn('AppRouter: user.reload() failed, using cached data');
        }
      }
      final uid = user?.uid;
      if (uid != _lastUid) {
        _verifyDismissed = false;
        _lastUid = uid;
        DebugConfig.log(DebugConfig.authFlow,
            'AppRouter: user changed to uid=$uid, verifyDismissed reset');
      }
      DebugConfig.log(DebugConfig.authFlow,
          'Auth state changed: uid=$uid, anon=${user?.isAnonymous}, emailVerified=${user?.emailVerified}');
      DebugConfig.log(DebugConfig.authFlow,
          'AppRouter: calling _authNotifier.notify() uid=$uid elapsed=${DateTime.now().difference(t0).inMilliseconds}ms');
      _authNotifier.notify();
    });
  }


}

class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
