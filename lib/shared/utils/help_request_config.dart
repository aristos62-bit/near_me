import '../../core/debug/debug_config.dart';
import '../models/public_profile.dart';

/// SPoT για το SOS / Επείγουσα Βοήθεια (sos.md).
/// Κεντρικός ορισμός TTL, radius options, maxLength και eligibility check —
/// ό,τι χρειάζεται το [help_request_sheet] και το [search_provider].
class HelpRequestConfig {
  HelpRequestConfig._();

  /// Αυτόματος τερματισμός ενός ενεργού SOS μετά από 60 λεπτά (§5.4).
  static const Duration ttl = Duration(minutes: 60);

  /// Επιλογές ακτίνας που προσφέρονται στον αιτούντα (§5.2, απόφαση #4).
  static const List<double> radiusOptions = [5, 10, 25, 50];

  /// Προεπιλεγμένη ακτίνα όταν δεν έχει επιλεχθεί άλλη.
  static const double defaultRadiusKm = 10.0;

  /// Μέγιστο μήκος μηνύματος (απόφαση #5) — ταιριάζει με το validation rule §9.2.
  static const int maxMessageLength = 80;

  /// Έλεγχος αν ο αιτών πληροί τις προϋποθέσεις για SOS (§5.2).
  /// Όλες οι πηγές είναι πραγματικές:
  /// - canComm: AuthRepository.canUserCommunicate(user)
  /// - isPublished: profile.isPublished (Drift)
  /// - hasGps: profile.latitudeExact != null
  /// - hasChannel: από το δημοσιευμένο PublicProfile (ΟΧΙ local toggles)
  /// - hasVisibleLocation: published geoHash != null (Β3)
  static bool canRequestHelp({
    required bool canComm,
    required bool isPublished,
    required bool hasGps,
    required bool hasChannel,
    required bool hasVisibleLocation,
  }) {
    final ok = canComm &&
        isPublished &&
        hasGps &&
        hasChannel &&
        hasVisibleLocation;
    if (!ok) {
      DebugConfig.log(DebugConfig.helpRequest,
          'canRequestHelp: BLOCKED canComm=$canComm isPublished=$isPublished '
          'hasGps=$hasGps hasChannel=$hasChannel hasVisibleLocation=$hasVisibleLocation');
    }
    return ok;
  }

  /// Επιστρέφει ποιες προϋποθέσεις λείπουν — για τη λίστα «Τι χρειάζεται
  /// για να ζητήσεις βοήθεια» (§5.2 Βήμα 1). Keys:
  /// verify / publish / gps / channel / visibleLocation.
  static List<String> missingRequirements({
    required bool canComm,
    required bool isPublished,
    required bool hasGps,
    required bool hasChannel,
    required bool hasVisibleLocation,
  }) {
    final missing = <String>[];
    if (!canComm) missing.add('verify');
    if (!isPublished) missing.add('publish');
    if (!hasGps) missing.add('gps');
    if (!hasChannel) missing.add('channel');
    if (!hasVisibleLocation) missing.add('visibleLocation');
    if (missing.isNotEmpty) {
      DebugConfig.log(DebugConfig.helpRequest,
          'missingRequirements: ${missing.join(", ")}');
    }
    return missing;
  }

  /// Έλεγχος αν ένας δημοσιευμένος βοηθός έχει ανοιχτό κανάλι επικοινωνίας.
  /// Διαβάζεται από το ήδη δημοσιευμένο PublicProfile (ό,τι βλέπουν πραγματικά
  /// οι βοηθοί) — ΟΧΙ από τα local privacy toggles (Εύρημα #3 / sos.md §5.2).
  static bool hasChannel(PublicProfile? pub) {
    if (pub == null) return false;
    return pub.allowDirectChat == true ||
        pub.allowVideoCall == true ||
        (pub.email != null && pub.email!.isNotEmpty) ||
        (pub.phone != null && pub.phone!.isNotEmpty);
  }

  /// Έλεγχος αν ένα ενεργό SOS είναι ακόμα εντός TTL (§5.4 / §6.1).
  /// Fail-safe: null updatedAt ή inactive → false (sos.md §9 «updatedAt null»).
  static bool isActiveWithinTtl(HelpRequest? h, DateTime now) {
    if (h == null || !h.active || h.updatedAt == null) return false;
    return now.difference(h.updatedAt!) <= ttl;
  }

  /// Ενεργό SOS εντός TTL ΚΑΙ εντός της ακτίνας του αιτούντος από τον βοηθό.
  static bool isUrgentForDistance(
      HelpRequest? h, double? distanceKm, DateTime now) {
    if (h == null || !h.active || h.updatedAt == null) return false;
    if (distanceKm == null) return false;
    return now.difference(h.updatedAt!) <= ttl && distanceKm <= h.radiusKm;
  }
}