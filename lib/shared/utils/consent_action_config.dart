import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ConsentActionInfo {
  final IconData icon;
  final IconData outlinedIcon;
  final Color color;
  final String enLabel;
  final String elLabel;

  const ConsentActionInfo({
    required this.icon,
    required this.outlinedIcon,
    required this.color,
    required this.enLabel,
    required this.elLabel,
  });
}

class ConsentActionConfig {
  ConsentActionConfig._();

  static const Map<String, ConsentActionInfo> actions = {
    'published': ConsentActionInfo(
      icon: Icons.cloud_upload,
      outlinedIcon: Icons.cloud_upload_outlined,
      color: AppColors.primary,
      enLabel: 'Published profile',
      elLabel: 'Δημοσίευση προφίλ',
    ),
    'unpublished': ConsentActionInfo(
      icon: Icons.cloud_off,
      outlinedIcon: Icons.cloud_off_outlined,
      color: AppColors.warning,
      enLabel: 'Unpublished profile',
      elLabel: 'Απόσυρση προφίλ',
    ),
    'shared_location': ConsentActionInfo(
      icon: Icons.location_on,
      outlinedIcon: Icons.location_on_outlined,
      color: Colors.blue,
      enLabel: 'Shared location',
      elLabel: 'Κοινοποίηση τοποθεσίας',
    ),
    'uploaded_photo': ConsentActionInfo(
      icon: Icons.photo,
      outlinedIcon: Icons.photo_outlined,
      color: Colors.purple,
      enLabel: 'Uploaded photo',
      elLabel: 'Ανέβασμα φωτογραφίας',
    ),
    'deleted_account': ConsentActionInfo(
      icon: Icons.delete_forever,
      outlinedIcon: Icons.delete_forever_outlined,
      color: AppColors.error,
      enLabel: 'Deleted account',
      elLabel: 'Διαγραφή λογαριασμού',
    ),
    'sent_request': ConsentActionInfo(
      icon: Icons.send,
      outlinedIcon: Icons.send_outlined,
      color: Colors.teal,
      enLabel: 'Sent a request',
      elLabel: 'Αποστολή αιτήματος',
    ),
    'accepted_request': ConsentActionInfo(
      icon: Icons.check_circle,
      outlinedIcon: Icons.check_circle_outline,
      color: Colors.green,
      enLabel: 'Accepted request',
      elLabel: 'Αποδοχή αιτήματος',
    ),
    'publish': ConsentActionInfo(
      icon: Icons.cloud_upload,
      outlinedIcon: Icons.cloud_upload_outlined,
      color: AppColors.primary,
      enLabel: 'Publish',
      elLabel: 'Δημοσίευση',
    ),
    'unpublish': ConsentActionInfo(
      icon: Icons.cloud_off,
      outlinedIcon: Icons.cloud_off_outlined,
      color: AppColors.warning,
      enLabel: 'Unpublish',
      elLabel: 'Απόσυρση',
    ),
    'group_created': ConsentActionInfo(
      icon: Icons.group_add,
      outlinedIcon: Icons.group_add_outlined,
      color: Colors.indigo,
      enLabel: 'Created a group',
      elLabel: 'Δημιουργία ομάδας',
    ),
    'group_joined': ConsentActionInfo(
      icon: Icons.login,
      outlinedIcon: Icons.login_outlined,
      color: Colors.teal,
      enLabel: 'Joined a group',
      elLabel: 'Εγγραφή σε ομάδα',
    ),
    'group_left': ConsentActionInfo(
      icon: Icons.exit_to_app,
      outlinedIcon: Icons.exit_to_app_outlined,
      color: AppColors.warning,
      enLabel: 'Left a group',
      elLabel: 'Αποχώρηση από ομάδα',
    ),
    'group_member_added': ConsentActionInfo(
      icon: Icons.person_add,
      outlinedIcon: Icons.person_add_outlined,
      color: Colors.green,
      enLabel: 'Added a member',
      elLabel: 'Προσθήκη μέλους',
    ),
  };

  static ConsentActionInfo? get(String action) => actions[action];

  static IconData icon(String action, {bool outlined = false}) {
    final info = actions[action];
    if (info == null) return Icons.info_outline;
    return outlined ? info.outlinedIcon : info.icon;
  }

  static Color color(String action) {
    return actions[action]?.color ?? Colors.grey;
  }

  static String label(String action, bool isGreek) {
    final info = actions[action];
    if (info == null) return action;
    return isGreek ? info.elLabel : info.enLabel;
  }
}
