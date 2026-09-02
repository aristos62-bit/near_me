import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/debug/debug_config.dart';
import '../../core/l10n/l10n.dart';
import '../utils/avatar_blur.dart';

/// SPoT — Εικόνα με blur και ρητό tap-to-reveal (για gallery/fullscreen).
/// Αν (racyLevel δικαιολογεί && blurEnabled && sigma>0) η εικόνα εμφανίζεται
/// θολή μαζί με κουμπί «Εμφάνιση». Το tap στο κουμπί/σκιά ξεθολώνει ΜΟΝΟ αυτή
/// την εικόνα μέχρι να κλείσει ο viewer. Zoom/pan του γονικού InteractiveViewer
/// διατηρούνται (burst σε ξεχωριστό route → κανένα cascade στο message list).
class BlurRevealImage extends StatefulWidget {
  final String imageUrl;
  final String? racyLevel;
  final bool blurEnabled;
  final double blurSigma;
  final BoxFit fit;

  const BlurRevealImage({
    super.key,
    required this.imageUrl,
    this.racyLevel,
    this.blurEnabled = false,
    this.blurSigma = 12.0,
    this.fit = BoxFit.contain,
  });

  @override
  State<BlurRevealImage> createState() => _BlurRevealImageState();
}

class _BlurRevealImageState extends State<BlurRevealImage> {
  bool _revealed = false;

  bool get _shouldBlur =>
      widget.blurEnabled &&
      isRacyLevel(widget.racyLevel) &&
      widget.blurSigma > 0 &&
      !_revealed;

  Widget _baseImage() => CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: widget.fit,
        placeholder: (_, _) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (_, _, _) => const Icon(
          Icons.broken_image,
          color: Colors.white,
        ),
      );

  void _reveal() {
    DebugConfig.log(
      DebugConfig.moderation,
      'BlurRevealImage: reveal url=${widget.imageUrl} racy=${widget.racyLevel}',
    );
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldBlur) return _baseImage();

    return GestureDetector(
      onTap: _reveal,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
            ),
            child: _baseImage(),
          ),
          Container(
            color: Colors.black38,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_off, size: 40, color: Colors.white70),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    L10n.blurRevealButton(isGreek: L10n.isGreek(context)),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
