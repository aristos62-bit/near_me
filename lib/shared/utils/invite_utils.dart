/// SPoT για εξαγωγή/επικύρωση κωδικού πρόσκλησης ομάδας.
///
/// Tokens δημιουργούνται από `Uuid().v4().replaceAll('-', '')` → 32 lowercase
/// hex (`GroupChatMixin.createInviteLink`). Αυτό το utility κάνει tolerant
/// extraction (URL `?token=...`, whitespace, πρώτη λέξη) + strict pre-validation
/// ΠΡΙΝ από οποιαδήποτε κλήση CF (αποτρέπει άκυρα requests).
class InviteUtils {
  InviteUtils._();

  static final RegExp _tokenPattern = RegExp(r'^[0-9a-f]{32}$');

  /// Εξάγει έγκυρο token (32 lowercase hex) ή επιστρέφει null για μη έγκυρο.
  ///
  /// Αν το input είναι URL με παράμετρο `token`, την εξάγει. Αλλιώς (για
  /// clipboard paste με whitespace) παίρνει την πρώτη λέξη.
  static String? extractInviteToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final q = uri.queryParameters['token'];
      if (q != null && q.isNotEmpty) {
        return _tokenPattern.hasMatch(q) ? q : null;
      }
    }

    final firstWord = trimmed.split(RegExp(r'\s+')).first.trim();
    return _tokenPattern.hasMatch(firstWord) ? firstWord : null;
  }

  static final RegExp _tokenInText = RegExp(r'[0-9a-f]{32}');

  /// Ανιχνεύει invite token (32 lowercase hex) οπουδήποτε στο κείμενο —
  /// π.χ. μέσα στο invite μήνυμα που στάλθηκε/προωθήθηκε σε chat.
  /// Επιστρέφει το token ή null αν δεν υπάρχει.
  static String? findInviteTokenInText(String text) =>
      _tokenInText.firstMatch(text)?.group(0);
}