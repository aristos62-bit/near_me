import 'package:flutter/material.dart';
import '../utils/consent_action_config.dart';

class ConsentBadge extends StatelessWidget {
  final String action;
  final String dataType;
  final DateTime timestamp;
  final String? details;

  const ConsentBadge({
    super.key,
    required this.action,
    required this.dataType,
    required this.timestamp,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = ConsentActionConfig.get(action);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (info?.color ?? Colors.grey).withAlpha(30),
          child: Icon(
            ConsentActionConfig.icon(action),
            color: info?.color ?? Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          ConsentActionConfig.label(action, _isGreek(context)),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formattedTimestamp(context),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: details != null && details!.isNotEmpty
            ? Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
    );
  }

  bool _isGreek(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'el';
  }

  String _formattedTimestamp(BuildContext context) {
    try {
      final now = DateTime.now();
      final diff = now.difference(timestamp);
      final greek = _isGreek(context);
      if (diff.isNegative) return greek ? 'Μόλις τώρα' : 'Just now';
      if (diff.inMinutes < 1) return greek ? 'Μόλις τώρα' : 'Just now';
      if (diff.inHours < 1) return greek ? '${diff.inMinutes}λ πριν' : '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return greek ? '${diff.inHours}ω πριν' : '${diff.inHours}h ago';
      if (diff.inDays < 30) return greek ? '${diff.inDays}η πριν' : '${diff.inDays}d ago';
      if (diff.inDays < 365) return greek ? '${(diff.inDays / 30).floor()}μ πριν' : '${(diff.inDays / 30).floor()}mo ago';
      return greek ? '${(diff.inDays / 365).floor()}χ πριν' : '${(diff.inDays / 365).floor()}y ago';
    } catch (_) {
      return '';
    }
  }
}
