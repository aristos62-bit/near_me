import '../debug/debug_config.dart';

class ErrorMessages {
  ErrorMessages._();

  static String get(String input, bool isGreek) {
    const sep = ' / ';
    final idx = input.indexOf(sep);
    if (idx != -1) {
      return isGreek ? input.substring(0, idx) : input.substring(idx + sep.length);
    }
    return _fromCode(input, isGreek);
  }

  static String _fromCode(String code, bool isGreek) {
    switch (code) {
      case 'auth/email-already-in-use':
        return isGreek ? 'Το email χρησιμοποιείται ήδη' : 'Email already in use';
      case 'auth/invalid-email':
        return isGreek ? 'Μη έγκυρο email' : 'Invalid email';
      case 'auth/weak-password':
        return isGreek ? 'Ο κωδικός είναι πολύ αδύναμος' : 'Password too weak';
      case 'auth/user-not-found':
        return isGreek ? 'Δεν βρέθηκε χρήστης' : 'User not found';
      case 'auth/wrong-password':
        return isGreek ? 'Λάθος κωδικός' : 'Wrong password';
      case 'auth/too-many-requests':
        return isGreek ? 'Πολλές προσπάθειες. Δοκίμασε αργότερα.' : 'Too many attempts. Try again later.';
      case 'auth/network-error':
        return isGreek ? 'Πρόβλημα δικτύου. Δοκίμασε ξανά.' : 'Network error. Try again.';
      case 'auth/unknown-error':
      case 'auth_required':
      case 'auth_error':
        return isGreek ? 'Σφάλμα ταυτοποίησης. Δοκίμασε ξανά.' : 'Authentication error. Try again.';
      case 'auth/operation-not-allowed':
        return isGreek ? 'Η επαλήθευση τηλεφώνου δεν είναι ενεργοποιημένη' : 'Phone verification not enabled';
      case 'auth/invalid-phone':
        return isGreek ? 'Μη έγκυρος αριθμός τηλεφώνου' : 'Invalid phone number';
      case 'auth/invalid-code':
        return isGreek ? 'Λάθος κωδικός επαλήθευσης' : 'Invalid verification code';
      case 'auth/invalid-verification':
        return isGreek ? 'Σφάλμα επαλήθευσης. Δοκίμασε ξανά.' : 'Verification error. Try again.';
      case 'auth/quota-exceeded':
        return isGreek ? 'Το ημερήσιο όριο SMS εξαντλήθηκε. Δοκίμασε αύριο.' : 'Daily SMS limit reached. Try again tomorrow.';
      case 'auth/provider-linked':
        return isGreek ? 'Το τηλέφωνο χρησιμοποιείται ήδη από άλλο λογαριασμό' : 'Phone already linked to another account';
      case 'auth/phone-timeout':
        return isGreek ? 'Το αίτημα επαλήθευσης έληξε. Δοκίμασε ξανά.' : 'Verification request timed out. Try again.';
      case 'auth/missing-client-identifier':
        return isGreek ? 'Σφάλμα ταυτοποίησης συσκευής. Βεβαιώσου ότι οι Υπηρεσίες Google Play είναι ενημερωμένες.' : 'Device identification error. Ensure Google Play Services are up to date.';
      case 'search/permission-denied':
        return isGreek ? 'Δεν βρέθηκαν χρήστες. Δοκίμασε άλλα φίλτρα.' : 'No users found. Try different filters.';
      case 'search/no-connectivity':
        return isGreek ? 'Δεν υπάρχει σύνδεση στο διαδίκτυο' : 'No internet connection';
      case 'search/unknown-error':
        return isGreek ? 'Σφάλμα αναζήτησης. Δοκίμασε ξανά.' : 'Search error. Try again.';
      case 'chat/encryption-error':
        return isGreek ? 'Σφάλμα κρυπτογράφησης' : 'Encryption error';
      case 'chat/network-error':
        return isGreek ? 'Σφάλμα δικτύου. Δοκίμασε ξανά.' : 'Network error. Try again.';
      case 'chat/send-failed':
        return isGreek ? 'Αποστολή απέτυχε' : 'Send failed';
      case 'chat/unknown-error':
        return isGreek ? 'Σφάλμα συνομιλίας. Δοκίμασε ξανά.' : 'Chat error. Try again.';
      case 'delete/unknown-error':
        return isGreek ? 'Σφάλμα διαγραφής λογαριασμού. Δοκίμασε ξανά.' : 'Account deletion error. Try again.';
      case 'stream/load-error':
        return isGreek ? 'Σφάλμα φόρτωσης. Δοκίμασε ξανά.' : 'Failed to load. Try again.';
      case 'request/send-failed':
        return isGreek ? 'Αποτυχία αποστολής' : 'Failed to send';
      case 'database_error':
      case 'firestore_error':
      case 'storage_error':
      case 'network_error':
      case 'validation_error':
      case 'unknown':
        return isGreek ? 'Σφάλμα συστήματος. Δοκίμασε ξανά.' : 'System error. Try again.';
    }
    DebugConfig.warn('ErrorMessages: unhandled code $code');
    assert(false, 'Missing ErrorMessages mapping: $code');
    return isGreek ? 'Σφάλμα συστήματος. Δοκίμασε ξανά.' : 'System error. Try again.';
  }
}
