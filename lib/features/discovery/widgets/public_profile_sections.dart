import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/models/public_profile.dart';

Widget buildProfileSectionCard(BuildContext context,
    {required Widget child, required String title, required IconData icon}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );
}

Widget buildProfileLookingForCard(
    BuildContext context, PublicProfile profile, ThemeData theme, bool isGreek) {
  final value = profile.lookingFor;
  if (value == null) return const SizedBox.shrink();
  return buildProfileSectionCard(
    context,
    icon: Icons.explore_outlined,
    title: isGreek ? 'Ενδιαφέρεται για' : 'Looking For',
    child: Chip(
      label: Text(L10n.lookingForLabel(value, isGreek: isGreek)),
      avatar: Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
      visualDensity: VisualDensity.compact,
    ),
  );
}

Widget buildProfileInterestsCard(
    BuildContext context, PublicProfile profile, ThemeData theme, bool isGreek) {
  final interests = profile.interests;
  if (interests == null || interests.isEmpty) return const SizedBox.shrink();
  return buildProfileSectionCard(
    context,
    icon: Icons.interests_outlined,
    title: isGreek ? 'Ενδιαφέροντα' : 'Interests',
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      children: interests.map((i) => Chip(
            label: Text(L10n.interestLabel(i, isGreek: isGreek),
                style: const TextStyle(fontSize: 13)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )).toList(),
    ),
  );
}

Widget buildProfileBioCard(
    BuildContext context, PublicProfile profile, ThemeData theme, bool isGreek) {
  final bio = profile.bio;
  if (bio == null || bio.isEmpty) return const SizedBox.shrink();
  return buildProfileSectionCard(
    context,
    icon: Icons.article_outlined,
    title: isGreek ? 'Σχετικά' : 'About',
    child: Text(bio,
        style: theme.textTheme.bodyMedium
            ?.copyWith(height: 1.5, color: theme.colorScheme.onSurfaceVariant)),
  );
}

Widget buildProfileCommunicationCard(
    BuildContext context, PublicProfile profile, ThemeData theme, bool isGreek) {
  return buildProfileSectionCard(
    context,
    icon: Icons.chat_outlined,
    title: isGreek ? 'Επικοινωνία' : 'Communication',
    child: Column(
      children: [
        _buildCommRow(
          icon: Icons.chat_bubble_outline,
          label: isGreek ? 'Απευθείας μηνύματα' : 'Direct Messages',
          allowed: profile.allowDirectChat,
          theme: theme,
          isGreek: isGreek,
        ),
        const SizedBox(height: 8),
        _buildCommRow(
          icon: Icons.videocam_outlined,
          label: isGreek ? 'Βιντεοκλήση' : 'Video Call',
          allowed: profile.allowVideoCall,
          theme: theme,
          isGreek: isGreek,
        ),
      ],
    ),
  );
}

Widget _buildCommRow({
  required IconData icon,
  required String label,
  required bool allowed,
  required ThemeData theme,
  required bool isGreek,
}) {
  return Row(
    children: [
      Icon(allowed ? Icons.check_circle : Icons.cancel_outlined, size: 20,
          color: allowed
              ? const Color(0xFF4CAF50)
              : theme.colorScheme.onSurfaceVariant.withAlpha(120)),
      const SizedBox(width: 10),
      Text(label, style: theme.textTheme.bodyMedium),
      const Spacer(),
      Text(allowed ? (isGreek ? 'Ναι' : 'Yes') : (isGreek ? 'Όχι' : 'No'),
          style: theme.textTheme.bodySmall?.copyWith(
              color: allowed
                  ? const Color(0xFF4CAF50)
                  : theme.colorScheme.onSurfaceVariant.withAlpha(120))),
    ],
  );
}

Widget buildProfileContactCard(BuildContext context, PublicProfile profile,
    ThemeData theme, bool isGreek, String uid) {
  final hasEmail = profile.email != null && profile.email!.isNotEmpty;
  final hasPhone = profile.phone != null && profile.phone!.isNotEmpty;
  if (!hasEmail && !hasPhone) return const SizedBox.shrink();

  DebugConfig.log(DebugConfig.uiInteraction,
      'PublicProfileView: contact card shown for $uid '
      '(email=$hasEmail, phone=$hasPhone)');

  return buildProfileSectionCard(
    context,
    icon: Icons.contact_mail_outlined,
    title: isGreek ? 'Στοιχεία Επικοινωνίας' : 'Contact Details',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasEmail)
          _buildContactRow(
            icon: Icons.email_outlined,
            label: isGreek ? 'Email' : 'Email',
            value: profile.email!,
            theme: theme,
          ),
        if (hasEmail && hasPhone) const SizedBox(height: 10),
        if (hasPhone)
          _buildContactRow(
            icon: Icons.phone_outlined,
            label: isGreek ? 'Τηλέφωνο' : 'Phone',
            value: profile.phone!,
            theme: theme,
          ),
      ],
    ),
  );
}

Widget _buildContactRow({
  required IconData icon,
  required String label,
  required String value,
  required ThemeData theme,
}) {
  return Row(
    children: [
      Icon(icon, size: 20, color: theme.colorScheme.primary),
      const SizedBox(width: 10),
      Text('$label: ',
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      Expanded(
        child: Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
    ],
  );
}
