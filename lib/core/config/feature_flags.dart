class FeatureFlags {
  const FeatureFlags._();

  // Search
  static const bool typesenseEnabled = false;

  // Communication
  static const bool videoCallEnabled = false;
  static const bool groupChatEnabled = true;
  static const bool incomingShareEnabled = true;
  static const bool phoneVerificationEnabled = false;

  // Discovery
  static const bool aiMatchingEnabled = false;
  static const bool verifiedBadgeEnabled = false;

  // SOS / Emergency Help
  static const bool helpRequestEnabled = true;

  // Monetization
  static const bool premiumTierEnabled = false;

  // Future
  static const bool groupEventsEnabled = false;
  static const bool webVersionEnabled = false;

  // Media
  static const bool gifSupportEnabled = true;
  static const bool mediaMessagesEnabled = true;
  static const bool audioMessagesEnabled = true;
  static const bool videoMessagesEnabled = true;

  // Message Expiry (P3.2)
  static const bool messageExpiryEnabled = true;

  // Reactions
  static const bool messageReactionsEnabled = true;

  // Reply to Message
  static const bool replyToMessageEnabled = true;
  static const bool replyPrivatelyEnabled = true;

  // Message actions (long-tap)
  static const bool editMessageEnabled = true;
  static const bool deleteMessageEnabled = true;
  static const bool messageInfoEnabled = true;
  static const bool messageEmailEnabled = true;
  static const bool messageShareEnabled = true;
}
