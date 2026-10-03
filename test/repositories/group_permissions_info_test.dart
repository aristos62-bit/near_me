import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/repositories/chat_repository.dart';

/// Καθαρός πίνακας `GroupPermissionsInfo.hasPermission` (zero deps).
/// Κανόνες (chat_repository.dart:27-39): overrides κερδίζουν πάντα ·
/// creator όλα · admin όλα εκτός manageAdmins/managePermissions · member τίποτα.
void main() {
  const all = GroupPermission.values;

  group('GroupPermissionsInfo creator', () {
    test('creator → όλα true', () {
      const info = GroupPermissionsInfo(
          roles: {'u1': 'creator'}, overrides: {});
      for (final p in all) {
        expect(info.hasPermission('u1', p), isTrue, reason: p.name);
      }
    });
  });

  group('GroupPermissionsInfo admin', () {
    const info = GroupPermissionsInfo(
        roles: {'u1': 'admin'}, overrides: {});

    test('κοινά δικαιώματα → true', () {
      expect(info.hasPermission('u1', GroupPermission.inviteMembers), isTrue);
      expect(info.hasPermission('u1', GroupPermission.removeMembers), isTrue);
      expect(info.hasPermission('u1', GroupPermission.deleteMessages), isTrue);
      expect(info.hasPermission('u1', GroupPermission.changeGroupName), isTrue);
    });

    test('manageAdmins/managePermissions → false', () {
      expect(info.hasPermission('u1', GroupPermission.manageAdmins), isFalse);
      expect(
          info.hasPermission('u1', GroupPermission.managePermissions), isFalse);
    });
  });

  group('GroupPermissionsInfo member/unknown', () {
    test('member → όλα false', () {
      const info =
          GroupPermissionsInfo(roles: {'u1': 'member'}, overrides: {});
      for (final p in all) {
        expect(info.hasPermission('u1', p), isFalse, reason: p.name);
      }
    });

    test('άγνωστος uid → member-fallback false', () {
      const info = GroupPermissionsInfo(roles: {}, overrides: {});
      expect(info.hasPermission('ghost', GroupPermission.inviteMembers),
          isFalse);
    });
  });

  group('GroupPermissionsInfo overrides', () {
    test('grant σε member → true', () {
      const info = GroupPermissionsInfo(
        roles: {'u1': 'member'},
        overrides: {
          'u1': {'inviteMembers': true}
        },
      );
      expect(info.hasPermission('u1', GroupPermission.inviteMembers), isTrue);
      expect(info.hasPermission('u1', GroupPermission.removeMembers), isFalse);
    });

    test('revoke σε admin → false', () {
      const info = GroupPermissionsInfo(
        roles: {'u1': 'admin'},
        overrides: {
          'u1': {'inviteMembers': false}
        },
      );
      expect(info.hasPermission('u1', GroupPermission.inviteMembers), isFalse);
      expect(info.hasPermission('u1', GroupPermission.removeMembers), isTrue);
    });

    test('override άλλου uid δεν επηρεάζει', () {
      const info = GroupPermissionsInfo(
        roles: {'u1': 'member'},
        overrides: {
          'u2': {'inviteMembers': true}
        },
      );
      expect(info.hasPermission('u1', GroupPermission.inviteMembers), isFalse);
    });
  });
}
