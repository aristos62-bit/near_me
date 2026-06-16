import 'package:firebase_core/firebase_core.dart';
import '../debug/debug_config.dart';

class FirebaseInit {
  static Future<bool> tryInitialize() async {
    try {
      await Firebase.initializeApp();
      DebugConfig.log(DebugConfig.serviceInit, 'Firebase initialized');
      return true;
    } catch (e) {
      DebugConfig.error('Firebase init failed', exception: e);
      return false;
    }
  }
}
