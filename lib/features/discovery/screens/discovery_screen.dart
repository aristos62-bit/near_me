import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../shared/widgets/gps_strength_indicator.dart';
import '../widgets/search_results_grid.dart';
import '../../profile/providers/location_service.dart';
import '../../profile/providers/profile_provider.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../providers/filters_provider.dart';
import '../providers/search_provider.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  // ── State flags ────────────────────────────────────────────────
  bool _isDetecting = false;
  bool _hasAttemptedAutoSearch = false; // τίθεται ΑΜΕΣΩΣ για race-condition fix
  DateTime? _lastAutoPublish;
  double _defaultRadius = 10.0;           // debounce για auto-publish

  static const _locationDebounce = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'DiscoveryScreen init');
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSearch());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _autoSearch() async {
    if (_hasAttemptedAutoSearch) {
      DebugConfig.log(DebugConfig.uiInteraction, '_autoSearch: skipped (already attempted)');
      return;
    }
    _hasAttemptedAutoSearch = true;
    DebugConfig.log(DebugConfig.uiInteraction, '_autoSearch: starting');
    await _performSearch();
  }

  Future<void> _performSearch() async {
    if (_isDetecting) return;
    if (mounted) setState(() => _isDetecting = true);

    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;

      if (loc.latitude != null && loc.longitude != null) {
        ref
            .read(searchFiltersProvider.notifier)
            .updateLocation(loc.latitude!, loc.longitude!, radiusKm: _defaultRadius);
        final activeFilters = ref.read(searchFiltersProvider);
        DebugConfig.log(DebugConfig.uiInteraction,
            'DiscoveryScreen: search() radius=$_defaultRadius km, '
                'filters=[gender=${activeFilters.gender}, '
                'age=${activeFilters.minAge}-${activeFilters.maxAge}, '
                'city=${activeFilters.city}, country=${activeFilters.country}, '
                'interests=${activeFilters.interests?.length}, '
                'lookingFor=${activeFilters.lookingFor}]');
        ref
            .read(searchProvider.notifier)
            .search();

        await _syncLocation(loc.latitude!, loc.longitude!);
      } else {
        final isGreek = L10n.isGreek(context);
        final msg = _locationFailureMessage(loc.failure, isGreek);
        if (msg != null && mounted) AppMessenger.showInfo(context, msg);
      }
    } catch (e, s) {
      DebugConfig.error('DiscoveryScreen location/search failed',
          data: e, exception: s);
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  /// Αποθηκεύει νέα τοποθεσία στο Drift (πάντα) και, αν το profile
  /// είναι published + εκτός debounce, κάνει publish στο Firestore.
  Future<void> _syncLocation(double lat, double lng) async {
    final now = DateTime.now();
    final withinDebounce = _lastAutoPublish != null &&
        now.difference(_lastAutoPublish!) < _locationDebounce;

    if (withinDebounce) {
      DebugConfig.log(DebugConfig.gpsLocation,
          '_syncLocation: within debounce (${now.difference(_lastAutoPublish!).inMinutes}min < ${_locationDebounce.inMinutes}min) — skip geocode+publish');
      try {
        await ref.read(profileRepositoryProvider).syncLocation(lat, lng);
      } catch (e, s) {
        DebugConfig.error('_syncLocation (debounced) failed', data: e, exception: s);
      }
      return;
    }

    try {
      final name = await LocationService.reverseGeocode(lat, lng);
      if (!mounted) return;

      await ref.read(profileRepositoryProvider).syncLocation(
        lat, lng,
        city: name?.city,
        country: name?.country,
      );

      final profile = await ref.read(profileRepositoryProvider).getProfile();
      if (!mounted) return;

      if (profile?.isPublished == true) {
        _lastAutoPublish = now;
        await ref.read(profileRepositoryProvider).publish();
        DebugConfig.log(DebugConfig.firestoreWrite,
            '_syncLocation: auto-publish OK (lat=$lat, lng=$lng, city=${name?.city}, country=${name?.country})');
      }
    } catch (e, s) {
      DebugConfig.error('_syncLocation failed', data: e, exception: s);
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
      case LocationFailure.staleData:
        return isGreek
            ? 'Η τοποθεσία είναι παλιά. Βγες σε ανοιχτό χώρο για ανανέωση'
            : 'Location data is stale. Go outside to refresh';
      case LocationFailure.error:
        return isGreek
            ? 'Σφάλμα κατά τον εντοπισμό τοποθεσίας'
            : 'Error detecting location';
      default:
        return null;
    }
  }

  Future<void> _onRefresh() async {
    DebugConfig.log(DebugConfig.uiInteraction, '_onRefresh: triggered — always _performSearch');
    await _performSearch();
  }

  Widget _buildRadiusSelector(bool isGreek) {
    final values = [1.0, 5.0, 10.0, 25.0, 50.0, 100.0];
    return PopupMenuButton<double>(
      tooltip: isGreek ? 'Ακτίνα αναζήτησης' : 'Search radius',
      onSelected: (km) async {
        if (km == _defaultRadius) return;
        setState(() => _defaultRadius = km);
        await ref.read(appSettingsProvider.notifier).setSearchRadius(km);
        await _performSearch();
      },
      itemBuilder: (_) => values.map((km) {
        final label = km >= 10
            ? '${km.toInt()} km'
            : '${km.toStringAsFixed(1)} km';
        return PopupMenuItem<double>(
          value: km,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                km == _defaultRadius
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar, size: 18),
            const SizedBox(width: 2),
            Text(
              '${_defaultRadius >= 10 ? _defaultRadius.toInt().toString() : _defaultRadius.toStringAsFixed(1)} km',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedRadius = ref.watch(
      appSettingsProvider.select((s) => s.asData?.value.searchRadiusKm),
    );
    if (savedRadius != null && mounted) {
      final clamped = savedRadius.clamp(1.0, 100.0);
      if (clamped != _defaultRadius) {
        _defaultRadius = clamped;
        DebugConfig.log(DebugConfig.uiInteraction,
            'DiscoveryScreen: loaded radius=$_defaultRadius km from AppSettings');
      }
    }

    final searchState = ref.watch(searchProvider);
    final theme = Theme.of(context);
    final isGreek = L10n.isGreek(context);

    return Scaffold(
      // ── FIX Πρόβλημα 2 (διορθωμένη θέση) ──
      // Το DiscoveryScreen έχει δικό του Scaffold, ξεχωριστό από του MainShell.
      // Το MediaQuery.viewInsets είναι καθολικό στην εφαρμογή, άρα χωρίς αυτό
      // το flag, όταν ανοίγει το πληκτρολόγιο σε ΑΛΛΗ οθόνη (π.χ. Phone Verify,
      // πάνω από το MainShell), αυτό το Scaffold συρρικνώνει πραγματικά το
      // body του σε κάθε frame του animation — προκαλώντας πλήρες relayout
      // στο ListView/ProfileCard, ενώ ο χρήστης δεν βλέπει καν αυτή την οθόνη.
      // Δεν υπάρχει TextField εδώ, άρα δεν χρειάζεται πραγματικό keyboard resize.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(isGreek ? 'Ανακάλυψη' : 'Discover'),
        actions: [
          const GpsStrengthIndicator(),
          _buildRadiusSelector(isGreek),
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
          return const SearchResultsGrid();
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
          child: const SearchResultsGrid(),
        );
      case SearchStatus.error:
        return Center(
          child: ErrorView(
            message: ErrorMessages.get(state.errorMessage ?? 'search/unknown-error', L10n.isGreek(context)),
            onRetry: _onRefresh,
          ),
        );
    }
  }

  Widget _buildSearchPrompt(ThemeData theme, bool isGreek) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_search,
                        size: 72,
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
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search, size: 20),
                      label: Text(_isDetecting
                          ? (isGreek ? 'Εντοπισμός...' : 'Locating...')
                          : (isGreek ? 'Αναζήτηση' : 'Search')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


}