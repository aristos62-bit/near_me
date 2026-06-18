import 'package:flutter/foundation.dart';

/// Συγκεντρωτικό αρχείο ελέγχου debug μηνυμάτων.
///
/// Κάθε flag ελέγχεται από το [debugMode] (master switch).
/// Σε release mode (kReleaseMode = true) όλα τα debugs απενεργοποιούνται αυτόματα.
///
/// Χρήση: DebugConfig.log(DebugConfig.databaseLocal, 'UserProfile loaded');
class DebugConfig {
  DebugConfig._();

  /// ─────────────────────────────────────────────────────────────
  /// MASTER SWITCH — απενεργοποιεί όλα τα debugs
  /// Σε release mode τίθεται αυτόματα false.
  ///
  /// Για να ενεργοποιήσεις debugs και σε release (π.χ. μέτρηση χρόνων):
  ///   flutter run --release --dart-define=ENABLE_RELEASE_DEBUG=true
  ///
  /// Ή με build:
  ///   flutter build apk --release --dart-define=ENABLE_RELEASE_DEBUG=true
  /// ─────────────────────────────────────────────────────────────
  static bool get debugMode {
    if (kReleaseMode) {
      return const bool.fromEnvironment('ENABLE_RELEASE_DEBUG', defaultValue: false);
    }
    return true;
  }

  /// ─────────────────────────────────────────────────────────────
  /// DATABASE — Isar local database operations
  /// ─────────────────────────────────────────────────────────────
  static const bool databaseLocal = true;        // read/write/delete local DB
  static const bool databaseLocalSchema = false;  // schema migrations, init
  static const bool databaseLocalStream = false;  // watchCollection / watchObject

  /// ─────────────────────────────────────────────────────────────
  /// FIRESTORE — Firebase remote database operations
  /// ─────────────────────────────────────────────────────────────
  static const bool firestoreRead = true;         // any read from Firestore
  static const bool firestoreWrite = true;        // any write to Firestore
  static const bool firestoreStream = false;      // onSnapshot listeners
  static const bool firestoreSecurity = false;    // security rule violations

  /// ─────────────────────────────────────────────────────────────
  /// AUTH — Firebase Authentication flow
  /// ─────────────────────────────────────────────────────────────
  static const bool authFlow = true;             // signIn, signUp, signOut
  static const bool authTokens = false;          // token refresh, secure storage
  static const bool authAnonymous = true;        // anonymous → verified upgrade
  static const bool authPhone = true;             // phone verification flow

  /// ─────────────────────────────────────────────────────────────
  /// CLOUD FUNCTIONS — Firebase Callable Functions
  /// ─────────────────────────────────────────────────────────────
  static const bool cloudFunctions = true;        // callable function calls

  /// ─────────────────────────────────────────────────────────────
  /// GPS & GEO — Location permissions and GeoHash
  /// ─────────────────────────────────────────────────────────────
  static const bool gpsPermissions = true;       // permission requests
  static const bool gpsLocation = true;          // lat/lng readings
  static const bool gpsGeoHash = false;          // geoHash conversion

  /// ─────────────────────────────────────────────────────────────
  /// PROVIDERS — Riverpod provider lifecycle
  /// ─────────────────────────────────────────────────────────────
  static const bool providerCreate = true;       // provider creation / init
  static const bool providerDispose = true;     // provider dispose
  static const bool providerInvalidate = true;  // ref.invalidate calls

  /// ─────────────────────────────────────────────────────────────
  /// SERVICES — Shared services (repo calls, service layer)
  /// ─────────────────────────────────────────────────────────────
  static const bool serviceInit = true;          // service initialization
  static const bool serviceCall = true;          // method calls
  static const bool serviceError = true;         // errors and exceptions
  static const bool presence = false;            // online presence events

  /// ─────────────────────────────────────────────────────────────
  /// REPOSITORIES — Repository pattern method calls
  /// ─────────────────────────────────────────────────────────────
  static const bool repositoryCall = true;       // search, publish, etc.
  static const bool repositoryResult = true;     // returned data size/timing

  /// ─────────────────────────────────────────────────────────────
  /// NAVIGATION — GoRouter navigation events
  /// ─────────────────────────────────────────────────────────────
  static const bool navigationRoute = true;     // route changes
  static const bool navigationDeepLink = false;  // deep link handling

  /// ─────────────────────────────────────────────────────────────
  /// UI — Widget rendering and user interactions
  /// ─────────────────────────────────────────────────────────────
  static const bool uiRebuild = true;           // widget rebuilds
  static const bool uiInteraction = true;       // button taps, form submits

  /// ─────────────────────────────────────────────────────────────
  /// CONSENT & GDPR — ConsentLog operations
  /// ─────────────────────────────────────────────────────────────
  static const bool consentLogWrite = true;      // writing consent entries
  static const bool consentLogRead = false;      // reading consent history

  /// ─────────────────────────────────────────────────────────────
  /// CHAT & ENCRYPTION — Φάση 3+
  /// ─────────────────────────────────────────────────────────────
  static const bool chatEncrypt = false;         // encryption / decryption
  static const bool chatStream = true;          // real-time chat listeners
  static const bool chatFcm = false;             // FCM notification events (chat)
  static const bool requestFcm = false;          // FCM for incoming requests

  /// ─────────────────────────────────────────────────────────────
  /// FILE STORAGE — Firebase Storage operations (Φάση 2+)
  /// ─────────────────────────────────────────────────────────────
  static const bool storageUpload = false;       // file uploads
  static const bool storageDownload = false;     // file downloads

  /// ─────────────────────────────────────────────────────────────
  /// Εκτυπώνει debug μήνυμα ΜΟΝΟ αν [flag] == true ΚΑΙ debugMode == true.
  /// ─────────────────────────────────────────────────────────────
  static void log(bool flag, String message, {Object? data}) {
    if (!debugMode || !flag) return;
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    if (data != null) {
      debugPrint('[$timestamp][DEBUG] $message | $data');
    } else {
      debugPrint('[$timestamp][DEBUG] $message');
    }
  }

  /// ─────────────────────────────────────────────────────────────
  /// Εκτυπώνει warning — εμφανίζεται ακόμα και αν το specific flag
  /// είναι false, αρκεί να είμαστε σε debug mode.
  /// ─────────────────────────────────────────────────────────────
  static void warn(String message, {Object? data}) {
    if (!debugMode) return;
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    if (data != null) {
      debugPrint('[$timestamp][WARN] $message | $data');
    } else {
      debugPrint('[$timestamp][WARN] $message');
    }
  }

  /// ─────────────────────────────────────────────────────────────
  /// Εκτυπώνει error — πάντα σε debug mode, ανεξαρτήτως flags.
  /// ─────────────────────────────────────────────────────────────
  static void error(String message, {Object? data, Object? exception}) {
    if (!debugMode) return;
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final buffer = StringBuffer('[$timestamp][ERROR] $message');
    if (data != null) buffer.write(' | data: $data');
    if (exception != null) buffer.write(' | exception: $exception');
    debugPrint(buffer.toString());
  }
}
