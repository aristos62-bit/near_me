import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/discovery/providers/status_provider.dart';
import '../../core/l10n/l10n.dart';
import '../models/public_profile.dart';
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
    return SizedBox(
      width: width ?? 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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

  Widget _buildAvatar(ThemeData theme) {
    final avatarUrl = profile.avatarUrl;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: ClipOval(
        child: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => _avatarPlaceholder(theme),
                errorWidget: (_, _, _) => _avatarPlaceholder(theme),
              )
            : _avatarPlaceholder(theme),
      ),
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
}
