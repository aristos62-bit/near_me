import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import '../debug/debug_config.dart';

class FirebaseInit {
  static Future<bool> tryInitialize() async {
    if (Firebase.apps.isNotEmpty) {
      DebugConfig.log(DebugConfig.serviceInit,
          'Firebase already initialized (main()) — skip duplicate init');
      return true;
    }
    final f = Firebase.initializeApp();
    unawaited(f.then<void>((_) {}, onError: (Object e, StackTrace s) => DebugConfig.warn('Firebase init late completion after timeout', data: e)));
    try {
      await f.timeout(const Duration(seconds: 6));
      DebugConfig.log(DebugConfig.serviceInit, 'Firebase initialized');
      return true;
    } on TimeoutException {
      DebugConfig.warn('Firebase init TIMEOUT after 6s');
      return false;
    } catch (e, s) {
      DebugConfig.error('Firebase init failed', data: e, exception: s);
      return false;
    }
  }
}
