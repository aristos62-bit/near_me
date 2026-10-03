import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/notifications/fcm_service.dart';
import 'package:near_me/core/services/idle_lock_service.dart';

/// `IdleLockService` statics χωρίς Firebase (μόνο plain bools/callbacks).
/// Κανόνας: cache ΠΑΝΤΑ disabled (αλλιώς γεννιούνται πραγματικοί Timers) +
/// reset + null callbacks στο tearDown (static pollution).
void _clean() {
  IdleLockService.reset();
  IdleLockService.onLockStateChanged = null;
  IdleLockService.onUnlocked = null;
  FcmService.isLocked = false;
  IdleLockService.primeCache(biometricEnabled: false, autoLockMinutes: 0);
}

void main() {
  group('IdleLockService guarded callback', () {
    test('αλλαγή → καλείται μία φορά· ίδια τιμή → σιγή', () {
      _clean();
      addTearDown(_clean);
      final seen = <bool>[];
      IdleLockService.onLockStateChanged = seen.add;
      IdleLockService.isLocked = true;
      IdleLockService.unlockManually();
      expect(seen, [false]);
      IdleLockService.unlockManually();
      expect(seen, [false]);
    });

    test('unlockManually → unlocked + Fcm unlock', () {
      _clean();
      addTearDown(_clean);
      var unlocked = 0;
      IdleLockService.onUnlocked = () => unlocked++;
      FcmService.isLocked = true;
      IdleLockService.unlockManually();
      expect(IdleLockService.isLocked, isFalse);
      expect(FcmService.isLocked, isFalse);
      expect(unlocked, 1);
    });

    test('reset → ξεκλειδώνει χωρίς callback αν ήδη false', () {
      _clean();
      addTearDown(_clean);
      var calls = 0;
      IdleLockService.onLockStateChanged = (_) => calls++;
      IdleLockService.reset();
      expect(IdleLockService.isLocked, isFalse);
      expect(calls, 0);
    });
  });

  group('IdleLockService startup/resume χωρίς biometric', () {
    test('applyStartupLock disabled → onUnlocked, χωρίς prompt', () async {
      _clean();
      addTearDown(_clean);
      var unlocked = 0;
      IdleLockService.onUnlocked = () => unlocked++;
      await IdleLockService.applyStartupLock(reason: 'test');
      expect(unlocked, 1);
      expect(IdleLockService.isLocked, isFalse);
    });

    test('onAppPaused → no-throw', () {
      _clean();
      addTearDown(_clean);
      expect(() => IdleLockService.onAppPaused(), returnsNormally);
    });

    test('checkOnResume φρέσκο unlock (<5s) → onUnlocked', () async {
      _clean();
      addTearDown(_clean);
      var unlocked = 0;
      IdleLockService.onUnlocked = () => unlocked++;
      IdleLockService.unlockManually();
      unlocked = 0;
      await IdleLockService.checkOnResume(reason: 'test');
      expect(unlocked, 1);
    });

    test('onSettingsChanged disable → no-throw, χωρίς timer', () {
      _clean();
      addTearDown(_clean);
      expect(
          () => IdleLockService.onSettingsChanged(
                previousBiometricEnabled: true,
                biometricEnabled: false,
                previousAutoLockMinutes: 5,
                autoLockMinutes: 5,
              ),
          returnsNormally);
      expect(IdleLockService.isLocked, isFalse);
    });

    test('onSettingsChanged enable+disable κύκλος → stable', () {
      _clean();
      addTearDown(_clean);
      IdleLockService.onSettingsChanged(
        previousBiometricEnabled: false,
        biometricEnabled: false,
        previousAutoLockMinutes: 5,
        autoLockMinutes: 10,
      );
      IdleLockService.onSettingsChanged(
        previousBiometricEnabled: false,
        biometricEnabled: false,
        previousAutoLockMinutes: 10,
        autoLockMinutes: 10,
      );
      expect(IdleLockService.isLocked, isFalse);
    });
  });
}
