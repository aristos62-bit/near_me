import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/debug/debug_config.dart';
import '../../../shared/models/public_profile.dart';
import '../../../shared/widgets/online_indicator.dart';
import '../providers/status_provider.dart';

class PublicProfileHeader extends ConsumerWidget {
  final PublicProfile profile;
  final String uid;

  const PublicProfileHeader({
    super.key,
    required this.profile,
    required this.uid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGreek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final headerBody = theme.textTheme.bodyMedium!.copyWith(color: Colors.white.withAlpha(220));
    final headerSmall = theme.textTheme.bodySmall!.copyWith(color: Colors.white.withAlpha(180));
    final statusAsync = ref.watch(userStatusProvider(uid));
    final isOnline = statusAsync.value?.isOnline ?? false;
    DebugConfig.log(DebugConfig.presence,
        'PublicProfileHeader uid=$uid isOnline=$isOnline (stream=${statusAsync.value?.isOnline} fallback=disabled)');

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 20, right: 20, bottom: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 108, height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ClipOval(
                  child: (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: profile.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _avatarPlaceholder(theme),
                          errorWidget: (_, _, _) => _avatarPlaceholder(theme),
                        )
                      : _avatarPlaceholder(theme),
                ),
              ),
              const SizedBox(height: 16),
              Text(profile.nickname ?? 'Unknown', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (profile.age != null) ...[
                    Icon(Icons.cake_outlined, size: 16, color: Colors.white.withAlpha(200)),
                    const SizedBox(width: 4),
                    Text('${profile.age}', style: headerBody),
                    const SizedBox(width: 14),
                  ],
                  if (profile.city != null && profile.city!.isNotEmpty
                      || profile.country != null && profile.country!.isNotEmpty) ...[
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.white.withAlpha(200)),
                    const SizedBox(width: 4),
                    if (profile.city != null && profile.city!.isNotEmpty) ...[
                      Flexible(child: Text(profile.city!, style: headerBody, overflow: TextOverflow.ellipsis)),
                    ],
                    if (profile.city != null && profile.city!.isNotEmpty
                        && profile.country != null && profile.country!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(',', style: headerBody),
                      const SizedBox(width: 4),
                    ],
                    if (profile.country != null && profile.country!.isNotEmpty) ...[
                      Flexible(child: Text(profile.country!, style: headerBody, overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (profile.gender != null && profile.gender!.isNotEmpty)
                    Text(L10n.genderLabel(profile.gender!, isGreek: true), style: headerSmall),
                  if (profile.gender != null && profile.gender!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(120))),
                    const SizedBox(width: 8),
                  ],
                  OnlineIndicator(isOnline: isOnline, size: 10),
                  const SizedBox(width: 4),
                  Text(L10n.onlineLabel(isOnline, isGreek: isGreek), style: headerSmall),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.person, size: 48, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
