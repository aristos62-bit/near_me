import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/utils/audit_detail_formatter.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('AuditDetailFormatter.format', () {
    testWidgets('returns empty string for null details', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'group_created',
        details: null,
        greek: false,
      );
      expect(result, '');
      await _settle(tester);
    });

    testWidgets('returns empty string for empty details', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'group_created',
        details: <String, dynamic>{},
        greek: false,
      );
      expect(result, '');
      await _settle(tester);
    });

    testWidgets('formats role_changed with known keys (English)', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'role_changed',
        details: {'oldRole': 'member', 'newRole': 'admin'},
        greek: false,
      );
      expect(result, contains('Previous role: Member'));
      expect(result, contains('New role: Admin'));
      await _settle(tester);
    });

    testWidgets('formats role_changed with known keys (Greek)', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'role_changed',
        details: {'oldRole': 'member', 'newRole': 'admin'},
        greek: true,
      );
      expect(result, contains('Παλιός ρόλος: Μέλος'));
      expect(result, contains('Νέος ρόλος: Διαχειριστής'));
      await _settle(tester);
    });

    testWidgets('formats permission field (English)', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'permission_changed',
        details: {'permission': 'inviteMembers'},
        greek: false,
      );
      expect(result, 'Permission: Invite members');
      await _settle(tester);
    });

    testWidgets('formats permission field (Greek)', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'permission_changed',
        details: {'permission': 'pinMessages'},
        greek: true,
      );
      expect(result, 'Δικαίωμα: Καρφίτσωμα μηνυμάτων');
      await _settle(tester);
    });

    testWidgets('formats newValue as bool (English)', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'permission_changed',
        details: {'newValue': true},
        greek: false,
      );
      expect(result, 'New value: Yes');
      await _settle(tester);
    });

    testWidgets('formats newValue as bool (Greek)', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'permission_changed',
        details: {'newValue': false},
        greek: true,
      );
      expect(result, 'Νέα τιμή: Όχι');
      await _settle(tester);
    });

    testWidgets('formats participantUids as count', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'participant_added',
        details: {'participantUids': ['a', 'b', 'c']},
        greek: false,
      );
      expect(result, 'Participants: 3');
      await _settle(tester);
    });

    testWidgets('returns dash for null value', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'role_changed',
        details: {'oldRole': null},
        greek: false,
      );
      expect(result, contains('—'));
      await _settle(tester);
    });

    testWidgets('passes through unknown keys as-is', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'group_created',
        details: {'unknownField': 'hello'},
        greek: false,
      );
      expect(result, 'unknownField: hello');
      await _settle(tester);
    });

    testWidgets('formats multiple entries joined by comma', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'role_changed',
        details: {'oldRole': 'member', 'newRole': 'admin'},
        greek: false,
      );
      expect(result, contains(', '));
      await _settle(tester);
    });

    testWidgets('formats newMax/oldMax fields', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'max_participants_changed',
        details: {'oldMax': 10, 'newMax': 25},
        greek: false,
      );
      expect(result, contains('Previous limit: 10'));
      expect(result, contains('New limit: 25'));
      await _settle(tester);
    });
  });

  group('AuditDetailFormatter.auditActionLabel', () {
    testWidgets('returns Greek label for known action', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('group_created', true),
        'Δημιουργία ομάδας',
      );
      await _settle(tester);
    });

    testWidgets('returns English label for known action', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('group_created', false),
        'Group created',
      );
      await _settle(tester);
    });

    testWidgets('returns raw action for unknown action', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('weird_action', true),
        'weird_action',
      );
      await _settle(tester);
    });

    testWidgets('covers participant_added label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('participant_added', false),
        'Member added',
      );
      await _settle(tester);
    });

    testWidgets('covers participant_removed label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('participant_removed', true),
        'Αφαίρεση μέλους',
      );
      await _settle(tester);
    });

    testWidgets('covers participant_left label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('participant_left', false),
        'Member left',
      );
      await _settle(tester);
    });

    testWidgets('covers role_changed label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('role_changed', true),
        'Αλλαγή ρόλου',
      );
      await _settle(tester);
    });

    testWidgets('covers permission_changed label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('permission_changed', false),
        'Permission changed',
      );
      await _settle(tester);
    });

    testWidgets('covers permission_overrides_reset label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('permission_overrides_reset', true),
        'Επαναφορά δικαιωμάτων',
      );
      await _settle(tester);
    });

    testWidgets('covers group_deleted label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('group_deleted', false),
        'Group deleted',
      );
      await _settle(tester);
    });

    testWidgets('covers max_participants_changed label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('max_participants_changed', true),
        'Αλλαγή ορίου μελών',
      );
      await _settle(tester);
    });

    testWidgets('covers avatar_changed label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('avatar_changed', false),
        'Avatar changed',
      );
      await _settle(tester);
    });

    testWidgets('covers public_join label', (tester) async {
      expect(
        AuditDetailFormatter.auditActionLabel('public_join', true),
        'Συμμετοχή σε ομάδα',
      );
      await _settle(tester);
    });
  });

  group('AuditDetailFormatter.format edge cases', () {
    testWidgets('handles role with no matching label', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'role_changed',
        details: {'newRole': 'superadmin'},
        greek: false,
      );
      expect(result, 'New role: superadmin');
      await _settle(tester);
    });

    testWidgets('handles permission with no matching label', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'permission_changed',
        details: {'permission': 'unknownPerm'},
        greek: false,
      );
      expect(result, 'Permission: unknownPerm');
      await _settle(tester);
    });

    testWidgets('handles newValue as non-bool string', (tester) async {
      final result = AuditDetailFormatter.format(
        action: 'permission_changed',
        details: {'newValue': 'custom_value'},
        greek: false,
      );
      expect(result, 'New value: custom_value');
      await _settle(tester);
    });
  });
}