import '../../shared/models/public_profile.dart';
import '../debug/debug_config.dart';

/// [SPoT] Κοινό try/catch για PublicProfile parsing.
///
/// Χρησιμοποιείται από το FirestoreSearchRepository και το
/// ProfileRepositoryImpl — το μόνο κοινό μέρος είναι το parse με try/catch.
/// Οποιοσδήποτε caller χρειάζεται επιπλέον guards (π.χ. uid checks στο
/// ProfileRepositoryImpl) τους κρατάει ΠΡΙΝ την κλήση — ΔΕΝ τους βάζουμε
/// εδώ, γιατί θα άλλαζε τη συμπεριφορά του search repository.
PublicProfile? tryParsePublicProfile(Map<String, dynamic> data) {
  try {
    return PublicProfile.fromJson(data);
  } catch (e) {
    DebugConfig.warn(
        'tryParsePublicProfile: skipped malformed public profile (uid=${data['uid']}): $e');
    return null;
  }
}