import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../debug/debug_config.dart';

class StorageHelpers {
  StorageHelpers._();

  static const _uploadImage = Duration(seconds: 15);
  static const _uploadAudio = Duration(seconds: 15);
  static const _uploadVideo = Duration(seconds: 30);
  static const _uploadThumbnail = Duration(seconds: 10);
  static const _downloadUrl = Duration(seconds: 10);

  static Duration timeoutFor(String type) => switch (type) {
    'video'  => _uploadVideo,
    'audio'  => _uploadAudio,
    'thumb'  => _uploadThumbnail,
    _        => _uploadImage,
  };

  static Future<TaskSnapshot> uploadBytesWithTimeout(
    Reference ref,
    Uint8List bytes, {
    required String contentType,
    required String type,
  }) async {
    final timeout = timeoutFor(type);
    DebugConfig.log(DebugConfig.storageUpload,
        'StorageHelpers: upload ${ref.fullPath} type=$type timeout=${timeout.inSeconds}s');
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    try {
      return await task.timeout(timeout);
    } on TimeoutException {
      DebugConfig.warn('StorageHelpers: upload TIMEOUT ${ref.fullPath} after ${timeout.inSeconds}s');
      await task.cancel().catchError((_) => false);
      rethrow;
    }
  }

  static Future<TaskSnapshot> uploadFileWithTimeout(
    UploadTask task,
    String path, {
    required Duration timeout,
  }) {
    DebugConfig.log(DebugConfig.storageUpload,
        'StorageHelpers: upload $path timeout=${timeout.inSeconds}s');
    final completer = Completer<TaskSnapshot>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        DebugConfig.warn('StorageHelpers: upload TIMEOUT $path after ${timeout.inSeconds}s');
        task.cancel().catchError((_) => false);
        completer.completeError(
          TimeoutException('Upload timed out after ${timeout.inSeconds}s'),
        );
      }
    });
    task.then((snapshot) {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(snapshot);
    }, onError: (Object error, StackTrace stack) {
      timer.cancel();
      if (!completer.isCompleted) completer.completeError(error, stack);
    });
    return completer.future;
  }

  static Future<String> downloadUrlWithTimeout(Reference ref) {
    return ref.getDownloadURL().timeout(_downloadUrl, onTimeout: () {
      DebugConfig.warn('StorageHelpers: getDownloadURL TIMEOUT ${ref.fullPath}');
      throw TimeoutException('Download URL timed out after ${_downloadUrl.inSeconds}s');
    });
  }
}
