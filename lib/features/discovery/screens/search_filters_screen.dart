import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/chip_selector.dart';
import '../../../shared/widgets/form_section.dart';
import '../../../shared/widgets/form_toggle.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../providers/filters_provider.dart';
import '../providers/saved_search_provider.dart';
import '../providers/search_provider.dart';

class SearchFiltersScreen extends ConsumerStatefulWidget {
  const SearchFiltersScreen({super.key});

  @override
  ConsumerState<SearchFiltersScreen> createState() =>
      _SearchFiltersScreenState();
}

class _SearchFiltersScreenState extends ConsumerState<SearchFiltersScreen> {
  RangeValues _ageRange = const RangeValues(18, 60);
  String _gender = 'all';
  List<String> _interests = [];
  String _lookingFor = '';
  bool _allowVideoCall = false;
  bool _allowDirectChat = false;
  bool _onlineOnly = false;
  double _radiusKm = 10;
  bool _radiusLimited = false;
  bool _hasLocation = false;
  late TextEditingController _cityCtrl;
  late TextEditingController _countryCtrl;

  static const _genderOptions = [
    'all', 'male', 'female', 'other', 'prefer_not',
  ];
  static const _lookingForOptions = [
    'roommate', 'social', 'friendship', 'networking',
    'exchange', 'help', 'employment',
  ];
  static const _allInterests = [
    'gamer', 'programmer', 'student', 'traveler', 'musician',
    'athlete', 'reader', 'chef', 'artist', 'photographer',
    'hiker', 'yoga', 'movies', 'dancing', 'fashion',
  ];

  @override
  void initState() {
    super.initState();
    _cityCtrl = TextEditingController();
    _countryCtrl = TextEditingController();
    DebugConfig.log(DebugConfig.uiInteraction, 'SearchFiltersScreen init');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFilters());
  }

  void _loadFilters() {
    final f = ref.read(searchFiltersProvider);
    setState(() {
      _ageRange = RangeValues(
        (f.minAge ?? 18).toDouble(),
        (f.maxAge ?? 60).toDouble(),
      );
      _gender = f.gender ?? 'all';
      _interests = List<String>.from(f.interests ?? []);
      _lookingFor = f.lookingFor ?? '';
      _allowVideoCall = f.allowVideoCall ?? false;
      _allowDirectChat = f.allowDirectChat ?? false;
      _onlineOnly = f.isOnlineNow ?? false;
      _radiusKm = f.radiusKm ?? 10;
      _radiusLimited = f.radiusKm != null;
      _hasLocation = f.latitude != null && f.longitude != null;
      _cityCtrl.text = f.city ?? '';
      _countryCtrl.text = f.country ?? '';
    });
  }

  void _apply() {
    DebugConfig.log(DebugConfig.uiInteraction, 'SearchFiltersScreen apply');
    final n = ref.read(searchFiltersProvider.notifier);
    n.updateAge(_ageRange.start.round(), _ageRange.end.round());
    n.updateGender(_gender == 'all' ? null : _gender);
    n.updateInterests(_interests.isEmpty ? null : _interests);
    n.updateLookingFor(_lookingFor.isEmpty ? null : _lookingFor);
    n.updateAllowVideoCall(_allowVideoCall);
    n.updateAllowDirectChat(_allowDirectChat);
    n.updateOnlineOnly(_onlineOnly);
    n.updateCity(_cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim());
    n.updateCountry(_countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim());
    n.updateRadius(_radiusLimited ? _radiusKm : null);
    ref.read(searchProvider.notifier).search();
    context.pop();
  }

  void _reset() {
    DebugConfig.log(DebugConfig.uiInteraction, 'SearchFiltersScreen reset');
    ref.read(searchFiltersProvider.notifier).reset();
    ref.read(searchProvider.notifier).clearResults();
    context.pop();
  }

  Future<void> _saveSearch(BuildContext context, bool isGreek) async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.localizedMessage(context, 'Αποθήκευση Αναζήτησης / Save Search')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isGreek ? 'Όνομα αναζήτησης' : 'Search name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isGreek ? 'Ακύρωση' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(isGreek ? 'Αποθήκευση' : 'Save'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    final filters = ref.read(searchFiltersProvider);
    await ref.read(savedSearchActionsProvider).save(filters, label);
    if (context.mounted) {
      AppMessenger.showSuccess(context,
          L10n.localizedMessage(context, 'Αποθηκεύτηκε / Saved'));
    }
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGreek = L10n.isGreek(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(isGreek ? 'Φίλτρα Αναζήτησης' : 'Search Filters'),
      ),
      body: Center(
        child: SizedBox(
          width: ResponsiveUtils.maxContentWidth(context),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              GradientHeader(
                icon: Icons.tune,
                title: isGreek ? 'Φίλτρα' : 'Filters',
                subtitle: isGreek
                    ? 'Προσδιόρισε τα κριτήρια αναζήτησης'
                    : 'Refine your search criteria',
              ),
              FormSection(title: isGreek ? 'Ηλικία' : 'Age', children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Text(
                        '${_ageRange.start.round()} - ${_ageRange.end.round()} '
                        '${isGreek ? 'ετών' : 'years'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      RangeSlider(
                        values: _ageRange,
                        min: 18,
                        max: 80,
                        divisions: 62,
                        labels: RangeLabels(
                          '${_ageRange.start.round()}',
                          '${_ageRange.end.round()}',
                        ),
                        onChanged: (v) => setState(() => _ageRange = v),
                      ),
                    ],
                  ),
                ),
              ]),
              FormSection(title: isGreek ? 'Φύλο' : 'Gender', children: [
                ChipSelector(
                  options: _genderOptions,
                  selectedValue: _gender,
                  onSelected: (v) => setState(() => _gender = v ?? 'all'),
                  labels: {
                    'all': isGreek ? 'Όλοι/ες' : 'All',
                    for (final g in _genderOptions.where((o) => o != 'all'))
                      g: L10n.genderLabel(g, isGreek: isGreek),
                  },
                ),
              ]),
              FormSection(title: isGreek ? 'Αναζητώ' : 'Looking For', children: [
                ChipSelector(
                  options: _lookingForOptions,
                  selectedValue: _lookingFor.isEmpty ? null : _lookingFor,
                  onSelected: (v) => setState(() => _lookingFor = v ?? ''),
                  labels: {
                    for (final o in _lookingForOptions)
                      o: L10n.lookingForLabel(o, isGreek: isGreek),
                  },
                ),
              ]),
              FormSection(title: isGreek ? 'Ενδιαφέροντα' : 'Interests', children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _allInterests.map((i) {
                    final selected = _interests.contains(i);
                    return FilterChip(
                      label: Text(L10n.interestLabel(i, isGreek: isGreek)),
                      selected: selected,
                      onSelected: (v) {
                        DebugConfig.log(DebugConfig.uiInteraction,
                            'SearchFilters interest: $i=$v');
                        setState(() {
                          v ? _interests.add(i) : _interests.remove(i);
                        });
                      },
                      selectedColor: AppColors.primary.withAlpha(25),
                      checkmarkColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: BorderSide(
                        color: selected
                            ? AppColors.primary.withAlpha(80)
                            : theme.dividerColor,
                      ),
                    );
                  }).toList(),
                ),
              ]),
              FormSection(title: isGreek ? 'Επικοινωνία' : 'Communication', children: [
                FormToggle(
                  icon: Icons.videocam_outlined,
                  title: isGreek ? 'Video Call' : 'Video Call',
                  subtitle: isGreek
                      ? 'Μόνο χρήστες που επιτρέπουν video call'
                      : 'Only users who allow video calls',
                  value: _allowVideoCall,
                  onChanged: (v) => setState(() => _allowVideoCall = v),
                ),
                const Divider(height: 4),
                FormToggle(
                  icon: Icons.chat_outlined,
                  title: isGreek ? 'Άμεσο μήνυμα' : 'Direct message',
                  subtitle: isGreek
                      ? 'Μόνο χρήστες που δέχονται άμεσα μηνύματα'
                      : 'Only users who accept direct messages',
                  value: _allowDirectChat,
                  onChanged: (v) => setState(() => _allowDirectChat = v),
                ),
                const Divider(height: 4),
                FormToggle(
                  icon: Icons.wifi_outlined,
                  title: isGreek ? 'Μόνο Online' : 'Online only',
                  subtitle: isGreek
                      ? 'Εμφάνισε μόνο χρήστες που είναι αυτή τη στιγμή online'
                      : 'Show only users who are currently online',
                  value: _onlineOnly,
                  onChanged: (v) => setState(() => _onlineOnly = v),
                ),
              ]),
              FormSection(title: isGreek ? 'Τοποθεσία' : 'Location', children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _cityCtrl,
                    decoration: InputDecoration(
                      labelText: isGreek ? 'Πόλη / Περιοχή' : 'City / Area',
                      prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _countryCtrl,
                  decoration: InputDecoration(
                    labelText: isGreek ? 'Χώρα' : 'Country',
                    prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14,
                    ),
                  ),
                ),
                const Divider(height: 4),
                AbsorbPointer(
                  absorbing: !_hasLocation,
                  child: Opacity(
                    opacity: _hasLocation ? 1.0 : 0.5,
                    child: FormToggle(
                      icon: Icons.map_outlined,
                      title: isGreek ? 'Περιορισμός απόστασης' : 'Distance limit',
                      subtitle: _radiusLimited
                          ? (isGreek
                              ? 'Ακτίνα ${_radiusKm.round()} χλμ'
                              : 'Radius ${_radiusKm.round()} km')
                          : (isGreek
                              ? 'Αναζήτηση παντού (χωρίς όριο)'
                              : 'Search everywhere (no limit)'),
                      value: _radiusLimited,
                      onChanged: (v) => setState(() => _radiusLimited = v),
                    ),
                  ),
                ),
                if (_radiusLimited && _hasLocation)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Text(
                          isGreek
                              ? '${_radiusKm.round()} χλμ'
                              : '${_radiusKm.round()} km',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Slider(
                          value: _radiusKm,
                          min: 1,
                          max: 500,
                          divisions: 499,
                          label: '${_radiusKm.round()} km',
                          onChanged: (v) => setState(() => _radiusKm = v),
                        ),
                      ],
                    ),
                  ),
                if (!_hasLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isGreek
                                ? 'Ενεργοποίησε την τοποθεσία για να χρησιμοποιήσεις την ακτίνα'
                                : 'Enable location to use radius',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  onPressed: _apply,
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(isGreek ? 'Εφαρμογή' : 'Apply'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(isGreek ? 'Επαναφορά' : 'Reset'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: () => _saveSearch(context, isGreek),
                  icon: const Icon(Icons.bookmark_border, size: 20),
                  label: Text(isGreek ? 'Αποθήκευση Αναζήτησης' : 'Save Search'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
