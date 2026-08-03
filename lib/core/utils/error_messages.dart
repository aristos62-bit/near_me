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
      case 'auth/invalid-credential':
        return isGreek ? 'Λάθος email ή κωδικός' : 'Wrong email or password';
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
      case 'network/no-connectivity':
        return isGreek ? 'Δεν υπάρχει σύνδεση στο διαδίκτυο' : 'No internet connection';
      case 'search/rate-limited':
        return isGreek ? 'Πολλές αναζητήσεις. Δοκίμασε ξανά σε λίγο.' : 'Too many searches. Try again shortly.';
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
      case 'chat/gif-send-failed':
        return isGreek ? 'Αποστολή GIF απέτυχε' : 'GIF send failed';
      case 'chat/gif-api-error':
        return isGreek ? 'Σφάλμα φόρτωσης GIF' : 'GIF loading error';
      case 'chat/image-send-failed':
        return isGreek ? 'Αποστολή φωτογραφίας απέτυχε' : 'Image send failed';
      case 'chat/audio-send-failed':
        return isGreek ? 'Αποστολή ηχογραφήματος απέτυχε' : 'Audio send failed';
      case 'chat/audio-playback-error':
        return isGreek ? 'Σφάλμα αναπαραγωγής' : 'Playback error';
      case 'chat/audio-permission-denied':
        return isGreek ? 'Δεν δόθηκε άδεια μικροφώνου' : 'Microphone permission denied';
      case 'chat/audio-too-short':
        return isGreek ? 'Το ηχητικό μήνυμα είναι πολύ σύντομο' : 'Audio message is too short';
      case 'chat/video-send-failed':
        return isGreek ? 'Αποστολή βίντεο απέτυχε' : 'Video send failed';
      case 'chat/video-permission-denied':
        return isGreek ? 'Δεν δόθηκε άδεια κάμερας' : 'Camera permission denied';
      case 'chat/video-too-short':
        return isGreek ? 'Το βίντεο είναι πολύ σύντομο' : 'Video is too short';
      case 'chat/video-too-large':
        return isGreek ? 'Το βίντεο είναι πολύ μεγάλο (max 15MB)' : 'Video too large (max 15MB)';
      case 'chat/video-too-long':
        return isGreek ? 'Το βίντεο είναι πολύ μεγάλο (μέγιστο 30s)' : 'Video is too long (max 30s)';
      case 'chat/video-playback-error':
        return isGreek ? 'Σφάλμα αναπαραγωγής βίντεο' : 'Video playback error';
      case 'chat/audio-too-long':
        return isGreek ? 'Μέγιστη διάρκεια 60 δευτερόλεπτα' : 'Maximum duration 60 seconds';
      case 'chat/reply-send-failed':
        return isGreek ? 'Αποτυχία αποστολής απάντησης' : 'Failed to send reply';
      case 'chat/link-invalid':
        return isGreek ? 'Μη έγκυρος σύνδεσμος' : 'Invalid link';
      case 'chat/link-open-failed':
        return isGreek ? 'Δεν ήταν δυνατό το άνοιγμα του συνδέσμου' : 'Could not open the link';
      case 'chat/delete-failed':
        return isGreek ? 'Αποτυχία διαγραφής συνομιλίας' : 'Failed to delete chat';
      case 'chat/delete-not-found':
        return isGreek ? 'Η συνομιλία δεν βρέθηκε' : 'Chat not found';
        case 'chat/email-no-app':
        return isGreek ? 'Δεν βρέθηκε εφαρμογή email' : 'No email app found';
      case 'chat/email-not-configured':
        return isGreek ? 'Δεν βρέθηκε ρυθμισμένη εφαρμογή email' : 'No configured email app found';
      case 'chat/email-attach-failed':
        return isGreek ? 'Δεν ήταν δυνατή η επισύναψη — θα σταλεί ο σύνδεσμος' : 'Could not attach file — sending link instead';
      case 'chat/email-not-available':
        return isGreek ? 'Η εφαρμογή email δεν είναι διαθέσιμη αυτή τη στιγμή' : 'Email composer is unavailable right now';
      case 'chat/email-send-failed':
        return isGreek ? 'Αποτυχία αποστολής email' : 'Failed to send email';
      case 'chat/share-file-failed':
        return isGreek ? 'Δεν ήταν δυνατή η κοινοποίηση αρχείου — θα σταλεί ο σύνδεσμος' : 'Could not share file — sending link instead';
      case 'chat/share-failed':
        return isGreek ? 'Αποτυχία κοινοποίησης' : 'Failed to share';
      case 'chat/no-chats-forward':
        return isGreek ? 'Δεν υπάρχουν συνομιλίες για προώθηση' : 'No chats available to forward to';
      case 'chat/forwarded':
        return isGreek ? 'Προωθήθηκε' : 'Forwarded';
      case 'chat/forward-failed':
        return isGreek ? 'Αποτυχία προώθησης' : 'Failed to forward';
      case 'chat/reply-privately-failed':
        return isGreek ? 'Δεν ήταν δυνατό το άνοιγμα προσωπικής συνομιλίας'
            : 'Could not open private chat';
      case 'chat/edit-timeout':
        return isGreek ? 'Το χρονικό όριο επεξεργασίας (15 λεπτά) έχει λήξει' : 'The 15-minute edit window has expired';
      case 'chat/messages-cleared':
        return isGreek ? 'Τα μηνύματα διαγράφηκαν' : 'Messages cleared';
      case 'chat/e2e-info-title':
        return isGreek ? 'E2E Κρυπτογράφηση' : 'E2E Encryption';
      case 'group/avatar-updated':
        return isGreek ? 'Η φωτογραφία ομάδας ενημερώθηκε' : 'Group avatar updated';
      case 'group/avatar-update-failed':
        return isGreek ? 'Αποτυχία ενημέρωσης φωτογραφίας ομάδας' : 'Failed to update group avatar';
      case 'group/avatar-removed':
        return isGreek ? 'Η φωτογραφία ομάδας αφαιρέθηκε' : 'Group avatar removed';
      case 'group/avatar-remove-failed':
        return isGreek ? 'Αποτυχία αφαίρεσης φωτογραφίας ομάδας' : 'Failed to remove group avatar';
      case 'group/invalid-participant-count':
        return isGreek ? 'Μη έγκυρος αριθμός συμμετεχόντων' : 'Invalid participant count';
      case 'group/max-participants-updated':
        return isGreek ? 'Το όριο συμμετεχόντων ενημερώθηκε' : 'Maximum participants updated';
      case 'group/max-participants-update-failed':
        return isGreek ? 'Αποτυχία ενημέρωσης ορίου συμμετεχόντων' : 'Failed to update max participants';
      case 'group/min-members':
        return isGreek ? 'Η ομάδα χρειάζεται τουλάχιστον 2 μέλη' : 'Group needs at least 2 members';
      case 'chat/message-expiry-creator-only':
        return isGreek ? 'Μόνο ο δημιουργός μπορεί να αλλάξει αυτήν τη ρύθμιση' : 'Only the creator can change this setting';
      case 'chat/message-expiry-invalid-value':
        return isGreek ? 'Μη έγκυρη τιμή αυτόματης διαγραφής' : 'Invalid message expiry value';
      case 'chat/message-expiry-updated':
        return isGreek ? 'Η αυτόματη διαγραφή ενημερώθηκε' : 'Auto-delete updated';
      case 'chat/message-expiry-update-failed':
        return isGreek ? 'Αποτυχία ενημέρωσης αυτόματης διαγραφής' : 'Failed to update auto-delete';
      case 'group/created':
        return isGreek ? 'Η ομάδα δημιουργήθηκε' : 'Group created';
      case 'group/create-failed':
        return isGreek ? 'Αποτυχία δημιουργίας ομάδας' : 'Failed to create group';
      case 'group/select-min-members':
        return isGreek ? 'Επίλεξε τουλάχιστον 1 άτομο' : 'Select at least 1 person';
      case 'group/name-updated':
        return isGreek ? 'Το όνομα ομάδας ενημερώθηκε' : 'Group name updated';
      case 'group/name-update-failed':
        return isGreek ? 'Αποτυχία ενημέρωσης ονόματος ομάδας' : 'Failed to update group name';
      case 'group/role-updated':
        return isGreek ? 'Ο ρόλος ενημερώθηκε' : 'Role updated';
      case 'group/role-change-failed':
        return isGreek ? 'Αποτυχία αλλαγής ρόλου' : 'Failed to change role';
      case 'group/delete-failed':
        return isGreek ? 'Αποτυχία διαγραφής ομάδας' : 'Failed to delete group';
      case 'group/add-member-failed':
        return isGreek ? 'Αποτυχία προσθήκης μέλους' : 'Failed to add member';
      case 'group/add-member-error':
        return isGreek ? 'Σφάλμα κατά την προσθήκη μέλους' : 'Error adding member';
      case 'group/permission-updated':
        return isGreek ? 'Τα δικαιώματα ενημερώθηκαν' : 'Permissions updated';
      case 'group/permission-update-failed':
        return isGreek ? 'Αποτυχία ενημέρωσης δικαιωμάτων' : 'Failed to update permissions';
      case 'group/permissions-reset':
        return isGreek ? 'Τα δικαιώματα επαναφέρθηκαν' : 'Permissions reset';
      case 'group/permissions-reset-failed':
        return isGreek ? 'Αποτυχία επαναφοράς δικαιωμάτων' : 'Failed to reset permissions';
      case 'group/member-removed':
        return isGreek ? 'Το μέλος αφαιρέθηκε' : 'Member removed';
      case 'group/member-remove-failed':
        return isGreek ? 'Αποτυχία αφαίρεσης μέλους' : 'Failed to remove member';
      case 'group/joined':
        return isGreek ? 'Εντάχθηκες στην ομάδα' : 'Joined the group';
      case 'group/join-failed':
        return isGreek ? 'Αποτυχία εισόδου στην ομάδα' : 'Failed to join group';
      case 'group/invite-days-invalid':
        return isGreek ? 'Οι ημέρες πρέπει να είναι 1-365' : 'Days must be 1-365';
      case 'group/invite-uses-invalid':
        return isGreek ? 'Οι χρήσεις πρέπει να είναι 1-1000' : 'Uses must be 1-1000';
      case 'group/invite-token-copied':
        return isGreek ? 'Το invite token αντιγράφηκε στο clipboard' : 'Invite token copied to clipboard';
      case 'group/invite-copied':
        return isGreek ? 'Αντιγράφηκε' : 'Copied';
      case 'profile/gps-permission-denied':
        return isGreek ? 'Δεν δόθηκε άδεια τοποθεσίας' : 'Location permission denied';
      case 'profile/gps-manual-entry':
        return isGreek ? 'Δεν δόθηκε άδεια GPS. Μπορείς να συμπληρώσεις χειροκίνητα την πόλη.' : 'GPS permission denied. You can enter the city manually.';
      case 'profile/photo-saved':
        return isGreek ? 'Η φωτογραφία αποθηκεύτηκε' : 'Photo saved';
      case 'profile/upload-failed':
        return isGreek ? 'Αποτυχία μεταφόρτωσης' : 'Upload failed';
      case 'profile/photo-upload-failed':
        return isGreek ? 'Αποτυχία μεταφόρτωσης φωτογραφίας' : 'Photo upload failed';
      case 'profile/unsaved-changes-title':
        return isGreek ? 'Μη αποθηκευμένες αλλαγές' : 'Unsaved changes';
      case 'profile/unsaved-changes-body':
        return isGreek ? 'Έχεις μη αποθηκευμένες αλλαγές. Θέλεις να αποθηκεύσεις πριν φύγεις;' : 'You have unsaved changes. Save before leaving?';
      case 'profile/nickname-required':
        return isGreek ? 'Το ψευδώνυμο είναι υποχρεωτικό' : 'Nickname is required';
      case 'profile/saved':
        return isGreek ? 'Αποθηκεύτηκε' : 'Saved';
      case 'profile/saved-success':
        return isGreek ? 'Το προφίλ αποθηκεύτηκε!' : 'Profile saved!';
      case 'profile/save-failed':
        return isGreek ? 'Αποτυχία αποθήκευσης' : 'Failed to save';
      case 'profile/save-profile-failed':
        return isGreek ? 'Αποτυχία αποθήκευσης προφίλ' : 'Failed to save profile';
      case 'profile/avatar-load-failed':
        return isGreek ? 'Αποτυχία φόρτωσης φωτογραφίας' : 'Failed to load avatar';
      case 'profile/photo-load-failed':
        return isGreek ? 'Αποτυχία φόρτωσης φωτογραφίας προφίλ' : 'Failed to load profile photo';
      case 'profile/no-groups-to-invite':
        return isGreek ? 'Δεν υπάρχουν διαθέσιμες ομάδες για πρόσκληση' : 'No groups available to invite to';
      case 'profile/invited-to-group':
        return isGreek ? 'Προσκλήθηκες στην ομάδα' : 'Invited to group';
      case 'profile/invite-failed':
        return isGreek ? 'Αποτυχία αποστολής πρόσκλησης' : 'Failed to send invitation';
      case 'profile/published':
        return isGreek ? 'Το προφίλ δημοσιεύτηκε' : 'Profile published';
      case 'profile/unpublished':
        return isGreek ? 'Το προφίλ αποσύρθηκε' : 'Profile unpublished';
      case 'profile/publish-toggle-failed':
        return isGreek ? 'Αποτυχία αλλαγής κατάστασης δημοσίευσης' : 'Failed to toggle publish state';
      case 'profile/changes-applied-public':
        return isGreek ? 'Οι αλλαγές εφαρμόστηκαν στο δημόσιο προφίλ σου' : 'Changes applied to your public profile';
      case 'privacy/unsaved-changes-title':
        return isGreek ? 'Μη αποθηκευμένες αλλαγές' : 'Unsaved changes';
      case 'privacy/unsaved-changes-body':
        return isGreek ? 'Έχεις μη αποθηκευμένες αλλαγές. Θέλεις να αποθηκεύσεις πριν φύγεις;' : 'You have unsaved changes. Save before leaving?';
      case 'privacy/changes-applied':
        return isGreek ? 'Οι αλλαγές εφαρμόστηκαν' : 'Changes applied';
      case 'privacy/changes-applied-public':
        return isGreek ? 'Οι αλλαγές εφαρμόστηκαν στο δημόσιο προφίλ σου' : 'Changes applied to your public profile';
      case 'privacy/saved':
        return isGreek ? 'Αποθηκεύτηκε' : 'Saved';
      case 'privacy/settings-saved':
        return isGreek ? 'Οι ρυθμίσεις απορρήτου αποθηκεύτηκαν' : 'Privacy settings saved';
      case 'privacy/save-failed':
        return isGreek ? 'Αποτυχία αποθήκευσης' : 'Failed to save';
      case 'auth/sign-out-failed':
        return isGreek ? 'Αποτυχία αποσύνδεσης' : 'Sign out failed';
      case 'auth/phone-removed':
        return isGreek ? 'Το τηλέφωνο αφαιρέθηκε' : 'Phone removed';
      case 'auth/phone-remove-failed':
        return isGreek ? 'Αποτυχία αφαίρεσης τηλεφώνου' : 'Failed to remove phone';
      case 'auth/fill-all-fields':
        return isGreek ? 'Συμπλήρωσε όλα τα πεδία' : 'Fill all fields';
      case 'auth/reset-email-sent':
        return isGreek ? 'Στάλθηκε email επαναφοράς' : 'Reset email sent';
      case 'auth/invalid-phone-input':
        return isGreek ? 'Μη έγκυρη είσοδος τηλεφώνου' : 'Invalid phone input';
      case 'auth/enter-verification-code':
        return isGreek ? 'Εισάγετε τον κωδικό επαλήθευσης' : 'Enter verification code';
      case 'settings/screenshot-protection-on':
        return isGreek ? 'Η προστασία screenshot ενεργοποιήθηκε' : 'Screenshot protection enabled';
      case 'settings/screenshot-protection-off':
        return isGreek ? 'Η προστασία screenshot απενεργοποιήθηκε' : 'Screenshot protection disabled';
      case 'settings/no-biometric':
        return isGreek ? 'Δεν υπάρχει διαθέσιμο βιομετρικό' : 'No biometric available';
      case 'settings/biometric-lock-on':
        return isGreek ? 'Το βιομετρικό κλείδωμα ενεργοποιήθηκε' : 'Biometric lock enabled';
      case 'settings/biometric-lock-off':
        return isGreek ? 'Το βιομετρικό κλείδωμα απενεργοποιήθηκε' : 'Biometric lock disabled';
      case 'report/submitted':
        return isGreek ? 'Η αναφορά υποβλήθηκε' : 'Report submitted';
      case 'report/submit-failed':
        return isGreek ? 'Αποτυχία υποβολής αναφοράς' : 'Failed to submit report';
      case 'block/unblocked':
        return isGreek ? 'Ξεμπλοκαρίστηκε' : 'Unblocked';
      case 'block/blocked':
        return isGreek ? 'Μπλοκαρίστηκε' : 'Blocked';
      case 'search/saved-search-deleted':
        return isGreek ? 'Η αποθηκευμένη αναζήτηση διαγράφηκε' : 'Saved search deleted';
      case 'search/filters-saved':
        return isGreek ? 'Τα φίλτρα αποθηκεύτηκαν' : 'Filters saved';
      case 'request/accepted':
        return isGreek ? 'Το αίτημα έγινε αποδεκτό' : 'Request accepted';
      case 'request/declined':
        return isGreek ? 'Το αίτημα απορρίφθηκε' : 'Request declined';
      case 'request/respond-failed':
        return isGreek ? 'Αποτυχία απάντησης σε αίτημα' : 'Failed to respond to request';
      case 'request/failed':
        return isGreek ? 'Απέτυχε' : 'Failed';
      case 'request/sent':
        return isGreek ? 'Το αίτημα στάλθηκε' : 'Request sent';
      case 'request/some-deletes-failed':
        return isGreek ? 'Ορισμένα αιτήματα δεν διαγράφηκαν' : 'Some requests could not be deleted';
      case 'delete/account-deleted':
        return isGreek ? 'Ο λογαριασμός διαγράφηκε' : 'Account deleted';
      case 'location/service-disabled':
        return isGreek ? 'Η υπηρεσία τοποθεσίας είναι απενεργοποιημένη' : 'Location service is disabled';
      case 'location/permission-denied':
        return isGreek ? 'Δεν δόθηκε άδεια τοποθεσίας' : 'Location permission denied';
      case 'location/permission-denied-forever':
        return isGreek ? 'Η άδεια τοποθεσίας απορρίφθηκε μόνιμα. Άλλαξέ την από τις ρυθμίσεις.' : 'Location permission permanently denied. Change in settings.';
      case 'location/timeout':
        return isGreek ? 'Το αίτημα τοποθεσίας έληξε' : 'Location request timed out';
      case 'location/stale-data':
        return isGreek ? 'Παρωχημένα δεδομένα τοποθεσίας' : 'Stale location data';
      case 'location/error':
        return isGreek ? 'Σφάλμα τοποθεσίας. Δοκίμασε ξανά.' : 'Location error. Try again.';
      case 'gps/no-signal':
        return isGreek ? 'Χωρίς σήμα GPS' : 'No GPS signal';
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
