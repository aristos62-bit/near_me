import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/l10n/l10n.dart';

void main() {
  group('inviteInvitationMessage', () {
    test('GR: περιέχει groupName + token + οδηγίες Συνομιλιών', () {
      final msg = L10n.inviteInvitationMessage(
        groupName: 'Παρέα',
        token: 'abc123',
        isGreek: true,
      );
      expect(msg, contains('"Παρέα"'));
      expect(msg, contains('abc123'));
      expect(msg, contains('Συνομιλιών'));
      expect(msg, contains('κλειδί'));
    });

    test('EN: περιέχει groupName + token + οδηγίες Chats page', () {
      final msg = L10n.inviteInvitationMessage(
        groupName: 'Friends',
        token: 'abc123',
        isGreek: false,
      );
      expect(msg, contains('"Friends"'));
      expect(msg, contains('abc123'));
      expect(msg, contains('Chats page'));
      expect(msg, contains('key at the top'));
    });

    test('GR: κενό groupName → generic "μια ομάδα", όχι κενά quotes', () {
      final msg = L10n.inviteInvitationMessage(
        groupName: '',
        token: 'abc123',
        isGreek: true,
      );
      expect(msg, contains('μια ομάδα'));
      expect(msg, isNot(contains('""')));
    });

    test('EN: κενό groupName → generic "a group", όχι κενά quotes', () {
      final msg = L10n.inviteInvitationMessage(
        groupName: '',
        token: 'abc123',
        isGreek: false,
      );
      expect(msg, contains('a group'));
      expect(msg, isNot(contains('""')));
    });
  });
}