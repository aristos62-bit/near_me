import 'dart:async';
import 'package:flutter/foundation.dart';
import '../debug/debug_config.dart';
import '../notifications/fcm_service.dart';
import '../utils/lock_screen.dart';

/// SRP-split από το main.dart (πρώην _NearMeAppState idle-lock/biometric).
/// Static service — ίδιο pattern με PresenceService/IncomingShareService:
/// static state + callback hooks, ΚΑΝΕΝΑ Riverpod provider → μηδέν rebuilds
/// πέρα από πραγματική αλλαγή isLocked (βλ. IncomingShareService doc).
///
/// ΔΥΟ ξεχωριστά callbacks προς NearMeApp, με διαφορετική σημασιολογία:
/// - [onLockStateChanged]: UI-facing, guarded (καλείται ΜΟΝΟ σε πραγματική
///   αλλαγή isLocked) → οδηγεί το setState/LockScreen visibility.
/// - [onUnlocked]: side-effects, καλείται ΚΑΘΕ φορά που επιβεβαιώνεται
///   "unlocked" outcome (ακόμα κι αν το isLocked δεν άλλαξε ποτέ — π.χ.
///   biometric off) → οδηγεί FcmService.tryExecutePendingNav +
///   IncomingShareService. Δεν μπορεί να ενοποιηθεί με το πρώτο γιατί ο
///   startup-χωρίς-biometric δρόμος δεν περνάει ΠΟΤΕ από isLocked=true.
///   Καλείται από ΟΛΑ τα branches του checkOnResume (όχι μόνο το
///   auth-success) ώστε ο caller (main.dart) να μη χρειάζεται δικό του
///   δεύτερο, ενδεχομένως προ-poll, execute call.
///
/// ΣΗΜΑΝΤΙΚΟ — δύο flags, διαφορετικό timing:
/// - FcmService.isLocked=true τίθεται ΠΡΙΝ ξεκινήσει το biometric prompt
///   (proactive block FCM/pending-nav όσο εκκρεμεί).
/// - IdleLockService.isLocked (UI, LockScreen) γίνεται true ΜΟΝΟ αν το
///   biometric αποτύχει/απορριφθεί/timeout.
class IdleLockService {
  IdleLockService._();

  static const _pauseThresholdSeconds = 60;

  static Timer? _idleTimer;
  static DateTime _lastUnlockTime = DateTime(2000);
  static DateTime? _lastPauseTime;
  static DateTime? _lastIdleReset;
  static int _lastResetDuration = 0;
  static bool _authInProgress = false;
  static int _cachedAutoLockMinutes = 0;
  static bool _cachedBiometricEnabled = false;

  static bool isLocked = false;
  static void Function(bool locked)? onLockStateChanged;
  static VoidCallback? onUnlocked;

  static void _setLocked(bool value) {
    if (isLocked == value) return;
    isLocked = value;
    onLockStateChanged?.call(value);
  }

  static void _markUnlocked() {
    _lastUnlockTime = DateTime.now();
    FcmService.isLocked = false;
    _setLocked(false);
    onUnlocked?.call();
  }

  /// Μόνο set cache, ΧΩΡΙΣ side effect στο idle timer — ο timer ξεκινά
  /// τεμπέλικα στο πρώτο pointer event (Listener), όχι αμέσως στο load.
  static void primeCache({required bool biometricEnabled, required int autoLockMinutes}) {
    _cachedBiometricEnabled = biometricEnabled;
    _cachedAutoLockMinutes = autoLockMinutes;
  }

  /// Κλήση μία φορά, στο πρώτο load του appSettingsProvider.
  static Future<void> applyStartupLock({required String reason}) async {
    if (!_cachedBiometricEnabled) {
      onUnlocked?.call();
      return;
    }
    FcmService.isLocked = true;
    await _authenticate(debugLabel: 'startup', reason: reason);
  }

  /// Κλήση από didChangeAppLifecycleState όταν state==resumed.
  static Future<void> checkOnResume({required String reason}) async {
    if (isLocked || _authInProgress) return;
    if (DateTime.now().difference(_lastUnlockTime).inSeconds < 5) {
      onUnlocked?.call();
      return;
    }
    if (!FcmService.hasPendingNavigation &&
        _lastPauseTime != null &&
        DateTime.now().difference(_lastPauseTime!).inSeconds < _pauseThresholdSeconds) {
      DebugConfig.log(DebugConfig.serviceCall,
          'IdleLockService: short pause — skipping biometric');
      onUnlocked?.call();
      return;
    }
    if (!_cachedBiometricEnabled) {
      onUnlocked?.call();
      return;
    }
    _authInProgress = true;
    try {
      FcmService.isLocked = true;
      await _authenticate(debugLabel: 'resume', reason: reason);
    } finally {
      _authInProgress = false;
    }
  }

  static Future<bool> _authenticate({required String debugLabel, required String reason}) async {
    DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: $debugLabel biometric start');
    try {
      final ok = await LockScreen.authenticate(reason: reason);
      if (ok) {
        DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: $debugLabel biometric success');
        _markUnlocked();
        return true;
      }
      DebugConfig.warn('IdleLockService: $debugLabel biometric rejected, locking');
      _setLocked(true);
      return false;
    } catch (e, s) {
      DebugConfig.error('IdleLockService: $debugLabel biometric failed', data: e, exception: s);
      FcmService.isLocked = false;
      return false;
    }
  }

  /// Από το onUnlock του LockScreen widget (το ίδιο ήδη έκανε το δικό
  /// του LockScreen.authenticate() πριν καλέσει αυτό).
  static void unlockManually() {
    _markUnlocked();
    notifyUserActivity();
  }

  static void onAppPaused() {
    _lastPauseTime = DateTime.now();
    _stopIdleTimer();
    DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: paused — idleTimer stopped');
  }

  /// p!=null && n!=null branch — 4 ανεξάρτητα if, ΙΔΙΑ σειρά με το πρωτότυπο.
  static void onSettingsChanged({
    required bool previousBiometricEnabled,
    required bool biometricEnabled,
    required int previousAutoLockMinutes,
    required int autoLockMinutes,
  }) {
    _cachedAutoLockMinutes = autoLockMinutes;
    _cachedBiometricEnabled = biometricEnabled;

    if (!previousBiometricEnabled && biometricEnabled) {
      _lastUnlockTime = DateTime.now();
    }
    if (previousAutoLockMinutes != autoLockMinutes) {
      DebugConfig.log(DebugConfig.serviceCall,
          'IdleLockService: autoLockMinutes changed $previousAutoLockMinutes → $autoLockMinutes');
      notifyUserActivity();
    }
    if (previousBiometricEnabled && !biometricEnabled) {
      DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: biometric disabled — idleTimer stopped');
      _stopIdleTimer();
    }
    if (!previousBiometricEnabled && biometricEnabled) {
      DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: biometric enabled — idleTimer started');
      notifyUserActivity();
    }
  }

  static void notifyUserActivity() {
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
    if (isLocked) {
      DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: idleTimer reset skipped (locked)');
      return;
    }
    _idleTimer = Timer(Duration(minutes: _cachedAutoLockMinutes), _onIdleTimeout);
    DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: idleTimer reset — ${_cachedAutoLockMinutes}min');
  }

  static void _onIdleTimeout() {
    if (isLocked) {
      DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: idleTimer timeout skipped (already locked)');
      return;
    }
    _idleTimer = null;
    DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: idleTimer timeout → locking app');
    FcmService.isLocked = true;
    _setLocked(true);
  }

  static void _stopIdleTimer() {
    if (_idleTimer != null) {
      _idleTimer!.cancel();
      _idleTimer = null;
      DebugConfig.log(DebugConfig.serviceCall, 'IdleLockService: idleTimer stopped');
    }
  }

  /// Sign-out.
  static void reset() {
    _stopIdleTimer();
    _authInProgress = false;
    _setLocked(false);
  }
}
