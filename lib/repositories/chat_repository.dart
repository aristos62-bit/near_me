import '../data/local/database.dart';

abstract class ChatRepository {
  Future<String> createChat(String otherUid);
  Future<void> sendMessage(String chatId, String content);
  Future<List<ChatCacheTableData>> getChats();
  Stream<List<ChatCacheTableData>> streamChats();
  Stream<List<Map<String, dynamic>>> messagesStream(String chatId);
  Future<void> markAsRead(String chatId);
  Future<void> deleteChat(String chatId);
  Future<void> clearMessages(String chatId);
}
