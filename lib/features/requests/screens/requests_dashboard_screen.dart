import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../repositories/auth_repository.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../profile/providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/requests_provider.dart';

class RequestsDashboardScreen extends ConsumerStatefulWidget {
  const RequestsDashboardScreen({super.key});
  @override
  ConsumerState<RequestsDashboardScreen> createState() => _RequestsDashboardScreenState();
}

class _RequestsDashboardScreenState extends ConsumerState<RequestsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _incomingFilter = 'all';
  String _outgoingFilter = 'all';
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _filter(bool isIncoming) => isIncoming ? _incomingFilter : _outgoingFilter;

  void _setFilter(bool isIncoming, String value) {
    final wasSelectionMode = _selectionMode;
    setState(() {
      if (isIncoming) { _incomingFilter = value; } else { _outgoingFilter = value; }
      if (wasSelectionMode) {
        _selectedIds.clear();
        _selectionMode = false;
      }
    });
    DebugConfig.log(DebugConfig.uiInteraction,
        'Requests filter: ${isIncoming ? "incoming" : "outgoing"}=$value${wasSelectionMode ? " (exited selection mode)" : ""}');
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) { _selectedIds.remove(id); } else { _selectedIds.add(id); }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _toggleSelectAll(WidgetRef ref, bool isIncoming) {
    final provider = isIncoming ? incomingRequestsProvider : outgoingRequestsProvider;
    final allRequests = ref.read(provider).asData?.value ?? [];
    final filter = _filter(isIncoming);
    final filtered = filter == 'all'
        ? allRequests
        : allRequests.where((r) => r['status'] == filter).toList();
    final allIds = filtered.map((r) => r['id'] as String).toSet();
    final willSelect = _selectedIds.length < filtered.length;
    setState(() {
      if (willSelect) {
        _selectedIds.addAll(allIds);
        _selectionMode = true;
      } else {
        _selectedIds.clear();
        _selectionMode = false;
      }
    });
    DebugConfig.log(DebugConfig.uiInteraction,
        '_toggleSelectAll: ${willSelect ? "select" : "deselect"} all (filter=$filter, total=${filtered.length})');
  }

  void _exitSelectionMode() {
    DebugConfig.log(DebugConfig.uiInteraction, '_exitSelectionMode: ${_selectedIds.length} items cleared');
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    DebugConfig.log(DebugConfig.uiInteraction, '_deleteSelected: count=$count');
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Διαγραφή / Delete'),
      message: L10n.localizedMessage(context, 'Διαγραφή $count αιτημάτων / Delete $count requests?'),
      confirmLabel: L10n.isGreek(context) ? 'Διαγραφή' : 'Delete',
      cancelLabel: L10n.isGreek(context) ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final repo = ref.read(requestRepositoryProvider);
    for (final id in _selectedIds.toList()) {
      try {
        await repo.deleteRequest(id);
      } catch (e) {
        DebugConfig.warn('deleteSelected: failed for $id', data: e);
      }
    }
    _exitSelectionMode();
    ref.invalidate(incomingRequestsProvider);
    ref.invalidate(outgoingRequestsProvider);
    if (mounted) {
      AppMessenger.showSuccess(
        context,
        L10n.localizedMessage(context, 'Διαγράφηκαν $count αιτήματα / Deleted $count requests'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;
    final canComm = AuthRepository.canUserCommunicate(user);
    DebugConfig.log(DebugConfig.uiInteraction, 'RequestsDashboard build: canComm=$canComm');

    if (!canComm) {
      return Scaffold(
        appBar: AppBar(title: Text(isGreek ? 'Αιτήματα' : 'Requests')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 72,
                    color: theme.colorScheme.primary.withAlpha(80)),
                const SizedBox(height: 20),
                Text(
                  isGreek ? 'Τα αιτήματα είναι κλειδωμένα' : 'Requests are locked',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  isGreek
                      ? 'Για να στείλεις και να λάβεις αιτήματα, πρέπει πρώτα να επαληθεύσεις τον λογαριασμό σου.'
                      : 'To send and receive requests, you need to verify your account first.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/auth'),
                  icon: const Icon(Icons.verified_user_outlined, size: 18),
                  label: Text(isGreek ? 'Επαλήθευση Λογαριασμού' : 'Verify Account'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(isGreek ? 'Αιτήματα' : 'Requests'),
        bottom: _selectionMode
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: isGreek ? 'Εισερχόμενα' : 'Incoming'),
                  Tab(text: isGreek ? 'Εξερχόμενα' : 'Outgoing'),
                ],
              ),
      ),
      body: _selectionMode
          ? _buildSelectionBar(isGreek, ref)
          : TabBarView(
              controller: _tabController,
              children: [
                _requestsTab(isIncoming: true, isGreek: isGreek),
                _requestsTab(isIncoming: false, isGreek: isGreek),
              ],
            ),
    );
  }

  Widget _buildSelectionBar(bool isGreek, WidgetRef ref) {
    final isIncoming = _tabController.index == 0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
          child: Row(
            children: [
              Text('${_selectedIds.length} ${isGreek ? 'επιλεγμένα' : 'selected'}'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _toggleSelectAll(ref, isIncoming),
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(isGreek ? 'Επιλογή όλων' : 'Select all'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                icon: const Icon(Icons.delete_forever, size: 18),
                label: Text(isGreek ? 'Διαγραφή' : 'Delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _requestsTab(isIncoming: true, isGreek: isGreek),
              _requestsTab(isIncoming: false, isGreek: isGreek),
            ],
          ),
        ),
      ],
    );
  }

  Widget _requestsTab({required bool isIncoming, required bool isGreek}) {
    final provider = isIncoming ? incomingRequestsProvider : outgoingRequestsProvider;
    final requestsAsync = ref.watch(provider);
    final filter = _filter(isIncoming);
    return Center(
      child: SizedBox(
        width: ResponsiveUtils.maxContentWidth(context),
        child: Column(
          children: [
            _FilterBar(
              filter: filter,
              isGreek: isGreek,
              onChanged: (v) => _setFilter(isIncoming, v),
            ),
            Expanded(
              child: requestsAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: L10n.localizedMessage(context, 'Σφάλμα φόρτωσης / Failed to load'),
                  onRetry: () => ref.invalidate(provider),
                ),
                data: (requests) {
                  final filtered = filter == 'all'
                      ? requests
                      : requests.where((r) => r['status'] == filter).toList();
                  if (filtered.isEmpty) {
                    return EmptyView(
                      icon: isIncoming ? Icons.inbox_outlined : Icons.outbox_outlined,
                      message: isIncoming
                          ? (isGreek ? 'Δεν έχεις εισερχόμενα αιτήματα' : 'No incoming requests')
                          : (isGreek ? 'Δεν έχεις στείλει αιτήματα' : 'No outgoing requests'),
                    );
                  }
                  return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _RequestCard(
                        request: filtered[i],
                        isIncoming: isIncoming,
                        isGreek: isGreek,
                        isSelected: _selectedIds.contains(filtered[i]['id']),
                        selectionMode: _selectionMode,
                        onToggleSelection: _selectionMode
                            ? () => _toggleSelection(filtered[i]['id'] as String)
                            : null,
                        onLongPress: () => setState(() {
                          _selectionMode = true;
                          _selectedIds.add(filtered[i]['id'] as String);
                        }),
                      ),
                    );
                  },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;
  final bool isIncoming;
  final bool isGreek;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onLongPress;

  const _RequestCard({
    required this.request,
    required this.isIncoming,
    required this.isGreek,
    this.isSelected = false,
    this.selectionMode = false,
    this.onToggleSelection,
    this.onLongPress,
  });

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _isResponding = false;

  @override
  Widget build(BuildContext context) {
    final otherUid = widget.request[widget.isIncoming ? 'fromUid' : 'toUid'] as String;
    final type = (widget.request['type'] as String?) ?? '';
    final status = (widget.request['status'] as String?) ?? '';
    final message = widget.request['message'] as String?;
    final requestId = (widget.request['id'] as String?) ?? '';
    final createdAt = (widget.request['createdAt'] as Timestamp?)?.toDate();
    final chatId = widget.request['chatId'] as String?;
    final theme = Theme.of(context);

    DebugConfig.log(DebugConfig.uiInteraction, '_RequestCard: id=$requestId other=$otherUid type=$type status=$status');

    final profileAsync = ref.watch(publicProfileStreamProvider(otherUid));
    final profile = profileAsync.asData?.value;
    final nickname = profile?.nickname ?? otherUid;
    final avatarUrl = profile?.avatarUrl;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: widget.isSelected ? theme.colorScheme.primaryContainer.withAlpha(60) : null,
      child: InkWell(
        onTap: widget.selectionMode ? widget.onToggleSelection : null,
        onLongPress: widget.selectionMode ? null : widget.onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        widget.isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: widget.isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withAlpha(25),
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(nickname, style: theme.textTheme.titleSmall)),
                  _TypeBadge(type: type, isGreek: widget.isGreek),
                  if (!widget.isIncoming) ...[
                    const SizedBox(width: 8),
                    _StatusBadge(status: status, isGreek: widget.isGreek),
                  ],
                ],
              ),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (createdAt != null)
                    Text(L10n.formatDateTime(context, createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  if (widget.isIncoming && status == 'pending') ...[
                    if (_isResponding)
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      _ActionChip(
                        label: widget.isGreek ? 'Αποδοχή' : 'Accept',
                        icon: Icons.check_circle,
                        color: Colors.green.shade700,
                        onTap: () => _respond(requestId, 'accepted'),
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        label: widget.isGreek ? 'Απόρριψη' : 'Decline',
                        icon: Icons.cancel,
                        color: Colors.red.shade700,
                        onTap: () => _respond(requestId, 'declined'),
                      ),
                    ],
                  ],
                  if (status == 'accepted' && type == 'chat' && chatId != null && chatId.isNotEmpty)
                    _ChatButton(chatId: chatId, isGreek: widget.isGreek),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return card;
  }

  void _respond(String requestId, String status) async {
    DebugConfig.log(DebugConfig.uiInteraction, '_RequestCard respond: $requestId status=$status');
    setState(() => _isResponding = true);
    try {
      final chatId = await ref.read(requestRepositoryProvider).respondToRequest(requestId, status);
      if (!mounted) return;
      if (chatId != null) {
        AppMessenger.showSuccess(context, L10n.localizedMessage(context, 'Αίτημα αποδέκτηκε / Request accepted'));
        context.push('/chat/$chatId');
      } else {
        final resultKey = status == 'accepted' ? 'accepted' : 'declined';
        AppMessenger.showSuccess(context,
            resultKey == 'accepted'
                ? L10n.localizedMessage(context, 'Αίτημα αποδέκτηκε / Request accepted')
                : L10n.localizedMessage(context, 'Αίτημα απορρίφθηκε / Request declined'));
      }
    } catch (e) {
      if (mounted) AppMessenger.showError(context, L10n.localizedMessage(context, 'Απέτυχε / Failed'));
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final bool isGreek;
  const _TypeBadge({required this.type, required this.isGreek});

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    Color color;
    switch (type) {
      case 'chat':
        label = isGreek ? 'Συνομιλία' : 'Chat';
        icon = Icons.chat_bubble_outline;
        color = Colors.blue;
      case 'video':
        label = isGreek ? 'Βιντεοκλήση' : 'Video Call';
        icon = Icons.videocam_outlined;
        color = Colors.purple;
      case 'email':
        label = isGreek ? 'Email' : 'Email';
        icon = Icons.email_outlined;
        color = Colors.orange;
      default:
        label = type;
        icon = Icons.help_outline;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isGreek;
  const _StatusBadge({required this.status, required this.isGreek});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (status) {
      case 'pending':
        label = isGreek ? 'Αναμονή' : 'Pending';
        color = Colors.orange;
      case 'accepted':
        label = isGreek ? 'Αποδέκτηκε' : 'Accepted';
        color = Colors.green;
      case 'declined':
        label = isGreek ? 'Απορρίφθηκε' : 'Declined';
        color = Colors.red;
      case 'expired':
        label = isGreek ? 'Έληξε' : 'Expired';
        color = Colors.grey;
      default:
        label = status;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: color.withAlpha(80)), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
        ]),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String filter;
  final bool isGreek;
  final ValueChanged<String> onChanged;
  const _FilterBar({required this.filter, required this.isGreek, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('all', isGreek ? 'Όλα' : 'All'),
      ('pending', isGreek ? 'Ενεργά' : 'Active'),
      ('accepted', isGreek ? 'Εκτελεσμένα' : 'Completed'),
      ('declined', isGreek ? 'Απορριφθέντα' : 'Declined'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final opt in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(opt.$2, style: TextStyle(fontSize: 13)),
                selected: filter == opt.$1,
                onSelected: (_) => onChanged(opt.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatButton extends StatelessWidget {
  final String chatId;
  final bool isGreek;
  const _ChatButton({required this.chatId, required this.isGreek});

  @override
  Widget build(BuildContext context) {
    DebugConfig.log(DebugConfig.uiInteraction, '_ChatButton: chatId=$chatId');
    return InkWell(
      onTap: () => context.push('/chat/$chatId'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue.shade700.withAlpha(80)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(
            isGreek ? 'Συνομιλία' : 'Chat',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.blue.shade700),
          ),
        ]),
      ),
    );
  }
}