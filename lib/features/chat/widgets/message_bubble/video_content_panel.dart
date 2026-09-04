import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/utils/avatar_blur.dart';

/// Το περιεχόμενο του video bubble (ClipRRect με thumb/video + controls).
/// Εξήχθη ακριβώς από το video_message_bubble.dart χωρίς αλλαγή συμπεριφοράς.
class VideoContentPanel extends StatelessWidget {
  final BorderRadius bubbleBorderRadius;
  final VideoPlayerController? controller;
  final bool isMyController;
  final String? thumbnailUrl;
  final bool isLoading;
  final double aspectRatio;
  final bool isPlaying;
  final bool isMuted;
  final double maxWidth;
  final bool blurEnabled;
  final String? videoRacyLevel;
  final double blurSigma;
  final String durationLabel;
  final VoidCallback onTap;
  final VoidCallback onToggleMute;

  const VideoContentPanel({
    super.key,
    required this.bubbleBorderRadius,
    required this.controller,
    required this.isMyController,
    required this.thumbnailUrl,
    required this.isLoading,
    required this.aspectRatio,
    required this.isPlaying,
    required this.isMuted,
    required this.maxWidth,
    required this.blurEnabled,
    required this.videoRacyLevel,
    required this.blurSigma,
    required this.durationLabel,
    required this.onTap,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: bubbleBorderRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: maxWidth,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isMyController && controller != null)
                      VideoPlayer(controller!)
                    else if (thumbnailUrl != null)
                      Stack(
                        alignment: Alignment.center,
                        fit: StackFit.expand,
                        children: [
                          wrapAvatarBlur(
                            blurOn: blurEnabled,
                            racyLevel: videoRacyLevel,
                            sigma: blurSigma,
                            child: CachedNetworkImage(
                              imageUrl: thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                color: Colors.black38,
                                child: const Icon(
                                  Icons.movie_creation_outlined,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          if (isLoading)
                            const CircularProgressIndicator(
                              color: Colors.white70,
                            ),
                        ],
                      )
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
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          durationLabel,
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
                          onTap: onToggleMute,
                          child: Icon(
                            isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
