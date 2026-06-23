import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../shared/widgets/profile_card.dart';
import '../../profile/providers/location_service.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/filters_provider.dart';
import '../providers/search_provider.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  bool _isDetecting = false;
  bool _hasAttemptedAutoSearch = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'DiscoveryScreen init');
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSearch());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  Future<void> _autoSearch() async {
    if (_hasAttemptedAutoSearch) return;
    await _performSearch();
  }

  Future<void> _performSearch() async {
    if (_isDetecting) return;
    setState(() => _isDetecting = true);

    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;
      if (loc.latitude != null && loc.longitude != null) {
        ref.read(searchFiltersProvider.notifier)
            .updateLocation(loc.latitude!, loc.longitude!, radiusKm: 10);
        ref.read(searchProvider.notifier)
            .searchNearby(loc.latitude!, loc.longitude!, 10);

        final profile = await ref.read(profileRepositoryProvider).getProfile();
        if (profile != null && mounted) {
          final needsCity = profile.city == null || profile.city!.isEmpty;
          final needsCountry = profile.country == null || profile.country!.isEmpty;
          if (needsCity || needsCountry) {
            final name = await LocationService.reverseGeocode(loc.latitude!, loc.longitude!);
            if (name != null && mounted) {
              DebugConfig.log(DebugConfig.gpsLocation,
                  'Auto-fill: city=${name.city}, country=${name.country}');
              await ref.read(profileRepositoryProvider).saveProfile(
                profile.copyWith(
                  city: needsCity ? Value(name.city) : Value.absent(),
                  country: needsCountry ? Value(name.country) : Value.absent(),
                ),
              );
              if (profile.isPublished && mounted) {
                DebugConfig.log(DebugConfig.repositoryCall,
                    'Auto-fill: published profile — auto-publishing');
                await ref.read(profileRepositoryProvider).publish();
              }
            }
          } else if (profile.isPublished) {
            final name = await LocationService.reverseGeocode(loc.latitude!, loc.longitude!);
            if (name != null && mounted) {
              final cityDiff = name.city != null && name.city != profile.city;
              final countryDiff = name.country != null && name.country != profile.country;
              if (cityDiff || countryDiff) {
                DebugConfig.log(DebugConfig.gpsLocation,
                    'Auto-sync: city=${name.city}, country=${name.country} (was city=${profile.city}, country=${profile.country})');
                await ref.read(profileRepositoryProvider).saveProfile(
                  profile.copyWith(
                    city: cityDiff ? Value(name.city) : Value.absent(),
                    country: countryDiff ? Value(name.country) : Value.absent(),
                  ),
                );
                await ref.read(profileRepositoryProvider).publish();
              }
            }
          }
        }
      } else if (!mounted) {
        return;
      } else {
        final isGreek = L10n.isGreek(context);
        final msg = _locationFailureMessage(loc.failure, isGreek);
        if (msg != null) AppMessenger.showInfo(context, msg);
      }
    } catch (e, s) {
      DebugConfig.error('DiscoveryScreen location/search failed', data: e, exception: s);
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false;
          _hasAttemptedAutoSearch = true;
        });
      }
    }
  }

  String? _locationFailureMessage(LocationFailure f, bool isGreek) {
    switch (f) {
      case LocationFailure.serviceDisabled:
        return isGreek
            ? 'Η υπηρεσία τοποθεσίας είναι απενεργοποιημένη'
            : 'Location services are disabled';
      case LocationFailure.permissionDenied:
        return isGreek
            ? 'Η άδεια τοποθεσίας δεν δόθηκε'
            : 'Location permission was denied';
      case LocationFailure.permissionDeniedForever:
        return isGreek
            ? 'Η άδεια τοποθεσίας απορρίφθηκε μόνιμα. Πήγαινε στις Ρυθμίσεις'
            : 'Location permission denied permanently. Go to Settings';
      case LocationFailure.timeout:
        return isGreek
            ? 'Ο εντοπισμός απέτυχε (timeout). Δοκίμασε ξανά'
            : 'Location timed out. Try again';
      case LocationFailure.error:
        return isGreek
            ? 'Σφάλμα κατά τον εντοπισμό τοποθεσίας'
            : 'Error detecting location';
      default:
        return null;
    }
  }

  Future<void> _onRefresh() async {
    final s = ref.read(searchProvider);
    if (s.status == SearchStatus.idle) {
      await _performSearch();
    } else {
      ref.read(searchProvider.notifier).search();
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final theme = Theme.of(context);
    final isGreek = L10n.isGreek(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isGreek ? 'Ανακάλυψη' : 'Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => context.push('/discovery/saved-searches'),
            tooltip: isGreek ? 'Αποθηκευμένες' : 'Saved',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => context.push('/discovery/filters'),
            tooltip: isGreek ? 'Φίλτρα' : 'Filters',
          ),
        ],
      ),
      body: _buildBody(searchState, theme, isGreek),
    );
  }

  Widget _buildBody(SearchState state, ThemeData theme, bool isGreek) {
    switch (state.status) {
      case SearchStatus.idle:
        return _buildSearchPrompt(theme, isGreek);
      case SearchStatus.loading:
        if (state.results.isNotEmpty) {
          return _buildResultsList(state, isGreek, isLoadingMore: true);
        }
        return Center(
          child: LoadingView(
            message: isGreek ? 'Αναζήτηση...' : 'Searching...',
          ),
        );
      case SearchStatus.success:
        if (state.results.isEmpty) {
          return Center(
            child: EmptyView(
              icon: Icons.search_off,
              message: isGreek
                  ? 'Δεν βρέθηκαν αποτελέσματα'
                  : 'No results found',
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: _buildResultsList(state, isGreek),
        );
      case SearchStatus.error:
        return Center(
          child: ErrorView(
            message: L10n.localizedMessage(context, state.errorMessage ??
                'Κάτι πήγε στραβά / Something went wrong'),
            onRetry: _onRefresh,
          ),
        );
    }
  }

  Widget _buildSearchPrompt(ThemeData theme, bool isGreek) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 72,
                color: theme.colorScheme.primary.withAlpha(80)),
            const SizedBox(height: 20),
            Text(
              isGreek ? 'Αναζήτησε άτομα κοντά σου' : 'Find people near you',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isDetecting ? null : _performSearch,
              icon: _isDetecting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search, size: 20),
              label: Text(_isDetecting
                  ? (isGreek ? 'Εντοπισμός...' : 'Locating...')
                  : (isGreek ? 'Αναζήτηση' : 'Search')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(SearchState state, bool isGreek, {bool isLoadingMore = false}) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final hPad = ResponsiveUtils.horizontalPadding(context);

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad.left, 12, hPad.right, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: state.results.map((p) {
            return ProfileCard(
              profile: p,
              width: isMobile ? double.infinity : 180,
              onTap: () => context.push('/user/${p.uid}'),
            );
          }).toList(),
        ),
        if (isLoadingMore || state.hasMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }
}
