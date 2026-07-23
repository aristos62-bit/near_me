import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/app_messenger.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/requests_provider.dart';

class RequestCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;
  final bool isIncoming;
  final bool isGreek;
  final bool isSelected;
  final bool selectionMode;
  final bool isHighlighted;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onLongPress;

  const RequestCard({
    super.key,
    required this.request,
    required this.isIncoming,
    required this.isGreek,
    this.isSelected = false,
    this.selectionMode = false,
    this.isHighlighted = false,
    this.onToggleSelection,
    this.onLongPress,
  });

  @override
  ConsumerState<RequestCard> createState() => RequestCardState();
}

class RequestCardState extends ConsumerState<RequestCard> {
  bool _isResponding = false;
  Timer? _highlightTimer;
  bool _showHighlight = false;

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) {
      _showHighlight = true;
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showHighlight = false);
      });
      DebugConfig.log(DebugConfig.uiInteraction, 'RequestCard: isHighlighted=true id=${widget.request['id']}');
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherUid = widget.request[widget.isIncoming ? 'fromUid' : 'toUid'] as String;
    final type = (widget.request['type'] as String?) ?? '';
    final status = (widget.request['status'] as String?) ?? '';
    final message = widget.request['message'] as String?;
    final requestId = (widget.request['id'] as String?) ?? '';
    final createdAt = (widget.request['createdAt'] as Timestamp?)?.toDate();
    final chatId = widget.request['chatId'] as String?;
    final readAt = widget.request['readAt'];
    final isUnread = widget.isIncoming && status == 'pending' && readAt == null;
    final theme = Theme.of(context);

    DebugConfig.log(DebugConfig.uiInteraction, 'RequestCard: id=$requestId other=$otherUid type=$type status=$status isUnread=$isUnread');

    final profileAsync = ref.watch(publicProfileStreamProvider(otherUid));
    final profile = profileAsync.asData?.value;
    final nickname = profile?.nickname ?? otherUid;
    final avatarUrl = profile?.avatarUrl;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: _showHighlight
          ? theme.colorScheme.primaryContainer.withAlpha(80)
          : widget.isSelected ? theme.colorScheme.primaryContainer.withAlpha(60) : null,
      child: InkWell(
        onTap: widget.selectionMode
            ? widget.onToggleSelection
            : (isUnread ? () => _markAsSeen(requestId) : null),
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
                  if (isUnread)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
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
                  Expanded(
                    child: Text(
                      nickname,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  _TypeBadge(type: type, isGreek: widget.isGreek),
                  if (!widget.isIncoming) ...[
                    const SizedBox(width: 8),
                    _StatusBadge(status: status, isGreek: widget.isGreek),
                  ],
                ],
              ),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(message, style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                ), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 8, runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (createdAt != null)
                    Text(L10n.formatDateTime(context, createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (widget.isIncoming && status == 'pending') ...[
                    if (_isResponding)
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      const SizedBox(width: 0),
                      _ActionChip(
                        label: widget.isGreek ? 'Αποδοχή' : 'Accept',
                        icon: Icons.check_circle,
                        color: Colors.green.shade700,
                        onTap: () => _respond(requestId, 'accepted'),
                      ),
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

  void _markAsSeen(String requestId) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'RequestCard markAsSeen: $requestId');
    try {
      await ref.read(requestRepositoryProvider).markRequestAsSeen(requestId);
    } catch (e) {
      DebugConfig.warn('RequestCard markAsSeen failed', data: e);
    }
  }

  void _respond(String requestId, String status) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'RequestCard respond: $requestId status=$status');
    setState(() => _isResponding = true);
    try {
      final chatId = await ref.read(requestRepositoryProvider).respondToRequest(requestId, status);
      if (!mounted) return;
      if (chatId != null) {
        AppMessenger.showSuccess(context, L10n.localizedMessage(context, 'Αίτημα αποδέκτηκε / Request accepted'));
        Future.microtask(() { if (mounted) context.push('/chat/$chatId'); });
      } else {
        AppMessenger.showSuccess(context,
            status == 'accepted'
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

class FilterBar extends StatelessWidget {
  final String filter;
  final bool isGreek;
  final ValueChanged<String> onChanged;
  const FilterBar({super.key, required this.filter, required this.isGreek, required this.onChanged});

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
