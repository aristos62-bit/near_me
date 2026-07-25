class MessageCallbacks {
  final Future<void> Function(String chatId)? onApproveDelete;
  final Future<void> Function(String chatId)? onRejectDelete;
  final Future<void> Function(String chatId)? onDeleteForMe;
  final Future<void> Function(String chatId)? onKeepChat;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;
  final void Function()? onReply;
  final void Function()? onEdit;
  final void Function()? onDelete;
  final void Function()? onInfo;
  final void Function()? onEmail;
  final void Function()? onShare;
  final Future<void> Function(String url)? onPlayVideo;

  const MessageCallbacks({
    this.onApproveDelete,
    this.onRejectDelete,
    this.onDeleteForMe,
    this.onKeepChat,
    this.onReact,
    this.onRemove,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onInfo,
    this.onEmail,
    this.onShare,
    this.onPlayVideo,
  });
}