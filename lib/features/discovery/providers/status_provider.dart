import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';

class UserStatus {
  final bool isOnline;
  final DateTime? lastSeen;
  const UserStatus({required this.isOnline, this.lastSeen});
}

const Duration _presenceTTL = Duration(seconds: 120);

final userStatusProvider = StreamProvider.family<UserStatus, String>((ref, uid) {
  return FirebaseFirestore.instance
      .doc('users/$uid/status/status')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return const UserStatus(isOnline: false);
    final data = snap.data()!;
    final isOnline = data['isOnline'] as bool? ?? false;
    final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();

    // TTL safety net: if lastSeen is older than 2 heartbeats, treat as offline
    final effectiveOnline = isOnline &&
        lastSeen != null &&
        DateTime.now().difference(lastSeen) < _presenceTTL;

    DebugConfig.log(DebugConfig.presence,
        'userStatus uid=$uid isOnline=$isOnline lastSeen=$lastSeen effective=$effectiveOnline');

    return UserStatus(
      isOnline: effectiveOnline,
      lastSeen: lastSeen,
    );
  });
});
