import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/debug/debug_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/read_receipt_indicator.dart';
import '../../../settings/providers/app_settings_provider.dart';
import '../../providers/chat_provider.dart';
import 'bubble_long_press_wrapper.dart';
import '../message_reactions.dart';

import 'reply_preview.dart';
import 'sender_header.dart';
import 'tail_painter.dart';

class GifImageBubble extends ConsumerWidget {
  final String content;
  final double bubbleMaxWidth;
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
  final bool isImage;
  final String? racyLevel;
  final Map<String, dynamic> reactions;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onReply;
  final VoidCallback? onReplyPrivately;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onInfo;
  final VoidCallback? onEmail;
  final VoidCallback? onShare;

  const GifImageBubble({
    super.key,
    required this.content,
    required this.bubbleMaxWidth,
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
    this.isImage = false,
    this.racyLevel,
    this.reactions = const {},
    this.onReact,
    this.onRemove,
    this.replyTo,
    this.onReply,
    this.onReplyPrivately,
    this.onEdit,
    this.onDelete,
    this.onInfo,
    this.onEmail,
    this.onShare,
  });

  static const double _bubbleRadius = 20;
  static const double _tailRadius = 8;
  static const Color _sentColor = AppColors.chatBubbleSent;

  static void _showImageFullScreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, _) => const CircularProgressIndicator(),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _showGallery(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _PhotoGalleryViewer(imageUrls: urls, initialIndex: initialIndex),
      ),
    );
  }

  void _openImagePreview(BuildContext context, WidgetRef ref) {
    final chatId = this.chatId;
    if (chatId == null || chatId.isEmpty) {
      _showImageFullScreen(context, content);
      return;
    }
    final msgs = ref.read(combinedMessagesProvider(chatId));
    final urls = msgs
        .where(
          (m) =>
              m['type'] == 'image' &&
              ((m['content'] as String?) ?? '').isNotEmpty,
        )
        .map((m) => m['content'] as String)
        .toList();
    final idx = urls.indexOf(content);
    DebugConfig.log(
      DebugConfig.uiInteraction,
      'GifImageBubble: image tap idx=$idx of ${urls.length} chat=$chatId',
    );
    if (urls.isEmpty) {
      _showImageFullScreen(context, content);
      return;
    }
    _showGallery(context, urls, idx < 0 ? 0 : idx);
  }

  Widget _buildMediaImage(ThemeData theme, {required bool applyBlur}) {
    final image = CachedNetworkImage(
      imageUrl: content,
      fit: BoxFit.cover,
      placeholder: (_, _) => SizedBox(
        width: 200,
        height: 200,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isMe ? Colors.white : theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      errorWidget: (_, _, _) => SizedBox(
        width: 200,
        height: 200,
        child: Icon(
          Icons.broken_image,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    if (!applyBlur) return image;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: image,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showTail = isLastInGroup;
    final sentColor = _sentColor;
    final receivedColor = theme.colorScheme.surfaceContainerHighest;
    final bubbleColor = isMe ? sentColor : receivedColor;
    final blurOn = ref.watch(appSettingsProvider
        .select((a) => a.value?.blurExplicitEnabled ?? FeatureFlags.blurExplicitByDefault));
    final applyBlur = blurOn &&
        (racyLevel == 'POSSIBLE' || racyLevel == 'LIKELY');

    final bubbleBorderRadius = BorderRadius.only(
      topLeft: const Radius.circular(_bubbleRadius),
      topRight: const Radius.circular(_bubbleRadius),
      bottomLeft: Radius.circular(
        (!isMe && showTail) ? _tailRadius : _bubbleRadius,
      ),
      bottomRight: Radius.circular(
        (isMe && showTail) ? _tailRadius : _bubbleRadius,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe &&
              showAvatar &&
              (senderAvatarUrl != null || senderNickname != null))
            SenderHeader(
              senderAvatarUrl: senderAvatarUrl,
              senderNickname: senderNickname,
              isGroupChat: isGroupChat,
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isMe)
                ReactionTriggerIcon(
                  chatId: chatId,
                  messageId: messageId,
                  reactions: reactions,
                  currentUid: currentUid,
                  isMe: isMe,
                  onReact: onReact,
                  onRemove: onRemove,
                ),
              Stack(
            clipBehavior: Clip.none,
            children: [
              BubbleLongPressWrapper(
                isMe: isMe,
                isGroupChat: isGroupChat,
                isSenderBlockedByMe: isSenderBlockedByMe,
                onReply: onReply,
                onReplyPrivately: onReplyPrivately,
                onEdit: onEdit,
                onDelete: onDelete,
                onInfo: onInfo,
                onEmail: onEmail,
                onShare: onShare,
                child: GestureDetector(
                  onTap: isImage ? () => _openImagePreview(context, ref) : null,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: bubbleMaxWidth,
                      maxHeight: 200,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: bubbleBorderRadius,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (replyTo != null)
                          BubbleQuoteSection(
                            replyTo: replyTo,
                            bubbleColor: bubbleColor,
                            isGroupChat: isGroupChat,
                          ),
                        _buildMediaImage(theme, applyBlur: applyBlur),
                  ],
                  ),
                ),
              ),
            ),
              if (showTail)
                Positioned(
                  bottom: 0,
                  right: isMe ? -8 : null,
                  left: !isMe ? -8 : null,
                  child: CustomPaint(
                    painter: TailPainter(color: bubbleColor),
                    size: const Size(10, 8),
                  ),
                ),
            ],
          ),
              if (!isMe)
                ReactionTriggerIcon(
                  chatId: chatId,
                  messageId: messageId,
                  reactions: reactions,
                  currentUid: currentUid,
                  isMe: isMe,
                  onReact: onReact,
                  onRemove: onRemove,
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 2,
              left: isMe ? 0 : 14,
              right: isMe ? 14 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                ReadReceiptIndicator(
                  isGroupChat: isGroupChat,
                  isMe: isMe,
                  isRead: isRead,
                  seenBy: seenBy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGalleryViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _PhotoGalleryViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<_PhotoGalleryViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  final TransformationController _zoomCtrl = TransformationController();
  late final AnimationController _zoomAnimCtrl;
  late int _current;
  bool _wasZoomed = false;
  Size _viewport = Size.zero;
  Matrix4? _zoomFrom;
  Matrix4? _zoomTo;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _zoomAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(_onZoomAnimTick);
    _zoomCtrl.addListener(_onZoomChanged);
    DebugConfig.log(
      DebugConfig.uiInteraction,
      'PhotoGalleryViewer: open idx=${widget.initialIndex} of ${widget.imageUrls.length}',
    );
  }

  @override
  void dispose() {
    _zoomAnimCtrl.removeListener(_onZoomAnimTick);
    _zoomAnimCtrl.dispose();
    _zoomCtrl.removeListener(_onZoomChanged);
    _zoomCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onZoomAnimTick() {
    final from = _zoomFrom;
    final to = _zoomTo;
    if (from == null || to == null) return;
    final t = Curves.easeOut.transform(_zoomAnimCtrl.value);
    _zoomCtrl.value = Matrix4Tween(begin: from, end: to).transform(t);
  }

  static Matrix4 _centeredZoom(Size size, double scale) {
    return Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
  }

  void _toggleZoom() {
    final currentScale = _zoomCtrl.value.getMaxScaleOnAxis();
    _zoomFrom = _zoomCtrl.value;
    _zoomTo = currentScale > 1.0
        ? Matrix4.identity()
        : _centeredZoom(_viewport, 2.5);
    _zoomAnimCtrl.forward(from: 0);
    DebugConfig.log(
      DebugConfig.uiInteraction,
      'PhotoGalleryViewer: double-tap zoom -> '
      '${currentScale > 1.0 ? "out" : "in"}',
    );
  }

  void _onZoomChanged() {
    final zoomed = _zoomCtrl.value.getMaxScaleOnAxis() > 1.0;
    if (zoomed != _wasZoomed) {
      _wasZoomed = zoomed;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_current + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          _viewport = constraints.biggest;
          return PageView.builder(
            controller: _pageCtrl,
            physics: _wasZoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) {
              setState(() => _current = i);
              _zoomAnimCtrl.stop();
              _zoomFrom = null;
              _zoomTo = null;
              _zoomCtrl.value = Matrix4.identity();
              _wasZoomed = false;
              DebugConfig.log(
                DebugConfig.uiInteraction,
                'PhotoGalleryViewer: page -> $i',
              );
            },
            itemBuilder: (_, i) => GestureDetector(
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _zoomCtrl,
                maxScale: 5,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[i],
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const CircularProgressIndicator(),
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
