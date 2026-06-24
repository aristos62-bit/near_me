import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile.freezed.dart';
part 'public_profile.g.dart';

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
    @Default(false) bool allowVideoCall,
    @Default(false) bool allowDirectChat,
    @Default(true) bool isVisible,
    @Default(false) bool isOnline,
    @Default(false) bool isManualLocation,
    String? email,
    String? phone,
    @Default('el') String lang,
    DateTime? updatedAt,
  }) = _PublicProfile;

  factory PublicProfile.fromJson(Map<String, dynamic> json) =>
      _$PublicProfileFromJson(json);
}
