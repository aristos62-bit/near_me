import 'package:flutter/material.dart';
import '../../../../core/config/feature_flags.dart';
import '../message_reactions.dart';

/// Κοινό wrapper γύρω από το [MessageReactions] — εμφανίζεται μόνο
/// όταν υπάρχει chatId και είναι ενεργό το feature flag. Ίδια χρήση
/// σε text, gif/image, και emoji-only bubbles.
class MessageReactionsRow extends StatelessWidget {
  final String? chatId;
  final Map<String, dynamic> reactions;
  final String currentUid;
  final String messageId;
  final bool isMe;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;

  const MessageReactionsRow({
    super.key,
    required this.chatId,
    required this.reactions,
    required this.currentUid,
    required this.messageId,
    required this.isMe,
    this.onReact,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (chatId == null || !FeatureFlags.messageReactionsEnabled) {
      return const SizedBox.shrink();
    }
    return MessageReactions(
      reactions: reactions,
      currentUid: currentUid,
      chatId: chatId!,
      messageId: messageId,
      isMe: isMe,
      onReact: onReact,
      onRemove: onRemove,
    );
  }
}