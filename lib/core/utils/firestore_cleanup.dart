import 'package:cloud_firestore/cloud_firestore.dart';
import '../debug/debug_config.dart';

/// Διαγράφει όλα τα έγγραφα ενός subcollection με batching (SPoT).
/// Χρησιμοποιείται από deleteGroup (audit_log, invites, messages),
/// clearMessages (messages) και _deleteChatForEveryone (messages).
///
/// [fatal]: αν true (default), αναρίπτει το σφάλμα — διατήρηση της αυστηρής
/// συμπεριφοράς clearMessages/_deleteChatForEveryone. Αν false, non-fatal —
/// το deleteGroup σβήνει κανονικά ακόμα κι αν ο καθαρισμός του subcollection
/// αποτύχει (ο κύριος σκοπός είναι ο καθαρισμός του chat document).
Future<void> deleteChatSubcollection(
    FirebaseFirestore firestore, String chatId, String subcollection,
    {bool fatal = true}) async {
  DebugConfig.log(DebugConfig.repositoryCall,
      'deleteChatSubcollection: clearing $subcollection chat=$chatId');
  try {
    const batchSize = 500;
    int totalDeleted = 0;
    bool hasMore = true;

    while (hasMore) {
      final docs = await firestore
          .collection('chats').doc(chatId).collection(subcollection)
          .limit(batchSize)
          .get();

      if (docs.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      totalDeleted += docs.docs.length;
      DebugConfig.log(DebugConfig.firestoreWrite,
          'deleteChatSubcollection: batch deleted ${docs.docs.length} of '
          '$subcollection (total=$totalDeleted) chat=$chatId');

      if (docs.docs.length < batchSize) hasMore = false;
    }

    DebugConfig.log(DebugConfig.repositoryResult,
        'deleteChatSubcollection: $subcollection cleared '
        '(total=$totalDeleted) chat=$chatId');
  } catch (e) {
    if (fatal) rethrow;
    DebugConfig.warn(
        'deleteChatSubcollection: failed to clear $subcollection '
        '(non-fatal) chat=$chatId', data: e);
  }
}
