import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class L10n {
  L10n._();

  static const List<Locale> supported = [Locale('el'), Locale('en')];
  static const Locale fallback = Locale('en');

  static bool isGreek(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'el';
  }

  static Locale? deviceLocale() {
    final locale = PlatformDispatcher.instance.locale;
    for (final supported in supported) {
      if (supported.languageCode == locale.languageCode) {
        return supported;
      }
    }
    return fallback;
  }

  static bool is24HourFormat(BuildContext context) {
    return MediaQuery.of(context).alwaysUse24HourFormat;
  }

  static String formatTimeOfDay(BuildContext context, TimeOfDay time) {
    if (is24HourFormat(context)) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return time.format(context);
  }

  static String formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat.yMd(locale).format(date);
  }

  static String formatDateTime(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat.yMMMd(locale).add_jm().format(date);
  }

  static String formatNumber(BuildContext context, num value) {
    final locale = Localizations.localeOf(context).languageCode;
    return NumberFormat.decimalPattern(locale).format(value);
  }

  static String distanceText(double km, {required bool metric}) {
    if (metric) {
      if (km < 1) return '${(km * 1000).round()} m';
      return '${km.toStringAsFixed(1)} km';
    }
    final miles = km * 0.621371;
    if (miles < 0.1) return '${(miles * 5280).round()} ft';
    return '${miles.toStringAsFixed(1)} mi';
  }

  static TemperatureUnit temperatureUnit(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'el' ? TemperatureUnit.celsius : TemperatureUnit.fahrenheit;
  }

  static String genderLabel(String gender, {required bool isGreek}) {
    switch (gender) {
      case 'male': return isGreek ? 'Άνδρας' : 'Male';
      case 'female': return isGreek ? 'Γυναίκα' : 'Female';
      case 'other': return isGreek ? 'Άλλο' : 'Other';
      case 'prefer_not': return isGreek ? 'Δεν επιθυμώ' : 'Prefer not to say';
      default: return gender;
    }
  }

  static String lookingForLabel(String key, {required bool isGreek}) {
    if (isGreek) {
      switch (key) {
        case 'roommate': return 'Συγκάτοικο';
        case 'social': return 'Παρέα';
        case 'friendship': return 'Φιλία';
        case 'networking': return 'Δικτύωση';
        case 'exchange': return 'Ανταλλαγή';
        case 'help': return 'Βοήθεια';
        case 'employment': return 'Απασχόληση';
      }
    } else {
      switch (key) {
        case 'roommate': return 'Roommate';
        case 'social': return 'Social';
        case 'friendship': return 'Friendship';
        case 'networking': return 'Networking';
        case 'exchange': return 'Exchange';
        case 'help': return 'Help';
        case 'employment': return 'Employment';
      }
    }
    return key;
  }

  static String reportReasonLabel(String reason, {required bool isGreek}) {
    if (isGreek) {
      switch (reason) {
        case 'spam': return 'Ανεπιθύμητη επικοινωνία (Spam)';
        case 'harassment': return 'Παρενόχληση';
        case 'fake_profile': return 'Ψεύτικο προφίλ';
        case 'inappropriate': return 'Ακατάλληλο περιεχόμενο';
        case 'other': return 'Άλλος λόγος';
        default: return reason;
      }
    }
    switch (reason) {
      case 'spam': return 'Spam';
      case 'harassment': return 'Harassment';
      case 'fake_profile': return 'Fake Profile';
      case 'inappropriate': return 'Inappropriate Content';
      case 'other': return 'Other';
      default: return reason;
    }
  }

  static List<String> reportReasons() {
    return ['spam', 'harassment', 'fake_profile', 'inappropriate', 'other'];
  }

  static String interestLabel(String key, {required bool isGreek}) {
    if (isGreek) {
      switch (key) {
        case 'gamer': return 'Gaming';
        case 'programmer': return 'Προγραμματισμός';
        case 'student': return 'Φοιτητής';
        case 'traveler': return 'Ταξίδια';
        case 'reader': return 'Διάβασμα';
        case 'photographer': return 'Φωτογραφία';
        case 'fashion': return 'Μόδα';
        case 'music': return 'Μουσική';
        case 'sports': return 'Αθλητισμός';
        case 'art': return 'Τέχνη';
        case 'cooking': return 'Μαγειρική';
        case 'movies': return 'Ταινίες';
        case 'nature': return 'Φύση';
        case 'pets': return 'Κατοικίδια';
        case 'volunteer': return 'Εθελοντισμός';
      }
    } else {
      switch (key) {
        case 'gamer': return 'Gaming';
        case 'programmer': return 'Programming';
        case 'student': return 'Student';
        case 'traveler': return 'Travel';
        case 'reader': return 'Reading';
        case 'photographer': return 'Photography';
        case 'fashion': return 'Fashion';
        case 'music': return 'Music';
        case 'sports': return 'Sports';
        case 'art': return 'Art';
        case 'cooking': return 'Cooking';
        case 'movies': return 'Movies';
        case 'nature': return 'Nature';
        case 'pets': return 'Pets';
        case 'volunteer': return 'Volunteer';
      }
    }
    return key;
  }

  static String onlineLabel(bool isOnline, {required bool isGreek}) {
    if (isOnline) return isGreek ? 'Σε σύνδεση' : 'Online';
    return isGreek ? 'Εκτός σύνδεσης' : 'Offline';
  }

  /// Splits a "ελληνικά / english" bilingual string and returns the locale-appropriate part.
  /// Returns the phone country dial code based on device locale (e.g. GR → +30, US → +1).
  static String phoneCountryCode() {
    final country = PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';
    switch (country) {
      case 'GR': return '+30';
      case 'US': return '+1';
      case 'GB': return '+44';
      case 'AU': return '+61';
      case 'CA': return '+1';
      case 'DE': return '+49';
      case 'FR': return '+33';
      case 'IT': return '+39';
      case 'ES': return '+34';
      case 'NL': return '+31';
      case 'BE': return '+32';
      case 'SE': return '+46';
      case 'NO': return '+47';
      case 'DK': return '+45';
      case 'FI': return '+358';
      case 'AT': return '+43';
      case 'CH': return '+41';
      case 'PT': return '+351';
      case 'IE': return '+353';
      case 'PL': return '+48';
      case 'CZ': return '+420';
      case 'HU': return '+36';
      case 'RO': return '+40';
      case 'BG': return '+359';
      case 'RU': return '+7';
      case 'CN': return '+86';
      case 'JP': return '+81';
      case 'KR': return '+82';
      case 'IN': return '+91';
      case 'BR': return '+55';
      case 'MX': return '+52';
      case 'TR': return '+90';
      case 'CY': return '+357';
      case 'AL': return '+355';
      default: return '+30'; // fallback Greek
    }
  }

  static String localizedMessage(BuildContext context, String bilingual) {
    final sep = ' / ';
    final idx = bilingual.indexOf(sep);
    if (idx == -1) return bilingual;
    return isGreek(context) ? bilingual.substring(0, idx) : bilingual.substring(idx + sep.length);
  }
}

enum TemperatureUnit { celsius, fahrenheit }
