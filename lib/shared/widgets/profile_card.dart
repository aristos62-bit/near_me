import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/discovery/providers/status_provider.dart';
import '../../core/config/feature_flags.dart';
import '../../core/l10n/l10n.dart';
import '../../features/settings/providers/app_settings_provider.dart';
import '../models/public_profile.dart';
import '../utils/avatar_blur.dart';
import '../utils/help_request_config.dart';
import 'online_indicator.dart';

class ProfileCard extends ConsumerWidget {
  final PublicProfile profile;
  final VoidCallback? onTap;
  final double? width;
  final double? distanceKm;

  const ProfileCard({
    super.key,
    required this.profile,
    this.onTap,
    this.width,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isGreek = L10n.isGreek(context);
    final statusAsync = ref.watch(userStatusProvider(profile.uid));
    final streamOnline = statusAsync.value?.isOnline;
    final isOnline = streamOnline ?? profile.isOnline;
    final isUrgent = _isUrgentSos();
    return SizedBox(
      width: width ?? 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: isUrgent
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.error, width: 2),
              )
            : null,
        color: isUrgent
            ? theme.colorScheme.errorContainer.withAlpha(60)
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(theme, ref),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUrgent) ...[
                        _buildSosBanner(theme, isGreek),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.nickname ?? L10n.unknownName(isGreek: isGreek),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          OnlineIndicator(isOnline: isOnline, size: 8),
                          const SizedBox(width: 3),
                          Text(
                            L10n.onlineLabel(isOnline, isGreek: isGreek),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isOnline
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (profile.city != null && profile.city!.isNotEmpty
                          || profile.country != null && profile.country!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  [profile.city, profile.country]
                                      .where((e) => e != null && e.isNotEmpty)
                                      .join(', '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                profile.isManualLocation ? Icons.help : Icons.check_circle,
                                size: 13,
                                color: profile.isManualLocation
                                    ? theme.colorScheme.error
                                    : const Color(0xFF4CAF50),
                              ),
                            ],
                          ),
                        ),
                      if (distanceKm != null || profile.age != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              if (distanceKm != null)
                                Text(
                                  L10n.distanceLabel(distanceKm!, profile.geoHash, isGreek: isGreek),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (distanceKm != null && profile.age != null)
                                Text(
                                  '·',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (profile.age != null)
                                Text(
                                  L10n.ageLabel(profile.age!, isGreek: isGreek),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (profile.lookingFor != null && profile.lookingFor!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search, size: 12, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    L10n.lookingForLabel(profile.lookingFor!, isGreek: isGreek),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, WidgetRef ref) {
    final avatarUrl = profile.avatarUrl;
    final blurOn = ref.watch(appSettingsProvider
        .select((a) => a.value?.blurExplicitEnabled ?? FeatureFlags.blurExplicitByDefault));
    final blurSigma = ref.watch(
        appSettingsProvider.select((a) => a.value?.blurSigma ?? 12.0));
    final applyBlur = blurOn && isRacyLevel(profile.avatarRacyLevel);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: ClipOval(
        child: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? (applyBlur
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                    child: _buildAvatarImage(theme),
                  )
                : _buildAvatarImage(theme))
            : _avatarPlaceholder(theme),
      ),
    );
  }

  Widget _buildAvatarImage(ThemeData theme) {
    return CachedNetworkImage(
      imageUrl: profile.avatarUrl!,
      fit: BoxFit.cover,
      placeholder: (_, _) => _avatarPlaceholder(theme),
      errorWidget: (_, _, _) => _avatarPlaceholder(theme),
    );
  }

  Widget _avatarPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: 32,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Pure read-only SOS check (§6.2) — active && updatedAt εντός TTL &&
  /// distanceKm != null && distanceKm <= radiusKm. Καμία νέα reactive dependency.
  bool _isUrgentSos() {
    final h = profile.helpRequest;
    if (h == null || !h.active || h.updatedAt == null) return false;
    final now = DateTime.now();
    if (now.difference(h.updatedAt!) > HelpRequestConfig.ttl) return false;
    if (distanceKm == null) return false;
    return distanceKm! <= h.radiusKm;
  }

  Widget _buildSosBanner(ThemeData theme, bool isGreek) {
    final h = profile.helpRequest;
    final message = h?.message;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sos, size: 13, color: theme.colorScheme.onError),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  L10n.needsHelpLabel(isGreek: isGreek),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onError,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (message != null && message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onError,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
