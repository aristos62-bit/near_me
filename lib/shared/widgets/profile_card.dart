import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/discovery/providers/status_provider.dart';
import '../../core/l10n/l10n.dart';
import '../../core/debug/debug_config.dart';
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
    DebugConfig.log(DebugConfig.presence,
        'ProfileCard uid=${profile.uid} isOnline=$isOnline (stream=$streamOnline profile=${profile.isOnline})');
    return SizedBox(
      width: width ?? 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatar(theme),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.nickname ?? 'Unknown',
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
                      Row(
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
                    if (distanceKm != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _distanceLabel(distanceKm!, isGreek, profile.geoHash),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (profile.age != null)
                      Text(
                        '${profile.age} years',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final avatarUrl = profile.avatarUrl;
    DebugConfig.log(DebugConfig.uiRebuild,
        'ProfileCard._buildAvatar: uid=${profile.uid}, avatarUrl=${avatarUrl != null && avatarUrl.isNotEmpty ? "present (${avatarUrl.length} chars)" : "null or empty"}');
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, _) => _avatarPlaceholder(theme),
        errorWidget: (_, _, _) => _avatarPlaceholder(theme),
      );
    }
    return _avatarPlaceholder(theme);
  }

  Widget _avatarPlaceholder(ThemeData theme) {
    return Container(
      height: 120,
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _distanceLabel(double km, bool isGreek, String? geoHash) {
    final dist = L10n.distanceText(km, metric: true);
    if (geoHash != null && geoHash.length >= 5) {
      return isGreek ? 'Απόσταση Συνοικίας εντός: $dist' : 'Distance within Neighborhood: $dist';
    }
    return isGreek ? 'Απόσταση Πόλης εντός: $dist' : 'Distance within City: $dist';
  }
}
