import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/form_section.dart';
import '../providers/location_autocomplete_service.dart';

/// Move-only από `profile_editor_screen` (Γ7, όριο 500 γραμμών).
/// Κατέχει focus nodes, debounce timers (800ms) και suggestions —
/// ο caller δίνει controllers + GPS state + callback ανίχνευσης.
class ProfileLocationSection extends StatefulWidget {
  final TextEditingController cityCtrl;
  final TextEditingController countryCtrl;
  final double? latitude;
  final double? longitude;
  final bool isDetectingLocation;
  final bool isGreek;
  final VoidCallback onDetectLocation;

  const ProfileLocationSection({
    super.key,
    required this.cityCtrl,
    required this.countryCtrl,
    required this.latitude,
    required this.longitude,
    required this.isDetectingLocation,
    required this.isGreek,
    required this.onDetectLocation,
  });

  @override
  State<ProfileLocationSection> createState() => _ProfileLocationSectionState();
}

class _ProfileLocationSectionState extends State<ProfileLocationSection> {
  List<LocationSuggestion> _citySuggestions = [], _countrySuggestions = [];
  Timer? _cityTimer, _countryTimer;
  final _cityFocusNode = FocusNode();
  final _countryFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _cityFocusNode.addListener(_onCityFocusChanged);
    _countryFocusNode.addListener(_onCountryFocusChanged);
  }

  @override
  void dispose() {
    _cityFocusNode.dispose();
    _countryFocusNode.dispose();
    _cityTimer?.cancel();
    _countryTimer?.cancel();
    super.dispose();
  }

  void _onCityFocusChanged() {
    if (!_cityFocusNode.hasFocus) setState(() => _citySuggestions = []);
  }

  void _onCountryFocusChanged() {
    if (!_countryFocusNode.hasFocus) setState(() => _countrySuggestions = []);
  }

  void _onChanged(String value, bool isCity) {
    final timer = isCity ? _cityTimer : _countryTimer;
    timer?.cancel();
    if (value.trim().length < 2) {
      if (isCity ? _citySuggestions.isNotEmpty : _countrySuggestions.isNotEmpty) {
        setState(() {
          if (isCity) {
            _citySuggestions = [];
          } else {
            _countrySuggestions = [];
          }
        });
      }
      return;
    }
    final newTimer = Timer(const Duration(milliseconds: 800), () async {
      final results = await LocationAutocompleteService.autocomplete(value);
      if (mounted) {
        setState(() {
          if (isCity) {
            _citySuggestions = results;
          } else {
            _countrySuggestions = results;
          }
        });
      }
      DebugConfig.log(DebugConfig.networkLocation,
          'ProfileLocation autocomplete: q=$value → ${results.length}');
    });
    if (isCity) {
      _cityTimer = newTimer;
    } else {
      _countryTimer = newTimer;
    }
  }

  void _select(LocationSuggestion s, bool isCity) {
    if (isCity) {
      widget.cityCtrl.text = s.name;
      _cityTimer?.cancel();
      setState(() => _citySuggestions = []);
    } else {
      widget.countryCtrl.text = s.name;
      _countryTimer?.cancel();
      setState(() => _countrySuggestions = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.isGreek;
    return FormSection(title: g ? 'Τοποθεσία' : 'Location', children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          controller: widget.cityCtrl,
          focusNode: _cityFocusNode,
          onChanged: (v) => _onChanged(v, true),
          decoration: InputDecoration(
            labelText: g ? 'Πόλη' : 'City',
            prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (_citySuggestions.isNotEmpty)
          _buildSuggestionDropdown(_citySuggestions, (s) => _select(s, true)),
      ]),
      const SizedBox(height: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          controller: widget.countryCtrl,
          focusNode: _countryFocusNode,
          onChanged: (v) => _onChanged(v, false),
          decoration: InputDecoration(
            labelText: g ? 'Χώρα' : 'Country',
            prefixIcon: const Icon(Icons.public_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (_countrySuggestions.isNotEmpty)
          _buildSuggestionDropdown(
              _countrySuggestions, (s) => _select(s, false)),
      ]),
      const SizedBox(height: 4),
      if (widget.latitude != null && widget.longitude != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.gps_fixed, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                  'GPS: ${widget.latitude!.toStringAsFixed(4)}, ${widget.longitude!.toStringAsFixed(4)}',
                  style: AppTypography.caption.copyWith(color: AppColors.success)),
            ])),
      OutlinedButton.icon(
          onPressed:
              widget.isDetectingLocation ? null : widget.onDetectLocation,
          icon: widget.isDetectingLocation
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.gps_fixed, size: 18),
          label: Text(widget.isDetectingLocation
              ? (g ? 'Ανίχνευση...' : 'Detecting...')
              : (g ? 'Ανίχνευση τοποθεσίας' : 'Detect Location')),
          style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)))),
      if (widget.latitude == null)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Icon(Icons.info_outline,
                  size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    g
                        ? 'Πάτα για αυτόματη ανίχνευση ή γράψε την πόλη χειροκίνητα'
                        : 'Tap to auto-detect or type city manually',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondaryLight)),
              ),
            ])),
    ]);
  }

  Widget _buildSuggestionDropdown(List<LocationSuggestion> suggestions,
      ValueChanged<LocationSuggestion> onSelected) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length,
        itemBuilder: (_, i) => ListTile(
          dense: true,
          title: Text(suggestions[i].displayName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onSelected(suggestions[i]),
        ),
      ),
    );
  }
}
