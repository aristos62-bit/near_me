import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../debug/debug_config.dart';
import 'timeouts.dart';

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
      late final QuerySnapshot<Map<String, dynamic>> docs;
      try {
        docs = await withTimeout(
          firestore
              .collection('chats').doc(chatId).collection(subcollection)
              .limit(batchSize)
              .get(),
          'cleanup.$subcollection',
          timeout: const Duration(seconds: 10),
        );
      } on TimeoutException {
        // Zombie batch (no-progress), όχι slow-progress: με fatal
        // συμπεριφερόμαστε όπως σε κάθε σφάλμα (rethrow)· με non-fatal
        // σπάμε το loop (όχι retry-in-place → anti-infinite-loop) και ο
        // caller προχωρά (deleteGroup σβήνει το parent — orphans όπως
        // στο error-case).
        if (fatal) rethrow;
        DebugConfig.warn(
            'deleteChatSubcollection: batch TIMEOUT, stopping $subcollection '
            '(non-fatal, partial) chat=$chatId');
        break;
      }

      if (docs.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      try {
        await withTimeout(
          batch.commit(),
          'cleanup.$subcollection.commit',
          timeout: const Duration(seconds: 10),
        );
      } on TimeoutException {
        if (fatal) rethrow;
        DebugConfig.warn(
            'deleteChatSubcollection: commit TIMEOUT, stopping $subcollection '
            '(non-fatal, partial) chat=$chatId');
        break;
      }

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
