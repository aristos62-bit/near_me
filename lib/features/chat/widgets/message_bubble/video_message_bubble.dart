import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/debug/debug_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/app_messenger.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../shared/utils/avatar_blur.dart';
import '../../providers/chat_provider.dart';
import 'bubble_long_press_wrapper.dart';
import '../message_reactions.dart';

import 'bubble_timestamp.dart';
import 'reply_preview.dart';
import 'sender_header.dart';
import 'tail_painter.dart';
import 'video_content_panel.dart';

class VideoMessageBubble extends ConsumerStatefulWidget {
  final String content;
  final double bubbleMaxWidth;
  final int duration;
  final String? thumbnailUrl;
  final String timeStr;
  final bool isMe;
  final bool isGroupChat;
  final bool isSenderBlockedByMe;
  final bool isGrouped;
  final bool isLastInGroup;
  final bool showAvatar;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final List<String> seenBy;
  final bool isRead;
  final String? chatId;
  final String currentUid;
  final String messageId;
  final Map<String, dynamic> reactions;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onReply;
  final VoidCallback? onReplyPrivately;
  final VoidCallback? onDelete;
  final VoidCallback? onInfo;
  final VoidCallback? onEmail;
  final VoidCallback? onShare;
  // TODO: αχρησιμοποίητο μετά τη μετάβαση σε videoPlaybackProvider —
  // κρατείται λόγω §7.3 (μην αλλάξεις την υπογραφή του MessageBubble).
  final dynamic videoPlayer;
  final Future<void> Function(String url)? onPlayVideo;
  final String? isLoadingUrl;
  final String? videoRacyLevel;
  final bool blurEnabled;
  final double blurSigma;

  const VideoMessageBubble({
    super.key,
    required this.content,
    required this.bubbleMaxWidth,
    this.duration = 0,
    this.thumbnailUrl,
    required this.timeStr,
    required this.isMe,
    this.isGroupChat = false,
    this.isSenderBlockedByMe = false,
    this.isGrouped = false,
    this.isLastInGroup = true,
    this.showAvatar = true,
    this.senderNickname,
    this.senderAvatarUrl,
    this.seenBy = const [],
    this.isRead = false,
    this.chatId,
    this.currentUid = '',
    this.messageId = '',
    this.reactions = const {},
    this.onReact,
    this.onRemove,
    this.replyTo,
    this.onReply,
    this.onReplyPrivately,
    this.onDelete,
    this.onInfo,
    this.onEmail,
    this.onShare,
    this.videoPlayer,
    this.onPlayVideo,
    this.isLoadingUrl,
    this.videoRacyLevel,
    this.blurEnabled = false,
    this.blurSigma = 12.0,
  });

  @override
  ConsumerState<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends ConsumerState<VideoMessageBubble> {
  bool _isPlaying = false;
  bool _isMuted = true;
  // Ρητή συναίνεση αποκάλυψης για racy βίντεο — μπορεί να ξαναρωτηθεί
  // μόνο όταν μηδενιστεί στο _resetState (αλλαγή content στο ίδιο State).
  bool _revealed = false;
  VoidCallback? _listener;
  // Single source of truth για "σε ποιον controller είμαι συνδεδεμένος" —
  // όχι re-derive από το provider στα cleanup (δεν είναι εγγυημένη η σειρά
  // dispose μεταξύ ChatScreen.stop() και του bubble's dispose()).
  VideoPlayerController? _attachedController;

  @override
  void initState() {
    super.initState();
    final controller =
        ref.read(videoPlaybackProvider)[widget.chatId]?.controller;
    _attachListener(controller);
  }

  @override
  void didUpdateWidget(VideoMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _resetState();
      _attachListener(
        ref.read(videoPlaybackProvider)[widget.chatId]?.controller,
      );
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    if (_attachedController != null && _listener != null) {
      _attachedController!.removeListener(_listener!);
    }
    _listener = null;
    _attachedController = null;
  }

  void _resetState() {
    _isPlaying = false;
    _isMuted = true;
    _revealed = false;
  }

  void _attachListener(VideoPlayerController? controller) {
    _removeListener();
    _attachedController = controller;
    if (controller == null) return;

    _listener = () {
      if (!mounted) return;
      final isPlaying = controller.value.isPlaying;
      if (isPlaying != _isPlaying) {
        setState(() => _isPlaying = isPlaying);
      }
      if (controller.value.isCompleted) {
        setState(() => _isPlaying = false);
      }
    };
    controller.addListener(_listener!);
  }

  VideoPlayerController? _getController() {
    final c = ref.read(videoPlaybackProvider)[widget.chatId]?.controller;
    if (c == null) return null;
    if (!c.value.isInitialized) return null;
    return c;
  }

  bool _isMyController() {
    final controller = _getController();
    if (controller == null) return false;
    return controller.dataSource == widget.content;
  }

  Future<void> _togglePlayPause() async {
    final chatId = widget.chatId;
    if (chatId == null) return;

    // Hard-block: racy βίντεο δεν φορτώνονται/παίζουν χωρίς ρητή συναίνεση.
    if (!_revealed &&
        !_isPlaying &&
        widget.blurEnabled &&
        isRacyLevel(widget.videoRacyLevel) &&
        widget.blurSigma > 0) {
      final isGreek = L10n.isGreek(context);
      final ok = await AppMessenger.showConfirmDialog(
        context,
        title: L10n.blurRevealVideoTitle(isGreek: isGreek),
        message: L10n.blurRevealVideoMessage(isGreek: isGreek),
        confirmLabel: L10n.blurRevealButton(isGreek: isGreek),
        cancelLabel: isGreek ? 'Άκυρο' : 'Cancel',
      );
      if (!mounted) return;
      if (!ok) return;
      _revealed = true;
    }

    if (_getController() == null) {
      await ref
          .read(videoPlaybackProvider.notifier)
          .play(chatId, widget.content);
      return;
    }
    final controller = _getController();
    if (controller == null) return;
    if (!_isMyController()) {
      await ref
          .read(videoPlaybackProvider.notifier)
          .play(chatId, widget.content);
      return;
    }
    try {
      if (_isPlaying) {
        await controller.pause();
      } else {
        controller.setVolume(_isMuted ? 0.0 : 1.0);
        await controller.play();
      }
    } catch (e, s) {
      DebugConfig.error(
        'VideoBubble: playback error msg=${widget.messageId}',
        data: e,
        exception: s,
      );
      if (mounted) {
        AppMessenger.showError(
          context,
          ErrorMessages.get('chat/video-playback-error', L10n.isGreek(context)),
        );
      }
    }
  }

  void _toggleMute() async {
    final controller = _getController();
    if (controller == null) return;
    try {
      setState(() => _isMuted = !_isMuted);
      controller.setVolume(_isMuted ? 0.0 : 1.0);
    } catch (e) {
      DebugConfig.warn('VideoBubble: mute toggle failed', data: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTail = widget.isLastInGroup;
    final bubbleColor = widget.isMe
        ? const Color(0xFF075E54)
        : theme.colorScheme.surfaceContainerHighest;

    // Reactive rendering value: μόνο για το συγκεκριμένο bubble Element —
    // δεν ανεβαίνει cascade στο ChatMessagesList/ListView.builder.
    final playback = ref.watch(
      videoPlaybackProvider.select((s) => s[widget.chatId]),
    );
    // Imperative side-effect: Riverpod-ισοδύναμο του didUpdateWidget για
    // reactive state — attach/detach σε αλλαγή ενεργού controller.
    ref.listen<VideoPlaybackInfo?>(
      videoPlaybackProvider.select((s) => s[widget.chatId]),
      (prev, next) {
        if (prev?.controller != next?.controller) {
          _attachListener(next?.controller);
        }
      },
    );

    final bubbleBorderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(!widget.isMe && showTail ? 4 : 16),
      bottomRight: Radius.circular(widget.isMe && showTail ? 4 : 16),
    );

    final totalSec = widget.duration;
    final totalMin = (totalSec ~/ 60).toString().padLeft(2, '0');
    final totalSecStr = (totalSec % 60).toString().padLeft(2, '0');
    final controller = _getController();
    final isMyController = _isMyController();
    final isLoading = widget.content == playback?.loadingUrl;
    final videoAspectRatio =
        (isMyController && controller != null && controller.value.isInitialized)
        ? controller.value.aspectRatio
        : 16 / 9;
    final thumbBlur = widget.blurEnabled && isRacyLevel(widget.videoRacyLevel) && widget.blurSigma > 0;
    DebugConfig.log(DebugConfig.moderation,
        'Video thumb blur: racy=${widget.videoRacyLevel} enabled=${widget.blurEnabled} sigma=${widget.blurSigma} apply=$thumbBlur');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: widget.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!widget.isMe &&
              widget.showAvatar &&
              (widget.senderAvatarUrl != null || widget.senderNickname != null))
            SenderHeader(
              senderAvatarUrl: widget.senderAvatarUrl,
              senderNickname: widget.senderNickname,
              isGroupChat: widget.isGroupChat,
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.isMe)
                ReactionTriggerIcon(
                  chatId: widget.chatId,
                  messageId: widget.messageId,
                  reactions: widget.reactions,
                  currentUid: widget.currentUid,
                  isMe: widget.isMe,
                  onReact: widget.onReact,
                  onRemove: widget.onRemove,
                ),
              Stack(
            clipBehavior: Clip.none,
            children: [
              BubbleLongPressWrapper(
                isMe: widget.isMe,
                isGroupChat: widget.isGroupChat,
                isSenderBlockedByMe: widget.isSenderBlockedByMe,
                canEdit: false,
                onReply: widget.onReply,
                onReplyPrivately: widget.onReplyPrivately,
                onDelete: widget.onDelete,
                onInfo: widget.onInfo,
                onEmail: widget.onEmail,
                onShare: widget.onShare,
                child: Container(
                  constraints: BoxConstraints(maxWidth: widget.bubbleMaxWidth),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: bubbleBorderRadius,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.replyTo != null)
                        BubbleQuoteSection(
                          replyTo: widget.replyTo,
                          bubbleColor: bubbleColor,
                          isGroupChat: widget.isGroupChat,
                        ),
                      VideoContentPanel(
                        bubbleBorderRadius: bubbleBorderRadius,
                        controller: controller,
                        isMyController: isMyController,
                        thumbnailUrl: widget.thumbnailUrl,
                        isLoading: isLoading,
                        aspectRatio: videoAspectRatio,
                        isPlaying: _isPlaying,
                        isMuted: _isMuted,
                        maxWidth: widget.bubbleMaxWidth,
                        blurEnabled: widget.blurEnabled,
                        videoRacyLevel: widget.videoRacyLevel,
                        blurSigma: widget.blurSigma,
                        durationLabel: '$totalMin:$totalSecStr',
                        onTap: _togglePlayPause,
                        onToggleMute: _toggleMute,
                      ),
                ],
                ),
              ),
            ),
              if (showTail)
                Positioned(
                  bottom: 0,
                  right: widget.isMe ? -8 : null,
                  left: !widget.isMe ? -8 : null,
                  child: CustomPaint(
                    painter: TailPainter(color: bubbleColor),
                    size: const Size(10, 8),
                  ),
                ),
            ],
          ),
              if (!widget.isMe)
                ReactionTriggerIcon(
                  chatId: widget.chatId,
                  messageId: widget.messageId,
                  reactions: widget.reactions,
                  currentUid: widget.currentUid,
                  isMe: widget.isMe,
                  onReact: widget.onReact,
                  onRemove: widget.onRemove,
                ),
            ],
          ),
          BubbleTimestamp(timeStr: widget.timeStr, isMe: widget.isMe),
          ],
      ),
    );
  }
}
