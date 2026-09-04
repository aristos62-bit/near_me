import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../widgets/public_profile_header.dart';
import '../widgets/public_profile_photo_gallery.dart';
import '../widgets/public_profile_sections.dart';
import '../widgets/public_profile_actions.dart';
import '../providers/search_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/utils/geohash_utils.dart';

class PublicProfileViewScreen extends ConsumerStatefulWidget {
  const PublicProfileViewScreen({super.key});

  @override
  ConsumerState<PublicProfileViewScreen> createState() =>
      _PublicProfileViewScreenState();
}

class _PublicProfileViewScreenState extends ConsumerState<PublicProfileViewScreen> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen init');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = GoRouterState.of(context).pathParameters['uid'];
    if (uid != null && uid != _uid) {
      _uid = uid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final isGreek = L10n.isGreek(context);

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(
          child: Text(isGreek ? 'Δεν βρέθηκε χρήστης' : 'User not found'),
        ),
      );
    }

    final profileAsync = ref.watch(publicProfileStreamProvider(uid));

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const LoadingView(),
      ),
      error: (e, s) {
        DebugConfig.error('PublicProfileView stream error', data: e, exception: s);
        return Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: ErrorView(
            message: ErrorMessages.get('stream/load-error', L10n.isGreek(context)),
            onRetry: () => ref.invalidate(publicProfileStreamProvider(uid)),
          ),
        );
      },
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: ErrorView(
              message: L10n.localizedMessage(context, 'Το προφίλ δεν βρέθηκε / Profile not found'),
            ),
          );
        }
        final theme = Theme.of(context);
        final searchState = ref.read(searchProvider);
        // Ζωντανός υπολογισμός από το τρέχον geoHash του προφίλ (live stream)
        // αντί για το "παγωμένο" searchState.distances — ενημερώνεται αμέσως
        // αν ο άλλος χρήστης αλλάξει Ακρίβεια Τοποθεσίας, χωρίς να χρειάζεται
        // νέο search.
        double? distanceKm;
        if (profile.geoHash != null) {
          if (searchState.searchCenterLat != null &&
              searchState.searchCenterLng != null) {
            distanceKm = GeoHashUtils.distanceToPoint(
              profile.geoHash!,
              searchState.searchCenterLat!,
              searchState.searchCenterLng!,
            );
          } else if (searchState.status == SearchStatus.success) {
            // Fallback ΜΟΝΟ όταν υπάρχει πραγματικό geoHash αλλά δεν έχουμε
            // ακόμα live search center σε αυτό το session.
            distanceKm = searchState.distances[uid];
          }
        }
        // Αν profile.geoHash == null (Κρυφό), distanceKm μένει null —
        // ποτέ δεν δείχνουμε παλιά/stale απόσταση για κρυφό προφίλ.
        if (distanceKm != null) {
          DebugConfig.log(DebugConfig.repositoryResult,
              'PublicProfileView uid=$uid distance=${distanceKm.toStringAsFixed(1)}km');
        }
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final w = ResponsiveUtils.resolveWidth(context, constraints);
              return SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: ResponsiveUtils.maxContentWidthFromWidth(w),
                    child: Column(
                  children: [
                    PublicProfileHeader(profile: profile, uid: uid, distanceKm: distanceKm),
                    if (profile.photoUrls != null && profile.photoUrls!.isNotEmpty)
                      PublicProfilePhotoGallery(profile: profile),
                    buildProfileLookingForCard(context, profile, theme, isGreek),
                    buildProfileInterestsCard(context, profile, theme, isGreek),
                    buildProfileBioCard(context, profile, theme, isGreek),
                    buildProfileCommunicationCard(context, profile, theme, isGreek),
                    buildProfileContactCard(context, profile, theme, isGreek, uid),
                    PublicProfileActions(uid: uid, profile: profile),
                  ],
                ),
              ),
            ),
          );
          },
        ),
      );
      },
    );
  }
}
