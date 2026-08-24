import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/utils/lock_screen.dart';
import '../../../core/utils/screen_protector.dart';
import '../../../data/local/database.dart';
import '../../../data/local/database_service.dart';
import '../../auth/providers/auth_provider.dart';

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AsyncValue<AppSettingsTableData>>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AsyncValue<AppSettingsTableData>> {
  @override
  AsyncValue<AppSettingsTableData> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    try {
      final db = DatabaseService.instance;
      final rows = await (db.select(db.appSettingsTable)..limit(1)).get();
      if (rows.isNotEmpty) {
        state = AsyncValue.data(rows.first);
      } else {
        final defaults = await _createDefaults(db);
        state = AsyncValue.data(defaults);
      }
    } catch (e, s) {
      DebugConfig.error('AppSettings load failed', data: e, exception: s);
      state = AsyncValue.error(e, s);
    }
  }

  Future<AppSettingsTableData> _createDefaults(AppDatabase db) async {
    final now = DateTime.now();
    final settings = AppSettingsTableData(
      id: 0,
      locale: 'el',
      themeMode: 'system',
      notificationsEnabled: true,
      biometricLockEnabled: false,
      screenshotPreventionEnabled: false,
      crashReportsEnabled: false,
      autoLockMinutes: 5,
      searchRadiusKm: 10.0,
      updatedAt: now,
    );
    try {
      await db.into(db.appSettingsTable).insert(settings.toCompanion(true));
    } catch (e) {
      DebugConfig.warn('AppSettings defaults insert failed', data: e);
    }
    return settings;
  }

  Future<void> setScreenshotPrevention(bool enabled) async {
    final current = state.value;
    if (current == null) return;

    DebugConfig.log(DebugConfig.serviceCall, 'AppSettings: screenshotPreventionEnabled=$enabled');

    try {
      final db = DatabaseService.instance;
      final updated = current.copyWith(
        screenshotPreventionEnabled: enabled,
        updatedAt: DateTime.now(),
      );
      await (db.update(db.appSettingsTable)
        ..where((t) => t.id.equals(updated.id))
      ).write(updated.toCompanion(true));
      state = AsyncValue.data(updated);
    } catch (e, s) {
      DebugConfig.error('AppSettings: failed to update screenshotPreventionEnabled', data: e, exception: s);
      state = AsyncValue.error(e, s);
      return;
    }

    if (enabled) {
      await ScreenProtector.enable();
    } else {
      await ScreenProtector.disable();
    }
  }

  Future<void> setCrashReports(bool enabled) async {
    final current = state.value;
    if (current == null) {
      DebugConfig.warn('AppSettings: setCrashReports skipped (no state)');
      return;
    }
    if (current.crashReportsEnabled == enabled) {
      DebugConfig.log(DebugConfig.serviceCall,
          'AppSettings: crashReportsEnabled skipped (unchanged $enabled)');
      return;
    }
    DebugConfig.log(DebugConfig.serviceCall,
        'AppSettings: crashReportsEnabled=$enabled');

    final db = DatabaseService.instance;
    try {
      final updated = current.copyWith(
        crashReportsEnabled: enabled,
        updatedAt: DateTime.now(),
      );
      await (db.update(db.appSettingsTable)
        ..where((t) => t.id.equals(updated.id))
      ).write(updated.toCompanion(true));
      state = AsyncValue.data(updated);
    } catch (e, s) {
      DebugConfig.error('AppSettings: failed to update crashReportsEnabled',
          data: e, exception: s);
      state = AsyncValue.error(e, s);
      return;
    }

    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(enabled);
      DebugConfig.log(DebugConfig.serviceInit,
          'AppSettings: Crashlytics collection=$enabled');
    } catch (e, s) {
      DebugConfig.error('AppSettings: Crashlytics toggle failed',
          data: e, exception: s);
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await db.logConsent(
        uid,
        enabled ? 'crash_reports_enabled' : 'crash_reports_disabled',
        'diagnostics',
        details: enabled
            ? 'Crash reporting enabled by user / Οι αναφορές σφαλμάτων ενεργοποιήθηκαν από τον χρήστη'
            : 'Crash reporting disabled by user / Οι αναφορές σφαλμάτων απενεργοποιήθηκαν από τον χρήστη',
      );
      DebugConfig.log(DebugConfig.consentLogWrite,
          'AppSettings: consent logged crashReports=$enabled');
    } catch (e, s) {
      DebugConfig.error('AppSettings: consent log failed',
          data: e, exception: s);
    }

    try {
      final user = ref.read(authStateProvider).value;
      if (enabled && user != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        await FirebaseCrashlytics.instance
            .setCustomKey('isAnonymous', user.isAnonymous);
        await FirebaseCrashlytics.instance
            .setCustomKey('emailVerified', user.emailVerified);
        DebugConfig.log(DebugConfig.serviceInit,
            'AppSettings: Crashlytics identifier synced uid=${user.uid}');
      } else if (!enabled) {
        await FirebaseCrashlytics.instance.setUserIdentifier('');
        await FirebaseCrashlytics.instance.deleteUnsentReports();
        DebugConfig.log(DebugConfig.serviceInit,
            'AppSettings: Crashlytics identifier cleared, unsent reports deleted');
      }
    } catch (e, s) {
      DebugConfig.error('AppSettings: Crashlytics identifier sync failed',
          data: e, exception: s);
    }
  }

  Future<void> setSearchRadius(double km) async {
    final current = state.value;
    if (current == null) {
      DebugConfig.warn('AppSettings: setSearchRadius skipped (no state)');
      return;
    }
    DebugConfig.log(DebugConfig.serviceCall,
        'AppSettings: searchRadiusKm=$km');
    try {
      final db = DatabaseService.instance;
      final updated = current.copyWith(
        searchRadiusKm: km,
        updatedAt: DateTime.now(),
      );
      await (db.update(db.appSettingsTable)
        ..where((t) => t.id.equals(updated.id))
      ).write(updated.toCompanion(true));
      state = AsyncValue.data(updated);
      DebugConfig.log(DebugConfig.serviceCall,
          'AppSettings: searchRadiusKm saved=$km');
    } catch (e, s) {
      DebugConfig.error('AppSettings: setSearchRadius failed',
          data: e, exception: s);
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    final current = state.value;
    if (current == null) {
      DebugConfig.warn('AppSettings: setAutoLockMinutes skipped (no state)');
      return;
    }
    final clamped = minutes.clamp(1, 30);
    if (current.autoLockMinutes == clamped) {
      DebugConfig.log(DebugConfig.serviceCall,
          'AppSettings: setAutoLockMinutes skipped (unchanged $clamped)');
      return;
    }
    DebugConfig.log(DebugConfig.serviceCall,
        'AppSettings: autoLockMinutes=$clamped (was ${current.autoLockMinutes})');
    try {
      final db = DatabaseService.instance;
      final updated = current.copyWith(
        autoLockMinutes: clamped,
        updatedAt: DateTime.now(),
      );
      await (db.update(db.appSettingsTable)
        ..where((t) => t.id.equals(updated.id))
      ).write(updated.toCompanion(true));
      state = AsyncValue.data(updated);
      DebugConfig.log(DebugConfig.serviceCall,
          'AppSettings: autoLockMinutes saved=$clamped');
    } catch (e, s) {
      DebugConfig.error('AppSettings: setAutoLockMinutes failed',
          data: e, exception: s);
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> setBiometricLock(bool enabled) async {
    final current = state.value;
    if (current == null) return;

    DebugConfig.log(DebugConfig.serviceCall,
        'AppSettings: biometricLockEnabled=$enabled');

    if (enabled) {
      final canUse = await LockScreen.canUseBiometric();
      if (!canUse) {
        DebugConfig.warn('AppSettings: biometric not available, cannot enable');
        return;
      }
      final authed = await LockScreen.authenticate(
        reason: 'Enable biometric lock',
      );
      if (!authed) {
        DebugConfig.warn('AppSettings: biometric test auth failed, abort enable');
        return;
      }
    }

    try {
      final db = DatabaseService.instance;
      final updated = current.copyWith(
        biometricLockEnabled: enabled,
        updatedAt: DateTime.now(),
      );
      await (db.update(db.appSettingsTable)
        ..where((t) => t.id.equals(updated.id))
      ).write(updated.toCompanion(true));
      state = AsyncValue.data(updated);
      DebugConfig.log(DebugConfig.serviceCall,
          'AppSettings: biometricLockEnabled saved=$enabled');
    } catch (e, s) {
      DebugConfig.error('AppSettings: failed to update biometricLockEnabled',
          data: e, exception: s);
      state = AsyncValue.error(e, s);
    }
  }
}
