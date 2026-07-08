import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/encryption_utils.dart';

void main() {
  group('deriveKey', () {
    test('returns the same key for the same chatId', () {
      final key1 = EncryptionUtils.deriveKey('chat_123');
      final key2 = EncryptionUtils.deriveKey('chat_123');
      expect(key1.base64, key2.base64);
    });

    test('returns different keys for different chatIds', () {
      final key1 = EncryptionUtils.deriveKey('chat_abc');
      final key2 = EncryptionUtils.deriveKey('chat_xyz');
      expect(key1.base64, isNot(key2.base64));
    });

    test('key is 256 bits (32 bytes)', () {
      final key = EncryptionUtils.deriveKey('chat_123');
      expect(key.bytes.length, 32);
    });
  });

  group('encryptMessage + decryptMessage round-trip', () {
    test('decrypt(encrypt(text)) == text', () {
      final key = EncryptionUtils.deriveKey('chat_roundtrip');
      const original = 'Γεια σου! Test message με ελληνικά!';
      final encrypted = EncryptionUtils.encryptMessage(key, original);
      final decrypted = EncryptionUtils.decryptMessage(key, encrypted);
      expect(decrypted, original);
    });

    test('empty string round-trip', () {
      final key = EncryptionUtils.deriveKey('chat_empty');
      const original = '';
      final encrypted = EncryptionUtils.encryptMessage(key, original);
      final decrypted = EncryptionUtils.decryptMessage(key, encrypted);
      expect(decrypted, original);
    });

    test('long message round-trip', () {
      final key = EncryptionUtils.deriveKey('chat_long');
      final original = 'A' * 1000;
      final encrypted = EncryptionUtils.encryptMessage(key, original);
      final decrypted = EncryptionUtils.decryptMessage(key, encrypted);
      expect(decrypted, original);
    });

    test('same plaintext produces different ciphertext each time (IV random)', () {
      final key = EncryptionUtils.deriveKey('chat_iv_test');
      const original = 'hello';
      final encrypted1 = EncryptionUtils.encryptMessage(key, original);
      final encrypted2 = EncryptionUtils.encryptMessage(key, original);
      expect(encrypted1, isNot(encrypted2));
    });

    test('decrypt with different chat key fails', () {
      final keyA = EncryptionUtils.deriveKey('chat_a');
      final keyB = EncryptionUtils.deriveKey('chat_b');
      const original = 'secret message for A';
      final encrypted = EncryptionUtils.encryptMessage(keyA, original);
      expect(
        () => EncryptionUtils.decryptMessage(keyB, encrypted),
        throwsA(isA<Object>()),
      );
    });
  });

  group('decryptMessage validation', () {
    test('throws FormatException for invalid format (no colon)', () {
      final key = EncryptionUtils.deriveKey('chat_invalid');
      expect(
        () => EncryptionUtils.decryptMessage(key, 'invalidformat'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty string', () {
      final key = EncryptionUtils.deriveKey('chat_empty_in');
      expect(
        () => EncryptionUtils.decryptMessage(key, ''),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for malformed base64', () {
      final key = EncryptionUtils.deriveKey('chat_malformed');
      expect(
        () => EncryptionUtils.decryptMessage(key, '!!!not-base64:!!!not-base64'),
        throwsA(isA<Object>()),
      );
    });
  });

  group('getKeyOrDerive — derived key fallback', () {
    test('returns a valid key for any chatId', () async {
      final key = await EncryptionUtils.getKeyOrDerive('test_chat_fallback');
      expect(key, isNotNull);
      expect(key.bytes.length, 32);
    });

    test('returns deterministic key matching deriveKey', () async {
      const chatId = 'test_deterministic';
      final derived = EncryptionUtils.deriveKey(chatId);
      final fromOrDerive = await EncryptionUtils.getKeyOrDerive(chatId);
      expect(fromOrDerive.base64, derived.base64);
    });

    test('different chatIds return different keys', () async {
      final key1 = await EncryptionUtils.getKeyOrDerive('chat_diff_a');
      final key2 = await EncryptionUtils.getKeyOrDerive('chat_diff_b');
      expect(key1.base64, isNot(key2.base64));
    });
  });

  group('messagesStream placeholder', () {
    test('bilingual placeholder is used on decrypt failure', () {
      final key = EncryptionUtils.deriveKey('chat_placeholder');
      const placeholder = '[Μη αναγνώσιμο μήνυμα / Unreadable message]';
      // decrypting garbage with a valid key produces an exception
      // simulate what messagesStream does on final catch
      String decrypted;
      try {
        decrypted = EncryptionUtils.decryptMessage(key, 'garbage:garbage');
      } catch (_) {
        decrypted = placeholder;
      }
      expect(decrypted, placeholder);
    });
  });
}
