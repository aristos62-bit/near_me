import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/debug/debug_config.dart';
import '../../../shared/utils/image_utils.dart';
import '../providers/chat_provider.dart';
import 'audio_recorder_sheet.dart';
import 'gif_picker_sheet.dart';
import 'media_picker_sheet.dart';

/// Αποστολή media (gif/photo/camera/audio/video) για τον `ChatInputBar`.
///
/// Όλες οι μέθοδοι χρησιμοποιούν ΜΟΝΟ το API του `ConsumerState`
/// (ref/setState/mounted/context) συν τα abstract members παρακάτω.
/// Πρόκειται για pure extract από το `chat_input_bar.dart` — καμία αλλαγή
/// συμπεριφοράς (ίδια flags, ίδια error codes, ίδια logging).
mixin ChatMediaSenderMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String get chatId;
  bool get emojiPickerVisible;
  VoidCallback get onEmojiDismiss;
  VoidCallback get onEmojiToggle;
  Map<String, dynamic>? buildReplyData();
  void clearReply();
  void clearError();
  void showInlineError(String code);
  void setSending(bool value);

  Future<void> pickGif() async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatInputBar: GIF picker shown');
    if (emojiPickerVisible) onEmojiDismiss();
    await showGifPickerSheet(context, onSelected: (url) async {
      if (!mounted) return;
      final replyToData = buildReplyData();
      clearReply();
      clearError();
      setSending(true);
      final ok = await ref.read(chatActionsProvider.notifier)
          .sendMediaMessage(chatId, content: url, type: 'gif', replyTo: replyToData);
      if (!mounted) return;
      setSending(false);
      if (!ok) {
        showInlineError('chat/gif-send-failed');
      }
    });
  }

  Future<void> pickAndSendPhoto() => _pickImage(ImageSource.gallery, 'photo');

  Future<void> pickAndSendCamera() => _pickImage(ImageSource.camera, 'camera');

  Future<void> _pickImage(ImageSource source, String debugLabel) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatInputBar: $debugLabel picker shown');
    if (emojiPickerVisible) onEmojiDismiss();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null || !mounted) return;
      final cropped = await ImageCropper.platform.cropImage(
        sourcePath: picked.path,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (cropped == null || !mounted) return;
      final bytes = await ImageUtils.stripExif(
          await File(cropped.path).readAsBytes());
      final replyToData = buildReplyData();
      clearReply();
      clearError();
      setSending(true);
      final ok = await ref.read(chatActionsProvider.notifier)
          .sendMediaMessage(chatId, content: '', type: 'image', replyTo: replyToData, imageBytes: bytes);
      if (!mounted) return;
      setSending(false);
      if (!ok) {
        final chatState = ref.read(chatActionsProvider);
        showInlineError(chatState.errorMessage ?? 'chat/image-send-failed');
      }
    } catch (e, s) {
      DebugConfig.error('ChatInputBar: _$debugLabel pick failed', data: e, exception: s);
      if (mounted) {
        showInlineError('chat/image-send-failed');
      }
    }
  }

  Future<void> recordAndSend() async {
    if (emojiPickerVisible) onEmojiDismiss();
    final result = await showAudioRecorderSheet(context);
    if (!mounted || result == null) return;
    final replyToData = buildReplyData();
    clearReply();
    clearError();
    setSending(true);
    final ok = await ref.read(chatActionsProvider.notifier)
        .sendMediaMessage(chatId,
            content: '', type: 'audio',
            replyTo: replyToData,
            audioBytes: result.bytes,
            duration: result.durationSeconds);
    if (!mounted) return;
    setSending(false);
    if (!ok) {
      showInlineError('chat/audio-send-failed');
    }
  }

  Future<void> pickAndSendVideoGallery() =>
      _pickVideo(ImageSource.gallery, 'videoGallery');

  Future<void> pickAndSendVideoCamera() =>
      _pickVideo(ImageSource.camera, 'videoCamera');

  Future<void> _pickVideo(ImageSource source, String debugLabel) async {
    DebugConfig.log(DebugConfig.chatVideo,
        'ChatInputBar: $debugLabel picker shown');
    if (emojiPickerVisible) onEmojiDismiss();

    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (picked == null || !mounted) return;

      final fileSize = await picked.length();
      if (fileSize >= 50 * 1024 * 1024) {
        if (!mounted) return;
        showInlineError('chat/video-too-large');
        return;
      }

      int durationSeconds = 0;
      try {
        final controller = VideoPlayerController.file(File(picked.path));
        await controller.initialize();
        durationSeconds = controller.value.duration.inSeconds;
        await controller.dispose();
      } catch (e) {
        DebugConfig.warn('ChatInputBar: video duration read failed', data: e);
      }

      if (!mounted) return;
      if (durationSeconds > 30) {
        showInlineError('chat/video-too-long');
        return;
      }
      if (durationSeconds < 1) {
        showInlineError('chat/video-too-short');
        return;
      }

      Uint8List? thumbBytes;
      try {
        thumbBytes = await VideoThumbnail.thumbnailData(
          video: picked.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 480,
          quality: 70,
        );
      } catch (e) {
        DebugConfig.warn('ChatInputBar: thumbnail generation failed', data: e);
      }

      if (!mounted) return;
      final replyToData = buildReplyData();
      clearReply();
      clearError();
      setSending(true);
      final ok = await ref.read(chatActionsProvider.notifier)
          .sendMediaMessage(chatId,
          content: '', type: 'video',
          replyTo: replyToData,
          videoPath: picked.path,
          duration: durationSeconds,
          thumbnailBytes: thumbBytes);
      if (!mounted) return;
      setSending(false);
      if (!ok) {
        final chatState = ref.read(chatActionsProvider);
        showInlineError(chatState.errorMessage ?? 'chat/video-send-failed');
      }
    } catch (e, s) {
      DebugConfig.error('ChatInputBar: $debugLabel pick failed', data: e,
          exception: s);
      if (mounted) {
        showInlineError('chat/video-send-failed');
      }
    }
  }

  Future<void> showMediaPicker() async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatInputBar: media + pressed');
    if (emojiPickerVisible) onEmojiDismiss();
    final action = await showMediaPickerSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case MediaAction.emoji:
        DebugConfig.log(DebugConfig.uiInteraction,
            'ChatInputBar: media popup: emoji');
        onEmojiToggle();
      case MediaAction.gif:
        DebugConfig.log(DebugConfig.uiInteraction,
            'ChatInputBar: media popup: gif');
        pickGif();
      case MediaAction.photo:
        DebugConfig.log(DebugConfig.uiInteraction,
            'ChatInputBar: media popup: photo');
        pickAndSendPhoto();
      case MediaAction.camera:
        DebugConfig.log(DebugConfig.uiInteraction,
            'ChatInputBar: media popup: camera');
        pickAndSendCamera();
      case MediaAction.record:
        DebugConfig.log(DebugConfig.chatAudio,
            'ChatInputBar: record pressed');
        recordAndSend();
      case MediaAction.videoGallery:
        DebugConfig.log(DebugConfig.chatVideo,
            'ChatInputBar: media popup: video gallery');
        pickAndSendVideoGallery();
      case MediaAction.videoCamera:
        DebugConfig.log(DebugConfig.chatVideo,
            'ChatInputBar: media popup: video camera');
        pickAndSendVideoCamera();
    }
  }
}