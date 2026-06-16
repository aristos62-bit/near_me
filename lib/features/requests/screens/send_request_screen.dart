import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/models/public_profile.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/requests_provider.dart';

class SendRequestScreen extends ConsumerStatefulWidget {
  final String uid;
  const SendRequestScreen({super.key, required this.uid});

  @override
  ConsumerState<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends ConsumerState<SendRequestScreen> {
  String? _selectedType;
  final _messageController = TextEditingController();
  bool _isSending = false;
  late final Future<PublicProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'SendRequestScreen init: uid=${widget.uid}');
    _profileFuture = ref.read(profileRepositoryProvider).getPublicProfile(widget.uid);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(isGreek ? 'Αποστολή Αιτήματος' : 'Send Request')),
      body: FutureBuilder<PublicProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final nickname = snapshot.data?.nickname ?? widget.uid;
          return Center(
            child: SizedBox(
              width: ResponsiveUtils.maxContentWidth(context),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecipientInfo(nickname, theme, isGreek),
                    const SizedBox(height: 24),
                    _buildTypeSelector(snapshot.data, theme, isGreek),
                    const SizedBox(height: 20),
                    _buildMessageField(theme, isGreek),
                    const SizedBox(height: 24),
                    _buildSendButton(theme, isGreek),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipientInfo(String nickname, ThemeData theme, bool isGreek) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withAlpha(25),
              child: Text(
                nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nickname, style: theme.textTheme.titleSmall),
                  Text(isGreek ? 'Παραλήπτης' : 'Recipient',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(PublicProfile? profile, ThemeData theme, bool isGreek) {
    final chatAllowed = profile?.allowDirectChat ?? true;
    final videoAllowed = profile?.allowVideoCall ?? true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.category_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(isGreek ? 'Τύπος Αιτήματος' : 'Request Type',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            if (chatAllowed)
              _typeChip('chat', Icons.chat_bubble_outline, isGreek ? 'Συνομιλία' : 'Chat', Colors.blue, theme)
            else
              _disabledTypeChip(Icons.chat_bubble_outline, isGreek ? 'Συνομιλία (μη διαθέσιμη)' : 'Chat (not available)', theme),
            const SizedBox(height: 8),
            if (videoAllowed)
              _typeChip('video', Icons.videocam_outlined, isGreek ? 'Βιντεοκλήση' : 'Video Call', Colors.purple, theme)
            else
              _disabledTypeChip(Icons.videocam_outlined, isGreek ? 'Βιντεοκλήση (μη διαθέσιμη)' : 'Video Call (not available)', theme),
            const SizedBox(height: 8),
            _typeChip('email', Icons.email_outlined, isGreek ? 'Email' : 'Email', Colors.orange, theme),
          ],
        ),
      ),
    );
  }

  Widget _disabledTypeChip(IconData icon, String label, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withAlpha(60)),
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(80))),
        ],
      ),
    );
  }

  Widget _typeChip(String type, IconData icon, String label, Color color, ThemeData theme) {
    final selected = _selectedType == type;
    return InkWell(
      onTap: () {
        DebugConfig.log(DebugConfig.uiInteraction, 'SendRequestScreen type selected: $type');
        setState(() => _selectedType = type);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : theme.dividerColor, width: selected ? 2 : 1),
          color: selected ? color.withAlpha(15) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: selected ? color : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.w600 : null,
                color: selected ? color : null)),
            const Spacer(),
            if (selected)
              Icon(Icons.check_circle, size: 20, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageField(ThemeData theme, bool isGreek) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.message_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(isGreek ? 'Μήνυμα (προαιρετικό)' : 'Message (optional)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: isGreek
                    ? 'Γράψε ένα σύντομο μήνυμα...'
                    : 'Write a short message...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withAlpha(120)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(14),
                counterText: '',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme, bool isGreek) {
    final user = ref.watch(authStateProvider).value;
    final isAnonymous = user == null || user.isAnonymous;
    final disabled = isAnonymous || _selectedType == null || _isSending;

    if (isAnonymous) {
      DebugConfig.log(DebugConfig.uiInteraction, 'SendRequestScreen: send button disabled (anonymous)');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAnonymous)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isGreek
                          ? 'Πρέπει να επαληθεύσεις τον λογαριασμό σου'
                          : 'You must verify your account',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: disabled ? null : _sendRequest,
            icon: _isSending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined, size: 20),
            label: Text(_isSending
                ? (isGreek ? 'Αποστολή...' : 'Sending...')
                : (isGreek ? 'Αποστολή Αιτήματος' : 'Send Request')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendRequest() async {
    final type = _selectedType!;
    final message = _messageController.text.trim();
    DebugConfig.log(DebugConfig.uiInteraction, 'SendRequestScreen send: to=${widget.uid} type=$type message=${message.length}chars');

    setState(() => _isSending = true);
    try {
      await ref.read(requestRepositoryProvider).sendRequest(
        widget.uid,
        type,
        message: message.isNotEmpty ? message : null,
      );
      if (mounted) {
        AppMessenger.showSuccess(context, L10n.localizedMessage(context,
            'Το αίτημα στάλθηκε / Request sent'));
        ref.invalidate(outgoingRequestsProvider);
        context.pop();
      }
    } catch (e) {
      DebugConfig.error('SendRequestScreen send failed', data: e);
      if (mounted) {
        setState(() => _isSending = false);
        final msg = e is AppException
            ? L10n.localizedMessage(context, e.message)
            : L10n.localizedMessage(context, 'Αποτυχία αποστολής / Failed to send');
        AppMessenger.showError(context, msg);
      }
    }
  }
}
