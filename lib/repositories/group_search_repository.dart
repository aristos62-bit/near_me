import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';

class GroupPublicProfile {
  final String chatId;
  final String groupName;
  final String? groupAvatarUrl;
  final int memberCount;
  final String? description;
  final List<String> tags;
  final String? city;
  final bool isPublic;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GroupPublicProfile({
    required this.chatId,
    required this.groupName,
    this.groupAvatarUrl,
    this.memberCount = 0,
    this.description,
    this.tags = const [],
    this.city,
    this.isPublic = true,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupPublicProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return GroupPublicProfile(
      chatId: data?['chatId'] as String? ?? doc.id,
      groupName: data?['groupName'] as String? ?? '',
      groupAvatarUrl: data?['groupAvatarUrl'] as String?,
      memberCount: data?['memberCount'] as int? ?? 0,
      description: data?['description'] as String?,
      tags: (data?['tags'] as List?)?.cast<String>() ?? [],
      city: data?['city'] as String?,
      isPublic: data?['isPublic'] as bool? ?? true,
      createdBy: data?['createdBy'] as String? ?? '',
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data?['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

abstract class GroupSearchRepository {
  Future<List<GroupPublicProfile>> searchGroups({
    String? query,
    String? city,
    List<String>? tags,
    int limit = 20,
  });

  Future<void> createPublicProfile(String chatId, GroupPublicProfile profile);

  Future<void> updatePublicProfile(String chatId, GroupPublicProfile profile);

  Future<void> deletePublicProfile(String chatId);
}

class FirestoreGroupSearchRepository implements GroupSearchRepository {
  final FirebaseFirestore firestore;

  FirestoreGroupSearchRepository({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<GroupPublicProfile>> searchGroups({
    String? query,
    String? city,
    List<String>? tags,
    int limit = 20,
  }) async {
    DebugConfig.log(DebugConfig.repositoryCall,
        'FirestoreGroupSearchRepository.searchGroups: query=$query, city=$city, tags=$tags, limit=$limit');

    limit = limit.clamp(1, 100);

    try {
      Query queryRef = firestore
          .collection('groups')
          .where('isPublic', isEqualTo: true);

      final hasCity = city != null && city.isNotEmpty;
      final hasTags = tags != null && tags.isNotEmpty;

      if (hasCity) {
        queryRef = queryRef.where('city', isEqualTo: city);
      }
      if (hasTags) {
        queryRef = queryRef.where(
          'tags',
          arrayContainsAny: tags.take(10).toList(),
        );
      }

      final snapshot = await queryRef.limit(limit).get();

      var results = snapshot.docs
          .map((doc) => GroupPublicProfile.fromFirestore(doc))
          .toList();

      if (query != null && query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        results = results
            .where((p) => p.groupName.toLowerCase().contains(lowerQuery))
            .toList();
      }

      DebugConfig.log(DebugConfig.repositoryResult,
          'searchGroups: ${results.length} results');
      return results;
    } on FirebaseException catch (e) {
      DebugConfig.error('searchGroups: Firestore query failed',
          data: e.message ?? e.code);
      throw AppException.firestore('search_groups', e);
    } catch (e, s) {
      DebugConfig.error('searchGroups failed', data: e, exception: s);
      throw AppException.firestore('search_groups', e);
    }
  }

  @override
  Future<void> createPublicProfile(
      String chatId, GroupPublicProfile profile) async {
    DebugConfig.log(DebugConfig.firestoreWrite,
        'createPublicProfile: chatId=$chatId');

    try {
      await firestore.collection('groups').doc(chatId).set({
        'chatId': chatId,
        'groupName': profile.groupName,
        if (profile.groupAvatarUrl != null)
          'groupAvatarUrl': profile.groupAvatarUrl,
        'memberCount': profile.memberCount,
        if (profile.description != null) 'description': profile.description,
        if (profile.tags.isNotEmpty) 'tags': profile.tags,
        if (profile.city != null) 'city': profile.city,
        'isPublic': profile.isPublic,
        'createdBy': profile.createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      DebugConfig.log(DebugConfig.repositoryResult,
          'createPublicProfile: done chatId=$chatId');
    } on FirebaseException catch (e) {
      DebugConfig.error('createPublicProfile: Firestore write failed',
          data: e.message ?? e.code);
      throw AppException.firestore('create_public_profile', e);
    } catch (e, s) {
      DebugConfig.error('createPublicProfile failed', data: e, exception: s);
      throw AppException.firestore('create_public_profile', e);
    }
  }

  @override
  Future<void> updatePublicProfile(
      String chatId, GroupPublicProfile profile) async {
    DebugConfig.log(DebugConfig.firestoreWrite,
        'updatePublicProfile: chatId=$chatId');

    try {
      final data = <String, dynamic>{
        'groupName': profile.groupName,
        'memberCount': profile.memberCount,
        'isPublic': profile.isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (profile.groupAvatarUrl != null) {
        data['groupAvatarUrl'] = profile.groupAvatarUrl;
      } else {
        data['groupAvatarUrl'] = FieldValue.delete();
      }
      if (profile.description != null) {
        data['description'] = profile.description;
      } else {
        data['description'] = FieldValue.delete();
      }
      if (profile.tags.isNotEmpty) {
        data['tags'] = profile.tags;
      } else {
        data['tags'] = FieldValue.delete();
      }
      if (profile.city != null) {
        data['city'] = profile.city;
      } else {
        data['city'] = FieldValue.delete();
      }
      await firestore.collection('groups').doc(chatId).update(data);
      DebugConfig.log(DebugConfig.repositoryResult,
          'updatePublicProfile: done chatId=$chatId');
    } on FirebaseException catch (e) {
      DebugConfig.error('updatePublicProfile: Firestore write failed',
          data: e.message ?? e.code);
      throw AppException.firestore('update_public_profile', e);
    } catch (e, s) {
      DebugConfig.error('updatePublicProfile failed', data: e, exception: s);
      throw AppException.firestore('update_public_profile', e);
    }
  }

  @override
  Future<void> deletePublicProfile(String chatId) async {
    DebugConfig.log(DebugConfig.firestoreWrite,
        'deletePublicProfile: chatId=$chatId');

    try {
      await firestore.collection('groups').doc(chatId).delete();
      DebugConfig.log(DebugConfig.repositoryResult,
          'deletePublicProfile: done chatId=$chatId');
    } on FirebaseException catch (e) {
      DebugConfig.error('deletePublicProfile: Firestore delete failed',
          data: e.message ?? e.code);
      throw AppException.firestore('delete_public_profile', e);
    } catch (e, s) {
      DebugConfig.error('deletePublicProfile failed', data: e, exception: s);
      throw AppException.firestore('delete_public_profile', e);
    }
  }
}
