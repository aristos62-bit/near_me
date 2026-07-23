import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../repositories/group_search_repository.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

final _searchResultsProvider = FutureProvider.autoDispose
    .family<List<GroupPublicProfile>, _SearchParams>((ref, params) {
      DebugConfig.log(
        DebugConfig.providerCreate,
        '_searchResultsProvider created: query=${params.query} city=${params.city} tags=${params.tags}',
      );
      ref.onDispose(
        () => DebugConfig.log(
          DebugConfig.providerDispose,
          '_searchResultsProvider disposed',
        ),
      );
      final repo = ref.watch(groupSearchRepositoryProvider);
      return repo.searchGroups(
        query: params.query,
        city: params.city,
        tags: params.tags,
        limit: 50,
      );
    });

class _SearchParams {
  final String? query;
  final String? city;
  final List<String>? tags;
  const _SearchParams({this.query, this.city, this.tags});

  @override
  bool operator ==(Object other) =>
      other is _SearchParams &&
      other.query == query &&
      other.city == city &&
      listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hash(query, city, tags);

  static bool listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class GroupSearchScreen extends ConsumerStatefulWidget {
  const GroupSearchScreen({super.key});

  @override
  ConsumerState<GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends ConsumerState<GroupSearchScreen> {
  final _queryCtrl = TextEditingController();
  Timer? _debounce;
  String? _city;
  List<String>? _tags;

  @override
  void dispose() {
    _queryCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  _SearchParams get _params => _SearchParams(
    query: _queryCtrl.text.trim().isEmpty ? null : _queryCtrl.text.trim(),
    city: _city,
    tags: _tags,
  );

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final resultsAsync = ref.watch(_searchResultsProvider(_params));

    return Scaffold(
      appBar: AppBar(title: Text(greek ? 'Αναζήτηση Ομάδων' : 'Search Groups')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveUtils.paddingValueFromWidth(
                ResponsiveUtils.resolveWidth(context, null),
              ),
              right: ResponsiveUtils.paddingValueFromWidth(
                ResponsiveUtils.resolveWidth(context, null),
              ),
              top: 8,
            ),
            child: TextField(
              controller: _queryCtrl,
              decoration: InputDecoration(
                hintText: greek ? 'Αναζήτηση με όνομα...' : 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryCtrl.clear();
                          setState(() {});
                          ref.invalidate(_searchResultsProvider);
                        },
                      )
                    : null,
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() {});
                });
              },
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: greek ? 'Αποτυχία αναζήτησης' : 'Search failed',
                onRetry: () => ref.invalidate(_searchResultsProvider),
              ),
              data: (results) {
                DebugConfig.log(
                  DebugConfig.repositoryResult,
                  'GroupSearchScreen: ${results.length} results',
                );
                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      greek ? 'Δεν βρέθηκαν ομάδες' : 'No groups found',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.paddingValueFromWidth(
                      ResponsiveUtils.resolveWidth(context, null),
                    ),
                  ),
                  itemCount: results.length,
                  itemBuilder: (_, i) => _GroupSearchTile(group: results[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSearchTile extends ConsumerWidget {
  final GroupPublicProfile group;
  const _GroupSearchTile({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final currentUid = ref.read(authStateProvider).value?.uid ?? '';
    final isCreator = group.createdBy == currentUid;
    final member = _isMember(ref);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    group.groupName.isNotEmpty
                        ? group.groupName[0].toUpperCase()
                        : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.groupName, style: theme.textTheme.titleMedium),
                      Text(
                        greek
                            ? '${group.memberCount} μέλη'
                            : '${group.memberCount} members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCreator)
                  Chip(
                    label: Text(
                      greek ? 'Δικός σου' : 'Yours',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (group.description != null && group.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(group.description!, style: theme.textTheme.bodySmall),
            ],
            if (group.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: group.tags
                    .map(
                      (t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (group.city != null && group.city!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(group.city!, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: isCreator
                  ? OutlinedButton(
                      onPressed: () =>
                          context.push('/groups/${group.chatId}/info'),
                      child: Text(greek ? 'Διαχείριση' : 'Manage'),
                    )
                  : member
                  ? OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/chat/${group.chatId}',
                        extra: ChatNavExtra(
                          isGroupChat: true,
                          groupName: group.groupName,
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(greek ? 'Είσαι Μέλος' : 'Member'),
                    )
                  : FilledButton.icon(
                      onPressed: () => _joinGroup(context, ref),
                      icon: const Icon(Icons.group_add, size: 18),
                      label: Text(greek ? 'Συμμετοχή' : 'Join'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(BuildContext context, WidgetRef ref) async {
    final greek = L10n.isGreek(context);
    DebugConfig.log(
      DebugConfig.uiInteraction,
      'GroupSearchScreen: join group ${group.chatId} (${group.groupName})',
    );
    final success = await ref
        .read(chatActionsProvider.notifier)
        .joinPublicGroup(group.chatId);
    if (success && context.mounted) {
      AppMessenger.showSuccess(
        context,
        greek ? 'Εντάχθηκες στην ομάδα!' : 'Joined the group!',
      );
      ref.invalidate(chatsProvider);
    } else if (context.mounted) {
      final state = ref.read(chatActionsProvider);
      AppMessenger.showError(
        context,
        state.errorMessage ??
            (greek ? 'Αποτυχία συμμετοχής' : 'Failed to join'),
      );
    }
  }

  bool _isMember(WidgetRef ref) {
    final chatsAsync = ref.watch(chatsProvider);
    return chatsAsync.asData?.value.any((c) => c.chatId == group.chatId) ??
        false;
  }
}
