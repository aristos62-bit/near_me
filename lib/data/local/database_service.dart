import '../../core/debug/debug_config.dart';
import '../../core/utils/app_exception.dart';
import 'database.dart';

class DatabaseService {
  DatabaseService._();

  static AppDatabase? _instance;

  static bool get isInitialized => _instance != null;

  static AppDatabase get instance {
    if (_instance == null) {
      throw const AppException(
        message:
            'DatabaseService not initialized. Call DatabaseService.init() first.',
        code: 'not_initialized',
      );
    }
    return _instance!;
  }

  static Future<AppDatabase> init() async {
    if (_instance != null) return _instance!;

    DebugConfig.log(DebugConfig.serviceInit, 'Opening Drift database...');

    try {
      _instance = AppDatabase();
      DebugConfig.log(DebugConfig.serviceInit, 'Drift database opened');
      return _instance!;
    } catch (e, s) {
      DebugConfig.error('Failed to open Drift database', data: e, exception: s);
      _instance = null;
      throw AppException.database('init', e, s);
    }
  }

  static Future<bool> tryInit() async {
    try {
      await init();
      return true;
    } catch (e, s) {
      DebugConfig.error('Drift init failed (non-fatal)', data: e, exception: s);
      return false;
    }
  }

  static Future<void> close() async {
    if (_instance == null) return;
    try {
      DebugConfig.log(DebugConfig.serviceInit, 'Closing Drift database...');
      _instance!.close();
    } catch (e, s) {
      DebugConfig.error('Error closing Drift database', data: e, exception: s);
    } finally {
      _instance = null;
    }
  }
}
