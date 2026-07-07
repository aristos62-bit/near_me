import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../repositories/auth_repository.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/requests_provider.dart';
import '../widgets/request_card_widgets.dart';

class RequestsDashboardScreen extends ConsumerStatefulWidget {
  final String? highlightRequestId;

  const RequestsDashboardScreen({super.key, this.highlightRequestId});

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
  bool _highlightPending = false;
  bool _highlightConsumed = false;
  ScrollController? _incomingScrollCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.highlightRequestId != null) {
      _highlightPending = true;
      _incomingScrollCtrl = ScrollController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabController.animateTo(0);
      });
    }
    DebugConfig.log(DebugConfig.navigationDeepLink,
        'RequestsDashboard init: highlightRequestId=${widget.highlightRequestId} pending=$_highlightPending');
  }

  @override
  void dispose() {
    _incomingScrollCtrl?.dispose();
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('${_selectedIds.length} ${isGreek ? 'επιλεγμένα' : 'selected'}'),
                const SizedBox(width: 12),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = ResponsiveUtils.resolveWidth(context, constraints);
        return Center(
          child: SizedBox(
            width: ResponsiveUtils.maxContentWidthFromWidth(w),
        child: Column(
          children: [
            FilterBar(
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

                  if (isIncoming && _highlightPending && !_highlightConsumed) {
                    _highlightConsumed = true;
                    _highlightPending = false;
                    final idx = filtered.indexWhere((r) => r['id'] == widget.highlightRequestId);
                    if (idx != -1) {
                      DebugConfig.log(DebugConfig.navigationDeepLink,
                          'RequestsDashboard: scrolling to highlightRequestId=${widget.highlightRequestId} at index=$idx');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _incomingScrollCtrl != null && _incomingScrollCtrl!.hasClients) {
                          final maxExtent = _incomingScrollCtrl!.position.maxScrollExtent;
                          _incomingScrollCtrl!.animateTo(
                            (idx * 200.0).clamp(0.0, maxExtent),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    } else {
                      DebugConfig.log(DebugConfig.navigationDeepLink,
                          'RequestsDashboard: highlightRequestId=${widget.highlightRequestId} not found in incoming');
                    }
                  }

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
                      controller: isIncoming ? _incomingScrollCtrl : null,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => RequestCard(
                        request: filtered[i],
                        isIncoming: isIncoming,
                        isGreek: isGreek,
                        isSelected: _selectedIds.contains(filtered[i]['id']),
                        selectionMode: _selectionMode,
                        isHighlighted: filtered[i]['id'] == widget.highlightRequestId,
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
      },
    );
  }
}
