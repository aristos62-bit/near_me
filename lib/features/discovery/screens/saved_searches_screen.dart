import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../data/local/database.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../providers/saved_search_provider.dart';

class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searches = ref.watch(savedSearchesProvider);
    final isGreek = L10n.isGreek(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isGreek ? 'Αποθηκευμένες Αναζητήσεις' : 'Saved Searches'),
      ),
      body: searches.when(
        loading: () => const Center(child: LoadingView()),
        error: (e, s) {
          DebugConfig.error('SavedSearchesScreen load error', data: e, exception: s);
          return ErrorView(
            message: L10n.localizedMessage(context, 'Σφάλμα φόρτωσης / Failed to load'),
            onRetry: () => ref.invalidate(savedSearchesProvider),
          );
        },
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: EmptyView(
                icon: Icons.bookmark_border,
              message: L10n.localizedMessage(context,
                  'Δεν έχεις αποθηκευμένες αναζητήσεις / No saved searches yet'),
                actionLabel: isGreek ? 'Πίσω στην Ανακάλυψη' : 'Back to Discover',
                onAction: () => context.pop(),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _SearchCard(search: list[index], isGreek: isGreek),
          );
        },
      ),
    );
  }
}

class _SearchCard extends ConsumerWidget {
  final SavedSearchTableData search;
  final bool isGreek;
  const _SearchCard({required this.search, required this.isGreek});

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (search.city != null && search.city!.isNotEmpty) {
      parts.add(search.city!);
    }
    if (search.minAge != null || search.maxAge != null) {
      parts.add('${search.minAge ?? 18}-${search.maxAge ?? 80} '
          '${isGreek ? 'ετών' : 'yrs'}');
    }
    if (search.gender != null && search.gender != 'all') {
      parts.add(L10n.genderLabel(search.gender!, isGreek: isGreek));
    }
    if (search.lookingFor != null && search.lookingFor!.isNotEmpty) {
      parts.add(L10n.lookingForLabel(search.lookingFor!, isGreek: isGreek));
    }
    if (search.radiusKm != null) {
      parts.add('${search.radiusKm!.round()} km');
    }
    final summary = parts.join(' • ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          DebugConfig.log(DebugConfig.uiInteraction,
              'SavedSearch apply: ${search.label}');
          await ref.read(savedSearchActionsProvider).apply(search);
          if (context.mounted) context.pop();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bookmark, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (search.label != null && search.label!.isNotEmpty)
                          ? search.label!
                          : (isGreek ? 'Χωρίς όνομα' : 'Unnamed'),
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20,
                        color: theme.colorScheme.error),
                    onPressed: () async {
                      final label = (search.label != null && search.label!.isNotEmpty)
                          ? search.label!
                          : (isGreek ? 'αναζήτησης' : 'search');
                      final confirmed = await AppMessenger.showConfirmDialog(
                        context,
                        title: L10n.localizedMessage(context, 'Διαγραφή / Delete'),
                        message: L10n.localizedMessage(context, 'Διαγραφή "$label" / Delete "$label"?'),
                        confirmLabel: isGreek ? 'Διαγραφή' : 'Delete',
                        isDestructive: true,
                      );
                      if (!confirmed || !context.mounted) return;
                      await ref.read(savedSearchActionsProvider).delete(search.id);
                      if (context.mounted) {
                        AppMessenger.showSuccess(context,
                            L10n.localizedMessage(context, 'Διαγράφηκε / Deleted'));
                      }
                    },
                  ),
                ],
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(summary, style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
              ],
              if (search.allowVideoCall == true ||
                  search.allowDirectChat == true ||
                  search.onlineOnly == true) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (search.allowVideoCall == true)
                      _buildBadge(
                        context,
                        icon: Icons.videocam,
                        label: isGreek ? 'Βίντεο' : 'Video',
                      ),
                    if (search.allowDirectChat == true)
                      _buildBadge(
                        context,
                        icon: Icons.chat,
                        label: isGreek ? 'Chat' : 'Chat',
                      ),
                    if (search.onlineOnly == true)
                      _buildBadge(
                        context,
                        icon: Icons.circle,
                        label: isGreek ? 'Μόνο Online' : 'Online Only',
                        iconColor: Colors.green,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                L10n.formatDateTime(context, search.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(140)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
