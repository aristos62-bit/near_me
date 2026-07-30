import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/connectivity_guard.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../providers/chat_provider.dart';

class AddParticipantScreen extends ConsumerStatefulWidget {
  final String chatId;
  final List<String> currentParticipantUids;
  final int maxParticipants;

  const AddParticipantScreen({
    super.key,
    required this.chatId,
    required this.currentParticipantUids,
    required this.maxParticipants,
  });

  @override
  ConsumerState<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends ConsumerState<AddParticipantScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isAdding = false;
  String? _errorText;
  List<String> _participantUids = [];
  int _maxParticipants = 8;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction,
        'AddParticipantScreen init: chat=${widget.chatId}');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  Future<void> _ensureDataLoaded() async {
    if (_dataLoaded && _participantUids.isNotEmpty) return;
    try {
      final uids = ref.read(participantUidsProvider(widget.chatId));
      // .future περιμένει την πρώτη διαθέσιμη τιμή του stream (ή την ήδη cache-αρισμένη),
      // αντί για ref.read που μπορεί να πιάσει AsyncLoading (null) στο πρώτο άνοιγμα.
      final chatSnap = await ref.read(chatDocProvider(widget.chatId).future);
      final chatData = chatSnap?.data() as Map<String, dynamic>?;
      final maxPart = chatData?['maxParticipants'] as int? ?? widget.maxParticipants;
      if (!mounted) return;
      setState(() {
        _participantUids = uids.isNotEmpty ? uids : widget.currentParticipantUids;
        _maxParticipants = maxPart;
        _dataLoaded = true;
      });
    } catch (e, s) {
      DebugConfig.error('AddParticipant: failed to load chat data', data: e, exception: s);
      if (mounted) {
        setState(() {
          _participantUids = widget.currentParticipantUids;
          _maxParticipants = widget.maxParticipants;
          _dataLoaded = true;
        });
      }
    }
  }

  Future<void> _search(String query) async {
    await _ensureDataLoaded();
    if (!mounted) return;
    if (!await ConnectivityGuard.ensure(context)) return;
    setState(() => _isSearching = true);
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final lowerQuery = query.toLowerCase();
      final currentUids = _participantUids.toSet();
      DebugConfig.log(DebugConfig.repositoryCall, 'AddParticipant search: query=$query');
      final snap = await ref.read(chatRepositoryProvider).searchUsersByNickname(query);

      if (!mounted) return;
      final results = snap
          .map((data) {
            final uid = data['uid'] as String? ?? '';
            final nickname = data['nickname'] as String? ?? uid;
            final isMember = currentUids.contains(uid);
            DebugConfig.log(DebugConfig.repositoryFilter,
                'AddParticipant: uid=$uid isMember=$isMember');
            return <String, dynamic>{
              'uid': uid,
              'nickname': nickname,
              'avatarUrl': data['avatarUrl'] as String?,
              'age': data['age'] as int?,
              'city': data['city'] as String?,
              'isMember': isMember,
            };
          })
          .where((u) => u['uid'] != currentUid)
          .where((u) => (u['nickname'] as String).toLowerCase().contains(lowerQuery))
          .toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
        _errorText = null;
      });
      DebugConfig.log(DebugConfig.repositoryResult,
          'AddParticipant search: ${results.length} results for "$query"');
    } catch (e, s) {
      DebugConfig.error('AddParticipant search failed', data: e, exception: s);
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

  Future<void> _addUser(Map<String, dynamic> user) async {
    final greek = L10n.isGreek(context);
    final uid = user['uid'] as String;
    final nickname = user['nickname'] as String;

    if (_participantUids.length >= _maxParticipants) {
      AppMessenger.showError(context, greek
          ? 'Το όριο μελών ($_maxParticipants) έχει συμπληρωθεί'
          : 'Max members ($_maxParticipants) reached');
      return;
    }
    if (!await ConnectivityGuard.ensure(context)) return;
    setState(() => _isAdding = true);
    try {
      final success = await ref.read(chatActionsProvider.notifier)
          .addParticipant(widget.chatId, uid);
      if (!mounted) return;
      if (success) {
        AppMessenger.showSuccess(context, greek
            ? 'Ο/Η $nickname προστέθηκε στην ομάδα'
            : '$nickname added to the group');
        _searchResults.removeWhere((u) => u['uid'] == uid);
        setState(() => _isAdding = false);
      } else {
        final state = ref.read(chatActionsProvider);
        AppMessenger.showError(context, state.errorMessage ??
            ErrorMessages.get('group/add-member-failed', greek));
        setState(() => _isAdding = false);
      }
    } catch (e, s) {
      DebugConfig.error('AddParticipant failed', data: e, exception: s);
      if (mounted) {
        setState(() => _isAdding = false);
        AppMessenger.showError(context, ErrorMessages.get('group/add-member-failed', greek));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final remaining = _maxParticipants - _participantUids.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(greek ? 'Προσθήκη Μέλους' : 'Add Member'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          final pad = ResponsiveUtils.paddingValueFromWidth(w);
          return ListView(
            padding: EdgeInsets.all(pad),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.group, size: 18,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                    Text(
                    greek
                        ? '${_participantUids.length}/$_maxParticipants μέλη'
                        : '${_participantUids.length}/$_maxParticipants members',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    greek
                        ? '$remaining θέσεις διαθέσιμες'
                        : '$remaining slots available',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: remaining > 0
                            ? Colors.green
                            : theme.colorScheme.error),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
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
                  child: Text(_errorText!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              if (remaining <= 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(children: [
                    Icon(Icons.group_off, size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
                    const SizedBox(height: 12),
                    Text(
                      greek
                          ? 'Το όριο μελών έχει συμπληρωθεί'
                          : 'Member limit reached',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ]),
                )
              else if (_searchCtrl.text.trim().length < 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    greek
                        ? 'Πληκτρολόγησε τουλάχιστον 2 χαρακτήρες'
                        : 'Type at least 2 characters',
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
                      trailing: user['isMember'] == true
                          ? Chip(
                              avatar: Icon(Icons.check_circle, size: 16,
                                  color: theme.colorScheme.primary),
                              label: Text(greek ? 'Μέλος' : 'Member',
                                  style: theme.textTheme.labelSmall),
                              visualDensity: VisualDensity.compact,
                            )
                          : _isAdding
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : FilledButton.tonal(
                                  onPressed: () => _addUser(user),
                                  child: Text(greek ? 'Προσθήκη' : 'Add'),
                                ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
