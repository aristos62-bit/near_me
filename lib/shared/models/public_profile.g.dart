// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicProfile _$PublicProfileFromJson(Map<String, dynamic> json) =>
    _PublicProfile(
      uid: json['uid'] as String,
      nickname: json['nickname'] as String?,
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      geoHash: json['geoHash'] as String?,
      interests: (json['interests'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      occupations: (json['occupations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      lookingFor: json['lookingFor'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      allowVideoCall: json['allowVideoCall'] as bool? ?? false,
      allowDirectChat: json['allowDirectChat'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      isOnline: json['isOnline'] as bool? ?? false,
      isManualLocation: json['isManualLocation'] as bool? ?? false,
      lang: json['lang'] as String? ?? 'el',
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$PublicProfileToJson(_PublicProfile instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'nickname': instance.nickname,
      'age': instance.age,
      'gender': instance.gender,
      'city': instance.city,
      'country': instance.country,
      'geoHash': instance.geoHash,
      'interests': instance.interests,
      'occupations': instance.occupations,
      'lookingFor': instance.lookingFor,
      'bio': instance.bio,
      'avatarUrl': instance.avatarUrl,
      'photoUrls': instance.photoUrls,
      'allowVideoCall': instance.allowVideoCall,
      'allowDirectChat': instance.allowDirectChat,
      'isVisible': instance.isVisible,
      'isOnline': instance.isOnline,
      'isManualLocation': instance.isManualLocation,
      'lang': instance.lang,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
