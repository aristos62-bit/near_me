import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../data/local/database.dart';
import '../../../shared/widgets/form_section.dart';
import '../../../shared/widgets/form_toggle.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/save_button.dart';
import '../providers/profile_provider.dart';
import '../providers/privacy_provider.dart';

class PrivacyEditorScreen extends ConsumerStatefulWidget {
  const PrivacyEditorScreen({super.key});

  @override
  ConsumerState<PrivacyEditorScreen> createState() => _PrivacyEditorScreenState();
}

class _PrivacyEditorScreenState extends ConsumerState<PrivacyEditorScreen> {
  late PrivacySettingsTableData _settings;
  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'PrivacyEditorScreen init');
    _settings = PrivacySettingsTableData(
      id: 0, showNickname: true, showFullName: true, showAge: true,
      showGender: true, showCity: true, showExactLocation: false,
      showPhone: false, showEmail: false, showInterests: true,
      showOccupation: true, showBio: true, showLookingFor: true, showPhotos: true,
      allowVideoCall: true, allowDirectChat: true, geoPrecision: 'neighborhood',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  Future<void> _loadSettings() async {
    final existing = await ref.read(privacySettingsProvider.future);
    if (existing != null && mounted) {
      setState(() { _settings = existing; _isLoaded = true; });
    } else if (mounted) {
      setState(() => _isLoaded = true);
    }
  }

  Future<void> _save() async {
    DebugConfig.log(DebugConfig.uiInteraction, 'PrivacyEditorScreen save');
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.savePrivacySettings(_settings);
      ref.invalidate(privacySettingsProvider);

      if (await repo.isPublished && mounted) {
        final greek = L10n.isGreek(context);
        final apply = await AppMessenger.showConfirmDialog(
          context,
          title: L10n.localizedMessage(context, 'Εφαρμογή Αλλαγών / Apply Changes'),
          message: L10n.localizedMessage(context, 'Το προφίλ σου είναι δημοσιευμένο. Θες να εφαρμοστούν οι αλλαγές απορρήτου τώρα; / Your profile is published. Apply privacy changes now?'),
          confirmLabel: greek ? 'Εφαρμογή' : 'Apply',
          cancelLabel: greek ? 'Αργότερα' : 'Later',
        );
        if (apply && mounted) {
          await repo.publish();
          if (mounted) {
            AppMessenger.showSuccess(context, L10n.localizedMessage(context, 'Οι αλλαγές εφαρμόστηκαν στο δημόσιο προφίλ σου / Changes applied to your public profile'));
          }
        }
      }

      if (mounted) {
        AppMessenger.showSuccess(context, L10n.localizedMessage(context, 'Οι ρυθμίσεις απορρήτου αποθηκεύτηκαν / Privacy settings saved'));
        context.pop();
      }
    } catch (e, s) {
      DebugConfig.error('PrivacyEditor save failed', data: e, exception: s);
      if (mounted) AppMessenger.showError(context, L10n.localizedMessage(context, 'Αποτυχία αποθήκευσης / Failed to save'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    if (!_isLoaded) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()), title: Text(greek ? 'Απόρρητο' : 'Privacy')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()), title: Text(greek ? 'Απόρρητο' : 'Privacy')),
      body: Center(
        child: SizedBox(
          width: ResponsiveUtils.maxContentWidth(context),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              GradientHeader(
                icon: Icons.shield_outlined,
                title: greek ? 'Έλεγξε τι βλέπουν οι άλλοι' : 'Control what others see',
                subtitle: greek ? 'Ποια πεδία του προφίλ σου εμφανίζονται δημόσια' : 'Which profile fields are visible publicly',
              ),
              FormSection(icon: Icons.lock_outline, title: greek ? 'Προσωπικά Στοιχεία' : 'Personal Info', children: [
                FormToggle(title: greek ? 'Ψευδώνυμο' : 'Nickname', subtitle: greek ? 'Να εμφανίζεται το ψευδώνυμό σου' : 'Show your nickname', value: _settings.showNickname, onChanged: (v) => setState(() => _settings = _settings.copyWith(showNickname: v))),
                FormToggle(title: greek ? 'Πλήρες Όνομα' : 'Full Name', subtitle: greek ? 'Να εμφανίζεται το πραγματικό σου όνομα' : 'Show your real name', value: _settings.showFullName, onChanged: (v) => setState(() => _settings = _settings.copyWith(showFullName: v))),
                FormToggle(title: greek ? 'Ηλικία' : 'Age', subtitle: greek ? 'Να εμφανίζεται η ηλικία σου' : 'Show your age', value: _settings.showAge, onChanged: (v) => setState(() => _settings = _settings.copyWith(showAge: v))),
                FormToggle(title: greek ? 'Φύλο' : 'Gender', subtitle: greek ? 'Να εμφανίζεται το φύλο σου' : 'Show your gender', value: _settings.showGender, onChanged: (v) => setState(() => _settings = _settings.copyWith(showGender: v))),
              ]),
              FormSection(icon: Icons.location_on_outlined, title: greek ? 'Τοποθεσία' : 'Location', children: [
                FormToggle(title: greek ? 'Πόλη' : 'City', subtitle: greek ? 'Να εμφανίζεται η πόλη σου' : 'Show your city', value: _settings.showCity, onChanged: (v) => setState(() => _settings = _settings.copyWith(showCity: v))),
                const SizedBox(height: 8),
                _buildGeoPrecision(greek),
              ]),
              FormSection(icon: Icons.contact_phone_outlined, title: greek ? 'Επικοινωνία' : 'Contact', children: [
                FormToggle(title: greek ? 'Τηλέφωνο' : 'Phone', subtitle: greek ? 'Να εμφανίζεται το τηλέφωνό σου' : 'Show your phone number', value: _settings.showPhone, onChanged: (v) => setState(() => _settings = _settings.copyWith(showPhone: v))),
                FormToggle(title: 'Email', subtitle: greek ? 'Να εμφανίζεται το email σου' : 'Show your email', value: _settings.showEmail, onChanged: (v) => setState(() => _settings = _settings.copyWith(showEmail: v))),
              ]),
              FormSection(icon: Icons.article_outlined, title: greek ? 'Περιεχόμενο Προφίλ' : 'Profile Content', children: [
                FormToggle(title: 'Bio', subtitle: greek ? 'Να εμφανίζεται η περιγραφή σου' : 'Show your bio', value: _settings.showBio, onChanged: (v) => setState(() => _settings = _settings.copyWith(showBio: v))),
                FormToggle(title: greek ? 'Ενδιαφέροντα' : 'Interests', subtitle: greek ? 'Να εμφανίζονται τα ενδιαφέροντά σου' : 'Show your interests', value: _settings.showInterests, onChanged: (v) => setState(() => _settings = _settings.copyWith(showInterests: v))),
                FormToggle(title: greek ? 'Απασχόληση' : 'Occupation', subtitle: greek ? 'Να εμφανίζεται η απασχόλησή σου' : 'Show your occupation', value: _settings.showOccupation, onChanged: (v) => setState(() => _settings = _settings.copyWith(showOccupation: v))),
                FormToggle(title: greek ? 'Αναζητώ' : 'Looking For', subtitle: greek ? 'Να εμφανίζεται ο λόγος αναζήτησης' : 'Show what you are looking for', value: _settings.showLookingFor, onChanged: (v) => setState(() => _settings = _settings.copyWith(showLookingFor: v))),
                FormToggle(title: greek ? 'Φωτογραφίες' : 'Photos', subtitle: greek ? 'Να εμφανίζονται οι φωτογραφίες σου' : 'Show your photos', value: _settings.showPhotos, onChanged: (v) => setState(() => _settings = _settings.copyWith(showPhotos: v))),
              ]),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SaveButton(
                  isSaving: _isSaving,
                  label: greek ? 'Αποθήκευση' : 'Save',
                  icon: Icons.shield_outlined,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeoPrecision(bool greek) {
    const options = ['city', 'neighborhood', 'hidden'];
    String label(String v) {
      switch (v) {
        case 'city': return greek ? 'Πόλη' : 'City';
        case 'neighborhood': return greek ? 'Συνοικία' : 'Neighborhood';
        case 'hidden': return greek ? 'Κρυφό' : 'Hidden';
        default: return v;
      }
    }
    String desc(String v) {
      switch (v) {
        case 'city': return greek ? '~100km², ευρεία περιοχή' : '~100km², broad area';
        case 'neighborhood': return greek ? '~2.5km², προεπιλογή' : '~2.5km², default';
        case 'hidden': return greek ? 'Δεν εμφανίζεται καθόλου' : 'Not displayed at all';
        default: return '';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greek ? 'Ακρίβεια Τοποθεσίας' : 'Location Precision', style: AppTypography.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((o) {
            final selected = _settings.geoPrecision == o;
            return ChoiceChip(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label(o), style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppColors.primary : null,
                  )),
                  Text(desc(o), style: TextStyle(
                    fontSize: 10,
                    color: selected ? AppColors.primary.withAlpha(180) : AppColors.textSecondaryLight,
                  )),
                ],
              ),
              selected: selected,
              onSelected: (_) {
                DebugConfig.log(DebugConfig.providerCreate, 'geoPrecision: $o');
                setState(() => _settings = _settings.copyWith(geoPrecision: o));
              },
              selectedColor: AppColors.primary.withAlpha(25),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            );
          }).toList(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 6),
              Text(greek ? 'Όσο μικρότερη η περιοχή, τόσο πιο εύκολο να σε εντοπίσουν' : 'The smaller the area, the easier to be located',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight)),
            ],
          ),
        ),
      ],
    );
  }
}
