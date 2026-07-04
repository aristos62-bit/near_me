import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drift/drift.dart';
import '../data/local/database.dart';
import '../data/local/database_service.dart';
import 'auth_repository.dart';
import 'request_repository.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';
import 'chat_repository.dart';
import 'chat_repository_impl.dart';

class RequestRepositoryImpl implements RequestRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AppDatabase _db;
  final ChatRepository _chatRepo;

  RequestRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AppDatabase? db,
    ChatRepository? chatRepo,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? DatabaseService.instance,
        _chatRepo = chatRepo ?? ChatRepositoryImpl();

  @override
  Future<void> sendRequest(String toUid, String type, {String? message}) async {
    final user = _auth.currentUser;
    if (user == null) throw AppException.auth('send_request', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    if (!AuthRepository.canUserCommunicate(user)) {
      DebugConfig.log(DebugConfig.authGuard, 'sendRequest: blocked unverified user');
      throw AppException.auth('send_request', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου για να στείλεις αίτημα / You must verify your account');
    }

    final uid = user.uid;
    DebugConfig.log(DebugConfig.repositoryCall, 'sendRequest: from=$uid to=$toUid type=$type');

    try {
      final blockDoc = await _firestore
          .doc('users/$toUid/blocked/$uid')
          .get();
      if (blockDoc.exists) {
        DebugConfig.log(DebugConfig.repositoryCall, 'sendRequest: blocked by $toUid');
        throw AppException.auth('send_request',
            'Αυτός ο χρήστης σε έχει αποκλείσει / This user has blocked you');
      }
      DebugConfig.log(DebugConfig.firestoreRead, 'sendRequest: not blocked by $toUid');
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.warn('sendRequest: block check failed (rules will enforce): $e');
    }

    // Validate target's communication settings
    try {
      final targetDoc = await _firestore
          .collection('users').doc(toUid).collection('public').doc('profile').get();
      if (!targetDoc.exists) {
        DebugConfig.log(DebugConfig.repositoryCall, 'sendRequest: target public profile not found');
        throw AppException.auth('send_request',
            'Ο χρήστης δεν έχει δημόσιο προφίλ / User has no public profile');
      }
      final targetData = targetDoc.data()!;
      if (type == 'chat' && targetData['allowDirectChat'] != true) {
        DebugConfig.log(DebugConfig.repositoryCall, 'sendRequest: target disabled direct chat');
        throw AppException.auth('send_request',
            'Ο χρήστης δεν επιτρέπει άμεσα μηνύματα / This user does not allow direct messages');
      }
      if (type == 'video' && targetData['allowVideoCall'] != true) {
        DebugConfig.log(DebugConfig.repositoryCall, 'sendRequest: target disabled video call');
        throw AppException.auth('send_request',
            'Ο χρήστης δεν επιτρέπει βιντεοκλήσεις / This user does not allow video calls');
      }
      DebugConfig.log(DebugConfig.firestoreRead,
          'sendRequest pre-check: exists=${targetDoc.exists} allowDirectChat=${targetData['allowDirectChat']} allowVideoCall=${targetData['allowVideoCall']}');
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.warn('sendRequest pre-check: target profile read failed: $e');
    }

    // debug: check own banned status before sending
    try {
      final bannedDoc = await _firestore.collection('banned').doc(uid).get();
      DebugConfig.log(DebugConfig.firestoreRead,
          'sendRequest pre-check: banned exists=${bannedDoc.exists}');
    } catch (e) {
      DebugConfig.warn('sendRequest pre-check: banned doc read failed: $e');
    }

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 48));

    try {
      await _firestore.collection('requests').add({
        'fromUid': uid,
        'toUid': toUid,
        'type': type,
        'status': 'pending',
        'message': message,
        'createdAt': now,
        'expiresAt': expiresAt,
      });
      DebugConfig.log(DebugConfig.repositoryResult, 'sendRequest: success to=$toUid type=$type');

      await _logConsent(uid, toUid, type);
    } catch (e) {
      DebugConfig.error('sendRequest failed', data: e);
      throw AppException.firestore('send_request', 'Αποτυχία αποστολής αιτήματος / Failed to send request');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final uid = user.uid;
    DebugConfig.log(DebugConfig.repositoryCall, 'getIncomingRequests: uid=$uid');

    try {
      final snapshot = await _firestore
          .collection('requests')
          .where('toUid', isEqualTo: uid)
          .where('status', whereIn: ['pending', 'accepted', 'declined', 'expired'])
          .orderBy('createdAt', descending: true)
          .get();

      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      DebugConfig.log(DebugConfig.repositoryResult, 'getIncomingRequests: ${result.length} requests');
      return result;
    } catch (e) {
      DebugConfig.error('getIncomingRequests failed', data: e);
      throw AppException.firestore('get_incoming', 'Αποτυχία φόρτωσης εισερχομένων / Failed to load incoming requests');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOutgoingRequests() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final uid = user.uid;
    DebugConfig.log(DebugConfig.repositoryCall, 'getOutgoingRequests: uid=$uid');

    try {
      final snapshot = await _firestore
          .collection('requests')
          .where('fromUid', isEqualTo: uid)
          .where('status', whereIn: ['pending', 'accepted', 'declined', 'expired'])
          .orderBy('createdAt', descending: true)
          .get();

      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      DebugConfig.log(DebugConfig.repositoryResult, 'getOutgoingRequests: ${result.length} requests');
      return result;
    } catch (e) {
      DebugConfig.error('getOutgoingRequests failed', data: e);
      throw AppException.firestore('get_outgoing', 'Αποτυχία φόρτωσης εξερχομένων / Failed to load outgoing requests');
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> streamIncomingRequests() {
    final user = _auth.currentUser;
    if (user == null) {
      DebugConfig.warn('streamIncomingRequests: no authenticated user');
      return const Stream.empty();
    }
    final uid = user.uid;
    DebugConfig.log(DebugConfig.firestoreStream, 'streamIncomingRequests: uid=$uid');
    return _firestore
        .collection('requests')
        .where('toUid', isEqualTo: uid)
        .where('status', whereIn: ['pending', 'accepted', 'declined', 'expired'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      DebugConfig.log(DebugConfig.firestoreStream, 'streamIncomingRequests: ${result.length} requests');
      return result;
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> streamOutgoingRequests() {
    final user = _auth.currentUser;
    if (user == null) {
      DebugConfig.warn('streamOutgoingRequests: no authenticated user');
      return const Stream.empty();
    }
    final uid = user.uid;
    DebugConfig.log(DebugConfig.firestoreStream, 'streamOutgoingRequests: uid=$uid');
    return _firestore
        .collection('requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', whereIn: ['pending', 'accepted', 'declined', 'expired'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      DebugConfig.log(DebugConfig.firestoreStream, 'streamOutgoingRequests: ${result.length} requests');
      return result;
    });
  }

  @override
  Future<String?> respondToRequest(String requestId, String status) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'respondToRequest: id=$requestId status=$status');

    if (status != 'accepted' && status != 'declined') {
      throw AppException(message: 'Μη έγκυρη κατάσταση / Invalid status: $status', code: 'validation_error');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw AppException.auth('respond_request', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    }
    if (!AuthRepository.canUserCommunicate(user)) {
      DebugConfig.log(DebugConfig.authGuard, 'respondToRequest: blocked unverified user');
      throw AppException.auth('respond_request', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου / You must verify your account');
    }

    try {
      final docRef = _firestore.collection('requests').doc(requestId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        DebugConfig.warn('respondToRequest: request not found id=$requestId');
        throw AppException(message: 'Το αίτημα δεν βρέθηκε / Request not found', code: 'not_found');
      }

      final data = docSnap.data()!;
      final currentStatus = data['status'] as String?;

      if (currentStatus != 'pending') {
        DebugConfig.warn('respondToRequest: already $currentStatus id=$requestId');
        throw AppException(
          message: 'Το αίτημα έχει ήδη απαντηθεί / Request already $currentStatus',
          code: 'conflict',
        );
      }

      final toUid = data['toUid'] as String?;
      if (toUid != user.uid) {
        DebugConfig.warn('respondToRequest: unauthorized by ${user.uid} (expected $toUid)');
        throw AppException.auth('respond_request', 'Δεν έχετε δικαίωμα / Unauthorized');
      }

      final type = data['type'] as String? ?? '';
      String? chatId;

      if (status == 'accepted') {
        chatId = data['chatId'] as String?;

        if (type == 'chat' && chatId == null) {
          final fromUid = data['fromUid'] as String? ?? '';
          DebugConfig.log(DebugConfig.repositoryCall, 'respondToRequest: creating chat for request=$requestId from=$fromUid');
          chatId = await _chatRepo.createChat(fromUid);
          DebugConfig.log(DebugConfig.repositoryResult, 'respondToRequest: chat created id=$chatId');
        }

        final updateData = <String, dynamic>{
          'status': status,
          'respondedAt': FieldValue.serverTimestamp(),
        };
        if (chatId != null) updateData['chatId'] = chatId;
        await docRef.update(updateData);
      } else {
        await docRef.update({
          'status': status,
          'respondedAt': FieldValue.serverTimestamp(),
        });
      }

      DebugConfig.log(DebugConfig.repositoryResult, 'respondToRequest: success id=$requestId status=$status chatId=$chatId');
      return chatId;
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.error('respondToRequest failed', data: e);
      throw AppException.firestore('respond_request', 'Αποτυχία απάντησης / Failed to respond to request');
    }
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) throw AppException.auth('delete_request', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    if (!AuthRepository.canUserCommunicate(user)) {
      DebugConfig.log(DebugConfig.authGuard, 'deleteRequest: blocked unverified user');
      throw AppException.auth('delete_request', 'Πρέπει να επαληθεύσεις τον λογαριασμό σου / You must verify your account');
    }

    DebugConfig.log(DebugConfig.repositoryCall, 'deleteRequest: id=$requestId');

    try {
      final docRef = _firestore.collection('requests').doc(requestId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        DebugConfig.warn('deleteRequest: not found id=$requestId');
        return;
      }

      final data = docSnap.data()!;
      final fromUid = data['fromUid'] as String?;
      final toUid = data['toUid'] as String?;

      if (fromUid != user.uid && toUid != user.uid) {
        throw AppException.auth('delete_request', 'Δεν έχετε δικαίωμα / Unauthorized');
      }

      await docRef.delete();
      DebugConfig.log(DebugConfig.repositoryResult, 'deleteRequest: done id=$requestId');
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.error('deleteRequest failed', data: e);
      throw AppException.firestore('delete_request', 'Αποτυχία διαγραφής / Failed to delete request');
    }
  }

  Future<void> _logConsent(String uid, String toUid, String type) async {
    try {
      await _db.into(_db.consentLogTable).insert(
        ConsentLogTableCompanion.insert(
          uid: Value(uid),
          action: Value('sent_request'),
          dataType: Value(type),
          details: Value('Sent request to $toUid / Αποστολή αιτήματος σε $toUid'),
        ),
      );
      DebugConfig.log(DebugConfig.consentLogWrite, 'sendRequest consent logged: type=$type to=$toUid');
    } catch (e, s) {
      DebugConfig.error('sendRequest consent log failed', data: e, exception: s);
      // Non-fatal: request already sent to Firestore
    }
  }
}
