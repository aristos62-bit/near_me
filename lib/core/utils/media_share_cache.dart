import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../debug/debug_config.dart';

/// Διαχειρίζεται τον προσωρινό φάκελο όπου αποθηκεύονται τα media
/// που κατεβάζονται για αποστολή σε email / εξωτερική κοινοποίηση
/// (βλ. ChatMessagesList._downloadMediaAsFile).
///
/// Ο φάκελος είναι αποκλειστικά δικός μας ώστε το sweep() να μην
/// κινδυνεύει να διαγράψει temp αρχεία άλλων plugins.
class MediaShareCache {
  MediaShareCache._();

  static const _folderName = 'near_me_share_cache';

  static Future<Directory> _dir() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Επιστρέφει το File path όπου πρέπει να γραφτεί/διαβαστεί
  /// το προσωρινό αρχείο για το δοσμένο msgId/extension.
  static Future<File> fileFor(String msgId, String ext) async {
    final dir = await _dir();
    return File('${dir.path}/$msgId.$ext');
  }

  /// Διαγράφει όλα τα αρχεία του cache. Καλείται στο startup της
  /// εφαρμογής — ασφαλές γιατί τα αρχεία εδώ είναι πάντα εφήμερα
  /// (ξαναδημιουργούνται on-demand όταν χρειαστούν).
  static Future<void> sweep() async {
    try {
      final dir = await _dir();
      final entries = await dir.list().toList();
      for (final entry in entries) {
        if (entry is File) {
          await entry.delete();
        }
      }
      DebugConfig.log(DebugConfig.serviceInit,
          'MediaShareCache: swept ${entries.length} file(s)');
    } catch (e) {
      DebugConfig.warn('MediaShareCache: sweep failed', data: e);
    }
  }
}