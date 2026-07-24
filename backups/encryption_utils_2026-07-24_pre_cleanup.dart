import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../debug/debug_config.dart';

class EncryptionUtils {
  EncryptionUtils._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );
  static const _keyPrefix = 'chat_key_';

  static const _keyAlgorithm = 'AES-256-GCM';
  static const _deriveSalt = 'near_me_e2e_key_';

  static encrypt.Key generateKey() {
    final key = encrypt.Key.fromSecureRandom(32);
    DebugConfig.log(DebugConfig.chatEncrypt, 'Generated new $_keyAlgorithm key');
    return key;
  }

  static encrypt.Key deriveKey(String chatId) {
    final hash = sha256.convert(utf8.encode('$_deriveSalt$chatId'));
    DebugConfig.log(DebugConfig.chatEncrypt, 'Derived key for chat: $chatId');
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  static Future<void> storeKey(String chatId, encrypt.Key key) async {
    try {
      final base64Key = key.base64;
      await _storage.write(key: '$_keyPrefix$chatId', value: base64Key);
      DebugConfig.log(DebugConfig.chatEncrypt, 'Stored key for chat: $chatId');
    } catch (e) {
      DebugConfig.warn('storeKey: storage write error for chat $chatId', data: e);
    }
  }

  static Future<encrypt.Key?> getKey(String chatId) async {
    try {
      final base64Key = await _storage.read(key: '$_keyPrefix$chatId');
      if (base64Key == null || base64Key.isEmpty) {
        DebugConfig.warn('No encryption key found for chat: $chatId');
        return null;
      }
      try {
        final key = encrypt.Key.fromBase64(base64Key);
        DebugConfig.log(DebugConfig.chatEncrypt, 'Retrieved key for chat: $chatId');
        return key;
      } catch (e) {
        DebugConfig.warn('getKey: invalid stored key for chat $chatId', data: e);
        return null;
      }
    } catch (e) {
      DebugConfig.warn('getKey: storage read error for chat $chatId', data: e);
      return null;
    }
  }

  static Future<encrypt.Key> getKeyOrDerive(String chatId) async {
    final stored = await getKey(chatId);
    if (stored != null) return stored;

    DebugConfig.log(DebugConfig.chatEncrypt, 'getKeyOrDerive: using derived key for chat: $chatId');
    final derived = deriveKey(chatId);

    try {
      await _storage.write(key: '$_keyPrefix$chatId', value: derived.base64);
      DebugConfig.log(DebugConfig.chatEncrypt, 'getKeyOrDerive: cached derived key for chat: $chatId');
    } catch (e) {
      DebugConfig.warn('getKeyOrDerive: failed to cache key for chat $chatId', data: e);
    }

    return derived;
  }

  static Future<void> deleteKey(String chatId) async {
    try {
      await _storage.delete(key: '$_keyPrefix$chatId');
      DebugConfig.log(DebugConfig.chatEncrypt, 'Deleted key for chat: $chatId');
    } catch (e) {
      DebugConfig.warn('deleteKey: storage delete error for chat $chatId', data: e);
    }
  }

  static String encryptMessage(encrypt.Key key, String plaintext) {
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final iv = encrypt.IV.fromSecureRandom(12);
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final result = '${iv.base64}:${encrypted.base64}';
    DebugConfig.log(DebugConfig.chatEncrypt, 'Encrypted message (${plaintext.length} chars -> ${result.length} chars)');
    return result;
  }

  static String decryptMessage(encrypt.Key key, String encrypted) {
    final parts = encrypted.split(':');
    if (parts.length != 2) {
      DebugConfig.error('Invalid encrypted message format');
      throw const FormatException('Invalid encrypted message format. Expected "iv:cipher".');
    }
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final iv = encrypt.IV.fromBase64(parts[0]);
    final decrypted = encrypter.decrypt64(parts[1], iv: iv);
    DebugConfig.log(DebugConfig.chatEncrypt, 'Decrypted message (${encrypted.length} chars -> ${decrypted.length} chars)');
    return decrypted;
  }

  static Future<void> clearAllKeys() async {
    try {
      await _storage.deleteAll();
      DebugConfig.log(DebugConfig.chatEncrypt, 'All encryption keys cleared');
    } catch (e) {
      DebugConfig.warn('clearAllKeys: storage deleteAll error', data: e);
    }
  }
}
