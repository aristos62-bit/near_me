import '../../../core/debug/debug_config.dart';

class AuditDetailFormatter {
  AuditDetailFormatter._();

  static String format({
    required String action,
    required Map<String, dynamic>? details,
    required bool greek,
  }) {
    if (details == null || details.isEmpty) return '';

    DebugConfig.log(DebugConfig.uiDetail,
        'AuditDetailFormatter: action=$action keys=${details.keys.join(",")} greek=$greek');

    final parts = <String>[];
    for (final entry in details.entries) {
      final label = _fieldLabel(entry.key, greek);
      final value = _fieldValue(entry.key, entry.value, greek);
      parts.add('$label: $value');
    }
    return parts.join(', ');
  }

  static const _fieldLabels = <String, ({String el, String en})>{
    'participantUids': (el: 'Συμμετέχοντες', en: 'Participants'),
    'oldRole': (el: 'Παλιός ρόλος', en: 'Previous role'),
    'newRole': (el: 'Νέος ρόλος', en: 'New role'),
    'permission': (el: 'Δικαίωμα', en: 'Permission'),
    'newValue': (el: 'Νέα τιμή', en: 'New value'),
    'oldMax': (el: 'Παλιό όριο', en: 'Previous limit'),
    'newMax': (el: 'Νέο όριο', en: 'New limit'),
  };

  static const _roleLabels = <String, ({String el, String en})>{
    'admin': (el: 'Διαχειριστής', en: 'Admin'),
    'member': (el: 'Μέλος', en: 'Member'),
    'creator': (el: 'Δημιουργός', en: 'Creator'),
  };

  static String auditActionLabel(String action, bool greek) {
    DebugConfig.log(DebugConfig.uiDetail,
        'AuditDetailFormatter.auditActionLabel: action=$action greek=$greek');
    final label = _actionLabels[action];
    if (label != null) return greek ? label.el : label.en;
    DebugConfig.warn('AuditDetailFormatter: unknown action=$action');
    return action;
  }

  static const _actionLabels = <String, ({String el, String en})>{
    'group_created': (el: 'Δημιουργία ομάδας', en: 'Group created'),
    'participant_added': (el: 'Προσθήκη μέλους', en: 'Member added'),
    'participant_removed': (el: 'Αφαίρεση μέλους', en: 'Member removed'),
    'participant_left': (el: 'Αποχώρηση μέλους', en: 'Member left'),
    'role_changed': (el: 'Αλλαγή ρόλου', en: 'Role changed'),
    'permission_changed': (el: 'Αλλαγή δικαιώματος', en: 'Permission changed'),
    'permission_overrides_reset': (el: 'Επαναφορά δικαιωμάτων', en: 'Permissions reset'),
    'group_deleted': (el: 'Διαγραφή ομάδας', en: 'Group deleted'),
    'max_participants_changed': (el: 'Αλλαγή ορίου μελών', en: 'Member limit changed'),
    'avatar_changed': (el: 'Αλλαγή φωτογραφίας', en: 'Avatar changed'),
    'public_join': (el: 'Συμμετοχή σε ομάδα', en: 'Joined group'),
  };

  static const _permissionLabels = <String, ({String el, String en})>{
    'inviteMembers': (el: 'Πρόσκληση μελών', en: 'Invite members'),
    'removeMembers': (el: 'Αφαίρεση μελών', en: 'Remove members'),
    'deleteMessages': (el: 'Διαγραφή μηνυμάτων', en: 'Delete messages'),
    'changeGroupName': (el: 'Αλλαγή ονόματος', en: 'Change name'),
    'changeGroupAvatar': (el: 'Αλλαγή φωτογραφίας', en: 'Change avatar'),
    'managePermissions': (el: 'Διαχείριση δικαιωμάτων', en: 'Manage permissions'),
    'manageAdmins': (el: 'Διαχείριση διαχειριστών', en: 'Manage admins'),
    'pinMessages': (el: 'Καρφίτσωμα μηνυμάτων', en: 'Pin messages'),
  };

  static String _fieldLabel(String key, bool greek) {
    final label = _fieldLabels[key];
    if (label != null) return greek ? label.el : label.en;
    DebugConfig.warn('AuditDetailFormatter: unknown key=$key');
    return key;
  }

  static String _fieldValue(String key, dynamic value, bool greek) {
    if (value == null) return '—';

    if (key == 'newRole' || key == 'oldRole') {
      final role = _roleLabels[value.toString()];
      if (role != null) return greek ? role.el : role.en;
    }

    if (key == 'permission') {
      final perm = _permissionLabels[value.toString()];
      if (perm != null) return greek ? perm.el : perm.en;
    }

    if (key == 'newValue') {
      if (value is bool) return greek ? (value ? 'Ναι' : 'Όχι') : (value ? 'Yes' : 'No');
    }

    if (key == 'participantUids' && value is List) {
      return value.length.toString();
    }

    return value.toString();
  }
}
