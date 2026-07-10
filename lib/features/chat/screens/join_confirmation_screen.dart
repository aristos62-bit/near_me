import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../repositories/chat_repository.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../providers/chat_provider.dart';

class JoinConfirmationScreen extends ConsumerStatefulWidget {
  final String token;

  const JoinConfirmationScreen({super.key, required this.token});

  @override
  ConsumerState<JoinConfirmationScreen> createState() => _JoinConfirmationScreenState();
}

class _JoinConfirmationScreenState extends ConsumerState<JoinConfirmationScreen> {
  InviteInfo? _inviteInfo;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction,
        'JoinConfirmationScreen init: token=${widget.token.length >= 8 ? widget.token.substring(0, 8) : widget.token}...');
    _fetchInviteInfo();
  }

  Future<void> _fetchInviteInfo() async {
    try {
      final info = await ref.read(chatActionsProvider.notifier)
          .getInviteInfo(widget.token);
      if (!mounted) return;
      if (info != null) {
        setState(() {
          _inviteInfo = info;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = null;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      DebugConfig.error('JoinConfirmation fetch info failed', data: e, exception: s);
      if (mounted) {
        setState(() {
          _error = (e is Exception) ? e.toString() : (e.toString());
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmJoin() async {
    final greek = L10n.isGreek(context);
    setState(() => _isJoining = true);
    try {
      final chatId = await ref.read(chatActionsProvider.notifier)
          .redeemInviteLink(widget.token);
      if (!mounted) return;
      if (chatId != null && chatId.isNotEmpty) {
        AppMessenger.showSuccess(context, greek
            ? 'Εντάχθηκες στην ομάδα'
            : 'Joined the group');
        context.go('/chat/$chatId');
      } else {
        final state = ref.read(chatActionsProvider);
        AppMessenger.showError(context, state.errorMessage ??
            (greek ? 'Αποτυχία εγγραφής' : 'Failed to join'));
        setState(() => _isJoining = false);
      }
    } catch (e, s) {
      DebugConfig.error('JoinConfirmation redeem failed', data: e, exception: s);
      if (mounted) {
        setState(() => _isJoining = false);
        AppMessenger.showError(context, greek
            ? 'Αποτυχία εγγραφής στην ομάδα'
            : 'Failed to join group');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(greek ? 'Πρόσκληση σε Ομάδα' : 'Group Invitation'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          final pad = ResponsiveUtils.paddingValueFromWidth(w);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: EdgeInsets.all(pad),
                children: _buildContent(greek, theme),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildContent(bool greek, ThemeData theme) {
    if (_isLoading) {
      return [
        const SizedBox(height: 80),
        const Center(child: LoadingView(message: 'Loading invite info...')),
      ];
    }

    if (_error != null) {
      return [
        const SizedBox(height: 64),
        Icon(Icons.link_off, size: 64,
            color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          greek ? 'Μη έγκυρη πρόσκληση' : 'Invalid invitation',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          greek
              ? 'Αυτός ο σύνδεσμος πρόσκλησης δεν είναι έγκυρος ή έχει λήξει.'
              : 'This invitation link is invalid or has expired.',
          style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.pop(),
          child: Text(greek ? 'Επιστροφή' : 'Go back'),
        ),
      ];
    }

    if (_inviteInfo == null) {
      return [
        const SizedBox(height: 80),
        const Center(child: EmptyView(
          icon: Icons.link_off,
          message: 'Invite info not found',
        )),
      ];
    }

    final info = _inviteInfo!;
    return [
      const SizedBox(height: 40),
      Icon(Icons.group_add, size: 72,
          color: theme.colorScheme.primary),
      const SizedBox(height: 16),
      Text(
        greek ? 'Πρόσκληση σε Ομάδα' : 'Group Invitation',
        style: theme.textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.group, size: 36,
                  color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(info.groupName ?? (greek ? 'Άγνωστη Ομάδα' : 'Unknown Group'),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center),
            if (info.memberCount != null) ...[
              const SizedBox(height: 8),
              Text(
                greek
                    ? '${info.memberCount} μέλη'
                    : '${info.memberCount} members',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _isJoining ? null : _confirmJoin,
        icon: _isJoining
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.login),
        label: Text(_isJoining
            ? (greek ? 'Εγγραφή...' : 'Joining...')
            : (greek ? 'Εγγραφή στην Ομάδα' : 'Join Group')),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => context.pop(),
        child: Text(greek ? 'Ακύρωση' : 'Cancel'),
      ),
    ];
  }
}
