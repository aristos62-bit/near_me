import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/debug/debug_config.dart';
import 'bubble_long_press_wrapper.dart';
import 'message_reactions_row.dart';
import 'reply_preview.dart';
import 'sender_header.dart';
import 'tail_painter.dart';

class VideoMessageBubble extends StatefulWidget {
  final String content;
  final int duration;
  final String timeStr;
  final bool isMe;
  final bool isGroupChat;
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
  final VoidCallback? onDelete;
  final dynamic videoPlayer;
  final Future<void> Function(String url)? onPlayVideo;
  final String? isLoadingUrl;

  const VideoMessageBubble({
    super.key,
    required this.content,
    this.duration = 0,
    required this.timeStr,
    required this.isMe,
    this.isGroupChat = false,
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
    this.onDelete,
    this.videoPlayer,
    this.onPlayVideo,
    this.isLoadingUrl,
  });

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  bool _isPlaying = false;
  bool _isMuted = true;
  VoidCallback? _listener;

  @override
  void initState() {
    super.initState();
    _initPlayerListeners();
  }

  @override
  void didUpdateWidget(VideoMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _resetState();
      _initPlayerListeners();
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    final controller = _getController();
    if (controller != null && _listener != null) {
      controller.removeListener(_listener!);
    }
    _listener = null;
  }

  void _resetState() {
    _isPlaying = false;
    _isMuted = true;
  }

  void _initPlayerListeners() {
    _removeListener();
    final controller = _getController();
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
    if (widget.videoPlayer == null) return null;
    final c = widget.videoPlayer as VideoPlayerController;
    if (!c.value.isInitialized) return null;
    return c;
  }

  bool _isMyController() {
    final controller = _getController();
    if (controller == null) return false;
    return controller.dataSource == widget.content;
  }

  Future<void> _togglePlayPause() async {
    if (widget.videoPlayer == null && widget.onPlayVideo != null) {
      await widget.onPlayVideo!(widget.content);
      return;
    }
    final controller = _getController();
    if (controller == null) return;
    if (!_isMyController()) {
      if (widget.onPlayVideo != null) {
        await widget.onPlayVideo!(widget.content);
      }
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
      DebugConfig.error('VideoBubble: playback error msg=${widget.messageId}',
          data: e, exception: s);
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
    final isLoading = widget.content == widget.isLoadingUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bubbleMaxWidth = constraints.maxWidth * 0.75;
          return Column(
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
              if (widget.replyTo != null)
                ReplyPreview(
                  replyTo: widget.replyTo!,
                  isMe: widget.isMe,
                  isGroupChat: widget.isGroupChat,
                ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  BubbleLongPressWrapper(
                    isMe: widget.isMe,
                    canEdit: false,
                    onReply: widget.onReply,
                    onDelete: widget.onDelete,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: bubbleBorderRadius,
                      ),
                      child: ClipRRect(
                        borderRadius: bubbleBorderRadius,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _togglePlayPause,
                              child: SizedBox(
                                width: bubbleMaxWidth,
                                height: bubbleMaxWidth * 9 / 16,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isMyController && controller != null)
                                      VideoPlayer(controller)
                                    else
                                      Container(
                                        color: Colors.black38,
                                        child: isLoading
                                            ? const CircularProgressIndicator(
                                                color: Colors.white70,
                                              )
                                            : const Icon(
                                                Icons.movie_creation_outlined,
                                                size: 48,
                                                color: Colors.white70,
                                              ),
                                      ),
                                    if (!isLoading)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          _isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          size: 36,
                                          color: Colors.white,
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '$totalMin:$totalSecStr',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isMyController)
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: GestureDetector(
                                          onTap: _toggleMute,
                                          child: Icon(
                                            _isMuted
                                                ? Icons.volume_off
                                                : Icons.volume_up,
                                            color: Colors.white70,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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
              Padding(
                padding: EdgeInsets.only(
                  top: 2,
                  left: widget.isMe ? 0 : 14,
                  right: widget.isMe ? 14 : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 10,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      widget.timeStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              MessageReactionsRow(
                chatId: widget.chatId,
                reactions: widget.reactions,
                currentUid: widget.currentUid,
                messageId: widget.messageId,
                isMe: widget.isMe,
                onReact: widget.onReact,
                onRemove: widget.onRemove,
              ),
            ],
          );
        },
      ),
    );
  }
}
