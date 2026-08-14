import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../debug/debug_config.dart';

/// Ελέγχει το μέγεθος του δίσκου-cache του CachedNetworkImage
/// στο startup, και το αδειάζει αν ξεπεράσει το όριο.
/// flutter_cache_manager δεν έχει byte-cap, μόνο count/age —
/// αυτό είναι το μόνο σημείο ελέγχου συνολικού μεγέθους.
class ImageCacheGuard {
  ImageCacheGuard._();

  static const int _maxBytes = 300 * 1024 * 1024; // 300MB
  // Φθηνό count-gate πριν το ακριβές byte-sum: κάτω από αυτό το πλήθος
  // αρχείων το cache είναι πρακτικά σίγουρα < 300MB, οπότε αποφεύγουμε
  // `await entity.length()` ανά αρχείο (χιλιάδες syscalls στο startup).
  static const int _countGate = 300;

  static Future<void> checkAndPrune() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/libCachedImageData');
      if (!await cacheDir.exists()) return;

      // Pass #1 (φθηνό): count χωρίς stat — κάθε entry είναι ήδη
      // File/FileSystemEntity από το dirent, χωρίς κανένα length() call.
      final files = <FileSystemEntity>[];
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          files.add(entity);
          if (files.length > _countGate) break; // γρήγορο bail-out
        }
      }

      // Αν το count δεν ξεπέρασε το gate, το cache είναι μικρό σχεδόν πάντα
      // (300 αρχεία × ακόμα και 1MB = 300MB). Δεν χρειάζεται byte-sum.
      if (files.length <= _countGate) {
        DebugConfig.log(DebugConfig.serviceInit,
            'ImageCacheGuard: current files=${files.length} (< gate, skip bytes)');
        return;
      }

      // Pass #2 (ακριβές): μόνο όταν το cache είναι ήδη μεγάλο — αποδεκτό
      // εφάπαξ overhead, γιατί ούτως ή άλλως θα αδειάσει σε λίγο.
      int totalBytes = 0;
      for (final entity in files) {
        totalBytes += await (entity as File).length();
      }
      DebugConfig.log(DebugConfig.serviceInit,
          'ImageCacheGuard: current size=${(totalBytes / 1024 / 1024).toStringAsFixed(1)}MB');

      if (totalBytes > _maxBytes) {
        // Το DefaultCacheManager().emptyCache() έχει bug στο 3.4.1:
        // διαγράφει τα entries από το DB αλλά ΟΧΙ τα αρχεία (relative path
        // χωρίς base dir → file.existsSync() = false πάντα). Γι' αυτό
        // σβήνουμε απευθείας τον φάκελο (1 native recursive delete αντί
        // για await ανά αρχείο) και μετά καθαρίζουμε το index της βιβλιοθήκης.
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
        try {
          await DefaultCacheManager().emptyCache();
        } catch (_) {}
        DebugConfig.log(DebugConfig.serviceInit,
            'ImageCacheGuard: pruned (was ${(totalBytes / 1024 / 1024).toStringAsFixed(0)}MB > 300MB limit)');
      }
    } catch (e) {
      DebugConfig.warn('ImageCacheGuard: check failed', data: e);
    }
  }
}
