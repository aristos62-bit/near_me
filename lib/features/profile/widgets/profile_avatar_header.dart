import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/gradient_header.dart';

/// Move-only από `profile_editor_screen` (Γ7, όριο 500 γραμμών).
class ProfileAvatarHeader extends StatelessWidget {
  final String? avatarUrl;
  final String nickname;
  final bool isUploading;
  final VoidCallback? onTap;
  final bool avatarErrorShown;
  final ValueChanged<bool> onErrorShown;

  const ProfileAvatarHeader({
    super.key,
    required this.avatarUrl,
    required this.nickname,
    required this.isUploading,
    required this.onTap,
    required this.avatarErrorShown,
    required this.onErrorShown,
  });

  @override
  Widget build(BuildContext context) {
    final g = L10n.isGreek(context);
    return GradientHeader(
      gradientColors: [AppColors.primary, AppColors.primaryDark.withAlpha(220)],
      icon: Icons.person,
      title: nickname.isNotEmpty
          ? nickname
          : (g ? 'Το Προφίλ σου' : 'Your Profile'),
      subtitle: g ? 'Πάτα για να προσθέσεις φωτογραφία' : 'Tap to add a photo',
      padding: EdgeInsets.fromLTRB(
          16, ResponsiveUtils.safeAreaPadding(context).top + 8, 16, 24),
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: SizedBox(
              width: 88,
              height: 88,
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _placeholder(g),
                      errorWidget: (ctx, url, err) {
                        DebugConfig.warn('CachedNetworkImage avatar error',
                            data: 'url=$url error=$err');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (ctx.mounted && !avatarErrorShown) {
                            onErrorShown(true);
                            AppMessenger.showError(
                                ctx,
                                ErrorMessages.get(
                                    'profile/photo-load-failed', g));
                          }
                        });
                        return _placeholder(g);
                      },
                    )
                  : _placeholder(g),
            ),
          ),
          if (isUploading)
            Positioned.fill(
                child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black26, shape: BoxShape.circle),
                    child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3)))),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child:
                    Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.primary)),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder(bool g) {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Center(
          child: Text(
              nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary))),
    );
  }
}
