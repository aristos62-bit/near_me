import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../providers/chat_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _searchCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _selected = <String, String>{};
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isCreating = false;
  bool _isPublic = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'CreateGroupScreen init');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _groupNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _tagsCtrl.dispose();
    _cityCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final lowerQuery = query.toLowerCase();
      final snap = await FirebaseFirestore.instance
          .collectionGroup('public')
          .where('isVisible', isEqualTo: true)
          .where('nicknameLowercase', isGreaterThanOrEqualTo: lowerQuery)
          .where('nicknameLowercase', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .orderBy('nicknameLowercase')
          .limit(50)
          .get();

      if (!mounted) return;
      final results = snap.docs
          .map((doc) {
            final data = doc.data();
            final uid = data['uid'] as String? ?? doc.id;
            final nickname = data['nickname'] as String? ?? uid;
            return <String, dynamic>{
              'uid': uid,
              'nickname': nickname,
              'avatarUrl': data['avatarUrl'] as String?,
              'age': data['age'] as int?,
              'city': data['city'] as String?,
            };
          })
          .where((u) => u['uid'] != currentUid)
          .where((u) => !_selected.containsKey(u['uid']))
          .where((u) => (u['nickname'] as String).toLowerCase().contains(lowerQuery))
          .toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
        _errorText = null;
      });
      DebugConfig.log(DebugConfig.repositoryResult, 'CreateGroup search: ${results.length} results for "$query"');
    } catch (e, s) {
      DebugConfig.error('CreateGroup search failed', data: e, exception: s);
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorText = L10n.isGreek(context)
              ? 'Σφάλμα αναζήτησης'
              : 'Search failed';
        });
      }
    }
  }

  void _toggleUser(Map<String, dynamic> user) {
    final uid = user['uid'] as String;
    final nickname = user['nickname'] as String;
    setState(() {
      if (_selected.containsKey(uid)) {
        _selected.remove(uid);
      } else if (_selected.length < 9) {
        _selected[uid] = nickname;
        _searchResults.removeWhere((u) => u['uid'] == uid);
      }
    });
  }

  void _removeSelected(String uid) {
    setState(() => _selected.remove(uid));
  }

  Future<void> _createGroup() async {
    final greek = L10n.isGreek(context);
    if (_selected.isEmpty) {
      AppMessenger.showError(context, greek
          ? 'Επίλεξε τουλάχιστον 1 άτομο'
          : 'Select at least 1 person');
      return;
    }
    setState(() => _isCreating = true);
    final groupName = _groupNameCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final tags = _tagsCtrl.text.trim().isNotEmpty
        ? _tagsCtrl.text.trim().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : <String>[];
    final city = _cityCtrl.text.trim();
    DebugConfig.log(DebugConfig.uiInteraction,
        'CreateGroupScreen: create with ${_selected.length} members, groupName="$groupName", isPublic=$_isPublic');
    try {
      final chatId = await ref.read(chatActionsProvider.notifier)
          .createGroupChat(_selected.keys.toList(), groupName: groupName.isNotEmpty ? groupName : null, isPublic: _isPublic, description: description.isNotEmpty ? description : null, tags: tags.isNotEmpty ? tags : null, city: city.isNotEmpty ? city : null);
      if (!mounted) return;
      AppMessenger.showSuccess(context, greek
          ? 'Η ομάδα δημιουργήθηκε'
          : 'Group created');
      context.replace('/chat/$chatId');
    } catch (e, s) {
      DebugConfig.error('CreateGroup failed', data: e, exception: s);
      if (mounted) {
        setState(() => _isCreating = false);
        AppMessenger.showError(context, greek
            ? 'Αποτυχία δημιουργίας ομάδας'
            : 'Failed to create group');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(greek ? 'Δημιουργία Ομάδας' : 'Create Group')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          final pad = ResponsiveUtils.paddingValueFromWidth(w);
          return ListView(
            padding: EdgeInsets.all(pad),
            children: [
              TextField(
                controller: _groupNameCtrl,
                decoration: InputDecoration(
                  labelText: greek ? 'Όνομα ομάδας (προαιρετικό)' : 'Group name (optional)',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: SwitchListTile(
                  title: Text(greek ? 'Δημόσια ομάδα' : 'Public group'),
                  subtitle: Text(
                    greek
                        ? 'Θα εμφανίζεται σε αναζήτηση ομάδων'
                        : 'Will appear in group search',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                ),
              ),
              if (_isPublic) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: greek ? 'Περιγραφή (προαιρετικό)' : 'Description (optional)',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagsCtrl,
                  decoration: InputDecoration(
                    labelText: greek ? 'Ετικέτες (προαιρ., διαχωρισμός με κόμμα)' : 'Tags (optional, comma separated)',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cityCtrl,
                  decoration: InputDecoration(
                    labelText: greek ? 'Πόλη (προαιρετικό)' : 'City (optional)',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selected.entries.map((e) => Chip(
                      label: Text(e.value),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeSelected(e.key),
                    )).toList(),
                  ),
                ),
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: greek ? 'Αναζήτηση χρηστών...' : 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_errorText!, style: TextStyle(color: theme.colorScheme.error)),
                ),
              if (_searchCtrl.text.trim().length < 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    greek ? 'Πληκτρολόγησε τουλάχιστον 2 χαρακτήρες' : 'Type at least 2 characters',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_searchResults.isEmpty)
                const EmptyView(
                  icon: Icons.person_search,
                  message: 'No users found',
                )
              else
                ...List.generate(_searchResults.length, (i) {
                  final user = _searchResults[i];
                  final uid = user['uid'] as String;
                  final nickname = user['nickname'] as String;
                  final avatarUrl = user['avatarUrl'] as String?;
                  final age = user['age'] as int?;
                  final city = user['city'] as String?;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(nickname[0].toUpperCase(),
                                style: TextStyle(color: theme.colorScheme.onPrimaryContainer))
                            : null,
                      ),
                      title: Text(nickname),
                      subtitle: Text([
                        if (age != null) '$age',
                        ?city,
                      ].join(' · ')),
                      trailing: IconButton(
                        icon: Icon(
                          _selected.containsKey(uid)
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: _selected.containsKey(uid)
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => _toggleUser(user),
                      ),
                    ),
                  );
                }),
              if (_selected.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  greek
                      ? '${_selected.length}/9 άτομα επιλεγμένα'
                      : '${_selected.length}/9 people selected',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _isCreating ? null : _createGroup,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.group_add),
                  label: Text(_isCreating
                      ? (greek ? 'Δημιουργία...' : 'Creating...')
                      : (greek ? 'Δημιουργία Ομάδας' : 'Create Group')),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
