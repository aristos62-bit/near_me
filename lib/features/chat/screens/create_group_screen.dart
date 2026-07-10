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
  final _selectedUids = <String>{};
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isCreating = false;
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
          .where((u) => !_selectedUids.contains(u['uid']))
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
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
      } else if (_selectedUids.length < 9) {
        _selectedUids.add(uid);
        _searchResults.removeWhere((u) => u['uid'] == uid);
      }
    });
  }

  void _removeSelected(String uid) {
    setState(() => _selectedUids.remove(uid));
  }

  Future<void> _createGroup() async {
    final greek = L10n.isGreek(context);
    if (_selectedUids.isEmpty) {
      AppMessenger.showError(context, greek
          ? 'Επίλεξε τουλάχιστον 1 άτομο'
          : 'Select at least 1 person');
      return;
    }
    setState(() => _isCreating = true);
    final groupName = _groupNameCtrl.text.trim();
    try {
      final chatId = await ref.read(chatActionsProvider.notifier)
          .createGroupChat(_selectedUids.toList(), groupName: groupName.isNotEmpty ? groupName : null);
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
              const SizedBox(height: 16),
              if (_selectedUids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedUids.map((uid) => Chip(
                      label: Text(uid.length > 12 ? '${uid.substring(0, 12)}...' : uid),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeSelected(uid),
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
                          _selectedUids.contains(uid)
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: _selectedUids.contains(uid)
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => _toggleUser(user),
                      ),
                    ),
                  );
                }),
              if (_selectedUids.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  greek
                      ? '${_selectedUids.length}/9 άτομα επιλεγμένα'
                      : '${_selectedUids.length}/9 people selected',
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
