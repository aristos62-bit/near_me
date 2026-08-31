import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile.freezed.dart';
part 'public_profile.g.dart';

@freezed
abstract class HelpRequest with _$HelpRequest {
  const factory HelpRequest({
    @Default(false) bool active,
    String? message,
    @Default(10.0) double radiusKm,
    DateTime? updatedAt,
  }) = _HelpRequest;

  factory HelpRequest.fromJson(Map<String, dynamic> json) =>
      _$HelpRequestFromJson(json);
}

@freezed
abstract class PublicProfile with _$PublicProfile {
  const factory PublicProfile({
    required String uid,
    String? nickname,
    int? age,
    String? gender,
    String? city,
    String? country,
    String? geoHash,
    List<String>? interests,
    List<String>? occupations,
    String? lookingFor,
    String? bio,
    String? avatarUrl,
    List<String>? photoUrls,
    String? avatarRacyLevel,
    List<String>? photoRacyLevels,
    @Default(false) bool allowVideoCall,
    @Default(false) bool allowDirectChat,
    @Default(true) bool isVisible,
    @Default(false) bool isOnline,
    @Default(false) bool isManualLocation,
    String? email,
    String? phone,
    @Default('el') String lang,
    DateTime? updatedAt,
    HelpRequest? helpRequest,
  }) = _PublicProfile;

  factory PublicProfile.fromJson(Map<String, dynamic> json) =>
      _$PublicProfileFromJson(json);
}
