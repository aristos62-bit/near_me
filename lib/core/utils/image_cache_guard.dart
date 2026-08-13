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

  static Future<void> checkAndPrune() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/libCachedImageData');
      if (!await cacheDir.exists()) return;

      int totalBytes = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }

      DebugConfig.log(DebugConfig.serviceInit,
          'ImageCacheGuard: current size=${(totalBytes / 1024 / 1024).toStringAsFixed(1)}MB');

      if (totalBytes > _maxBytes) {
        // Το DefaultCacheManager().emptyCache() έχει bug στο 3.4.1:
        // διαγράφει τα entries από το DB αλλά ΟΧΙ τα αρχεία (relative path
        // χωρίς base dir → file.existsSync() = false πάντα). Γι' αυτό
        // σβήνουμε απευθείας όλα τα αρχεία του φακέλου.
        var deleted = 0;
        final entities = await cacheDir.list(recursive: true).toList();
        for (final entity in entities) {
          if (entity is File) {
            try {
              await entity.delete();
              deleted++;
            } catch (_) {}
          }
        }
        try {
          await DefaultCacheManager().emptyCache();
        } catch (_) {}
        DebugConfig.log(DebugConfig.serviceInit,
            'ImageCacheGuard: pruned $deleted file(s) (was ${(totalBytes / 1024 / 1024).toStringAsFixed(0)}MB > 300MB limit)');
      }
    } catch (e) {
      DebugConfig.warn('ImageCacheGuard: check failed', data: e);
    }
  }
}
