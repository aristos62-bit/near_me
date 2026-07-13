class SystemMessageFormatter {
  SystemMessageFormatter._();

  static ({String el, String en}) format({
    required String action,
    required String actorNickname,
    List<String> targetNicknames = const [],
    String? groupName,
    Map<String, String>? extra,
  }) {
    String el, en;

    switch (action) {
      case 'group_created':
        el = '$actorNickname δημιούργησε την ομάδα';
        en = '$actorNickname created the group';
        break;

      case 'participant_added':
        final isSelfJoin = targetNicknames.length == 1 && targetNicknames[0] == actorNickname;
        if (isSelfJoin) {
          el = '$actorNickname εντάχθηκε στην ομάδα';
          en = '$actorNickname joined the group';
        } else {
          final target = targetNicknames.isNotEmpty ? targetNicknames[0] : '';
          el = '$actorNickname πρόσθεσε τον/την $target';
          en = '$actorNickname added $target';
        }
        break;

      case 'participant_removed':
        final target = targetNicknames.isNotEmpty ? targetNicknames[0] : '';
        el = '$actorNickname αφαίρεσε τον/την $target';
        en = '$actorNickname removed $target';
        break;

      case 'participant_left':
        el = '$actorNickname αποχώρησε';
        en = '$actorNickname left';
        break;

      case 'name_changed':
        final newName = extra?['newName'] ?? (targetNicknames.isNotEmpty ? targetNicknames[0] : '');
        el = '$actorNickname άλλαξε το όνομα σε $newName';
        en = '$actorNickname changed name to $newName';
        break;

      case 'role_changed':
        final target = targetNicknames.isNotEmpty ? targetNicknames[0] : '';
        final newRole = targetNicknames.length > 1 ? targetNicknames[1] : extra?['newRole'] ?? 'member';
        if (newRole == 'admin') {
          el = '$actorNickname όρισε τον/την $target ως Διαχειριστή';
          en = '$actorNickname set $target as Admin';
        } else {
          el = '$actorNickname όρισε τον/την $target ως Μέλος';
          en = '$actorNickname set $target as Member';
        }
        break;

      case 'group_deleted':
        el = '$actorNickname διέγραψε την ομάδα';
        en = '$actorNickname deleted the group';
        break;

      case 'avatar_changed':
        el = '$actorNickname άλλαξε τη φωτογραφία';
        en = '$actorNickname changed the avatar';
        break;

      case 'avatar_removed':
        el = '$actorNickname αφαίρεσε τη φωτογραφία';
        en = '$actorNickname removed the avatar';
        break;

      case 'max_participants_changed':
        final newMax = targetNicknames.isNotEmpty ? targetNicknames[0] : '';
        el = '$actorNickname άλλαξε το όριο μελών σε $newMax';
        en = '$actorNickname changed member limit to $newMax';
        break;

      case 'permission_changed':
        final target = targetNicknames.isNotEmpty ? targetNicknames[0] : '';
        final permName = targetNicknames.length > 1 ? targetNicknames[1] : '';
        final permAction = targetNicknames.length > 2 ? targetNicknames[2] : '';
        if (permAction == 'granted') {
          el = '$actorNickname έδωσε δικαίωμα $permName στον/στην $target';
          en = '$actorNickname granted $permName permission to $target';
        } else {
          el = '$actorNickname αφαίρεσε δικαίωμα $permName από τον/την $target';
          en = '$actorNickname revoked $permName permission from $target';
        }
        break;

      case 'permission_overrides_reset':
        final resetTarget = targetNicknames.isNotEmpty ? targetNicknames[0] : '';
        el = '$actorNickname επανέφερε τα δικαιώματα για τον/την $resetTarget';
        en = '$actorNickname reset permissions for $resetTarget';
        break;

      default:
        el = action;
        en = action;
    }

    if (groupName != null && groupName.isNotEmpty) {
      el = '$groupName: $el';
      en = '$groupName: $en';
    }

    return (el: el, en: en);
  }
}
