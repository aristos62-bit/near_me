import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/l10n/l10n.dart';
import 'package:near_me/shared/utils/invite_utils.dart';

void main() {
  final valid = '0123456789abcdef0123456789abcdef'; // 32 lowercase hex

  group('extractInviteToken', () {
    test('valid 32-hex token → returned as-is', () {
      expect(InviteUtils.extractInviteToken(valid), valid);
    });

    test('whitespace around valid token → trimmed', () {
      expect(InviteUtils.extractInviteToken('  $valid  '), valid);
    });

    test('URL with ?token= → token extracted', () {
      expect(
        InviteUtils.extractInviteToken('https://nearme.app/join?token=$valid'),
        valid,
      );
    });

    test('URL with token + extra params → token extracted', () {
      expect(
        InviteUtils.extractInviteToken(
            'https://nearme.app/join?utm=x&token=$valid&ref=y'),
        valid,
      );
    });

    test('URL without token → null', () {
      expect(InviteUtils.extractInviteToken('https://nearme.app/join'), isNull);
    });

    test('empty / whitespace-only → null', () {
      expect(InviteUtils.extractInviteToken(''), isNull);
      expect(InviteUtils.extractInviteToken('   '), isNull);
    });

    test('too short (31 chars) → null', () {
      expect(InviteUtils.extractInviteToken(valid.substring(0, 31)), isNull);
    });

    test('non-hex character → null', () {
      expect(
        InviteUtils.extractInviteToken('0123456789abcdef0123456789abcdeg'),
        isNull,
      );
    });

    test('uppercase hex → null (strict lowercase)', () {
      expect(InviteUtils.extractInviteToken(valid.toUpperCase()), isNull);
    });

    test('first word valid in a longer message → extracted', () {
      expect(InviteUtils.extractInviteToken('$valid some extra words'), valid);
    });

    test('invalid first word in message → null', () {
      expect(InviteUtils.extractInviteToken('Πρόσκληση $valid'), isNull);
    });

    test('full invite message token-first (GR) → token extracted', () {
      final msg = L10n.inviteInvitationMessage(
        groupName: 'Παρέα',
        token: valid,
        isGreek: true,
      );
      expect(InviteUtils.extractInviteToken(msg), valid);
    });

    test('full invite message token-first (EN) → token extracted', () {
      final msg = L10n.inviteInvitationMessage(
        groupName: 'Friends',
        token: valid,
        isGreek: false,
      );
      expect(InviteUtils.extractInviteToken(msg), valid);
    });

    test('natural-language message without leading token → null', () {
      expect(
        InviteUtils.extractInviteToken('Έχεις πρόσκληση! Κωδικός: $valid'),
        isNull,
      );
    });
  });

  group('findInviteTokenInText', () {
    test('token mid-sentence in invite message → found', () {
      expect(
        InviteUtils.findInviteTokenInText(
          'Έχεις πρόσκληση στην ομάδα "Παρέα"! Κάνε επικόλληση τον '
          'κωδικό $valid στη σελίδα Συνομιλιών.',
        ),
        valid,
      );
    });

    test('token inside URL in text → found', () {
      expect(
        InviteUtils.findInviteTokenInText('Δες αυτό: https://nearme.app/join?token=$valid&x=1'),
        valid,
      );
    });

    test('anchor token at start → found', () {
      expect(InviteUtils.findInviteTokenInText('$valid μη εξουσιοδοτημένο'), valid);
    });

    test('31-char hex in text → null', () {
      expect(InviteUtils.findInviteTokenInText('κωδικός ${valid.substring(0, 31)} εδώ'), isNull);
    });

    test('non-hex 32-char in text → null', () {
      expect(
        InviteUtils.findInviteTokenInText('κωδικός 0123456789abcdef0123456789abcdeg εδώ'),
        isNull,
      );
    });

    test('uppercase hex in text → null (strict lowercase)', () {
      expect(InviteUtils.findInviteTokenInText('κωδικός ${valid.toUpperCase()} εδώ'), isNull);
    });

    test('plain text without token → null', () {
      expect(InviteUtils.findInviteTokenInText('just a normal hello message'), isNull);
    });

    test('empty / short text → null', () {
      expect(InviteUtils.findInviteTokenInText(''), isNull);
      expect(InviteUtils.findInviteTokenInText('hi'), isNull);
    });
  });
}