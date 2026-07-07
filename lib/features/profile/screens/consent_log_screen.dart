import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/l10n.dart';
import '../../../data/local/database.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../shared/utils/consent_action_config.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../providers/consent_log_provider.dart';

class ConsentLogScreen extends ConsumerStatefulWidget {
  const ConsentLogScreen({super.key});

  @override
  ConsumerState<ConsentLogScreen> createState() => _ConsentLogScreenState();
}

class _ConsentLogScreenState extends ConsumerState<ConsentLogScreen> {
  String? _filterAction;

  static const _actionFilters = <String?>[
    null,
    'publish',
    'unpublish',
    'sent_request',
    'shared_location',
    'uploaded_photo',
    'deleted_account',
  ];

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(consentLogStreamProvider);
    final theme = Theme.of(context);
    final greek = L10n.isGreek(context);

    return Scaffold(
      appBar: AppBar(title: Text(greek ? 'Ιστορικό Συγκατάθεσης' : 'Consent Log')),
      body: logsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: L10n.localizedMessage(context, 'Σφάλμα φόρτωσης / Failed to load'),
          details: e.toString(),
          onRetry: () => ref.invalidate(consentLogStreamProvider),
        ),
        data: (logs) {
          final filtered = _filterAction == null
              ? logs
              : logs.where((l) => l.action == _filterAction).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final w = ResponsiveUtils.resolveWidth(context, constraints);
              final isWide = ResponsiveUtils.isTabletFromWidth(w);
              return Column(
                children: [
                  _buildHeader(theme, greek, logs.length),
                  _buildFilterBar(theme, greek),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyView(
                            icon: Icons.shield_outlined,
                            message: _filterAction == null
                                ? (greek
                                    ? 'Δεν υπάρχουν καταχωρήσεις ακόμα\nΟι ενέργειες συγκατάθεσης θα εμφανίζονται εδώ'
                                    : 'No consent entries yet\nActions will appear here')
                                : (greek
                                    ? 'Δεν υπάρχουν καταχωρήσεις για αυτή την ενέργεια'
                                    : 'No entries for this action'),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: isWide ? 48 : 12,
                              vertical: 8,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _buildEntry(theme, filtered[i], greek),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool greek, int total) {
    return GradientHeader(
      icon: Icons.shield_outlined,
      title: greek ? 'Ιστορικό Συγκατάθεσης' : 'Consent Log',
      subtitle: greek
          ? 'Βλέπε ποιες ενέργειες έκανες και πότε κοινοποίησες δεδομένα σου'
          : 'See what actions you performed and when you shared your data',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool greek) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _actionFilters.map((action) {
            final selected = _filterAction == action;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_filterLabel(action, greek)),
                selected: selected,
                onSelected: (_) => setState(() => _filterAction = action),
                selectedColor: ConsentActionConfig.color(action ?? 'published').withAlpha(30),
                checkmarkColor: ConsentActionConfig.color(action ?? 'published'),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: selected ? ConsentActionConfig.color(action ?? 'published') : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEntry(ThemeData theme, ConsentLogTableData log, bool greek) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ConsentActionConfig.color(log.action).withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            ConsentActionConfig.icon(log.action, outlined: true),
            color: ConsentActionConfig.color(log.action),
            size: 22,
          ),
        ),
        title: Text(
          ConsentActionConfig.label(log.action, greek),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              _dataTypeLabel(log.dataType, greek),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _formatTimestamp(context, log.timestamp, greek),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
              ),
            ),
          ],
        ),
        trailing: log.details != null && log.details!.isNotEmpty
            ? Tooltip(
                message: log.details!,
                child: Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant.withAlpha(150)),
              )
            : null,
      ),
    );
  }

  String _filterLabel(String? action, bool greek) {
    if (action == null) return greek ? 'Όλες' : 'All';
    return ConsentActionConfig.label(action, greek);
  }

  String _dataTypeLabel(String type, bool greek) {
    switch (type) {
      case 'profile': return greek ? 'Δεδομένα: Προφίλ' : 'Data: Profile';
      case 'location': return greek ? 'Δεδομένα: Τοποθεσία' : 'Data: Location';
      case 'photo': return greek ? 'Δεδομένα: Φωτογραφία' : 'Data: Photo';
      case 'chat_key': return greek ? 'Δεδομένα: Κλειδί συνομιλίας' : 'Data: Chat Key';
      default: return greek ? 'Δεδομένα: $type' : 'Data: $type';
    }
  }

  String _formatTimestamp(BuildContext context, DateTime dt, bool greek) {
    final now = DateTime.now();
    final time = DateFormat('HH:mm').format(dt);

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return greek ? 'Σήμερα, $time' : 'Today, $time';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return greek ? 'Χθες, $time' : 'Yesterday, $time';
    }
    final date = DateFormat(greek ? 'd MMMM' : 'MMM d').format(dt);
    if (dt.year == now.year) return '$date, $time';
    final yearStr = DateFormat('y').format(dt);
    return '$date $yearStr, $time';
  }
}
