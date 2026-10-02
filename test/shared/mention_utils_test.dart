import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/utils/mention_utils.dart';

/// Pure `MentionService` — extract/validate χωρίς Firebase.
void main() {
  const nicknames = {'u1': 'Aris', 'u2': 'Maria'};

  group('MentionService.extractMentions', () {
    test('κενό κείμενο ή κενά nicknames → []', () {
      expect(MentionService.extractMentions('', nicknames), isEmpty);
      expect(MentionService.extractMentions('hello @Aris', {}), isEmpty);
    });

    test('βρίσκει @mention case-insensitive', () {
      expect(
        MentionService.extractMentions('γεια @aris τι κάνεις', nicknames),
        ['u1'],
      );
    });

    test('απογυμνώνει τελικό στίξη', () {
      expect(
        MentionService.extractMentions('ρώτα την @Maria!', nicknames),
        ['u2'],
      );
    });

    test('άγνωστο nickname αγνοείται', () {
      expect(
        MentionService.extractMentions('γεια @Nikos', nicknames),
        isEmpty,
      );
    });

    test('πολλαπλά mentions χωρίς διπλότυπα', () {
      final found = MentionService.extractMentions(
          '@Aris και @maria και @ARIS', nicknames);
      expect(found.toSet(), {'u1', 'u2'});
    });

    test('@ χωρίς @-πρόθεμα δεν ταιριάζει', () {
      expect(
        MentionService.extractMentions('Aris χωρίς παπάκι', nicknames),
        isEmpty,
      );
    });
  });

  group('MentionService.validateParticipants', () {
    test('κενά mentions → []', () {
      expect(MentionService.validateParticipants([], ['u1']), isEmpty);
    });

    test('κρατάει μόνο συμμετέχοντες', () {
      expect(
        MentionService.validateParticipants(
            ['u1', 'u9'], ['u1', 'u2']),
        ['u1'],
      );
    });

    test('όλα έγκυρα → όλα περνάνε', () {
      expect(
        MentionService.validateParticipants(['u1', 'u2'], ['u1', 'u2']),
        ['u1', 'u2'],
      );
    });
  });
}
