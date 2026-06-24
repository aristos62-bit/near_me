// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'public_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PublicProfile {

 String get uid; String? get nickname; int? get age; String? get gender; String? get city; String? get country; String? get geoHash; List<String>? get interests; List<String>? get occupations; String? get lookingFor; String? get bio; String? get avatarUrl; List<String>? get photoUrls; bool get allowVideoCall; bool get allowDirectChat; bool get isVisible; bool get isOnline; bool get isManualLocation; String? get email; String? get phone; String get lang; DateTime? get updatedAt;
/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicProfileCopyWith<PublicProfile> get copyWith => _$PublicProfileCopyWithImpl<PublicProfile>(this as PublicProfile, _$identity);

  /// Serializes this PublicProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicProfile&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.age, age) || other.age == age)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.geoHash, geoHash) || other.geoHash == geoHash)&&const DeepCollectionEquality().equals(other.interests, interests)&&const DeepCollectionEquality().equals(other.occupations, occupations)&&(identical(other.lookingFor, lookingFor) || other.lookingFor == lookingFor)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&const DeepCollectionEquality().equals(other.photoUrls, photoUrls)&&(identical(other.allowVideoCall, allowVideoCall) || other.allowVideoCall == allowVideoCall)&&(identical(other.allowDirectChat, allowDirectChat) || other.allowDirectChat == allowDirectChat)&&(identical(other.isVisible, isVisible) || other.isVisible == isVisible)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.isManualLocation, isManualLocation) || other.isManualLocation == isManualLocation)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,uid,nickname,age,gender,city,country,geoHash,const DeepCollectionEquality().hash(interests),const DeepCollectionEquality().hash(occupations),lookingFor,bio,avatarUrl,const DeepCollectionEquality().hash(photoUrls),allowVideoCall,allowDirectChat,isVisible,isOnline,isManualLocation,email,phone,lang,updatedAt]);

@override
String toString() {
  return 'PublicProfile(uid: $uid, nickname: $nickname, age: $age, gender: $gender, city: $city, country: $country, geoHash: $geoHash, interests: $interests, occupations: $occupations, lookingFor: $lookingFor, bio: $bio, avatarUrl: $avatarUrl, photoUrls: $photoUrls, allowVideoCall: $allowVideoCall, allowDirectChat: $allowDirectChat, isVisible: $isVisible, isOnline: $isOnline, isManualLocation: $isManualLocation, email: $email, phone: $phone, lang: $lang, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $PublicProfileCopyWith<$Res>  {
  factory $PublicProfileCopyWith(PublicProfile value, $Res Function(PublicProfile) _then) = _$PublicProfileCopyWithImpl;
@useResult
$Res call({
 String uid, String? nickname, int? age, String? gender, String? city, String? country, String? geoHash, List<String>? interests, List<String>? occupations, String? lookingFor, String? bio, String? avatarUrl, List<String>? photoUrls, bool allowVideoCall, bool allowDirectChat, bool isVisible, bool isOnline, bool isManualLocation, String? email, String? phone, String lang, DateTime? updatedAt
});




}
/// @nodoc
class _$PublicProfileCopyWithImpl<$Res>
    implements $PublicProfileCopyWith<$Res> {
  _$PublicProfileCopyWithImpl(this._self, this._then);

  final PublicProfile _self;
  final $Res Function(PublicProfile) _then;

/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? nickname = freezed,Object? age = freezed,Object? gender = freezed,Object? city = freezed,Object? country = freezed,Object? geoHash = freezed,Object? interests = freezed,Object? occupations = freezed,Object? lookingFor = freezed,Object? bio = freezed,Object? avatarUrl = freezed,Object? photoUrls = freezed,Object? allowVideoCall = null,Object? allowDirectChat = null,Object? isVisible = null,Object? isOnline = null,Object? isManualLocation = null,Object? email = freezed,Object? phone = freezed,Object? lang = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,geoHash: freezed == geoHash ? _self.geoHash : geoHash // ignore: cast_nullable_to_non_nullable
as String?,interests: freezed == interests ? _self.interests : interests // ignore: cast_nullable_to_non_nullable
as List<String>?,occupations: freezed == occupations ? _self.occupations : occupations // ignore: cast_nullable_to_non_nullable
as List<String>?,lookingFor: freezed == lookingFor ? _self.lookingFor : lookingFor // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,photoUrls: freezed == photoUrls ? _self.photoUrls : photoUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,allowVideoCall: null == allowVideoCall ? _self.allowVideoCall : allowVideoCall // ignore: cast_nullable_to_non_nullable
as bool,allowDirectChat: null == allowDirectChat ? _self.allowDirectChat : allowDirectChat // ignore: cast_nullable_to_non_nullable
as bool,isVisible: null == isVisible ? _self.isVisible : isVisible // ignore: cast_nullable_to_non_nullable
as bool,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,isManualLocation: null == isManualLocation ? _self.isManualLocation : isManualLocation // ignore: cast_nullable_to_non_nullable
as bool,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicProfile].
extension PublicProfilePatterns on PublicProfile {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicProfile value)  $default,){
final _that = this;
switch (_that) {
case _PublicProfile():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicProfile value)?  $default,){
final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uid,  String? nickname,  int? age,  String? gender,  String? city,  String? country,  String? geoHash,  List<String>? interests,  List<String>? occupations,  String? lookingFor,  String? bio,  String? avatarUrl,  List<String>? photoUrls,  bool allowVideoCall,  bool allowDirectChat,  bool isVisible,  bool isOnline,  bool isManualLocation,  String? email,  String? phone,  String lang,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that.uid,_that.nickname,_that.age,_that.gender,_that.city,_that.country,_that.geoHash,_that.interests,_that.occupations,_that.lookingFor,_that.bio,_that.avatarUrl,_that.photoUrls,_that.allowVideoCall,_that.allowDirectChat,_that.isVisible,_that.isOnline,_that.isManualLocation,_that.email,_that.phone,_that.lang,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uid,  String? nickname,  int? age,  String? gender,  String? city,  String? country,  String? geoHash,  List<String>? interests,  List<String>? occupations,  String? lookingFor,  String? bio,  String? avatarUrl,  List<String>? photoUrls,  bool allowVideoCall,  bool allowDirectChat,  bool isVisible,  bool isOnline,  bool isManualLocation,  String? email,  String? phone,  String lang,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _PublicProfile():
return $default(_that.uid,_that.nickname,_that.age,_that.gender,_that.city,_that.country,_that.geoHash,_that.interests,_that.occupations,_that.lookingFor,_that.bio,_that.avatarUrl,_that.photoUrls,_that.allowVideoCall,_that.allowDirectChat,_that.isVisible,_that.isOnline,_that.isManualLocation,_that.email,_that.phone,_that.lang,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uid,  String? nickname,  int? age,  String? gender,  String? city,  String? country,  String? geoHash,  List<String>? interests,  List<String>? occupations,  String? lookingFor,  String? bio,  String? avatarUrl,  List<String>? photoUrls,  bool allowVideoCall,  bool allowDirectChat,  bool isVisible,  bool isOnline,  bool isManualLocation,  String? email,  String? phone,  String lang,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that.uid,_that.nickname,_that.age,_that.gender,_that.city,_that.country,_that.geoHash,_that.interests,_that.occupations,_that.lookingFor,_that.bio,_that.avatarUrl,_that.photoUrls,_that.allowVideoCall,_that.allowDirectChat,_that.isVisible,_that.isOnline,_that.isManualLocation,_that.email,_that.phone,_that.lang,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicProfile implements PublicProfile {
  const _PublicProfile({required this.uid, this.nickname, this.age, this.gender, this.city, this.country, this.geoHash, final  List<String>? interests, final  List<String>? occupations, this.lookingFor, this.bio, this.avatarUrl, final  List<String>? photoUrls, this.allowVideoCall = false, this.allowDirectChat = false, this.isVisible = true, this.isOnline = false, this.isManualLocation = false, this.email, this.phone, this.lang = 'el', this.updatedAt}): _interests = interests,_occupations = occupations,_photoUrls = photoUrls;
  factory _PublicProfile.fromJson(Map<String, dynamic> json) => _$PublicProfileFromJson(json);

@override final  String uid;
@override final  String? nickname;
@override final  int? age;
@override final  String? gender;
@override final  String? city;
@override final  String? country;
@override final  String? geoHash;
 final  List<String>? _interests;
@override List<String>? get interests {
  final value = _interests;
  if (value == null) return null;
  if (_interests is EqualUnmodifiableListView) return _interests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String>? _occupations;
@override List<String>? get occupations {
  final value = _occupations;
  if (value == null) return null;
  if (_occupations is EqualUnmodifiableListView) return _occupations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? lookingFor;
@override final  String? bio;
@override final  String? avatarUrl;
 final  List<String>? _photoUrls;
@override List<String>? get photoUrls {
  final value = _photoUrls;
  if (value == null) return null;
  if (_photoUrls is EqualUnmodifiableListView) return _photoUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  bool allowVideoCall;
@override@JsonKey() final  bool allowDirectChat;
@override@JsonKey() final  bool isVisible;
@override@JsonKey() final  bool isOnline;
@override@JsonKey() final  bool isManualLocation;
@override final  String? email;
@override final  String? phone;
@override@JsonKey() final  String lang;
@override final  DateTime? updatedAt;

/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicProfileCopyWith<_PublicProfile> get copyWith => __$PublicProfileCopyWithImpl<_PublicProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicProfile&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.age, age) || other.age == age)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.geoHash, geoHash) || other.geoHash == geoHash)&&const DeepCollectionEquality().equals(other._interests, _interests)&&const DeepCollectionEquality().equals(other._occupations, _occupations)&&(identical(other.lookingFor, lookingFor) || other.lookingFor == lookingFor)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&const DeepCollectionEquality().equals(other._photoUrls, _photoUrls)&&(identical(other.allowVideoCall, allowVideoCall) || other.allowVideoCall == allowVideoCall)&&(identical(other.allowDirectChat, allowDirectChat) || other.allowDirectChat == allowDirectChat)&&(identical(other.isVisible, isVisible) || other.isVisible == isVisible)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.isManualLocation, isManualLocation) || other.isManualLocation == isManualLocation)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,uid,nickname,age,gender,city,country,geoHash,const DeepCollectionEquality().hash(_interests),const DeepCollectionEquality().hash(_occupations),lookingFor,bio,avatarUrl,const DeepCollectionEquality().hash(_photoUrls),allowVideoCall,allowDirectChat,isVisible,isOnline,isManualLocation,email,phone,lang,updatedAt]);

@override
String toString() {
  return 'PublicProfile(uid: $uid, nickname: $nickname, age: $age, gender: $gender, city: $city, country: $country, geoHash: $geoHash, interests: $interests, occupations: $occupations, lookingFor: $lookingFor, bio: $bio, avatarUrl: $avatarUrl, photoUrls: $photoUrls, allowVideoCall: $allowVideoCall, allowDirectChat: $allowDirectChat, isVisible: $isVisible, isOnline: $isOnline, isManualLocation: $isManualLocation, email: $email, phone: $phone, lang: $lang, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$PublicProfileCopyWith<$Res> implements $PublicProfileCopyWith<$Res> {
  factory _$PublicProfileCopyWith(_PublicProfile value, $Res Function(_PublicProfile) _then) = __$PublicProfileCopyWithImpl;
@override @useResult
$Res call({
 String uid, String? nickname, int? age, String? gender, String? city, String? country, String? geoHash, List<String>? interests, List<String>? occupations, String? lookingFor, String? bio, String? avatarUrl, List<String>? photoUrls, bool allowVideoCall, bool allowDirectChat, bool isVisible, bool isOnline, bool isManualLocation, String? email, String? phone, String lang, DateTime? updatedAt
});




}
/// @nodoc
class __$PublicProfileCopyWithImpl<$Res>
    implements _$PublicProfileCopyWith<$Res> {
  __$PublicProfileCopyWithImpl(this._self, this._then);

  final _PublicProfile _self;
  final $Res Function(_PublicProfile) _then;

/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? nickname = freezed,Object? age = freezed,Object? gender = freezed,Object? city = freezed,Object? country = freezed,Object? geoHash = freezed,Object? interests = freezed,Object? occupations = freezed,Object? lookingFor = freezed,Object? bio = freezed,Object? avatarUrl = freezed,Object? photoUrls = freezed,Object? allowVideoCall = null,Object? allowDirectChat = null,Object? isVisible = null,Object? isOnline = null,Object? isManualLocation = null,Object? email = freezed,Object? phone = freezed,Object? lang = null,Object? updatedAt = freezed,}) {
  return _then(_PublicProfile(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,geoHash: freezed == geoHash ? _self.geoHash : geoHash // ignore: cast_nullable_to_non_nullable
as String?,interests: freezed == interests ? _self._interests : interests // ignore: cast_nullable_to_non_nullable
as List<String>?,occupations: freezed == occupations ? _self._occupations : occupations // ignore: cast_nullable_to_non_nullable
as List<String>?,lookingFor: freezed == lookingFor ? _self.lookingFor : lookingFor // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,photoUrls: freezed == photoUrls ? _self._photoUrls : photoUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,allowVideoCall: null == allowVideoCall ? _self.allowVideoCall : allowVideoCall // ignore: cast_nullable_to_non_nullable
as bool,allowDirectChat: null == allowDirectChat ? _self.allowDirectChat : allowDirectChat // ignore: cast_nullable_to_non_nullable
as bool,isVisible: null == isVisible ? _self.isVisible : isVisible // ignore: cast_nullable_to_non_nullable
as bool,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,isManualLocation: null == isManualLocation ? _self.isManualLocation : isManualLocation // ignore: cast_nullable_to_non_nullable
as bool,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
