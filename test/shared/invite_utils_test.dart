import 'package:flutter_test/flutter_test.dart';
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

    test('natural-language message without leading token → null', () {
      expect(
        InviteUtils.extractInviteToken('Έχεις πρόσκληση! Κωδικός: $valid'),
        isNull,
      );
    });
  });
}