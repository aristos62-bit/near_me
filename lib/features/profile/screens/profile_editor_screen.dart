import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../data/local/database.dart';
import '../../../features/chat/providers/chat_provider.dart';
import '../../../shared/widgets/chip_selector.dart';
import '../../../shared/widgets/form_section.dart';
import '../../../shared/widgets/form_toggle.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/save_button.dart';
import '../providers/location_autocomplete_service.dart';
import '../providers/location_service.dart';
import '../providers/profile_provider.dart';

class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key});
  @override
  ConsumerState<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController _nicknameCtrl, _fullNameCtrl, _bioCtrl, _birthYearCtrl;
  late TextEditingController _cityCtrl, _countryCtrl, _emailCtrl, _phoneCtrl;

  String? _gender, _lookingFor, _avatarUrl;
  List<String> _interests = [], _photoUrls = [];
  bool _allowVideoCall = false, _allowDirectChat = true, _isSaving = false;
  bool _isDetectingLocation = false, _isUploadingAvatar = false, _avatarErrorShown = false;
  bool _locationDetectedViaGps = false;
  double? _latitude, _longitude;
  int? _uploadingPhotoIndex;
  List<LocationSuggestion> _citySuggestions = [], _countrySuggestions = [];
  Timer? _cityTimer, _countryTimer;
  final _cityFocusNode = FocusNode();
  final _countryFocusNode = FocusNode();
  UserProfileTableData? _loadedProfile;

  static const _genders = ['male', 'female', 'other', 'prefer_not'];
  static const _lookingForOptions = ['roommate', 'social', 'friendship', 'networking', 'exchange', 'help', 'employment'];
  static const _allInterests = ['gaming', 'programming', 'education', 'travel', 'music',
    'painting', 'arts', 'sports', 'cooking', 'shopping', 'reading', 'photography',
    'theater', 'cinema', 'series', 'fashion', 'dancing', 'pets', 'social', 'board_games',
    'computers', 'collecting', 'fishing', 'hunting', 'extreme_sports', 'swimming',
    'other'];

  Map<String, String> _genderLabels(bool g) => {
    'male': g ? 'Άνδρας' : 'Male', 'female': g ? 'Γυναίκα' : 'Female',
    'other': g ? 'Άλλο' : 'Other', 'prefer_not': g ? 'Δεν επιθυμώ' : 'Prefer not',
  };
  Map<String, String> _lookingForLabels(bool g) => {
    'roommate': g ? 'Συγκάτοικο' : 'Roommate', 'social': g ? 'Παρέα' : 'Social',
    'friendship': g ? 'Φιλία' : 'Friendship', 'networking': g ? 'Δικτύωση' : 'Networking',
    'exchange': g ? 'Ανταλλαγή' : 'Exchange', 'help': g ? 'Βοήθεια' : 'Help',
    'employment': g ? 'Απασχόληση' : 'Employment',
  };

  bool get _isDirty {
    final p = _loadedProfile;
    if (p == null) {
      if (_nicknameCtrl.text.isNotEmpty) return true;
      if (_fullNameCtrl.text.isNotEmpty) return true;
      if (_bioCtrl.text.isNotEmpty) return true;
      if (_birthYearCtrl.text.isNotEmpty) return true;
      if (_cityCtrl.text.isNotEmpty) return true;
      if (_countryCtrl.text.isNotEmpty) return true;
      if (_emailCtrl.text.isNotEmpty) return true;
      if (_phoneCtrl.text.isNotEmpty) return true;
      if (_gender != null) return true;
      if (_lookingFor != null) return true;
      if (_interests.isNotEmpty) return true;
      if (_allowVideoCall != false) return true;
      if (_allowDirectChat != true) return true;
      if (_avatarUrl != null) return true;
      if (_photoUrls.isNotEmpty) return true;
      if (_latitude != null) return true;
      if (_longitude != null) return true;
      return false;
    }
    if (_nicknameCtrl.text != (p.nickname ?? '')) return true;
    if (_fullNameCtrl.text != (p.fullName ?? '')) return true;
    if (_bioCtrl.text != (p.bio ?? '')) return true;
    if (_birthYearCtrl.text != (p.birthYear?.toString() ?? '')) return true;
    if (_cityCtrl.text != (p.city ?? '')) return true;
    if (_countryCtrl.text != (p.country ?? '')) return true;
    if (_emailCtrl.text != (p.email ?? '')) return true;
    if (_phoneCtrl.text != (p.phone ?? '')) return true;
    if (_gender != p.gender) return true;
    if (_lookingFor != p.lookingFor) return true;
    if (!listEquals(_interests, p.interests ?? [])) return true;
    if (_allowVideoCall != p.allowVideoCall) return true;
    if (_allowDirectChat != p.allowDirectChat) return true;
    if (_avatarUrl != p.avatarUrl) return true;
    if (!listEquals(_photoUrls, p.photoUrls ?? [])) return true;
    if (_latitude != p.latitudeExact) return true;
    if (_longitude != p.longitudeExact) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'ProfileEditorScreen init');
    _nicknameCtrl = TextEditingController(); _fullNameCtrl = TextEditingController();
    _bioCtrl = TextEditingController(); _birthYearCtrl = TextEditingController();
    _cityCtrl = TextEditingController(); _countryCtrl = TextEditingController();
    _emailCtrl = TextEditingController(); _phoneCtrl = TextEditingController();
    _cityFocusNode.addListener(_onCityFocusChanged);
    _countryFocusNode.addListener(_onCountryFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose(); _fullNameCtrl.dispose(); _bioCtrl.dispose();
    _birthYearCtrl.dispose(); _cityCtrl.dispose(); _countryCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose();
    _cityFocusNode.dispose();
    _countryFocusNode.dispose();
    _cityTimer?.cancel();
    _countryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final repo = ref.read(profileRepositoryProvider);
    final profile = await repo.getProfile();
    if (profile == null) return;
    _nicknameCtrl.text = profile.nickname ?? '';
    _fullNameCtrl.text = profile.fullName ?? '';
    _bioCtrl.text = profile.bio ?? '';
    _birthYearCtrl.text = profile.birthYear?.toString() ?? '';
    _cityCtrl.text = profile.city ?? '';
    _countryCtrl.text = profile.country ?? '';
    _emailCtrl.text = profile.email ?? '';
    _phoneCtrl.text = profile.phone ?? '';
    _gender = profile.gender;
    _lookingFor = profile.lookingFor;
    _interests = profile.interests ?? [];
    _allowVideoCall = profile.allowVideoCall;
    _allowDirectChat = profile.allowDirectChat;
    _latitude = profile.latitudeExact;
    _longitude = profile.longitudeExact;
    _locationDetectedViaGps = false;
    _avatarUrl = profile.avatarUrl;
    _avatarErrorShown = false;
    DebugConfig.log(DebugConfig.uiRebuild,
        'ProfileEditor _loadProfile: avatarUrl=${_avatarUrl != null && _avatarUrl!.isNotEmpty ? "present (${_avatarUrl!.length} chars)" : "null or empty"}');
    _photoUrls = profile.photoUrls ?? [];
    _loadedProfile = profile;
    if (mounted) setState(() {});
  }

  Future<void> _detectLocation() async {
    DebugConfig.log(DebugConfig.gpsPermissions, 'ProfileEditor: detect location');
    setState(() => _isDetectingLocation = true);
    final result = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (result.isFromGps && result.latitude != null && result.longitude != null) {
      final name = await LocationService.reverseGeocode(result.latitude!, result.longitude!);
      if (!mounted) return;
      setState(() {
        _isDetectingLocation = false;
        _locationDetectedViaGps = true;
        _latitude = result.latitude;
        _longitude = result.longitude;
        if (name?.city != null) _cityCtrl.text = name!.city!;
        if (name?.country != null) _countryCtrl.text = name!.country!;
      });
    } else {
      setState(() => _isDetectingLocation = false);
      if (!mounted) return;
      AppMessenger.showInfo(context, L10n.localizedMessage(context, 'Δεν δόθηκε άδεια GPS. Μπορείς να συμπληρώσεις χειροκίνητα την πόλη. / GPS permission denied. You can enter the city manually.'));
    }
  }

  void _onCityFocusChanged() {
    if (!_cityFocusNode.hasFocus) setState(() => _citySuggestions = []);
  }

  void _onCountryFocusChanged() {
    if (!_countryFocusNode.hasFocus) setState(() => _countrySuggestions = []);
  }

  void _onCityChanged(String value) {
    _cityTimer?.cancel();
    if (value.trim().length < 2) {
      if (_citySuggestions.isNotEmpty) setState(() => _citySuggestions = []);
      return;
    }
    _cityTimer = Timer(const Duration(milliseconds: 800), () async {
      final results = await LocationAutocompleteService.autocomplete(value);
      if (mounted) setState(() => _citySuggestions = results);
    });
  }

  void _onCountryChanged(String value) {
    _countryTimer?.cancel();
    if (value.trim().length < 2) {
      if (_countrySuggestions.isNotEmpty) setState(() => _countrySuggestions = []);
      return;
    }
    _countryTimer = Timer(const Duration(milliseconds: 800), () async {
      final results = await LocationAutocompleteService.autocomplete(value);
      if (mounted) setState(() => _countrySuggestions = results);
    });
  }

  void _selectCity(LocationSuggestion s) {
    _cityCtrl.text = s.name;
    _cityTimer?.cancel();
    setState(() => _citySuggestions = []);
  }

  void _selectCountry(LocationSuggestion s) {
    _countryCtrl.text = s.name;
    _countryTimer?.cancel();
    setState(() => _countrySuggestions = []);
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    if (!context.mounted) return;
    final ctx = context;
    final g = L10n.isGreek(ctx);
    DebugConfig.log(DebugConfig.storageUpload, 'Avatar file picked: ${picked.name}');
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 800,
      maxHeight: 800,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: g ? 'Περικοπή' : 'Crop',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: AppColors.primary,
          cropFrameColor: Colors.white,
          cropGridColor: Colors.white38,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          cropStyle: CropStyle.rectangle,
          aspectRatioPresets: [CropAspectRatioPreset.square],
          showCropGrid: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: g ? 'Περικοπή' : 'Crop',
          doneButtonTitle: g ? 'Τέλος' : 'Done',
          cancelButtonTitle: g ? 'Ακύρωση' : 'Cancel',
          aspectRatioLockEnabled: true,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
      ],
    );
    if (cropped == null || !mounted) return;
    if (!context.mounted) return;
    DebugConfig.log(DebugConfig.storageUpload, 'Avatar cropped: ${cropped.path}');
    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await cropped.readAsBytes();
      final url = await ref.read(profileRepositoryProvider).saveAvatar(bytes);
      setState(() { _avatarUrl = url; _avatarErrorShown = false; });
      if (!context.mounted) return;
      if (mounted) AppMessenger.showSuccess(ctx, L10n.localizedMessage(ctx, 'Η φωτογραφία αποθηκεύτηκε! / Photo saved!'));
    } catch (e, s) {
      DebugConfig.error('Avatar upload failed', data: e, exception: s);
      if (mounted) AppMessenger.showError(ctx, L10n.localizedMessage(ctx, 'Αποτυχία μεταφόρτωσης / Upload failed'));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _pickAndUploadPhoto(int index) async {
    if (_uploadingPhotoIndex != null) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    if (!context.mounted) return;
    final ctx = context;
    final g = L10n.isGreek(ctx);
    DebugConfig.log(DebugConfig.storageUpload, 'Photo picked: ${picked.name} index=$index');
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1024,
      maxHeight: 1024,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: g ? 'Περικοπή' : 'Crop',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: AppColors.primary,
          cropFrameColor: Colors.white,
          cropGridColor: Colors.white38,
          lockAspectRatio: false,
          initAspectRatio: CropAspectRatioPreset.original,
          cropStyle: CropStyle.rectangle,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
          showCropGrid: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: g ? 'Περικοπή' : 'Crop',
          doneButtonTitle: g ? 'Τέλος' : 'Done',
          cancelButtonTitle: g ? 'Ακύρωση' : 'Cancel',
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );
    if (cropped == null || !mounted) return;
    if (!context.mounted) return;
    DebugConfig.log(DebugConfig.storageUpload, 'Photo cropped: ${cropped.path} index=$index');
    setState(() => _uploadingPhotoIndex = index);
    try {
      final bytes = await cropped.readAsBytes();
      final url = await ref.read(profileRepositoryProvider).savePhoto(bytes, index);
      setState(() { while (_photoUrls.length <= index) { _photoUrls.add(''); } _photoUrls[index] = url; });
    } catch (e, s) {
      DebugConfig.error('Photo upload failed', data: e, exception: s);
      if (!context.mounted) return;
      if (mounted) AppMessenger.showError(ctx, L10n.localizedMessage(ctx, 'Αποτυχία μεταφόρτωσης φωτογραφίας / Photo upload failed'));
    } finally {
      if (mounted) setState(() => _uploadingPhotoIndex = null);
    }
  }

  Future<void> _removePhoto(int index) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'Remove photo index=$index');
    try {
      await ref.read(profileRepositoryProvider).deletePhoto(index);
      setState(() { if (index < _photoUrls.length) _photoUrls.removeAt(index); });
    } catch (e) {
      DebugConfig.error('Remove photo failed', data: e);
    }
  }

  Future<void> _onBack() async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ProfileEditorScreen onBack, dirty=$_isDirty, saving=$_isSaving');
    if (_isSaving) return;
    if (!_isDirty) {
      if (context.mounted) context.pop();
      return;
    }
    final g = L10n.isGreek(context);
    final save = await AppMessenger.showConfirmDialog(
      context,
      title: g ? 'Αποθήκευση αλλαγών;' : 'Save changes?',
      message: g
          ? 'Έχεις μη αποθηκευμένες αλλαγές. Θες να αποθηκευτούν;'
          : 'You have unsaved changes. Save them?',
      confirmLabel: g ? 'Αποθήκευση' : 'Save',
      cancelLabel: g ? 'Απόρριψη' : 'Discard',
    );
    if (save == true) {
      await _save();
    } else if (save == false && context.mounted) {
      if (!mounted)return;
      context.pop();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    DebugConfig.log(DebugConfig.uiInteraction, 'ProfileEditorScreen save');
    setState(() => _isSaving = true);
    try {
      final name = _nicknameCtrl.text.trim();
      if (name.isEmpty) {
        if (mounted) AppMessenger.showError(context, L10n.localizedMessage(context, 'Το ψευδώνυμο είναι υποχρεωτικό / Nickname is required'));
        setState(() => _isSaving = false);
        return;
      }
      final repo = ref.read(profileRepositoryProvider);
      final locationChanged = _loadedProfile != null && (
          _cityCtrl.text.trim() != (_loadedProfile!.city ?? '') ||
          _countryCtrl.text.trim() != (_loadedProfile!.country ?? ''));
      final keepLatLng = _locationDetectedViaGps ||
          (!locationChanged && _latitude != null && _longitude != null);
      DebugConfig.log(DebugConfig.serviceCall,
          'ProfileEditor save: city=${_cityCtrl.text.trim()}, country=${_countryCtrl.text.trim()}, '
          'lat=$_latitude, lng=$_longitude, locationDetectedViaGps=$_locationDetectedViaGps, '
          'locationChanged=$locationChanged, keepLatLng=$keepLatLng');
      final profile = UserProfileTableData(
        id: 0,
        nickname: name,
        fullName: _fullNameCtrl.text.trim().isEmpty ? null : _fullNameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        birthYear: int.tryParse(_birthYearCtrl.text.trim()),
        gender: _gender,
        city: _cityCtrl.text.trim(),
        country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
        interests: _interests,
        lookingFor: _lookingFor,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        allowVideoCall: _allowVideoCall,
        allowDirectChat: _allowDirectChat,
        isPublished: _loadedProfile?.isPublished ?? false,
        latitudeExact: keepLatLng ? _latitude : null,
        longitudeExact: keepLatLng ? _longitude : null,
        avatarUrl: _avatarUrl,
        photoUrls: _photoUrls.isEmpty ? null : _photoUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveProfile(profile);

      // ΝΕΟ: sync nickname/avatar σε όλα τα chat docs
      final chatRepo = ref.read(chatRepositoryProvider);
      try {
        await chatRepo.syncMyProfileAcrossChats(
          nickname: name,
          avatarUrl: _avatarUrl,
        );
      } catch (e, s) {
        DebugConfig.warn('syncMyProfileAcrossChats failed', data: '$e\n$s');
      }

      final commSettingsChanged = _loadedProfile != null && (
          _allowVideoCall != _loadedProfile!.allowVideoCall ||
          _allowDirectChat != _loadedProfile!.allowDirectChat);
      if (commSettingsChanged || (locationChanged && _loadedProfile!.isPublished)) {
        DebugConfig.log(DebugConfig.repositoryCall,
            'ProfileEditor: comm settings or location changed, auto-publishing');
        try {
          await repo.publish();
          DebugConfig.log(DebugConfig.repositoryResult,
              'ProfileEditor: auto-publish success');
        } catch (e, s) {
          DebugConfig.warn('ProfileEditor: auto-publish failed', data: '$e\n$s');
        }
      }
      try {
        ref.invalidate(currentProfileProvider);
      } catch (_) {
        // autoDispose stream race — data already saved, ignore
      }
      if (mounted) {
        AppMessenger.showSuccess(context, L10n.localizedMessage(context, 'Το προφίλ αποθηκεύτηκε! / Profile saved!'));
        context.pop();
      }
    } catch (e, s) {
      DebugConfig.error('ProfileEditor save failed', data: e, exception: s);
      if (mounted) AppMessenger.showError(context, L10n.localizedMessage(context, 'Αποτυχία αποθήκευσης προφίλ / Failed to save profile'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = L10n.isGreek(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.close), onPressed: _onBack), title: Text(g ? 'Επεξεργασία Προφίλ' : 'Edit Profile')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          return Center(child: SizedBox(width: ResponsiveUtils.maxContentWidthFromWidth(w),
        child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          _buildAvatarHeader(),
          FormSection(title: g ? 'Βασικά Στοιχεία' : 'Basic Info', children: [
            _buildTextField(icon: Icons.person, label: g ? 'Ψευδώνυμο' : 'Nickname', ctrl: _nicknameCtrl, required: true),
            _buildTextField(icon: Icons.badge_outlined, label: g ? 'Πλήρες Όνομα' : 'Full Name', ctrl: _fullNameCtrl),
            _buildTextField(icon: Icons.article_outlined, label: g ? 'Βιογραφικό' : 'Bio', ctrl: _bioCtrl, maxLines: 3),
          ]),
          FormSection(title: g ? 'Προσωπικά' : 'Personal', children: [
            _buildTextField(icon: Icons.cake_outlined, label: g ? 'Έτος Γέννησης' : 'Birth Year', ctrl: _birthYearCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            ChipSelector(options: _genders, selectedValue: _gender, onSelected: (v) => setState(() => _gender = v), labels: _genderLabels(g)),
          ]),
          FormSection(title: g ? 'Τοποθεσία' : 'Location', children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: _cityCtrl, focusNode: _cityFocusNode,
                onChanged: _onCityChanged,
                decoration: InputDecoration(
                  labelText: g ? 'Πόλη' : 'City',
                  prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              if (_citySuggestions.isNotEmpty)
                _buildSuggestionDropdown(_citySuggestions, _selectCity),
            ]),
            const SizedBox(height: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: _countryCtrl, focusNode: _countryFocusNode,
                onChanged: _onCountryChanged,
                decoration: InputDecoration(
                  labelText: g ? 'Χώρα' : 'Country',
                  prefixIcon: const Icon(Icons.public_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              if (_countrySuggestions.isNotEmpty)
                _buildSuggestionDropdown(_countrySuggestions, _selectCountry),
            ]),
            const SizedBox(height: 4),
            if (_latitude != null && _longitude != null)
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                Icon(Icons.gps_fixed, size: 14, color: AppColors.success), const SizedBox(width: 6),
                Text('GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}', style: AppTypography.caption.copyWith(color: AppColors.success)),
              ])),
            OutlinedButton.icon(onPressed: _isDetectingLocation ? null : _detectLocation,
              icon: _isDetectingLocation ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.gps_fixed, size: 18),
              label: Text(_isDetectingLocation ? (g ? 'Ανίχνευση...' : 'Detecting...') : (g ? 'Ανίχνευση τοποθεσίας' : 'Detect Location')),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
            if (_latitude == null)
              Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.textSecondaryLight), const SizedBox(width: 6),
                Text(g ? 'Πάτα για αυτόματη ανίχνευση ή γράψε την πόλη χειροκίνητα' : 'Tap to auto-detect or type city manually',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight)),
              ])),
          ]),
          FormSection(title: g ? 'Ενδιαφέροντα' : 'Interests', children: [_buildInterestChips()]),
          FormSection(title: g ? 'Αναζητώ' : 'Looking For', children: [
            ChipSelector(options: _lookingForOptions, selectedValue: _lookingFor, onSelected: (v) => setState(() => _lookingFor = v), labels: _lookingForLabels(g)),
          ]),
          FormSection(title: g ? 'Φωτογραφίες' : 'Photos', children: [_buildPhotoGallery(g)]),
          FormSection(title: g ? 'Επικοινωνία' : 'Communication', children: [
            _buildTextField(icon: Icons.email_outlined, label: g ? 'Ηλ. Ταχυδρομείο' : 'Email', ctrl: _emailCtrl, keyboardType: TextInputType.emailAddress),
            _buildTextField(icon: Icons.phone_outlined, label: g ? 'Τηλέφωνο' : 'Phone', ctrl: _phoneCtrl, keyboardType: TextInputType.phone),
            const SizedBox(height: 4),
            FormToggle(icon: Icons.videocam_outlined, title: g ? 'Βιντεοκλήση' : 'Video Call', subtitle: g ? 'Να επιτρέπονται αιτήματα βιντεοκλήσης' : 'Allow video call requests', value: _allowVideoCall, onChanged: (v) => setState(() => _allowVideoCall = v)),
            FormToggle(icon: Icons.chat_outlined, title: g ? 'Άμεσο Chat' : 'Direct Chat', subtitle: g ? 'Να επιτρέπονται άμεσα μηνύματα' : 'Allow direct messages', value: _allowDirectChat, onChanged: (v) => setState(() => _allowDirectChat = v)),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: SaveButton(isSaving: _isSaving, label: g ? 'Αποθήκευση' : 'Save', onPressed: _save)),
        ]),
      ),
    ),
    );
    },
  ),
  ),
);
  }

  Widget _buildAvatarPlaceholder(bool g) {
    return Container(width: 88, height: 88, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Center(child: Text(_nicknameCtrl.text.isNotEmpty ? _nicknameCtrl.text[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary))),
    );
  }

  Widget _buildAvatarHeader() {
    final g = L10n.isGreek(context);
    return GradientHeader(
      gradientColors: [AppColors.primary, AppColors.primaryDark.withAlpha(220)], icon: Icons.person,
      title: _nicknameCtrl.text.isNotEmpty ? _nicknameCtrl.text : (g ? 'Το Προφίλ σου' : 'Your Profile'),
      subtitle: g ? 'Πάτα για να προσθέσεις φωτογραφία' : 'Tap to add a photo',
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 24),
      child: GestureDetector(onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
        child: Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(44),
            child: SizedBox(width: 88, height: 88,
              child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                ? CachedNetworkImage(imageUrl: _avatarUrl!, fit: BoxFit.cover,
                    placeholder: (_, _) => _buildAvatarPlaceholder(g),
                    errorWidget: (ctx, url, err) {
                      DebugConfig.warn('CachedNetworkImage avatar error', data: 'url=$url error=$err');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (ctx.mounted && !_avatarErrorShown) {
                          _avatarErrorShown = true;
                          AppMessenger.showError(ctx, g ? 'Αποτυχία φόρτωσης φωτογραφίας προφίλ' : 'Failed to load profile photo');
                        }
                      });
                      return _buildAvatarPlaceholder(g);
                    },
                  )
                : _buildAvatarPlaceholder(g),
            ),
          ),
          if (_isUploadingAvatar) Positioned.fill(child: Container(decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
            child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))),
          Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.primary)),
          ),
        ]),
      ),
    );
  }

  Widget _buildPhotoGallery(bool g) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < _photoUrls.length; i++)
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(imageUrl: _photoUrls[i], width: 100, height: 100, fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey.shade200, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
                errorWidget: (_, _, _) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
              ),
            ),
            Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => _removePhoto(i),
              child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)))),
            if (_uploadingPhotoIndex == i) Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))),
          ]),
        if (_photoUrls.length < 5)
          GestureDetector(onTap: () => _pickAndUploadPhoto(_photoUrls.length),
            child: Container(width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary), const SizedBox(height: 4),
                Text(g ? 'Προσθήκη' : 'Add', style: AppTypography.caption.copyWith(color: AppColors.primary)),
              ]))),
      ]),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text(g ? 'Μέχρι 5 φωτογραφίες' : 'Up to 5 photos',
        style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight))),
    ]);
  }

  Widget _buildSuggestionDropdown(List<LocationSuggestion> suggestions, ValueChanged<LocationSuggestion> onSelected) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length,
        itemBuilder: (_, i) => ListTile(
          dense: true,
          title: Text(suggestions[i].displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onSelected(suggestions[i]),
        ),
      ),
    );
  }

  Widget _buildTextField({required IconData icon, required String label, required TextEditingController ctrl, bool required = false, int maxLines = 1, TextInputType? keyboardType}) {
    final g = L10n.isGreek(context);
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? (g ? 'Υποχρεωτικό πεδίο' : 'Required') : null : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))));
  }

  Widget _buildInterestChips() {
    final g = L10n.isGreek(context);
    final theme = Theme.of(context);
    return Wrap(spacing: 8, runSpacing: 6, children: _allInterests.map((i) {
      final s = _interests.contains(i);
      return FilterChip(label: Text(L10n.interestLabel(i, isGreek: g)), selected: s,
        onSelected: (v) => setState(() => v ? _interests.add(i) : _interests.remove(i)),
        selectedColor: AppColors.primary.withAlpha(25), checkmarkColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: s ? AppColors.primary.withAlpha(80) : theme.dividerColor));
    }).toList());
  }
}
