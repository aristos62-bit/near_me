import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/local/database_service.dart';
import 'core/l10n/l10n.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/firebase/firebase_init.dart';
import 'core/debug/debug_config.dart';
import 'dart:async';
import 'core/notifications/fcm_service.dart';
import 'core/config/feature_flags.dart';
import 'core/services/idle_lock_service.dart';
import 'core/services/incoming_share_service.dart';
import 'core/services/presence_service.dart';
import 'core/utils/app_messenger.dart';
import 'core/utils/lock_screen.dart';
import 'core/utils/screen_protector.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/settings/providers/app_settings_provider.dart';
import 'providers/unread_badge_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/utils/media_share_cache.dart';
import 'core/utils/image_cache_guard.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'shared/widgets/global_connectivity_banner.dart';
import 'shared/widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() - ξανακαλείται στο FirebaseInit.tryInitialize(),
  // αλλά εκείνο είναι idempotent (Firebase.apps.isNotEmpty guard) — ασφαλές
  // και σε web builds όπου το διπλό init πετάει [core/duplicate-app]
  await Firebase.initializeApp();

  // Crashlytics handlers - ΠΡΕΠΕΙ να γίνουν ΜΕΤΑ το initializeApp.
  // Collection: OFF native (AndroidManifest firebase_crashlytics_collection_enabled),
  // ενεργοποιείται runtime από το αποθηκευμένο consent (first-load settings).
  // Το plugin υποστηρίζει μόνο Android/iOS/macOS — σε web/Windows/Linux
  // οι κλήσεις παραλείπονται (default Flutter error handling παραμένει).
  final bool crashlyticsSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  if (crashlyticsSupported) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }
  // Uncaught async errors (εκτός Flutter framework) → Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    DebugConfig.error('main: uncaught async error', data: error, exception: stack);
    if (crashlyticsSupported) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  runApp(
    ProviderScope(
      child: const AppBootstrap(),
    ),
  );
}

/// SPoT splash + parallel boot (`addPostFrameCallback 87`).
/// - Parallel: `FirebaseInit.tryInitialize() 6s timeout` SPoT `firebase_init:5` + `DatabaseService.tryInit()` SPoT + `Stopwatch` SPoT `1.2` -> `TIMING` `serviceInit 84` (`oldsessions:986`).
/// - Fire-and-forget `MediaShareCache.sweep / ImageCacheGuard` `unawaited catchError` SPoT `1.4` (όχι `PlatformDispatcher fatal`).
/// - UX: `_kSplashMinDuration 800ms` min + `AnimatedSwitcher 400ms` `196` transition.
/// - Fail-open: `false` -> `_errorScreen 617/622` (Firebase/DB).
/// - Lifecycle: `_hasFirebaseInitCompleted 98` guard -> `PresenceService 104` (όχι πριν init).
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> with WidgetsBindingObserver {
  static const _kSplashMinDuration = Duration(milliseconds: 800);
  bool _isFirebaseInitialized = false;
  bool _isDatabaseInitialized = false;
  bool _isAppReady = false;
  bool _hasFirebaseInitCompleted = false;
  late final DateTime _t0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _t0 = DateTime.now();
    DebugConfig.log(DebugConfig.serviceInit,
        '[TIMING] Splash rendered immediately');
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAfterFrame());
  }
  @override
  void dispose() {
    DebugConfig.log(DebugConfig.serviceInit, 'AppBootstrap: removeObserver');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasFirebaseInitCompleted) return;
    if (_isAppReady) {
      DebugConfig.log(DebugConfig.serviceInit,
          'AppBootstrap: lifecycle $state (NearMeApp handles it)');
    } else {
      DebugConfig.log(DebugConfig.presence,
          'AppBootstrap: forwarding lifecycle $state to PresenceService');
      PresenceService.handleLifecycle(state);
    }
  }

  Future<void> _initAfterFrame() async {
    final tPostFrame = DateTime.now();
    DebugConfig.log(DebugConfig.serviceInit,
        '[TIMING] addPostFrameCallback fired at ${tPostFrame.difference(_t0).inMilliseconds}ms');

    final firebaseSw = Stopwatch()..start();
    DebugConfig.log(DebugConfig.serviceInit, '[TIMING] Firebase start');
    final firebaseFuture = FirebaseInit.tryInitialize().whenComplete(() => firebaseSw.stop());

    final dbSw = Stopwatch()..start();
    DebugConfig.log(DebugConfig.serviceInit, '[TIMING] Database start');
    final dbFuture = DatabaseService.tryInit().whenComplete(() => dbSw.stop());

    // Fire-and-forget: δεν μπλοκάρει το startup timing, καθαρίζει
    // τυχόν "ορφανά" temp αρχεία media από προηγούμενα email/share.
    // catchError ΥΠΟΧΡΕΩΤΙΚΟ εδώ: bare unawaited() χωρίς error handler
    // αφήνει exception να φτάσει σε PlatformDispatcher.instance.onError
    // (main.dart πάνω) → καταγράφεται ως FATAL στο Crashlytics, ψευδές
    // crash για ένα απλό cache-cleanup που απέτυχε.
    unawaited(MediaShareCache.sweep().catchError((Object e, StackTrace s) {
      DebugConfig.error('main: MediaShareCache.sweep failed',
          data: e, exception: s, reportToCrashlytics: true);
    }));

    // Fire-and-forget: ελέγχει το μέγεθος του CachedNetworkImage disk
    // cache και το αδειάζει αν ξεπεράσει το όριο (flutter_cache_manager
    // δεν έχει byte-cap, μόνο count/age — βλ. αξιολόγηση 2GB storage).
    unawaited(ImageCacheGuard.checkAndPrune().catchError((Object e, StackTrace s) {
      DebugConfig.error('main: ImageCacheGuard.checkAndPrune failed',
          data: e, exception: s, reportToCrashlytics: true);
    }));

    final firebaseReady = await firebaseFuture;
    DebugConfig.log(
      DebugConfig.serviceInit,
      '[TIMING] Firebase init: ${firebaseSw.elapsedMilliseconds}ms',
    );

    if (firebaseReady) {
      AppRouter.firebaseReady = true;
      AppRouter.init();
      FcmService.init();
      IncomingShareService.init();
      PresenceService.init();
      _hasFirebaseInitCompleted = true;
      final current = WidgetsBinding.instance.lifecycleState;
      if (current != null && current != AppLifecycleState.resumed) {
        DebugConfig.log(DebugConfig.presence,
            'AppBootstrap: initial state $current → PresenceService');
        PresenceService.handleLifecycle(current);
      }
    }

    final dbReady = await dbFuture;
    DebugConfig.log(
      DebugConfig.serviceInit,
      '[TIMING] Database init: ${dbSw.elapsedMilliseconds}ms',
    );

    final tParallelEnd = DateTime.now();

    DebugConfig.log(
      DebugConfig.serviceInit,
      '[TIMING] NearMeApp transition at ${tParallelEnd.difference(_t0).inMilliseconds}ms from splash',
    );

    final elapsed = DateTime.now().difference(_t0);
    if (elapsed < _kSplashMinDuration) {
      await Future.delayed(_kSplashMinDuration - elapsed);
    }

    if (mounted) {
      setState(() {
        _isFirebaseInitialized = firebaseReady;
        _isDatabaseInitialized = dbReady;
        _isAppReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: !_isAppReady
          ? const SplashScreen(key: ValueKey('splash'))
          : NearMeApp(
              key: const ValueKey('app'),
              isDatabaseReady: _isDatabaseInitialized,
              isFirebaseReady: _isFirebaseInitialized,
            ),
    );
  }
}

class NearMeApp extends ConsumerStatefulWidget {
  final bool isDatabaseReady;
  final bool isFirebaseReady;

  const NearMeApp({super.key, required this.isDatabaseReady, required this.isFirebaseReady});

  @override
  ConsumerState<NearMeApp> createState() => _NearMeAppState();
}

class _NearMeAppState extends ConsumerState<NearMeApp> with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _fcmSub;
  bool _isLocked = false;
  late final Locale _deviceLocale;

  String get _biometricReason {
    final unlock = L10n.isGreekLocale(_deviceLocale) ? 'Ξεκλείδωσε το' : 'Unlock';
    return '$unlock ${L10n.appNameFromLocale(_deviceLocale)}';
  }

  @override
  void initState() {
    super.initState();
    _deviceLocale = L10n.deviceLocale();
    IdleLockService.onLockStateChanged = (locked) {
      if (!mounted) return;
      setState(() => _isLocked = locked);
    };
    IdleLockService.onUnlocked = () {
      if (!mounted) return;
      FcmService.tryExecutePendingNav();
      _executeIncomingShareSafely();
    };
    WidgetsBinding.instance.addObserver(this);
    IncomingShareService.onPending = _executeIncomingShareSafely;
    _fcmSub = FcmService.foregroundStream.listen(
      _onFcmForeground,
      onError: (e) => DebugConfig.error('main: FCM foreground stream error', data: e),
      cancelOnError: false,
    );

  }

  Future<void> _applyCrashConsent(bool enabled) async {
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(enabled);
      DebugConfig.log(DebugConfig.serviceInit,
          'main: Crashlytics collection=$enabled (saved consent)');
      if (!enabled) {
        await FirebaseCrashlytics.instance.deleteUnsentReports();
        DebugConfig.log(DebugConfig.serviceInit,
            'main: Crashlytics unsent reports deleted (no consent)');
        return;
      }
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        await FirebaseCrashlytics.instance
            .setCustomKey('isAnonymous', user.isAnonymous);
        await FirebaseCrashlytics.instance
            .setCustomKey('emailVerified', user.emailVerified);
        DebugConfig.log(DebugConfig.serviceInit,
            'main: Crashlytics identifier synced uid=${user.uid}');
      }
    } catch (e, s) {
      DebugConfig.error('main: apply saved crash consent failed',
          data: e, exception: s);
    }
  }

  /// Εκτελεί το pending incoming share αν το app είναι ξεκλείδωτο και ο
  /// Navigator είναι έτοιμος. Χρησιμοποιεί ΑΠΟΚΛΕΙΣΤΙΚΑ το context του
  /// Navigator (AppRouter.navigatorKey) — ο builder context του MaterialApp
  /// είναι πάνω από τον Navigator και ο Navigator.of δεν τον βρίσκει.
  void _executeIncomingShareSafely() {
    if (!FeatureFlags.incomingShareEnabled) return;
    if (!mounted || _isLocked) return;
    final navCtx = AppRouter.navigatorKey.currentContext;
    if (navCtx != null) {
      IncomingShareService.tryExecutePending(ref, navCtx);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLocked) {
        final c = AppRouter.navigatorKey.currentContext;
        if (c != null) IncomingShareService.tryExecutePending(ref, c);
      }
    });
  }

  @override
  void dispose() {
    IncomingShareService.onPending = null;
    IdleLockService.onLockStateChanged = null;
    IdleLockService.onUnlocked = null;
    IdleLockService.reset();
    WidgetsBinding.instance.removeObserver(this);
    _fcmSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    PresenceService.handleLifecycle(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      IdleLockService.onAppPaused();
    } else if (state == AppLifecycleState.resumed && mounted) {
      IdleLockService.checkOnResume(reason: _biometricReason).then((_) {
        if (!IdleLockService.isLocked && mounted) {
          IdleLockService.notifyUserActivity();
          IncomingShareService.pollPending();
          _executeIncomingShareSafely();
        }
      });
    }
  }

  void _onFcmForeground(RemoteMessage msg) {
    DebugConfig.log(DebugConfig.chatFcm, 'main: FCM foreground ${msg.messageId} type=${msg.data['type']}');
    if (!mounted) {
      DebugConfig.log(DebugConfig.chatFcm, 'main: FCM foreground skip !mounted');
      return;
    }
    if (FcmService.shouldSuppressForeground(msg)) {
      DebugConfig.log(DebugConfig.chatFcm, 'main: FCM foreground suppressed (in-chat)');
      return;
    }
    if (_isLocked) {
      DebugConfig.log(DebugConfig.chatFcm, 'main: FCM foreground suppressed locked');
      return;
    }
    final ctx = AppRouter.navigatorKey.currentContext;
    if (ctx == null) {
      DebugConfig.warn('main: FCM foreground no Navigator context (splash)');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = AppRouter.navigatorKey.currentContext;
        if (c != null && mounted && !_isLocked && !FcmService.shouldSuppressForeground(msg)) {
          final notif = msg.notification;
          if (notif != null) AppMessenger.showInfo(c, '${notif.title ?? ''}: ${notif.body ?? ''}');
        }
      });
      return;
    }
    final notif = msg.notification;
    if (notif != null) {
      AppMessenger.showInfo(ctx, '${notif.title ?? ''}: ${notif.body ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(unreadBadgeProvider, (_, _) {});
    ref.listen(authStateProvider, (prev, next) {
      final prevUser = prev?.value;
      final nextUser = next.value;
      DebugConfig.log(DebugConfig.authFlow,
          'main: authStateProvider listener fired '
          'prevUid=${prevUser?.uid ?? "null"} prevVerified=${prevUser?.emailVerified} '
          'nextUid=${nextUser?.uid ?? "null"} nextVerified=${nextUser?.emailVerified}');
      if (mounted) {
        final uidChanged = prevUser?.uid != nextUser?.uid;
        final emailVerifiedChanged =
            prevUser?.emailVerified != nextUser?.emailVerified;
        if ((uidChanged || emailVerifiedChanged) && prev is AsyncData) {
          DebugConfig.log(DebugConfig.authFlow,
              'main: auth changed — about to invalidate chatsProvider '
                  'uidChanged=$uidChanged emailVerifiedChanged=$emailVerifiedChanged');
          ref.invalidate(chatsProvider);
          // Crashlytics keys/identifier ΜΟΝΟ όταν υπάρχει consent (crashReportsEnabled)
          final crashConsent =
              ref.read(appSettingsProvider).value?.crashReportsEnabled ?? false;
          if (uidChanged) {
            DebugConfig.log(DebugConfig.authFlow,
                'main: uid changed ${prevUser?.uid ?? "null"} → ${nextUser?.uid ?? "null"}');
          }
          if (crashConsent) {
            // custom keys σε ΚΑΘΕ auth αλλαγή (φρεσκάρισμα emailVerified)
            FirebaseCrashlytics.instance.setCustomKey(
                'isAnonymous', nextUser?.isAnonymous ?? true);
            FirebaseCrashlytics.instance.setCustomKey(
                'emailVerified', nextUser?.emailVerified ?? false);
            if (uidChanged) {
              // user ID μόνο σε αλλαγή χρήστη ('' στο sign-out = καθαρίζει)
              FirebaseCrashlytics.instance
                  .setUserIdentifier(nextUser?.uid ?? '');
            }
          }

          if (emailVerifiedChanged) {
            DebugConfig.log(DebugConfig.authFlow,
                'main: emailVerified changed ${prevUser?.emailVerified} → ${nextUser?.emailVerified}');
          }
          DebugConfig.log(DebugConfig.providerDispose,
              'main: invalidated chatsProvider (auth change)');
        }
        // Claims-check: τρέχει όσο ο χρήστης είναι verified — καλύπτει και
        // cold start, άρα το restart μετά από εξωτερική επαλήθευση φρεσκάρει
        // το stale token. Φθηνός έλεγχος (getIdTokenResult(false), χωρίς
        // δίκτυο): αν το claim συμφωνεί ήδη με το γνωστό emailVerified=true,
        // τίποτα άλλο. Force refresh μόνο όταν το token λέει ακόμα unverified.
        if (nextUser != null && nextUser.emailVerified) {
          nextUser.getIdTokenResult(false).then((tokenResult) async {
            final tokenSaysVerified =
                tokenResult.claims?['email_verified'] == true;
            if (tokenSaysVerified) {
              DebugConfig.log(DebugConfig.authFlow,
                  'main: cached ID token already reflects emailVerified, skip refresh uid=${nextUser.uid}');
              return;
            }
            DebugConfig.log(DebugConfig.authFlow,
                'main: cached ID token stale (claims say unverified) — force refreshing uid=${nextUser.uid}');
            await nextUser.getIdToken(true).timeout(const Duration(seconds: 6));
            DebugConfig.log(DebugConfig.authFlow,
                'main: ID token force-refreshed uid=${nextUser.uid}');
          }).catchError((Object e, StackTrace s) {
            DebugConfig.error('main: ID token check/refresh failed',
                data: e, exception: s);
          });
        }
      }
      if (prevUser != null && nextUser == null && mounted) {
        IdleLockService.reset();
      }
    });
    ref.listen(chatsProvider, (prev, next) {
      DebugConfig.log(DebugConfig.chatStream,
          'main: chatsProvider emitted prev=${prev?.value?.length} next=${next.value?.length}');
    });
    ref.listen(appSettingsProvider, (prev, next) {
      if (!mounted) return;
      final p = prev?.value;
      final n = next.value;
      if (p == null && n != null) {
        IdleLockService.primeCache(
          biometricEnabled: n.biometricLockEnabled,
          autoLockMinutes: n.autoLockMinutes,
        );
        if (n.screenshotPreventionEnabled) {
          ScreenProtector.enable();
        }
        IdleLockService.applyStartupLock(reason: _biometricReason);
        _applyCrashConsent(n.crashReportsEnabled);
      }
      if (p != null && n != null) {
        IdleLockService.onSettingsChanged(
          previousBiometricEnabled: p.biometricLockEnabled,
          biometricEnabled: n.biometricLockEnabled,
          previousAutoLockMinutes: p.autoLockMinutes,
          autoLockMinutes: n.autoLockMinutes,
        );
      }
    });
    if (!widget.isFirebaseReady) {
      return _errorScreen(context, Icons.warning_amber, 'Firebase initialization failed',
          'Please check your internet connection and google-services.json');
    }

    if (!widget.isDatabaseReady) {
      return _errorScreen(context, Icons.storage, 'Database initialization failed',
          'Please restart the app. If the issue persists, reinstall the app.');
    }

    return MaterialApp.router(
      title: L10n.appNameFromLocale(_deviceLocale),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      builder: (context, child) {
        return Stack(
          children: [
            Listener(
              onPointerDown: (_) => IdleLockService.notifyUserActivity(),
              onPointerMove: (_) => IdleLockService.notifyUserActivity(),
              onPointerSignal: (_) => IdleLockService.notifyUserActivity(),
              child: child ?? const SizedBox.shrink(),
            ),
            const GlobalConnectivityBanner(),
            if (_isLocked)
              LockScreen(onUnlock: IdleLockService.unlockManually,
              ),
          ],
        );
      },
      themeMode: ThemeMode.system,
      locale: _deviceLocale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.supported,
      routerConfig: AppRouter.router,
    );
  }

  Widget _errorScreen(BuildContext context, IconData icon, String title, String message) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
