import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../../../core/debug/debug_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/app_messenger.dart';
import '../../../../core/utils/error_messages.dart';
import 'bubble_long_press_wrapper.dart';
import 'message_reactions_row.dart';
import 'reply_preview.dart';
import 'sender_header.dart';
import 'tail_painter.dart';

class AudioMessageBubble extends StatefulWidget {
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
  final AudioPlayer? audioPlayer;

  const AudioMessageBubble({
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
    this.audioPlayer,
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initPlayerListeners();
  }

  @override
  void didUpdateWidget(AudioMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _resetState();
      _initPlayerListeners();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    super.dispose();
  }

  void _resetState() {
    _isPlaying = false;
    _position = Duration.zero;
    _progress = 0.0;
  }

  void _initPlayerListeners() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();

    final player = widget.audioPlayer;
    if (player == null) return;

    _positionSub = player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      if (!_isMySource(player)) return;
      setState(() {
        _position = pos;
        if (widget.duration > 0) {
          _progress = pos.inMilliseconds / (widget.duration * 1000).clamp(1, double.infinity);
        }
      });
    });

    _playerStateSub = player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      if (!_isMySource(player)) {
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
          _position = Duration.zero;
        });
        return;
      }
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
          _position = Duration.zero;
        });
      } else if (state == PlayerState.playing) {
        setState(() => _isPlaying = true);
      } else {
        setState(() => _isPlaying = false);
      }
    });
  }

  bool _isMySource(AudioPlayer player) {
    final source = player.source;
    return source is UrlSource && source.url == widget.content;
  }

  Future<void> _togglePlayPause() async {
    final player = widget.audioPlayer;
    if (player == null) return;

    try {
      if (_isPlaying) {
        await player.pause();
        DebugConfig.log(DebugConfig.chatAudio, 'AudioBubble: pause msg=${widget.messageId}');
      } else {
        await player.stop();
        await player.play(UrlSource(widget.content));
        DebugConfig.log(DebugConfig.chatAudio, 'AudioBubble: play msg=${widget.messageId}');
      }
    } catch (e, s) {
      DebugConfig.error('AudioBubble: playback error msg=${widget.messageId}', data: e, exception: s);
      if (mounted) {
        AppMessenger.showError(context,
            ErrorMessages.get('chat/audio-playback-error', L10n.isGreek(context)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTail = widget.isLastInGroup;
    final bubbleColor = widget.isMe
        ? theme.colorScheme.primaryContainer
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
    final posSec = _position.inSeconds;
    final posMin = (posSec ~/ 60).toString().padLeft(2, '0');
    final posSecStr = (posSec % 60).toString().padLeft(2, '0');

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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _togglePlayPause,
                            icon: Icon(
                              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              size: 32,
                              color: widget.isMe
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _progress,
                                    minHeight: 4,
                                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      widget.isMe
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_isPlaying ? "$posMin:$posSecStr / " : ""}$totalMin:$totalSecStr',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
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
              MessageReactionsRow(
                chatId: widget.chatId,
                reactions: widget.reactions,
                currentUid: widget.currentUid,
                messageId: widget.messageId,
                isMe: widget.isMe,
                onReact: widget.onReact,
                onRemove: widget.onRemove,
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
            ],
          );
        },
      ),
    );
  }
}
