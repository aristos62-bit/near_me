// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SearchFilters {

 String? get city; String? get country; String? get geoHash; double? get latitude; double? get longitude; double? get radiusKm; int? get minAge; int? get maxAge; String? get gender; List<String>? get interests; String? get lookingFor; bool? get allowVideoCall; bool? get allowDirectChat; bool? get isOnlineNow; int get limit;
/// Create a copy of SearchFilters
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchFiltersCopyWith<SearchFilters> get copyWith => _$SearchFiltersCopyWithImpl<SearchFilters>(this as SearchFilters, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchFilters&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.geoHash, geoHash) || other.geoHash == geoHash)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.radiusKm, radiusKm) || other.radiusKm == radiusKm)&&(identical(other.minAge, minAge) || other.minAge == minAge)&&(identical(other.maxAge, maxAge) || other.maxAge == maxAge)&&(identical(other.gender, gender) || other.gender == gender)&&const DeepCollectionEquality().equals(other.interests, interests)&&(identical(other.lookingFor, lookingFor) || other.lookingFor == lookingFor)&&(identical(other.allowVideoCall, allowVideoCall) || other.allowVideoCall == allowVideoCall)&&(identical(other.allowDirectChat, allowDirectChat) || other.allowDirectChat == allowDirectChat)&&(identical(other.isOnlineNow, isOnlineNow) || other.isOnlineNow == isOnlineNow)&&(identical(other.limit, limit) || other.limit == limit));
}


@override
int get hashCode => Object.hash(runtimeType,city,country,geoHash,latitude,longitude,radiusKm,minAge,maxAge,gender,const DeepCollectionEquality().hash(interests),lookingFor,allowVideoCall,allowDirectChat,isOnlineNow,limit);

@override
String toString() {
  return 'SearchFilters(city: $city, country: $country, geoHash: $geoHash, latitude: $latitude, longitude: $longitude, radiusKm: $radiusKm, minAge: $minAge, maxAge: $maxAge, gender: $gender, interests: $interests, lookingFor: $lookingFor, allowVideoCall: $allowVideoCall, allowDirectChat: $allowDirectChat, isOnlineNow: $isOnlineNow, limit: $limit)';
}


}

/// @nodoc
abstract mixin class $SearchFiltersCopyWith<$Res>  {
  factory $SearchFiltersCopyWith(SearchFilters value, $Res Function(SearchFilters) _then) = _$SearchFiltersCopyWithImpl;
@useResult
$Res call({
 String? city, String? country, String? geoHash, double? latitude, double? longitude, double? radiusKm, int? minAge, int? maxAge, String? gender, List<String>? interests, String? lookingFor, bool? allowVideoCall, bool? allowDirectChat, bool? isOnlineNow, int limit
});




}
/// @nodoc
class _$SearchFiltersCopyWithImpl<$Res>
    implements $SearchFiltersCopyWith<$Res> {
  _$SearchFiltersCopyWithImpl(this._self, this._then);

  final SearchFilters _self;
  final $Res Function(SearchFilters) _then;

/// Create a copy of SearchFilters
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? city = freezed,Object? country = freezed,Object? geoHash = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? radiusKm = freezed,Object? minAge = freezed,Object? maxAge = freezed,Object? gender = freezed,Object? interests = freezed,Object? lookingFor = freezed,Object? allowVideoCall = freezed,Object? allowDirectChat = freezed,Object? isOnlineNow = freezed,Object? limit = null,}) {
  return _then(_self.copyWith(
city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,geoHash: freezed == geoHash ? _self.geoHash : geoHash // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,radiusKm: freezed == radiusKm ? _self.radiusKm : radiusKm // ignore: cast_nullable_to_non_nullable
as double?,minAge: freezed == minAge ? _self.minAge : minAge // ignore: cast_nullable_to_non_nullable
as int?,maxAge: freezed == maxAge ? _self.maxAge : maxAge // ignore: cast_nullable_to_non_nullable
as int?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,interests: freezed == interests ? _self.interests : interests // ignore: cast_nullable_to_non_nullable
as List<String>?,lookingFor: freezed == lookingFor ? _self.lookingFor : lookingFor // ignore: cast_nullable_to_non_nullable
as String?,allowVideoCall: freezed == allowVideoCall ? _self.allowVideoCall : allowVideoCall // ignore: cast_nullable_to_non_nullable
as bool?,allowDirectChat: freezed == allowDirectChat ? _self.allowDirectChat : allowDirectChat // ignore: cast_nullable_to_non_nullable
as bool?,isOnlineNow: freezed == isOnlineNow ? _self.isOnlineNow : isOnlineNow // ignore: cast_nullable_to_non_nullable
as bool?,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchFilters].
extension SearchFiltersPatterns on SearchFilters {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchFilters value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchFilters() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchFilters value)  $default,){
final _that = this;
switch (_that) {
case _SearchFilters():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchFilters value)?  $default,){
final _that = this;
switch (_that) {
case _SearchFilters() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? city,  String? country,  String? geoHash,  double? latitude,  double? longitude,  double? radiusKm,  int? minAge,  int? maxAge,  String? gender,  List<String>? interests,  String? lookingFor,  bool? allowVideoCall,  bool? allowDirectChat,  bool? isOnlineNow,  int limit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchFilters() when $default != null:
return $default(_that.city,_that.country,_that.geoHash,_that.latitude,_that.longitude,_that.radiusKm,_that.minAge,_that.maxAge,_that.gender,_that.interests,_that.lookingFor,_that.allowVideoCall,_that.allowDirectChat,_that.isOnlineNow,_that.limit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? city,  String? country,  String? geoHash,  double? latitude,  double? longitude,  double? radiusKm,  int? minAge,  int? maxAge,  String? gender,  List<String>? interests,  String? lookingFor,  bool? allowVideoCall,  bool? allowDirectChat,  bool? isOnlineNow,  int limit)  $default,) {final _that = this;
switch (_that) {
case _SearchFilters():
return $default(_that.city,_that.country,_that.geoHash,_that.latitude,_that.longitude,_that.radiusKm,_that.minAge,_that.maxAge,_that.gender,_that.interests,_that.lookingFor,_that.allowVideoCall,_that.allowDirectChat,_that.isOnlineNow,_that.limit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? city,  String? country,  String? geoHash,  double? latitude,  double? longitude,  double? radiusKm,  int? minAge,  int? maxAge,  String? gender,  List<String>? interests,  String? lookingFor,  bool? allowVideoCall,  bool? allowDirectChat,  bool? isOnlineNow,  int limit)?  $default,) {final _that = this;
switch (_that) {
case _SearchFilters() when $default != null:
return $default(_that.city,_that.country,_that.geoHash,_that.latitude,_that.longitude,_that.radiusKm,_that.minAge,_that.maxAge,_that.gender,_that.interests,_that.lookingFor,_that.allowVideoCall,_that.allowDirectChat,_that.isOnlineNow,_that.limit);case _:
  return null;

}
}

}

/// @nodoc


class _SearchFilters implements SearchFilters {
  const _SearchFilters({this.city, this.country, this.geoHash, this.latitude, this.longitude, this.radiusKm, this.minAge, this.maxAge, this.gender, final  List<String>? interests, this.lookingFor, this.allowVideoCall, this.allowDirectChat, this.isOnlineNow, this.limit = 20}): _interests = interests;
  

@override final  String? city;
@override final  String? country;
@override final  String? geoHash;
@override final  double? latitude;
@override final  double? longitude;
@override final  double? radiusKm;
@override final  int? minAge;
@override final  int? maxAge;
@override final  String? gender;
 final  List<String>? _interests;
@override List<String>? get interests {
  final value = _interests;
  if (value == null) return null;
  if (_interests is EqualUnmodifiableListView) return _interests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? lookingFor;
@override final  bool? allowVideoCall;
@override final  bool? allowDirectChat;
@override final  bool? isOnlineNow;
@override@JsonKey() final  int limit;

/// Create a copy of SearchFilters
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchFiltersCopyWith<_SearchFilters> get copyWith => __$SearchFiltersCopyWithImpl<_SearchFilters>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchFilters&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.geoHash, geoHash) || other.geoHash == geoHash)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.radiusKm, radiusKm) || other.radiusKm == radiusKm)&&(identical(other.minAge, minAge) || other.minAge == minAge)&&(identical(other.maxAge, maxAge) || other.maxAge == maxAge)&&(identical(other.gender, gender) || other.gender == gender)&&const DeepCollectionEquality().equals(other._interests, _interests)&&(identical(other.lookingFor, lookingFor) || other.lookingFor == lookingFor)&&(identical(other.allowVideoCall, allowVideoCall) || other.allowVideoCall == allowVideoCall)&&(identical(other.allowDirectChat, allowDirectChat) || other.allowDirectChat == allowDirectChat)&&(identical(other.isOnlineNow, isOnlineNow) || other.isOnlineNow == isOnlineNow)&&(identical(other.limit, limit) || other.limit == limit));
}


@override
int get hashCode => Object.hash(runtimeType,city,country,geoHash,latitude,longitude,radiusKm,minAge,maxAge,gender,const DeepCollectionEquality().hash(_interests),lookingFor,allowVideoCall,allowDirectChat,isOnlineNow,limit);

@override
String toString() {
  return 'SearchFilters(city: $city, country: $country, geoHash: $geoHash, latitude: $latitude, longitude: $longitude, radiusKm: $radiusKm, minAge: $minAge, maxAge: $maxAge, gender: $gender, interests: $interests, lookingFor: $lookingFor, allowVideoCall: $allowVideoCall, allowDirectChat: $allowDirectChat, isOnlineNow: $isOnlineNow, limit: $limit)';
}


}

/// @nodoc
abstract mixin class _$SearchFiltersCopyWith<$Res> implements $SearchFiltersCopyWith<$Res> {
  factory _$SearchFiltersCopyWith(_SearchFilters value, $Res Function(_SearchFilters) _then) = __$SearchFiltersCopyWithImpl;
@override @useResult
$Res call({
 String? city, String? country, String? geoHash, double? latitude, double? longitude, double? radiusKm, int? minAge, int? maxAge, String? gender, List<String>? interests, String? lookingFor, bool? allowVideoCall, bool? allowDirectChat, bool? isOnlineNow, int limit
});




}
/// @nodoc
class __$SearchFiltersCopyWithImpl<$Res>
    implements _$SearchFiltersCopyWith<$Res> {
  __$SearchFiltersCopyWithImpl(this._self, this._then);

  final _SearchFilters _self;
  final $Res Function(_SearchFilters) _then;

/// Create a copy of SearchFilters
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? city = freezed,Object? country = freezed,Object? geoHash = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? radiusKm = freezed,Object? minAge = freezed,Object? maxAge = freezed,Object? gender = freezed,Object? interests = freezed,Object? lookingFor = freezed,Object? allowVideoCall = freezed,Object? allowDirectChat = freezed,Object? isOnlineNow = freezed,Object? limit = null,}) {
  return _then(_SearchFilters(
city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,geoHash: freezed == geoHash ? _self.geoHash : geoHash // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,radiusKm: freezed == radiusKm ? _self.radiusKm : radiusKm // ignore: cast_nullable_to_non_nullable
as double?,minAge: freezed == minAge ? _self.minAge : minAge // ignore: cast_nullable_to_non_nullable
as int?,maxAge: freezed == maxAge ? _self.maxAge : maxAge // ignore: cast_nullable_to_non_nullable
as int?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,interests: freezed == interests ? _self._interests : interests // ignore: cast_nullable_to_non_nullable
as List<String>?,lookingFor: freezed == lookingFor ? _self.lookingFor : lookingFor // ignore: cast_nullable_to_non_nullable
as String?,allowVideoCall: freezed == allowVideoCall ? _self.allowVideoCall : allowVideoCall // ignore: cast_nullable_to_non_nullable
as bool?,allowDirectChat: freezed == allowDirectChat ? _self.allowDirectChat : allowDirectChat // ignore: cast_nullable_to_non_nullable
as bool?,isOnlineNow: freezed == isOnlineNow ? _self.isOnlineNow : isOnlineNow // ignore: cast_nullable_to_non_nullable
as bool?,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
