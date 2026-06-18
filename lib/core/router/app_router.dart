import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_shell.dart';
import '../debug/debug_config.dart';
import '../l10n/l10n.dart';
import '../../features/discovery/screens/discovery_screen.dart';
import '../../features/discovery/screens/public_profile_view_screen.dart';
import '../../features/discovery/screens/saved_searches_screen.dart';
import '../../features/discovery/screens/search_filters_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
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
          'Redirect: location=$location, user=${user?.uid ?? "null"}, isAnonymous=${user?.isAnonymous}');
      if (user == null && !isWelcomeRoute) return '/welcome';
      if (user != null) {
        if (isWelcomeRoute) {
          return user.isAnonymous ? '/anonymous-info' : '/';
        }
        if (isAuthRoute && !user.isAnonymous) return '/';
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
      GoRoute(path: '/requests/send/:uid', pageBuilder: (context, state) {
        final uid = state.pathParameters['uid']!;
        return _modal(SendRequestScreen(uid: uid));
      }),
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
    FirebaseAuth.instance.authStateChanges().listen((user) {
      DebugConfig.log(DebugConfig.authFlow,
          'Auth state changed: uid=${user?.uid}, anon=${user?.isAnonymous}');
      _authNotifier.notify();
    });
  }


}

class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
