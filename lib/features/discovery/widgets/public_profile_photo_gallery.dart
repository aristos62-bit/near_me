import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/models/public_profile.dart';
import '../../../shared/utils/avatar_blur.dart';
import '../../settings/providers/app_settings_provider.dart';
import 'public_profile_sections.dart';

class PublicProfilePhotoGallery extends ConsumerWidget {
  final PublicProfile profile;

  const PublicProfilePhotoGallery({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGreek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final photos = profile.photoUrls!.take(9).toList();
    // SPoT blurOn/sigma — μία φορά έξω από itemBuilder (όχι per-item watch, storm fix Session 224)
    final blurOn = ref.watch(appSettingsProvider
        .select((a) => a.value?.blurExplicitEnabled ?? FeatureFlags.blurExplicitByDefault));
    final blurSigma = ref.watch(
        appSettingsProvider.select((a) => a.value?.blurSigma ?? 12.0));
    return buildProfileSectionCard(
      context,
      icon: Icons.photo_library_outlined,
      title: isGreek ? 'Φωτογραφίες' : 'Photos',
      child: SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (ctx, i) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final racyLevels = profile.photoRacyLevels;
            final level =
                (racyLevels != null && i < racyLevels.length) ? racyLevels[i] : null;
            final image = CachedNetworkImage(
              imageUrl: photos[i],
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              placeholder: (ctx, url) => Container(width: 100, height: 100,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant.withAlpha(80))),
              errorWidget: (ctx, url, err) => Container(width: 100, height: 100,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant.withAlpha(80))),
            );
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: (blurOn && isRacyLevel(level))
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                      child: image,
                    )
                  : image,
            );
          },
        ),
      ),
    );
  }
}
