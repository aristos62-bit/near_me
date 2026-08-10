import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n.dart';

/// Leaf widget — modal sheet με preview του εισερχόμενου shared content.
/// Επιστρέφει true αν ο χρήστης θέλει να προωθηθεί σε συνομιλία.
/// Δεν κάνει κανένα watch → μηδέν rebuilds.
Future<bool?> showIncomingShareSheet(
  BuildContext context, {
  required String type,
  required String content,
  String? filePath,
  Uint8List? thumbnailBytes,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    builder: (ctx) {
      final greek = L10n.isGreek(ctx);
      final isMedia = filePath != null &&
          (type == 'image' || type == 'gif' || type == 'video' || type == 'audio');
      final isUrl = !isMedia &&
          (type == 'url' || content.trimLeft().startsWith(RegExp(r'^https?://')));
      final icon = isMedia
          ? (type == 'video'
              ? Icons.videocam_outlined
              : type == 'audio'
                  ? Icons.mic_outlined
                  : Icons.image_outlined)
          : (isUrl ? Icons.link : Icons.forward_to_inbox_outlined);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      greek ? 'Εισερχόμενο περιεχόμενο' : 'Incoming content',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isMedia
                    ? _buildMediaPreview(type, filePath, thumbnailBytes)
                    : SingleChildScrollView(
                        child: SelectableText(content, style: Theme.of(ctx).textTheme.bodyMedium),
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send),
                  label: Text(greek ? 'Προώθηση σε συνομιλία' : 'Forward to a chat'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildMediaPreview(String type, String filePath, Uint8List? thumbnailBytes) {
  final showImage = type == 'image' || type == 'gif';
  if (showImage) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(filePath),
        width: double.infinity,
        height: 170,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _mediaIcon(type),
      ),
    );
  }
  if (type == 'video' && thumbnailBytes != null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        thumbnailBytes,
        width: double.infinity,
        height: 170,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _mediaIcon(type),
      ),
    );
  }
  return _mediaIcon(type);
}

Widget _mediaIcon(String type) {
  final IconData icon;
  if (type == 'video') {
    icon = Icons.videocam_outlined;
  } else if (type == 'audio') {
    icon = Icons.mic_outlined;
  } else {
    icon = Icons.image_outlined;
  }
  return Center(
    child: Icon(icon, size: 48, color: Colors.grey),
  );
}
