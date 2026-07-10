import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

final _chatDocForSettingsProvider = StreamProvider.autoDispose.family<DocumentSnapshot?, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, '_chatDocForSettingsProvider created for chat: $chatId');
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, '_chatDocForSettingsProvider disposed for chat: $chatId'));
  return FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots();
});

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String chatId;
  const GroupSettingsScreen({super.key, required this.chatId});

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  final _maxPController = TextEditingController();
  bool _isSavingMax = false;
  bool _isUploadingAvatar = false;
  int? _currentMax;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'GroupSettingsScreen init: ${widget.chatId}');
  }

  @override
  void dispose() {
    _maxPController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final greek = L10n.isGreek(context);
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (xFile == null) return;
      if (!mounted) return;
      setState(() => _isUploadingAvatar = true);
      final success = await ref.read(chatActionsProvider.notifier).updateGroupAvatar(widget.chatId, xFile);
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      if (success) {
        AppMessenger.showSuccess(context, greek ? 'Το avatar ενημερώθηκε' : 'Avatar updated');
      }
    } catch (e, s) {
      DebugConfig.error('GroupSettings: pickAndUploadAvatar failed', data: e, exception: s);
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      AppMessenger.showError(context, greek ? 'Αποτυχία αλλαγής avatar' : 'Failed to update avatar');
    }
  }

  Future<void> _removeAvatar() async {
    final greek = L10n.isGreek(context);
    try {
      setState(() => _isUploadingAvatar = true);
      await ref.read(chatActionsProvider.notifier).removeGroupAvatar(widget.chatId);
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      AppMessenger.showSuccess(context, greek ? 'Το avatar αφαιρέθηκε' : 'Avatar removed');
    } catch (e, s) {
      DebugConfig.error('GroupSettings: removeAvatar failed', data: e, exception: s);
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      AppMessenger.showError(context, greek ? 'Αποτυχία αφαίρεσης avatar' : 'Failed to remove avatar');
    }
  }

  Future<void> _saveMaxParticipants() async {
    final greek = L10n.isGreek(context);
    final newMax = int.tryParse(_maxPController.text.trim());
    if (newMax == null || newMax < 2 || newMax > 100) {
      AppMessenger.showError(context, greek
          ? 'Επιτρέπονται 2-100 συμμετέχοντες'
          : 'Allowed 2-100 participants');
      return;
    }
    if (newMax == _currentMax) return;
    setState(() => _isSavingMax = true);
    try {
      final success = await ref.read(chatActionsProvider.notifier).updateMaxParticipants(widget.chatId, newMax);
      if (!mounted) return;
      setState(() => _isSavingMax = false);
      if (success) {
        setState(() => _currentMax = newMax);
        AppMessenger.showSuccess(context, greek ? 'Ενημερώθηκε' : 'Updated');
      }
    } catch (e, s) {
      DebugConfig.error('GroupSettings: saveMaxParticipants failed', data: e, exception: s);
      if (!mounted) return;
      setState(() => _isSavingMax = false);
      AppMessenger.showError(context, greek ? 'Αποτυχία ενημέρωσης' : 'Failed to update');
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final currentUid = ref.read(authStateProvider).value?.uid ?? '';
    final chatDoc = ref.watch(_chatDocForSettingsProvider(widget.chatId));
    final permissionsAsync = ref.watch(groupPermissionsProvider(widget.chatId));

    final chatData = chatDoc.asData?.value?.data() as Map<String, dynamic>?;
    final avatarUrl = chatData?['groupAvatarUrl'] as String?;
    final maxP = chatData?['maxParticipants'] as int? ?? 10;
    if (_currentMax == null && maxP > 0) {
      _currentMax = maxP;
      _maxPController.text = maxP.toString();
    }

    final isCreator = chatData?['createdBy'] == currentUid;
    final canChangeAvatar = chatData != null && (isCreator || (chatData['participantRoles'] as Map?)?[currentUid] == 'admin');

    return Scaffold(
      appBar: AppBar(title: Text(greek ? 'Ρυθμίσεις Ομάδας' : 'Group Settings')),
      body: chatDoc.isLoading
          ? const LoadingView()
          : ListView(
              padding: EdgeInsets.all(ResponsiveUtils.paddingValueFromWidth(
                  ResponsiveUtils.resolveWidth(context, null))),
              children: [
                _sectionHeader(context, greek ? 'Avatar Ομάδας' : 'Group Avatar'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null ? const Icon(Icons.group, size: 40) : null,
                          ),
                          if (_isUploadingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FilledButton.icon(
                              onPressed: canChangeAvatar && !_isUploadingAvatar ? _pickAndUploadAvatar : null,
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: Text(greek ? 'Αλλαγή' : 'Change'),
                            ),
                            if (avatarUrl != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: canChangeAvatar && !_isUploadingAvatar ? _removeAvatar : null,
                                icon: const Icon(Icons.delete, size: 18),
                                label: Text(greek ? 'Αφαίρεση' : 'Remove'),
                                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionHeader(context, greek ? 'Μέγιστος Αριθμός Μελών' : 'Max Participants'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _maxPController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: greek ? 'Αριθμός μελών (2-100)' : 'Member count (2-100)',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _isSavingMax
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : FilledButton(
                              onPressed: _saveMaxParticipants,
                              child: Text(greek ? 'Αποθήκευση' : 'Save'),
                            ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionHeader(context, greek ? 'Δικαιώματα' : 'Permissions'),
                permissionsAsync.when(
                  loading: () => const Card(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )),
                  error: (e, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(greek ? 'Αποτυχία φόρτωσης' : 'Failed to load',
                          style: theme.textTheme.bodySmall),
                    ),
                  ),
                  data: (perms) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _permRow(greek ? 'Δημιουργός' : 'Creator', greek ? 'Πλήρη δικαιώματα' : 'Full access'),
                          _permRow(greek ? 'Διαχειριστής' : 'Admin', greek
                              ? 'Όλα εκτός από διαχείριση admins & permissions'
                              : 'All except manage admins & permissions'),
                          _permRow(greek ? 'Μέλος' : 'Member', greek
                              ? 'Μόνο ανάγνωση (default)'
                              : 'Read-only (default)'),
                          const Divider(),
                          Text(greek ? 'Ατομικές Παραμετροποιήσεις:' : 'Individual Overrides:',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          if (perms.overrides.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(greek ? 'Καμία' : 'None',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant)),
                            )
                          else
                            ...perms.overrides.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${e.key}: ${e.value.entries.where((ee) => ee.value).map((ee) => ee.key).join(", ")}',
                                style: theme.textTheme.bodySmall,
                              ),
                            )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  Widget _permRow(String role, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(role, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(description, style: theme.textTheme.bodySmall)),
      ]),
    );
  }
}
