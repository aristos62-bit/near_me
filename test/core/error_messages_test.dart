import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/error_messages.dart';

/// Direct κάλυψη του `ErrorMessages.get` — ~100 codes χωρίς κανένα test.
/// Μόνο known codes (unhandled → assert σε debug) + bilingual passthrough.
void main() {
  group('ErrorMessages auth', () {
    test('auth/invalid-email el/en', () {
      expect(ErrorMessages.get('auth/invalid-email', true), 'Μη έγκυρο email');
      expect(ErrorMessages.get('auth/invalid-email', false), 'Invalid email');
    });

    test('auth/network-error el/en', () {
      expect(ErrorMessages.get('auth/network-error', true),
          'Πρόβλημα δικτύου. Δοκίμασε ξανά.');
      expect(
          ErrorMessages.get('auth/network-error', false), 'Network error. Try again.');
    });

    test('auth/phone-timeout el/en', () {
      expect(ErrorMessages.get('auth/phone-timeout', true),
          'Το αίτημα επαλήθευσης έληξε. Δοκίμασε ξανά.');
      expect(ErrorMessages.get('auth/phone-timeout', false),
          'Verification request timed out. Try again.');
    });

    test('auth_required fallback el/en', () {
      expect(ErrorMessages.get('auth_required', true),
          'Σφάλμα ταυτοποίησης. Δοκίμασε ξανά.');
      expect(ErrorMessages.get('auth_required', false),
          'Authentication error. Try again.');
    });
  });

  group('ErrorMessages search/network', () {
    test('search/no-connectivity el/en', () {
      expect(ErrorMessages.get('search/no-connectivity', true),
          'Δεν υπάρχει σύνδεση στο διαδίκτυο');
      expect(ErrorMessages.get('search/no-connectivity', false),
          'No internet connection');
    });

    test('search/rate-limited el/en', () {
      expect(ErrorMessages.get('search/rate-limited', true),
          'Πολλές αναζητήσεις. Δοκίμασε ξανά σε λίγο.');
      expect(ErrorMessages.get('search/rate-limited', false),
          'Too many searches. Try again shortly.');
    });
  });

  group('ErrorMessages chat', () {
    test('chat/network-error el/en', () {
      expect(ErrorMessages.get('chat/network-error', true),
          'Σφάλμα δικτύου. Δοκίμασε ξανά.');
      expect(
          ErrorMessages.get('chat/network-error', false), 'Network error. Try again.');
    });

    test('chat/send-failed el/en', () {
      expect(ErrorMessages.get('chat/send-failed', true), 'Αποστολή απέτυχε');
      expect(ErrorMessages.get('chat/send-failed', false), 'Send failed');
    });

    test('chat/video-too-large el/en', () {
      expect(ErrorMessages.get('chat/video-too-large', true),
          'Το βίντεο είναι πολύ μεγάλο (max 15MB)');
      expect(ErrorMessages.get('chat/video-too-large', false),
          'Video too large (max 15MB)');
    });
  });

  group('ErrorMessages group', () {
    test('group/create-failed el/en', () {
      expect(ErrorMessages.get('group/create-failed', true),
          'Αποτυχία δημιουργίας ομάδας');
      expect(
          ErrorMessages.get('group/create-failed', false), 'Failed to create group');
    });

    test('group/join-failed el/en', () {
      expect(ErrorMessages.get('group/join-failed', true),
          'Αποτυχία εισόδου στην ομάδα');
      expect(ErrorMessages.get('group/join-failed', false), 'Failed to join group');
    });
  });

  group('ErrorMessages profile/privacy', () {
    test('profile/saved el/en', () {
      expect(ErrorMessages.get('profile/saved', true), 'Αποθηκεύτηκε');
      expect(ErrorMessages.get('profile/saved', false), 'Saved');
    });

    test('privacy/settings-saved el/en', () {
      expect(ErrorMessages.get('privacy/settings-saved', true),
          'Οι ρυθμίσεις απορρήτου αποθηκεύτηκαν');
      expect(ErrorMessages.get('privacy/settings-saved', false),
          'Privacy settings saved');
    });
  });

  group('ErrorMessages report/block/help/request', () {
    test('report/submitted el/en', () {
      expect(ErrorMessages.get('report/submitted', true), 'Η αναφορά υποβλήθηκε');
      expect(ErrorMessages.get('report/submitted', false), 'Report submitted');
    });

    test('block/blocked + block/unblocked el/en', () {
      expect(ErrorMessages.get('block/blocked', true), 'Μπλοκαρίστηκε');
      expect(ErrorMessages.get('block/blocked', false), 'Blocked');
      expect(ErrorMessages.get('block/unblocked', true), 'Ξεμπλοκαρίστηκε');
      expect(ErrorMessages.get('block/unblocked', false), 'Unblocked');
    });

    test('help/activated el/en', () {
      expect(ErrorMessages.get('help/activated', true),
          'Η επείγουσα βοήθεια ενεργοποιήθηκε');
      expect(ErrorMessages.get('help/activated', false), 'Emergency help activated');
    });

    test('request/sent + request/respond-failed el/en', () {
      expect(ErrorMessages.get('request/sent', true), 'Το αίτημα στάλθηκε');
      expect(ErrorMessages.get('request/sent', false), 'Request sent');
      expect(ErrorMessages.get('request/respond-failed', true),
          'Αποτυχία απάντησης σε αίτημα');
      expect(ErrorMessages.get('request/respond-failed', false),
          'Failed to respond to request');
    });
  });

  group('ErrorMessages settings/moderation/system', () {
    test('settings/blur-on el/en', () {
      expect(ErrorMessages.get('settings/blur-on', true), 'Το θάμπωμα ενεργοποιήθηκε');
      expect(ErrorMessages.get('settings/blur-on', false), 'Blur enabled');
    });

    test('moderation/blocked-explicit el/en', () {
      expect(ErrorMessages.get('moderation/blocked-explicit', true),
          'Η φωτογραφία απορρίφθηκε (ακατάλληλο περιεχόμενο)');
      expect(ErrorMessages.get('moderation/blocked-explicit', false),
          'Photo rejected (explicit content)');
    });

    test('database_error fallback el/en', () {
      expect(ErrorMessages.get('database_error', true),
          'Σφάλμα συστήματος. Δοκίμασε ξανά.');
      expect(ErrorMessages.get('database_error', false), 'System error. Try again.');
    });
  });

  group('ErrorMessages bilingual passthrough', () {
    test('μήνυμα με separator επιστρέφεται κατά locale', () {
      const bilingual = 'Γράψε μήνυμα / Write message';
      expect(ErrorMessages.get(bilingual, true), 'Γράψε μήνυμα');
      expect(ErrorMessages.get(bilingual, false), 'Write message');
    });
  });
}
