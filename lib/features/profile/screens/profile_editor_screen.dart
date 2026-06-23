import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../data/local/database.dart';
import '../../../shared/widgets/chip_selector.dart';
import '../../../shared/widgets/form_section.dart';
import '../../../shared/widgets/form_toggle.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/save_button.dart';
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
  bool _isDetectingLocation = false, _isUploadingAvatar = false;
  double? _latitude, _longitude;
  int? _uploadingPhotoIndex;
  UserProfileTableData? _loadedProfile;

  static const _genders = ['male', 'female', 'other', 'prefer_not'];
  static const _lookingForOptions = ['roommate', 'social', 'friendship', 'networking', 'exchange', 'help', 'employment'];
  static const _allInterests = ['gamer', 'programmer', 'student', 'traveler', 'musician',
    'athlete', 'reader', 'chef', 'artist', 'photographer', 'hiker', 'yoga', 'movies', 'dancing', 'fashion'];

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
    if (_loadedProfile == null) return false;
    final p = _loadedProfile!;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose(); _fullNameCtrl.dispose(); _bioCtrl.dispose();
    _birthYearCtrl.dispose(); _cityCtrl.dispose(); _countryCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose();
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
    _avatarUrl = profile.avatarUrl;
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

  Future<void> _pickAndUploadAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null || !mounted) return;
    if (!context.mounted)return;
    final ctx = context;
    DebugConfig.log(DebugConfig.storageUpload, 'Avatar file picked: ${picked.name}');
    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref.read(profileRepositoryProvider).saveAvatar(bytes);
      setState(() => _avatarUrl = url);
      if (!context.mounted)return;
      if (mounted) AppMessenger.showSuccess(ctx, L10n.localizedMessage(ctx, 'Η φωτογραφία αποθηκεύτηκε! / Photo saved!'));
    } catch (e, s) {
      DebugConfig.error('Avatar upload failed', data: e, exception: s);
      if (mounted) AppMessenger.showError(ctx, L10n.localizedMessage(ctx, 'Αποτυχία μεταφόρτωσης / Upload failed'));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _pickAndUploadPhoto(int index) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;
    if (!context.mounted)return;
    final ctx = context;
    DebugConfig.log(DebugConfig.storageUpload, 'Photo picked: ${picked.name} index=$index');
    setState(() => _uploadingPhotoIndex = index);
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref.read(profileRepositoryProvider).savePhoto(bytes, index);
      setState(() { while (_photoUrls.length <= index) { _photoUrls.add(''); } _photoUrls[index] = url; });
    } catch (e, s) {
      DebugConfig.error('Photo upload failed', data: e, exception: s);
      if (!context.mounted)return;
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
        latitudeExact: _latitude,
        longitudeExact: _longitude,
        avatarUrl: _avatarUrl,
        photoUrls: _photoUrls.isEmpty ? null : _photoUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveProfile(profile);
      final commSettingsChanged = _loadedProfile != null && (
          _allowVideoCall != _loadedProfile!.allowVideoCall ||
          _allowDirectChat != _loadedProfile!.allowDirectChat);
      final locationChanged = _loadedProfile != null && (
          _cityCtrl.text.trim() != (_loadedProfile!.city ?? '') ||
          _countryCtrl.text.trim() != (_loadedProfile!.country ?? ''));
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
      ref.invalidate(currentProfileProvider);
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
      body: Center(child: SizedBox(width: ResponsiveUtils.maxContentWidth(context),
        child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          _buildAvatarHeader(),
          FormSection(title: g ? 'Βασικά Στοιχεία' : 'Basic Info', children: [
            _buildTextField(icon: Icons.person, label: g ? 'Ψευδώνυμο' : 'Nickname', ctrl: _nicknameCtrl, required: true),
            _buildTextField(icon: Icons.badge_outlined, label: g ? 'Πλήρες Όνομα' : 'Full Name', ctrl: _fullNameCtrl),
            _buildTextField(icon: Icons.article_outlined, label: 'Bio', ctrl: _bioCtrl, maxLines: 3),
          ]),
          FormSection(title: g ? 'Προσωπικά' : 'Personal', children: [
            _buildTextField(icon: Icons.cake_outlined, label: g ? 'Έτος Γέννησης' : 'Birth Year', ctrl: _birthYearCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            ChipSelector(options: _genders, selectedValue: _gender, onSelected: (v) => setState(() => _gender = v), labels: _genderLabels(g)),
          ]),
          FormSection(title: g ? 'Τοποθεσία' : 'Location', children: [
            _buildTextField(icon: Icons.location_city_outlined, label: g ? 'Πόλη' : 'City', ctrl: _cityCtrl),
            _buildTextField(icon: Icons.public_outlined, label: g ? 'Χώρα' : 'Country', ctrl: _countryCtrl),
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
            _buildTextField(icon: Icons.email_outlined, label: 'Email', ctrl: _emailCtrl, keyboardType: TextInputType.emailAddress),
            _buildTextField(icon: Icons.phone_outlined, label: g ? 'Τηλέφωνο' : 'Phone', ctrl: _phoneCtrl, keyboardType: TextInputType.phone),
            const SizedBox(height: 4),
            FormToggle(icon: Icons.videocam_outlined, title: 'Video Call', subtitle: g ? 'Να επιτρέπονται αιτήματα video call' : 'Allow video call requests', value: _allowVideoCall, onChanged: (v) => setState(() => _allowVideoCall = v)),
            FormToggle(icon: Icons.chat_outlined, title: g ? 'Άμεσο Chat' : 'Direct Chat', subtitle: g ? 'Να επιτρέπονται άμεσα μηνύματα' : 'Allow direct messages', value: _allowDirectChat, onChanged: (v) => setState(() => _allowDirectChat = v)),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: SaveButton(isSaving: _isSaving, label: g ? 'Αποθήκευση' : 'Save', onPressed: _save)),
        ]),
      ),
    ),
  ),
  ),
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
          CircleAvatar(radius: 44, backgroundColor: Colors.white,
            backgroundImage: _avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!) : null,
            child: _avatarUrl == null
              ? Text(_nicknameCtrl.text.isNotEmpty ? _nicknameCtrl.text[0].toUpperCase() : '?', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary))
              : null),
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
