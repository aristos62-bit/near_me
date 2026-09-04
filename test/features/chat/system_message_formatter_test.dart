import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/utils/system_message_formatter.dart';

void main() {
  group('SystemMessageFormatter.format — bilingual', () {
    test('group_created', () {
      final r = SystemMessageFormatter.format(
          action: 'group_created', actorNickname: 'Νίκος');
      expect(r.el, 'Νίκος δημιούργησε την ομάδα');
      expect(r.en, 'Νίκος created the group');
    });

    test('group_deleted', () {
      final r = SystemMessageFormatter.format(
          action: 'group_deleted', actorNickname: 'Μαρία');
      expect(r.el, 'Μαρία διέγραψε την ομάδα');
      expect(r.en, 'Μαρία deleted the group');
    });

    test('participant_added by another member', () {
      final r = SystemMessageFormatter.format(
          action: 'participant_added',
          actorNickname: 'Νίκος',
          targetNicknames: ['Γιώργος']);
      expect(r.el, 'Νίκος πρόσθεσε τον/την Γιώργος');
      expect(r.en, 'Νίκος added Γιώργος');
    });

    test('participant_added self-join', () {
      final r = SystemMessageFormatter.format(
          action: 'participant_added',
          actorNickname: 'Άννα',
          targetNicknames: ['Άννα']);
      expect(r.el, 'Άννα εντάχθηκε στην ομάδα');
      expect(r.en, 'Άννα joined the group');
    });

    test('participant_removed', () {
      final r = SystemMessageFormatter.format(
          action: 'participant_removed',
          actorNickname: 'Νίκος',
          targetNicknames: ['Πέτρος']);
      expect(r.el, 'Νίκος αφαίρεσε τον/την Πέτρος');
      expect(r.en, 'Νίκος removed Πέτρος');
    });

    test('participant_left', () {
      final r = SystemMessageFormatter.format(
          action: 'participant_left', actorNickname: 'Σοφία');
      expect(r.el, 'Σοφία αποχώρησε');
      expect(r.en, 'Σοφία left');
    });

    test('name_changed', () {
      final r = SystemMessageFormatter.format(
          action: 'name_changed',
          actorNickname: 'Νίκος',
          targetNicknames: ['Ομάδα Α']);
      expect(r.el, 'Νίκος άλλαξε το όνομα σε Ομάδα Α');
      expect(r.en, 'Νίκος changed name to Ομάδα Α');
    });

    test('role_changed to admin', () {
      final r = SystemMessageFormatter.format(
          action: 'role_changed',
          actorNickname: 'Νίκος',
          targetNicknames: ['Γιώργος', 'admin']);
      expect(r.el, 'Νίκος όρισε τον/την Γιώργος ως Διαχειριστή');
      expect(r.en, 'Νίκος set Γιώργος as Admin');
    });

    test('role_changed to member', () {
      final r = SystemMessageFormatter.format(
          action: 'role_changed',
          actorNickname: 'Νίκος',
          targetNicknames: ['Γιώργος', 'member']);
      expect(r.el, 'Νίκος όρισε τον/την Γιώργος ως Μέλος');
      expect(r.en, 'Νίκος set Γιώργος as Member');
    });

    test('avatar_changed', () {
      final r = SystemMessageFormatter.format(
          action: 'avatar_changed', actorNickname: 'Μαρία');
      expect(r.el, 'Μαρία άλλαξε τη φωτογραφία');
      expect(r.en, 'Μαρία changed the avatar');
    });

    test('avatar_removed', () {
      final r = SystemMessageFormatter.format(
          action: 'avatar_removed', actorNickname: 'Μαρία');
      expect(r.el, 'Μαρία αφαίρεσε τη φωτογραφία');
      expect(r.en, 'Μαρία removed the avatar');
    });

    test('max_participants_changed', () {
      final r = SystemMessageFormatter.format(
          action: 'max_participants_changed',
          actorNickname: 'Νίκος',
          targetNicknames: ['25']);
      expect(r.el, 'Νίκος άλλαξε το όριο μελών σε 25');
      expect(r.en, 'Νίκος changed member limit to 25');
    });

    test('permission_changed granted', () {
      final r = SystemMessageFormatter.format(
          action: 'permission_changed',
          actorNickname: 'Νίκος',
          targetNicknames: ['Γιώργος', 'inviteMembers', 'granted']);
      expect(r.el, 'Νίκος έδωσε δικαίωμα inviteMembers στον/στην Γιώργος');
      expect(r.en, 'Νίκος granted inviteMembers permission to Γιώργος');
    });

    test('permission_changed revoked', () {
      final r = SystemMessageFormatter.format(
          action: 'permission_changed',
          actorNickname: 'Νίκος',
          targetNicknames: ['Γιώργος', 'inviteMembers', 'revoked']);
      expect(r.el, 'Νίκος αφαίρεσε δικαίωμα inviteMembers από τον/την Γιώργος');
      expect(r.en, 'Νίκος revoked inviteMembers permission from Γιώργος');
    });

    test('permission_overrides_reset', () {
      final r = SystemMessageFormatter.format(
          action: 'permission_overrides_reset',
          actorNickname: 'Νίκος',
          targetNicknames: ['Άννα']);
      expect(r.el, 'Νίκος επανέφερε τα δικαιώματα για τον/την Άννα');
      expect(r.en, 'Νίκος reset permissions for Άννα');
    });

    test('message_expiry_changed', () {
      final r = SystemMessageFormatter.format(
          action: 'message_expiry_changed', actorNickname: 'Νίκος');
      expect(r.el, 'Νίκος όρισε αυτόματη διαγραφή μηνυμάτων');
      expect(r.en, 'Νίκος set message expiry');
    });

    test('delete_request', () {
      final r = SystemMessageFormatter.format(
          action: 'delete_request', actorNickname: 'Μαρία');
      expect(r.el, 'Μαρία θέλει να διαγράψει την συνομιλία σας');
      expect(r.en, 'Μαρία wants to delete this chat');
    });

    test('delete_approved', () {
      final r = SystemMessageFormatter.format(
          action: 'delete_approved', actorNickname: 'Μαρία');
      expect(r.el, 'Μαρία αποδέχθηκε την διαγραφή — η συνομιλία διαγράφηκε');
      expect(r.en, 'Μαρία approved — chat deleted');
    });

    test('delete_local', () {
      final r = SystemMessageFormatter.format(
          action: 'delete_local', actorNickname: 'Μαρία');
      expect(r.el, 'Μαρία αποχώρησε');
      expect(r.en, 'Μαρία left the chat');
    });

    test('groupName prefix applied', () {
      final r = SystemMessageFormatter.format(
          action: 'group_created',
          actorNickname: 'Νίκος',
          groupName: 'Ομάδα Α');
      expect(r.el, 'Ομάδα Α: Νίκος δημιούργησε την ομάδα');
      expect(r.en, 'Ομάδα Α: Νίκος created the group');
    });

    test('unknown action returns the action as-is', () {
      final r = SystemMessageFormatter.format(
          action: 'weird_action', actorNickname: 'Νίκος');
      expect(r.el, 'weird_action');
      expect(r.en, 'weird_action');
    });
  });
}
