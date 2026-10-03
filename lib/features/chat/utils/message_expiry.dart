/// Single Point of Truth για τις τιμές αυτόματης διαγραφής μηνυμάτων (P3.2).
///
/// Ενοποιεί τα 6 σημεία duplication (group/1-1 guards, duration switch,
/// 2 dropdown blocks, banner display). Pure Dart — μηδέν flutter imports,
/// ίδιο pattern με το `SystemMessageFormatter`.
class MessageExpiry {
  const MessageExpiry._();

  static const String off = 'off';

  /// Κλειδωμένη σειρά εμφάνισης (χρησιμοποιείται και στα dropdowns).
  static const List<String> values = [
    'off',
    '1min',
    '5min',
    '30min',
    '6h',
    '12h',
    '24h',
  ];

  static bool isValid(String value) => values.contains(value);

  /// Διάρκεια για `expiresAt` — `null` για `off`/άγνωστες (όπως πριν).
  static Duration? durationFor(String value) {
    return switch (value) {
      '1min' => const Duration(minutes: 1),
      '5min' => const Duration(minutes: 5),
      '30min' => const Duration(minutes: 30),
      '6h' => const Duration(hours: 6),
      '12h' => const Duration(hours: 12),
      '24h' => const Duration(hours: 24),
      _ => null,
    };
  }

  /// Bilingual label (`''` για άγνωστες, όπως πριν).
  static String display(String value, {required bool greek}) {
    return switch (value) {
      '1min' => greek ? '1 λεπτό' : '1 minute',
      '5min' => greek ? '5 λεπτά' : '5 minutes',
      '30min' => greek ? '30 λεπτά' : '30 minutes',
      '6h' => greek ? '6 ώρες' : '6 hours',
      '12h' => greek ? '12 ώρες' : '12 hours',
      '24h' => greek ? '24 ώρες' : '24 hours',
      _ => '',
    };
  }
}
