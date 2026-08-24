import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() - καλείται και αλλού, αλλά δεν πειράζει
  await Firebase.initializeApp();

  // Crashlytics setup - ΠΡΕΠΕΙ να γίνει ΜΕΤΑ το initializeApp
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  runApp(
    ProviderScope(
      child: const AppBootstrap(),
    ),
  );
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> with WidgetsBindingObserver {
  bool _firebaseReady = false;
  bool _dbReady = false;
  bool _ready = false;
  bool _firebaseInitDone = false;
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
    if (!_firebaseInitDone) return;
    if (_ready) {
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

    final tFirebaseStart = DateTime.now();
    DebugConfig.log(DebugConfig.serviceInit, '[TIMING] Firebase start');

    final firebaseFuture = FirebaseInit.tryInitialize();

    final tDbStart = DateTime.now();
    DebugConfig.log(DebugConfig.serviceInit, '[TIMING] Database start');

    final dbFuture = DatabaseService.tryInit();

    // Fire-and-forget: δεν μπλοκάρει το startup timing, καθαρίζει
    // τυχόν "ορφανά" temp αρχεία media από προηγούμενα email/share.
    unawaited(MediaShareCache.sweep());

    // Fire-and-forget: ελέγχει το μέγεθος του CachedNetworkImage disk
    // cache και το αδειάζει αν ξεπεράσει το όριο (flutter_cache_manager
    // δεν έχει byte-cap, μόνο count/age — βλ. αξιολόγηση 2GB storage).
    unawaited(ImageCacheGuard.checkAndPrune());

    final firebaseReady = await firebaseFuture;
    final tFirebaseEnd = DateTime.now();

    DebugConfig.log(
      DebugConfig.serviceInit,
      '[TIMING] Firebase init: ${tFirebaseEnd.difference(tFirebaseStart).inMilliseconds}ms',
    );

    if (firebaseReady) {
      AppRouter.firebaseReady = true;
      AppRouter.init();
      FcmService.init();
      IncomingShareService.init();
      PresenceService.init();
      _firebaseInitDone = true;
      final current = WidgetsBinding.instance.lifecycleState;
      if (current != null && current != AppLifecycleState.resumed) {
        DebugConfig.log(DebugConfig.presence,
            'AppBootstrap: initial state $current → PresenceService');
        PresenceService.handleLifecycle(current);
      }
    }

    final dbReady = await dbFuture;
    final tDbEnd = DateTime.now();

    DebugConfig.log(
      DebugConfig.serviceInit,
      '[TIMING] Database init: ${tDbEnd.difference(tDbStart).inMilliseconds}ms',
    );

    final tParallelEnd = DateTime.now();

    DebugConfig.log(
      DebugConfig.serviceInit,
      '[TIMING] NearMeApp transition at ${tParallelEnd.difference(_t0).inMilliseconds}ms from splash',
    );

    final elapsed = DateTime.now().difference(_t0);
    if (elapsed < const Duration(seconds: 3)) {
      await Future.delayed(const Duration(seconds: 3) - elapsed);
    }

    if (mounted) {
      setState(() {
        _firebaseReady = firebaseReady;
        _dbReady = dbReady;
        _ready = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: !_ready
          ? _splashScreen(key: const ValueKey('splash'))
          : NearMeApp(
              key: const ValueKey('app'),
              dbReady: _dbReady,
              firebaseReady: _firebaseReady,
            ),
    );
  }

  Widget _splashScreen({Key? key}) {
    return Directionality(
      key: key,
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.black12,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icons/near_me.webp', width: 250, height: 250),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NearMeApp extends ConsumerStatefulWidget {
  final bool dbReady;
  final bool firebaseReady;

  const NearMeApp({super.key, required this.dbReady, required this.firebaseReady});

  @override
  ConsumerState<NearMeApp> createState() => _NearMeAppState();
}

class _NearMeAppState extends ConsumerState<NearMeApp> with WidgetsBindingObserver {
  static const _pauseThresholdSeconds = 60;

  BuildContext? _appContext;
  StreamSubscription<RemoteMessage>? _fcmSub;
  bool _isLocked = false;
  bool _authInProgress = false;
  DateTime _lastUnlockTime = DateTime(2000);
  DateTime? _lastPauseTime;
  DateTime? _lastIdleReset;
  int _lastResetDuration = 0;
  Timer? _idleTimer;
  int _cachedAutoLockMinutes = 0;
  bool _cachedBiometricEnabled = false;
  late final Locale? _deviceLocale;

  @override
  void initState() {
    super.initState();
    _deviceLocale = L10n.deviceLocale();
    WidgetsBinding.instance.addObserver(this);
    IncomingShareService.onPending = _executeIncomingShareSafely;
    _fcmSub = FcmService.foregroundStream.listen(
      _onFcmForeground,
      onError: (e) => DebugConfig.error('main: FCM foreground stream error', data: e),
      cancelOnError: false,
    );

  }

  Future<void> _applyStartupLock() async {
    try {
      final settings = ref.read(appSettingsProvider).value;
      if (settings == null || !settings.biometricLockEnabled) {
        FcmService.tryExecutePendingNav();
        _executeIncomingShareSafely();
        return;
      }
      DebugConfig.log(DebugConfig.serviceCall,
          'main: startup biometric lock check');
      FcmService.isLocked = true;
      final locale = _deviceLocale!;
      final appName = L10n.appNameFromLocale(locale);
      final unlockedLabel = L10n.isGreekLocale(locale) ? 'Ξεκλείδωσε το' : 'Unlock';
      final authed = await LockScreen.authenticate(
        reason: '$unlockedLabel $appName',
      );
      if (authed) {
        FcmService.isLocked = false;
        _lastUnlockTime = DateTime.now();
        FcmService.tryExecutePendingNav();
        _executeIncomingShareSafely();
      } else if (mounted) {
        setState(() => _isLocked = true);
      }
    } catch (e) {
      FcmService.isLocked = false;
      DebugConfig.error('main: startup biometric lock failed', data: e);
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
    _stopIdleTimer();
    WidgetsBinding.instance.removeObserver(this);
    _fcmSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    PresenceService.handleLifecycle(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _lastPauseTime = DateTime.now();
      _stopIdleTimer();
      DebugConfig.log(DebugConfig.serviceCall,
          'main: lifecycle $state — idleTimer stopped');
    } else if (state == AppLifecycleState.resumed && mounted) {
      _checkBiometricLock().then((_) {
        if (!_isLocked && mounted) {
          _resetIdleTimer();
          IncomingShareService.pollPending();
          _executeIncomingShareSafely();
        }
      });
    }
  }

  Future<void> _checkBiometricLock() async {
    if (_isLocked || _authInProgress) return;
    if (DateTime.now().difference(_lastUnlockTime).inSeconds < 5) return;
    if (!FcmService.hasPendingNavigation &&
        _lastPauseTime != null &&
        DateTime.now().difference(_lastPauseTime!).inSeconds < _pauseThresholdSeconds) {
      DebugConfig.log(DebugConfig.serviceCall,
          'main: short pause (${DateTime.now().difference(_lastPauseTime!).inSeconds}s < $_pauseThresholdSeconds s) — skipping biometric');
      return;
    }
    _authInProgress = true;
    try {
      final settings = ref.read(appSettingsProvider).value;
      if (settings == null || !settings.biometricLockEnabled) return;
      DebugConfig.log(DebugConfig.serviceCall,
          'main: checking biometric lock on resume');
      FcmService.isLocked = true;
      final locale = _deviceLocale!;
      final appName = L10n.appNameFromLocale(locale);
      final unlockedLabel = L10n.isGreekLocale(locale) ? 'Ξεκλείδωσε το' : 'Unlock';
      final authed = await LockScreen.authenticate(
        reason: '$unlockedLabel $appName',
      );
      if (authed) {
        FcmService.isLocked = false;
        _lastUnlockTime = DateTime.now();
        FcmService.tryExecutePendingNav();
        _executeIncomingShareSafely();
      } else if (mounted) {
        DebugConfig.warn('main: biometric auth failed, locking app');
        setState(() => _isLocked = true);
      }
    } catch (e) {
      FcmService.isLocked = false;
      DebugConfig.error('main: biometric lock check failed', data: e);
    } finally {
      _authInProgress = false;
    }
  }

  void _stopIdleTimer() {
    if (_idleTimer != null) {
      _idleTimer!.cancel();
      _idleTimer = null;
      DebugConfig.log(DebugConfig.serviceCall, 'main: idleTimer stopped');
    }
  }

  void _resetIdleTimer() {
    if (!_cachedBiometricEnabled || _cachedAutoLockMinutes <= 0) return;

    final now = DateTime.now();
    final durationChanged = _lastResetDuration != _cachedAutoLockMinutes;
    if (!durationChanged && _idleTimer != null && _lastIdleReset != null &&
        now.difference(_lastIdleReset!) < const Duration(seconds: 1)) {
      return;
    }

    _lastIdleReset = now;
    _lastResetDuration = _cachedAutoLockMinutes;

    _stopIdleTimer();
    if (_isLocked) {
      DebugConfig.log(DebugConfig.serviceCall,
          'main: idleTimer reset skipped (locked)');
      return;
    }
    _idleTimer = Timer(
      Duration(minutes: _cachedAutoLockMinutes),
      _onIdleTimeout,
    );
    DebugConfig.log(DebugConfig.serviceCall,
        'main: idleTimer reset — ${_cachedAutoLockMinutes}min');
  }

  void _onIdleTimeout() {
    if (_isLocked) {
      DebugConfig.log(DebugConfig.serviceCall,
          'main: idleTimer timeout skipped (already locked)');
      return;
    }
    _idleTimer = null;
    DebugConfig.log(DebugConfig.serviceCall,
        'main: idleTimer timeout → locking app');
    if (mounted) {
      FcmService.isLocked = true;
      setState(() => _isLocked = true);
    }
  }

  void _onFcmForeground(RemoteMessage msg) {
    if (!mounted) return;
    final ctx = _appContext;
    if (ctx == null) return;
    if (FcmService.shouldSuppressForeground(msg)) return;
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
          if (uidChanged) {
            DebugConfig.log(DebugConfig.authFlow,
                'main: uid changed ${prevUser?.uid ?? "null"} → ${nextUser?.uid ?? "null"}');
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
        _stopIdleTimer();
        if (_isLocked) {
          setState(() => _isLocked = false);
        }
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
      if (n != null) {
        _cachedAutoLockMinutes = n.autoLockMinutes;
        _cachedBiometricEnabled = n.biometricLockEnabled;
      }
      if (p == null && n != null) {
        if (n.screenshotPreventionEnabled) {
          ScreenProtector.enable();
        }
        _applyStartupLock();
      }
      if (p != null && n != null) {
        if (!p.biometricLockEnabled && n.biometricLockEnabled) {
          _lastUnlockTime = DateTime.now();
        }
        if (p.autoLockMinutes != n.autoLockMinutes) {
          DebugConfig.log(DebugConfig.serviceCall,
              'main: autoLockMinutes changed ${p.autoLockMinutes} → ${n.autoLockMinutes}');
          _resetIdleTimer();
        }
        if (p.biometricLockEnabled && !n.biometricLockEnabled) {
          DebugConfig.log(DebugConfig.serviceCall,
              'main: biometric disabled — idleTimer stopped');
          _stopIdleTimer();
        }
        if (!p.biometricLockEnabled && n.biometricLockEnabled) {
          DebugConfig.log(DebugConfig.serviceCall,
              'main: biometric enabled — idleTimer started');
          _resetIdleTimer();
        }
      }
    });
    if (!widget.firebaseReady) {
      return _errorScreen(context, Icons.warning_amber, 'Firebase initialization failed',
          'Please check your internet connection and google-services.json');
    }

    if (!widget.dbReady) {
      return _errorScreen(context, Icons.storage, 'Database initialization failed',
          'Please restart the app. If the issue persists, reinstall the app.');
    }

    return MaterialApp.router(
      title: L10n.appNameFromLocale(_deviceLocale!),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      builder: (context, child) {
        _appContext = context;
        return Stack(
          children: [
            Listener(
              onPointerDown: (_) => _resetIdleTimer(),
              onPointerMove: (_) => _resetIdleTimer(),
              onPointerSignal: (_) => _resetIdleTimer(),
              child: child ?? const SizedBox.shrink(),
            ),
            if (_isLocked)
              LockScreen(
                onUnlock: () {
                  DebugConfig.log(DebugConfig.serviceCall,
                      'main: lock screen unlock success');
                  FcmService.isLocked = false;
                  FcmService.tryExecutePendingNav();
                  _executeIncomingShareSafely();
                  setState(() {
                    _isLocked = false;
                    _lastUnlockTime = DateTime.now();
                  });
                  _resetIdleTimer();
                },
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
