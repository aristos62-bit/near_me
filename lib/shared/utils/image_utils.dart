import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/debug/debug_config.dart';

class ImageUtils {
  ImageUtils._();

  static Future<Uint8List> stripExif(Uint8List bytes) async {
    if (kIsWeb) return bytes;
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 100,
        format: CompressFormat.jpeg,
      );
      final saved = bytes.length - result.length;
      DebugConfig.log(DebugConfig.storageUpload,
          'stripExif: removed EXIF (saved $saved bytes)');
      return result;
    } catch (e) {
      DebugConfig.warn('stripExif failed, using original bytes', data: e);
      return bytes;
    }
  }
}
