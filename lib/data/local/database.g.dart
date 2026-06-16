// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UserProfileTableTable extends UserProfileTable
    with TableInfo<$UserProfileTableTable, UserProfileTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bioMeta = const VerificationMeta('bio');
  @override
  late final GeneratedColumn<String> bio = GeneratedColumn<String>(
    'bio',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthYearMeta = const VerificationMeta(
    'birthYear',
  );
  @override
  late final GeneratedColumn<int> birthYear = GeneratedColumn<int>(
    'birth_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String> interests =
      GeneratedColumn<String>(
        'interests',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<List<String>?>(
        $UserProfileTableTable.$converterinterestsn,
      );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String>
  occupations = GeneratedColumn<String>(
    'occupations',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<List<String>?>($UserProfileTableTable.$converteroccupationsn);
  static const VerificationMeta _lookingForMeta = const VerificationMeta(
    'lookingFor',
  );
  @override
  late final GeneratedColumn<String> lookingFor = GeneratedColumn<String>(
    'looking_for',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeExactMeta = const VerificationMeta(
    'latitudeExact',
  );
  @override
  late final GeneratedColumn<double> latitudeExact = GeneratedColumn<double>(
    'latitude_exact',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeExactMeta = const VerificationMeta(
    'longitudeExact',
  );
  @override
  late final GeneratedColumn<double> longitudeExact = GeneratedColumn<double>(
    'longitude_exact',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manualLocationTextMeta =
      const VerificationMeta('manualLocationText');
  @override
  late final GeneratedColumn<String> manualLocationText =
      GeneratedColumn<String>(
        'manual_location_text',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String> photoUrls =
      GeneratedColumn<String>(
        'photo_urls',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<List<String>?>(
        $UserProfileTableTable.$converterphotoUrlsn,
      );
  static const VerificationMeta _allowVideoCallMeta = const VerificationMeta(
    'allowVideoCall',
  );
  @override
  late final GeneratedColumn<bool> allowVideoCall = GeneratedColumn<bool>(
    'allow_video_call',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_video_call" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _allowDirectChatMeta = const VerificationMeta(
    'allowDirectChat',
  );
  @override
  late final GeneratedColumn<bool> allowDirectChat = GeneratedColumn<bool>(
    'allow_direct_chat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_direct_chat" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPublishedMeta = const VerificationMeta(
    'isPublished',
  );
  @override
  late final GeneratedColumn<bool> isPublished = GeneratedColumn<bool>(
    'is_published',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_published" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    nickname,
    fullName,
    email,
    phone,
    bio,
    birthYear,
    gender,
    interests,
    occupations,
    lookingFor,
    city,
    country,
    latitudeExact,
    longitudeExact,
    manualLocationText,
    avatarUrl,
    photoUrls,
    allowVideoCall,
    allowDirectChat,
    isPublished,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('bio')) {
      context.handle(
        _bioMeta,
        bio.isAcceptableOrUnknown(data['bio']!, _bioMeta),
      );
    }
    if (data.containsKey('birth_year')) {
      context.handle(
        _birthYearMeta,
        birthYear.isAcceptableOrUnknown(data['birth_year']!, _birthYearMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('looking_for')) {
      context.handle(
        _lookingForMeta,
        lookingFor.isAcceptableOrUnknown(data['looking_for']!, _lookingForMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('latitude_exact')) {
      context.handle(
        _latitudeExactMeta,
        latitudeExact.isAcceptableOrUnknown(
          data['latitude_exact']!,
          _latitudeExactMeta,
        ),
      );
    }
    if (data.containsKey('longitude_exact')) {
      context.handle(
        _longitudeExactMeta,
        longitudeExact.isAcceptableOrUnknown(
          data['longitude_exact']!,
          _longitudeExactMeta,
        ),
      );
    }
    if (data.containsKey('manual_location_text')) {
      context.handle(
        _manualLocationTextMeta,
        manualLocationText.isAcceptableOrUnknown(
          data['manual_location_text']!,
          _manualLocationTextMeta,
        ),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('allow_video_call')) {
      context.handle(
        _allowVideoCallMeta,
        allowVideoCall.isAcceptableOrUnknown(
          data['allow_video_call']!,
          _allowVideoCallMeta,
        ),
      );
    }
    if (data.containsKey('allow_direct_chat')) {
      context.handle(
        _allowDirectChatMeta,
        allowDirectChat.isAcceptableOrUnknown(
          data['allow_direct_chat']!,
          _allowDirectChatMeta,
        ),
      );
    }
    if (data.containsKey('is_published')) {
      context.handle(
        _isPublishedMeta,
        isPublished.isAcceptableOrUnknown(
          data['is_published']!,
          _isPublishedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      ),
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      bio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bio'],
      ),
      birthYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_year'],
      ),
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      interests: $UserProfileTableTable.$converterinterestsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}interests'],
        ),
      ),
      occupations: $UserProfileTableTable.$converteroccupationsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}occupations'],
        ),
      ),
      lookingFor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}looking_for'],
      ),
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      ),
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      latitudeExact: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude_exact'],
      ),
      longitudeExact: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude_exact'],
      ),
      manualLocationText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manual_location_text'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      photoUrls: $UserProfileTableTable.$converterphotoUrlsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}photo_urls'],
        ),
      ),
      allowVideoCall: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_video_call'],
      )!,
      allowDirectChat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_direct_chat'],
      )!,
      isPublished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_published'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserProfileTableTable createAlias(String alias) {
    return $UserProfileTableTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterinterests =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $converterinterestsn =
      NullAwareTypeConverter.wrap($converterinterests);
  static TypeConverter<List<String>, String> $converteroccupations =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $converteroccupationsn =
      NullAwareTypeConverter.wrap($converteroccupations);
  static TypeConverter<List<String>, String> $converterphotoUrls =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $converterphotoUrlsn =
      NullAwareTypeConverter.wrap($converterphotoUrls);
}

class UserProfileTableData extends DataClass
    implements Insertable<UserProfileTableData> {
  final int id;
  final String? uid;
  final String? nickname;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? bio;
  final int? birthYear;
  final String? gender;
  final List<String>? interests;
  final List<String>? occupations;
  final String? lookingFor;
  final String? city;
  final String? country;
  final double? latitudeExact;
  final double? longitudeExact;
  final String? manualLocationText;
  final String? avatarUrl;
  final List<String>? photoUrls;
  final bool allowVideoCall;
  final bool allowDirectChat;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserProfileTableData({
    required this.id,
    this.uid,
    this.nickname,
    this.fullName,
    this.email,
    this.phone,
    this.bio,
    this.birthYear,
    this.gender,
    this.interests,
    this.occupations,
    this.lookingFor,
    this.city,
    this.country,
    this.latitudeExact,
    this.longitudeExact,
    this.manualLocationText,
    this.avatarUrl,
    this.photoUrls,
    required this.allowVideoCall,
    required this.allowDirectChat,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    if (!nullToAbsent || fullName != null) {
      map['full_name'] = Variable<String>(fullName);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || bio != null) {
      map['bio'] = Variable<String>(bio);
    }
    if (!nullToAbsent || birthYear != null) {
      map['birth_year'] = Variable<int>(birthYear);
    }
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || interests != null) {
      map['interests'] = Variable<String>(
        $UserProfileTableTable.$converterinterestsn.toSql(interests),
      );
    }
    if (!nullToAbsent || occupations != null) {
      map['occupations'] = Variable<String>(
        $UserProfileTableTable.$converteroccupationsn.toSql(occupations),
      );
    }
    if (!nullToAbsent || lookingFor != null) {
      map['looking_for'] = Variable<String>(lookingFor);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || latitudeExact != null) {
      map['latitude_exact'] = Variable<double>(latitudeExact);
    }
    if (!nullToAbsent || longitudeExact != null) {
      map['longitude_exact'] = Variable<double>(longitudeExact);
    }
    if (!nullToAbsent || manualLocationText != null) {
      map['manual_location_text'] = Variable<String>(manualLocationText);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    if (!nullToAbsent || photoUrls != null) {
      map['photo_urls'] = Variable<String>(
        $UserProfileTableTable.$converterphotoUrlsn.toSql(photoUrls),
      );
    }
    map['allow_video_call'] = Variable<bool>(allowVideoCall);
    map['allow_direct_chat'] = Variable<bool>(allowDirectChat);
    map['is_published'] = Variable<bool>(isPublished);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProfileTableCompanion toCompanion(bool nullToAbsent) {
    return UserProfileTableCompanion(
      id: Value(id),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      fullName: fullName == null && nullToAbsent
          ? const Value.absent()
          : Value(fullName),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      bio: bio == null && nullToAbsent ? const Value.absent() : Value(bio),
      birthYear: birthYear == null && nullToAbsent
          ? const Value.absent()
          : Value(birthYear),
      gender: gender == null && nullToAbsent
          ? const Value.absent()
          : Value(gender),
      interests: interests == null && nullToAbsent
          ? const Value.absent()
          : Value(interests),
      occupations: occupations == null && nullToAbsent
          ? const Value.absent()
          : Value(occupations),
      lookingFor: lookingFor == null && nullToAbsent
          ? const Value.absent()
          : Value(lookingFor),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      latitudeExact: latitudeExact == null && nullToAbsent
          ? const Value.absent()
          : Value(latitudeExact),
      longitudeExact: longitudeExact == null && nullToAbsent
          ? const Value.absent()
          : Value(longitudeExact),
      manualLocationText: manualLocationText == null && nullToAbsent
          ? const Value.absent()
          : Value(manualLocationText),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      photoUrls: photoUrls == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrls),
      allowVideoCall: Value(allowVideoCall),
      allowDirectChat: Value(allowDirectChat),
      isPublished: Value(isPublished),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfileTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileTableData(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String?>(json['uid']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      fullName: serializer.fromJson<String?>(json['fullName']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      bio: serializer.fromJson<String?>(json['bio']),
      birthYear: serializer.fromJson<int?>(json['birthYear']),
      gender: serializer.fromJson<String?>(json['gender']),
      interests: serializer.fromJson<List<String>?>(json['interests']),
      occupations: serializer.fromJson<List<String>?>(json['occupations']),
      lookingFor: serializer.fromJson<String?>(json['lookingFor']),
      city: serializer.fromJson<String?>(json['city']),
      country: serializer.fromJson<String?>(json['country']),
      latitudeExact: serializer.fromJson<double?>(json['latitudeExact']),
      longitudeExact: serializer.fromJson<double?>(json['longitudeExact']),
      manualLocationText: serializer.fromJson<String?>(
        json['manualLocationText'],
      ),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      photoUrls: serializer.fromJson<List<String>?>(json['photoUrls']),
      allowVideoCall: serializer.fromJson<bool>(json['allowVideoCall']),
      allowDirectChat: serializer.fromJson<bool>(json['allowDirectChat']),
      isPublished: serializer.fromJson<bool>(json['isPublished']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String?>(uid),
      'nickname': serializer.toJson<String?>(nickname),
      'fullName': serializer.toJson<String?>(fullName),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'bio': serializer.toJson<String?>(bio),
      'birthYear': serializer.toJson<int?>(birthYear),
      'gender': serializer.toJson<String?>(gender),
      'interests': serializer.toJson<List<String>?>(interests),
      'occupations': serializer.toJson<List<String>?>(occupations),
      'lookingFor': serializer.toJson<String?>(lookingFor),
      'city': serializer.toJson<String?>(city),
      'country': serializer.toJson<String?>(country),
      'latitudeExact': serializer.toJson<double?>(latitudeExact),
      'longitudeExact': serializer.toJson<double?>(longitudeExact),
      'manualLocationText': serializer.toJson<String?>(manualLocationText),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'photoUrls': serializer.toJson<List<String>?>(photoUrls),
      'allowVideoCall': serializer.toJson<bool>(allowVideoCall),
      'allowDirectChat': serializer.toJson<bool>(allowDirectChat),
      'isPublished': serializer.toJson<bool>(isPublished),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProfileTableData copyWith({
    int? id,
    Value<String?> uid = const Value.absent(),
    Value<String?> nickname = const Value.absent(),
    Value<String?> fullName = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> bio = const Value.absent(),
    Value<int?> birthYear = const Value.absent(),
    Value<String?> gender = const Value.absent(),
    Value<List<String>?> interests = const Value.absent(),
    Value<List<String>?> occupations = const Value.absent(),
    Value<String?> lookingFor = const Value.absent(),
    Value<String?> city = const Value.absent(),
    Value<String?> country = const Value.absent(),
    Value<double?> latitudeExact = const Value.absent(),
    Value<double?> longitudeExact = const Value.absent(),
    Value<String?> manualLocationText = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    Value<List<String>?> photoUrls = const Value.absent(),
    bool? allowVideoCall,
    bool? allowDirectChat,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProfileTableData(
    id: id ?? this.id,
    uid: uid.present ? uid.value : this.uid,
    nickname: nickname.present ? nickname.value : this.nickname,
    fullName: fullName.present ? fullName.value : this.fullName,
    email: email.present ? email.value : this.email,
    phone: phone.present ? phone.value : this.phone,
    bio: bio.present ? bio.value : this.bio,
    birthYear: birthYear.present ? birthYear.value : this.birthYear,
    gender: gender.present ? gender.value : this.gender,
    interests: interests.present ? interests.value : this.interests,
    occupations: occupations.present ? occupations.value : this.occupations,
    lookingFor: lookingFor.present ? lookingFor.value : this.lookingFor,
    city: city.present ? city.value : this.city,
    country: country.present ? country.value : this.country,
    latitudeExact: latitudeExact.present
        ? latitudeExact.value
        : this.latitudeExact,
    longitudeExact: longitudeExact.present
        ? longitudeExact.value
        : this.longitudeExact,
    manualLocationText: manualLocationText.present
        ? manualLocationText.value
        : this.manualLocationText,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    photoUrls: photoUrls.present ? photoUrls.value : this.photoUrls,
    allowVideoCall: allowVideoCall ?? this.allowVideoCall,
    allowDirectChat: allowDirectChat ?? this.allowDirectChat,
    isPublished: isPublished ?? this.isPublished,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserProfileTableData copyWithCompanion(UserProfileTableCompanion data) {
    return UserProfileTableData(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      bio: data.bio.present ? data.bio.value : this.bio,
      birthYear: data.birthYear.present ? data.birthYear.value : this.birthYear,
      gender: data.gender.present ? data.gender.value : this.gender,
      interests: data.interests.present ? data.interests.value : this.interests,
      occupations: data.occupations.present
          ? data.occupations.value
          : this.occupations,
      lookingFor: data.lookingFor.present
          ? data.lookingFor.value
          : this.lookingFor,
      city: data.city.present ? data.city.value : this.city,
      country: data.country.present ? data.country.value : this.country,
      latitudeExact: data.latitudeExact.present
          ? data.latitudeExact.value
          : this.latitudeExact,
      longitudeExact: data.longitudeExact.present
          ? data.longitudeExact.value
          : this.longitudeExact,
      manualLocationText: data.manualLocationText.present
          ? data.manualLocationText.value
          : this.manualLocationText,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      photoUrls: data.photoUrls.present ? data.photoUrls.value : this.photoUrls,
      allowVideoCall: data.allowVideoCall.present
          ? data.allowVideoCall.value
          : this.allowVideoCall,
      allowDirectChat: data.allowDirectChat.present
          ? data.allowDirectChat.value
          : this.allowDirectChat,
      isPublished: data.isPublished.present
          ? data.isPublished.value
          : this.isPublished,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileTableData(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('nickname: $nickname, ')
          ..write('fullName: $fullName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('bio: $bio, ')
          ..write('birthYear: $birthYear, ')
          ..write('gender: $gender, ')
          ..write('interests: $interests, ')
          ..write('occupations: $occupations, ')
          ..write('lookingFor: $lookingFor, ')
          ..write('city: $city, ')
          ..write('country: $country, ')
          ..write('latitudeExact: $latitudeExact, ')
          ..write('longitudeExact: $longitudeExact, ')
          ..write('manualLocationText: $manualLocationText, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('photoUrls: $photoUrls, ')
          ..write('allowVideoCall: $allowVideoCall, ')
          ..write('allowDirectChat: $allowDirectChat, ')
          ..write('isPublished: $isPublished, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    uid,
    nickname,
    fullName,
    email,
    phone,
    bio,
    birthYear,
    gender,
    interests,
    occupations,
    lookingFor,
    city,
    country,
    latitudeExact,
    longitudeExact,
    manualLocationText,
    avatarUrl,
    photoUrls,
    allowVideoCall,
    allowDirectChat,
    isPublished,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileTableData &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.nickname == this.nickname &&
          other.fullName == this.fullName &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.bio == this.bio &&
          other.birthYear == this.birthYear &&
          other.gender == this.gender &&
          other.interests == this.interests &&
          other.occupations == this.occupations &&
          other.lookingFor == this.lookingFor &&
          other.city == this.city &&
          other.country == this.country &&
          other.latitudeExact == this.latitudeExact &&
          other.longitudeExact == this.longitudeExact &&
          other.manualLocationText == this.manualLocationText &&
          other.avatarUrl == this.avatarUrl &&
          other.photoUrls == this.photoUrls &&
          other.allowVideoCall == this.allowVideoCall &&
          other.allowDirectChat == this.allowDirectChat &&
          other.isPublished == this.isPublished &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserProfileTableCompanion extends UpdateCompanion<UserProfileTableData> {
  final Value<int> id;
  final Value<String?> uid;
  final Value<String?> nickname;
  final Value<String?> fullName;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<String?> bio;
  final Value<int?> birthYear;
  final Value<String?> gender;
  final Value<List<String>?> interests;
  final Value<List<String>?> occupations;
  final Value<String?> lookingFor;
  final Value<String?> city;
  final Value<String?> country;
  final Value<double?> latitudeExact;
  final Value<double?> longitudeExact;
  final Value<String?> manualLocationText;
  final Value<String?> avatarUrl;
  final Value<List<String>?> photoUrls;
  final Value<bool> allowVideoCall;
  final Value<bool> allowDirectChat;
  final Value<bool> isPublished;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UserProfileTableCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.nickname = const Value.absent(),
    this.fullName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.bio = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.gender = const Value.absent(),
    this.interests = const Value.absent(),
    this.occupations = const Value.absent(),
    this.lookingFor = const Value.absent(),
    this.city = const Value.absent(),
    this.country = const Value.absent(),
    this.latitudeExact = const Value.absent(),
    this.longitudeExact = const Value.absent(),
    this.manualLocationText = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.photoUrls = const Value.absent(),
    this.allowVideoCall = const Value.absent(),
    this.allowDirectChat = const Value.absent(),
    this.isPublished = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserProfileTableCompanion.insert({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.nickname = const Value.absent(),
    this.fullName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.bio = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.gender = const Value.absent(),
    this.interests = const Value.absent(),
    this.occupations = const Value.absent(),
    this.lookingFor = const Value.absent(),
    this.city = const Value.absent(),
    this.country = const Value.absent(),
    this.latitudeExact = const Value.absent(),
    this.longitudeExact = const Value.absent(),
    this.manualLocationText = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.photoUrls = const Value.absent(),
    this.allowVideoCall = const Value.absent(),
    this.allowDirectChat = const Value.absent(),
    this.isPublished = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<UserProfileTableData> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<String>? nickname,
    Expression<String>? fullName,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? bio,
    Expression<int>? birthYear,
    Expression<String>? gender,
    Expression<String>? interests,
    Expression<String>? occupations,
    Expression<String>? lookingFor,
    Expression<String>? city,
    Expression<String>? country,
    Expression<double>? latitudeExact,
    Expression<double>? longitudeExact,
    Expression<String>? manualLocationText,
    Expression<String>? avatarUrl,
    Expression<String>? photoUrls,
    Expression<bool>? allowVideoCall,
    Expression<bool>? allowDirectChat,
    Expression<bool>? isPublished,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (nickname != null) 'nickname': nickname,
      if (fullName != null) 'full_name': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (bio != null) 'bio': bio,
      if (birthYear != null) 'birth_year': birthYear,
      if (gender != null) 'gender': gender,
      if (interests != null) 'interests': interests,
      if (occupations != null) 'occupations': occupations,
      if (lookingFor != null) 'looking_for': lookingFor,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (latitudeExact != null) 'latitude_exact': latitudeExact,
      if (longitudeExact != null) 'longitude_exact': longitudeExact,
      if (manualLocationText != null)
        'manual_location_text': manualLocationText,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (photoUrls != null) 'photo_urls': photoUrls,
      if (allowVideoCall != null) 'allow_video_call': allowVideoCall,
      if (allowDirectChat != null) 'allow_direct_chat': allowDirectChat,
      if (isPublished != null) 'is_published': isPublished,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserProfileTableCompanion copyWith({
    Value<int>? id,
    Value<String?>? uid,
    Value<String?>? nickname,
    Value<String?>? fullName,
    Value<String?>? email,
    Value<String?>? phone,
    Value<String?>? bio,
    Value<int?>? birthYear,
    Value<String?>? gender,
    Value<List<String>?>? interests,
    Value<List<String>?>? occupations,
    Value<String?>? lookingFor,
    Value<String?>? city,
    Value<String?>? country,
    Value<double?>? latitudeExact,
    Value<double?>? longitudeExact,
    Value<String?>? manualLocationText,
    Value<String?>? avatarUrl,
    Value<List<String>?>? photoUrls,
    Value<bool>? allowVideoCall,
    Value<bool>? allowDirectChat,
    Value<bool>? isPublished,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return UserProfileTableCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      nickname: nickname ?? this.nickname,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      birthYear: birthYear ?? this.birthYear,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      occupations: occupations ?? this.occupations,
      lookingFor: lookingFor ?? this.lookingFor,
      city: city ?? this.city,
      country: country ?? this.country,
      latitudeExact: latitudeExact ?? this.latitudeExact,
      longitudeExact: longitudeExact ?? this.longitudeExact,
      manualLocationText: manualLocationText ?? this.manualLocationText,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      allowVideoCall: allowVideoCall ?? this.allowVideoCall,
      allowDirectChat: allowDirectChat ?? this.allowDirectChat,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (bio.present) {
      map['bio'] = Variable<String>(bio.value);
    }
    if (birthYear.present) {
      map['birth_year'] = Variable<int>(birthYear.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (interests.present) {
      map['interests'] = Variable<String>(
        $UserProfileTableTable.$converterinterestsn.toSql(interests.value),
      );
    }
    if (occupations.present) {
      map['occupations'] = Variable<String>(
        $UserProfileTableTable.$converteroccupationsn.toSql(occupations.value),
      );
    }
    if (lookingFor.present) {
      map['looking_for'] = Variable<String>(lookingFor.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (latitudeExact.present) {
      map['latitude_exact'] = Variable<double>(latitudeExact.value);
    }
    if (longitudeExact.present) {
      map['longitude_exact'] = Variable<double>(longitudeExact.value);
    }
    if (manualLocationText.present) {
      map['manual_location_text'] = Variable<String>(manualLocationText.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (photoUrls.present) {
      map['photo_urls'] = Variable<String>(
        $UserProfileTableTable.$converterphotoUrlsn.toSql(photoUrls.value),
      );
    }
    if (allowVideoCall.present) {
      map['allow_video_call'] = Variable<bool>(allowVideoCall.value);
    }
    if (allowDirectChat.present) {
      map['allow_direct_chat'] = Variable<bool>(allowDirectChat.value);
    }
    if (isPublished.present) {
      map['is_published'] = Variable<bool>(isPublished.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileTableCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('nickname: $nickname, ')
          ..write('fullName: $fullName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('bio: $bio, ')
          ..write('birthYear: $birthYear, ')
          ..write('gender: $gender, ')
          ..write('interests: $interests, ')
          ..write('occupations: $occupations, ')
          ..write('lookingFor: $lookingFor, ')
          ..write('city: $city, ')
          ..write('country: $country, ')
          ..write('latitudeExact: $latitudeExact, ')
          ..write('longitudeExact: $longitudeExact, ')
          ..write('manualLocationText: $manualLocationText, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('photoUrls: $photoUrls, ')
          ..write('allowVideoCall: $allowVideoCall, ')
          ..write('allowDirectChat: $allowDirectChat, ')
          ..write('isPublished: $isPublished, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PrivacySettingsTableTable extends PrivacySettingsTable
    with TableInfo<$PrivacySettingsTableTable, PrivacySettingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrivacySettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _showNicknameMeta = const VerificationMeta(
    'showNickname',
  );
  @override
  late final GeneratedColumn<bool> showNickname = GeneratedColumn<bool>(
    'show_nickname',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_nickname" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showFullNameMeta = const VerificationMeta(
    'showFullName',
  );
  @override
  late final GeneratedColumn<bool> showFullName = GeneratedColumn<bool>(
    'show_full_name',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_full_name" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showAgeMeta = const VerificationMeta(
    'showAge',
  );
  @override
  late final GeneratedColumn<bool> showAge = GeneratedColumn<bool>(
    'show_age',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_age" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showGenderMeta = const VerificationMeta(
    'showGender',
  );
  @override
  late final GeneratedColumn<bool> showGender = GeneratedColumn<bool>(
    'show_gender',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_gender" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showCityMeta = const VerificationMeta(
    'showCity',
  );
  @override
  late final GeneratedColumn<bool> showCity = GeneratedColumn<bool>(
    'show_city',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_city" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showExactLocationMeta = const VerificationMeta(
    'showExactLocation',
  );
  @override
  late final GeneratedColumn<bool> showExactLocation = GeneratedColumn<bool>(
    'show_exact_location',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_exact_location" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showPhoneMeta = const VerificationMeta(
    'showPhone',
  );
  @override
  late final GeneratedColumn<bool> showPhone = GeneratedColumn<bool>(
    'show_phone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_phone" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showEmailMeta = const VerificationMeta(
    'showEmail',
  );
  @override
  late final GeneratedColumn<bool> showEmail = GeneratedColumn<bool>(
    'show_email',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_email" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showInterestsMeta = const VerificationMeta(
    'showInterests',
  );
  @override
  late final GeneratedColumn<bool> showInterests = GeneratedColumn<bool>(
    'show_interests',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_interests" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showOccupationMeta = const VerificationMeta(
    'showOccupation',
  );
  @override
  late final GeneratedColumn<bool> showOccupation = GeneratedColumn<bool>(
    'show_occupation',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_occupation" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showBioMeta = const VerificationMeta(
    'showBio',
  );
  @override
  late final GeneratedColumn<bool> showBio = GeneratedColumn<bool>(
    'show_bio',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_bio" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showLookingForMeta = const VerificationMeta(
    'showLookingFor',
  );
  @override
  late final GeneratedColumn<bool> showLookingFor = GeneratedColumn<bool>(
    'show_looking_for',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_looking_for" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _allowVideoCallMeta = const VerificationMeta(
    'allowVideoCall',
  );
  @override
  late final GeneratedColumn<bool> allowVideoCall = GeneratedColumn<bool>(
    'allow_video_call',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_video_call" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _allowDirectChatMeta = const VerificationMeta(
    'allowDirectChat',
  );
  @override
  late final GeneratedColumn<bool> allowDirectChat = GeneratedColumn<bool>(
    'allow_direct_chat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_direct_chat" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _geoPrecisionMeta = const VerificationMeta(
    'geoPrecision',
  );
  @override
  late final GeneratedColumn<String> geoPrecision = GeneratedColumn<String>(
    'geo_precision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('neighborhood'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    showNickname,
    showFullName,
    showAge,
    showGender,
    showCity,
    showExactLocation,
    showPhone,
    showEmail,
    showInterests,
    showOccupation,
    showBio,
    showLookingFor,
    allowVideoCall,
    allowDirectChat,
    geoPrecision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'privacy_settings_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrivacySettingsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    if (data.containsKey('show_nickname')) {
      context.handle(
        _showNicknameMeta,
        showNickname.isAcceptableOrUnknown(
          data['show_nickname']!,
          _showNicknameMeta,
        ),
      );
    }
    if (data.containsKey('show_full_name')) {
      context.handle(
        _showFullNameMeta,
        showFullName.isAcceptableOrUnknown(
          data['show_full_name']!,
          _showFullNameMeta,
        ),
      );
    }
    if (data.containsKey('show_age')) {
      context.handle(
        _showAgeMeta,
        showAge.isAcceptableOrUnknown(data['show_age']!, _showAgeMeta),
      );
    }
    if (data.containsKey('show_gender')) {
      context.handle(
        _showGenderMeta,
        showGender.isAcceptableOrUnknown(data['show_gender']!, _showGenderMeta),
      );
    }
    if (data.containsKey('show_city')) {
      context.handle(
        _showCityMeta,
        showCity.isAcceptableOrUnknown(data['show_city']!, _showCityMeta),
      );
    }
    if (data.containsKey('show_exact_location')) {
      context.handle(
        _showExactLocationMeta,
        showExactLocation.isAcceptableOrUnknown(
          data['show_exact_location']!,
          _showExactLocationMeta,
        ),
      );
    }
    if (data.containsKey('show_phone')) {
      context.handle(
        _showPhoneMeta,
        showPhone.isAcceptableOrUnknown(data['show_phone']!, _showPhoneMeta),
      );
    }
    if (data.containsKey('show_email')) {
      context.handle(
        _showEmailMeta,
        showEmail.isAcceptableOrUnknown(data['show_email']!, _showEmailMeta),
      );
    }
    if (data.containsKey('show_interests')) {
      context.handle(
        _showInterestsMeta,
        showInterests.isAcceptableOrUnknown(
          data['show_interests']!,
          _showInterestsMeta,
        ),
      );
    }
    if (data.containsKey('show_occupation')) {
      context.handle(
        _showOccupationMeta,
        showOccupation.isAcceptableOrUnknown(
          data['show_occupation']!,
          _showOccupationMeta,
        ),
      );
    }
    if (data.containsKey('show_bio')) {
      context.handle(
        _showBioMeta,
        showBio.isAcceptableOrUnknown(data['show_bio']!, _showBioMeta),
      );
    }
    if (data.containsKey('show_looking_for')) {
      context.handle(
        _showLookingForMeta,
        showLookingFor.isAcceptableOrUnknown(
          data['show_looking_for']!,
          _showLookingForMeta,
        ),
      );
    }
    if (data.containsKey('allow_video_call')) {
      context.handle(
        _allowVideoCallMeta,
        allowVideoCall.isAcceptableOrUnknown(
          data['allow_video_call']!,
          _allowVideoCallMeta,
        ),
      );
    }
    if (data.containsKey('allow_direct_chat')) {
      context.handle(
        _allowDirectChatMeta,
        allowDirectChat.isAcceptableOrUnknown(
          data['allow_direct_chat']!,
          _allowDirectChatMeta,
        ),
      );
    }
    if (data.containsKey('geo_precision')) {
      context.handle(
        _geoPrecisionMeta,
        geoPrecision.isAcceptableOrUnknown(
          data['geo_precision']!,
          _geoPrecisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrivacySettingsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrivacySettingsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      ),
      showNickname: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_nickname'],
      )!,
      showFullName: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_full_name'],
      )!,
      showAge: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_age'],
      )!,
      showGender: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_gender'],
      )!,
      showCity: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_city'],
      )!,
      showExactLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_exact_location'],
      )!,
      showPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_phone'],
      )!,
      showEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_email'],
      )!,
      showInterests: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_interests'],
      )!,
      showOccupation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_occupation'],
      )!,
      showBio: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_bio'],
      )!,
      showLookingFor: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_looking_for'],
      )!,
      allowVideoCall: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_video_call'],
      )!,
      allowDirectChat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_direct_chat'],
      )!,
      geoPrecision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geo_precision'],
      )!,
    );
  }

  @override
  $PrivacySettingsTableTable createAlias(String alias) {
    return $PrivacySettingsTableTable(attachedDatabase, alias);
  }
}

class PrivacySettingsTableData extends DataClass
    implements Insertable<PrivacySettingsTableData> {
  final int id;
  final String? uid;
  final bool showNickname;
  final bool showFullName;
  final bool showAge;
  final bool showGender;
  final bool showCity;
  final bool showExactLocation;
  final bool showPhone;
  final bool showEmail;
  final bool showInterests;
  final bool showOccupation;
  final bool showBio;
  final bool showLookingFor;
  final bool allowVideoCall;
  final bool allowDirectChat;
  final String geoPrecision;
  const PrivacySettingsTableData({
    required this.id,
    this.uid,
    required this.showNickname,
    required this.showFullName,
    required this.showAge,
    required this.showGender,
    required this.showCity,
    required this.showExactLocation,
    required this.showPhone,
    required this.showEmail,
    required this.showInterests,
    required this.showOccupation,
    required this.showBio,
    required this.showLookingFor,
    required this.allowVideoCall,
    required this.allowDirectChat,
    required this.geoPrecision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    map['show_nickname'] = Variable<bool>(showNickname);
    map['show_full_name'] = Variable<bool>(showFullName);
    map['show_age'] = Variable<bool>(showAge);
    map['show_gender'] = Variable<bool>(showGender);
    map['show_city'] = Variable<bool>(showCity);
    map['show_exact_location'] = Variable<bool>(showExactLocation);
    map['show_phone'] = Variable<bool>(showPhone);
    map['show_email'] = Variable<bool>(showEmail);
    map['show_interests'] = Variable<bool>(showInterests);
    map['show_occupation'] = Variable<bool>(showOccupation);
    map['show_bio'] = Variable<bool>(showBio);
    map['show_looking_for'] = Variable<bool>(showLookingFor);
    map['allow_video_call'] = Variable<bool>(allowVideoCall);
    map['allow_direct_chat'] = Variable<bool>(allowDirectChat);
    map['geo_precision'] = Variable<String>(geoPrecision);
    return map;
  }

  PrivacySettingsTableCompanion toCompanion(bool nullToAbsent) {
    return PrivacySettingsTableCompanion(
      id: Value(id),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
      showNickname: Value(showNickname),
      showFullName: Value(showFullName),
      showAge: Value(showAge),
      showGender: Value(showGender),
      showCity: Value(showCity),
      showExactLocation: Value(showExactLocation),
      showPhone: Value(showPhone),
      showEmail: Value(showEmail),
      showInterests: Value(showInterests),
      showOccupation: Value(showOccupation),
      showBio: Value(showBio),
      showLookingFor: Value(showLookingFor),
      allowVideoCall: Value(allowVideoCall),
      allowDirectChat: Value(allowDirectChat),
      geoPrecision: Value(geoPrecision),
    );
  }

  factory PrivacySettingsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrivacySettingsTableData(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String?>(json['uid']),
      showNickname: serializer.fromJson<bool>(json['showNickname']),
      showFullName: serializer.fromJson<bool>(json['showFullName']),
      showAge: serializer.fromJson<bool>(json['showAge']),
      showGender: serializer.fromJson<bool>(json['showGender']),
      showCity: serializer.fromJson<bool>(json['showCity']),
      showExactLocation: serializer.fromJson<bool>(json['showExactLocation']),
      showPhone: serializer.fromJson<bool>(json['showPhone']),
      showEmail: serializer.fromJson<bool>(json['showEmail']),
      showInterests: serializer.fromJson<bool>(json['showInterests']),
      showOccupation: serializer.fromJson<bool>(json['showOccupation']),
      showBio: serializer.fromJson<bool>(json['showBio']),
      showLookingFor: serializer.fromJson<bool>(json['showLookingFor']),
      allowVideoCall: serializer.fromJson<bool>(json['allowVideoCall']),
      allowDirectChat: serializer.fromJson<bool>(json['allowDirectChat']),
      geoPrecision: serializer.fromJson<String>(json['geoPrecision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String?>(uid),
      'showNickname': serializer.toJson<bool>(showNickname),
      'showFullName': serializer.toJson<bool>(showFullName),
      'showAge': serializer.toJson<bool>(showAge),
      'showGender': serializer.toJson<bool>(showGender),
      'showCity': serializer.toJson<bool>(showCity),
      'showExactLocation': serializer.toJson<bool>(showExactLocation),
      'showPhone': serializer.toJson<bool>(showPhone),
      'showEmail': serializer.toJson<bool>(showEmail),
      'showInterests': serializer.toJson<bool>(showInterests),
      'showOccupation': serializer.toJson<bool>(showOccupation),
      'showBio': serializer.toJson<bool>(showBio),
      'showLookingFor': serializer.toJson<bool>(showLookingFor),
      'allowVideoCall': serializer.toJson<bool>(allowVideoCall),
      'allowDirectChat': serializer.toJson<bool>(allowDirectChat),
      'geoPrecision': serializer.toJson<String>(geoPrecision),
    };
  }

  PrivacySettingsTableData copyWith({
    int? id,
    Value<String?> uid = const Value.absent(),
    bool? showNickname,
    bool? showFullName,
    bool? showAge,
    bool? showGender,
    bool? showCity,
    bool? showExactLocation,
    bool? showPhone,
    bool? showEmail,
    bool? showInterests,
    bool? showOccupation,
    bool? showBio,
    bool? showLookingFor,
    bool? allowVideoCall,
    bool? allowDirectChat,
    String? geoPrecision,
  }) => PrivacySettingsTableData(
    id: id ?? this.id,
    uid: uid.present ? uid.value : this.uid,
    showNickname: showNickname ?? this.showNickname,
    showFullName: showFullName ?? this.showFullName,
    showAge: showAge ?? this.showAge,
    showGender: showGender ?? this.showGender,
    showCity: showCity ?? this.showCity,
    showExactLocation: showExactLocation ?? this.showExactLocation,
    showPhone: showPhone ?? this.showPhone,
    showEmail: showEmail ?? this.showEmail,
    showInterests: showInterests ?? this.showInterests,
    showOccupation: showOccupation ?? this.showOccupation,
    showBio: showBio ?? this.showBio,
    showLookingFor: showLookingFor ?? this.showLookingFor,
    allowVideoCall: allowVideoCall ?? this.allowVideoCall,
    allowDirectChat: allowDirectChat ?? this.allowDirectChat,
    geoPrecision: geoPrecision ?? this.geoPrecision,
  );
  PrivacySettingsTableData copyWithCompanion(
    PrivacySettingsTableCompanion data,
  ) {
    return PrivacySettingsTableData(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      showNickname: data.showNickname.present
          ? data.showNickname.value
          : this.showNickname,
      showFullName: data.showFullName.present
          ? data.showFullName.value
          : this.showFullName,
      showAge: data.showAge.present ? data.showAge.value : this.showAge,
      showGender: data.showGender.present
          ? data.showGender.value
          : this.showGender,
      showCity: data.showCity.present ? data.showCity.value : this.showCity,
      showExactLocation: data.showExactLocation.present
          ? data.showExactLocation.value
          : this.showExactLocation,
      showPhone: data.showPhone.present ? data.showPhone.value : this.showPhone,
      showEmail: data.showEmail.present ? data.showEmail.value : this.showEmail,
      showInterests: data.showInterests.present
          ? data.showInterests.value
          : this.showInterests,
      showOccupation: data.showOccupation.present
          ? data.showOccupation.value
          : this.showOccupation,
      showBio: data.showBio.present ? data.showBio.value : this.showBio,
      showLookingFor: data.showLookingFor.present
          ? data.showLookingFor.value
          : this.showLookingFor,
      allowVideoCall: data.allowVideoCall.present
          ? data.allowVideoCall.value
          : this.allowVideoCall,
      allowDirectChat: data.allowDirectChat.present
          ? data.allowDirectChat.value
          : this.allowDirectChat,
      geoPrecision: data.geoPrecision.present
          ? data.geoPrecision.value
          : this.geoPrecision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrivacySettingsTableData(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('showNickname: $showNickname, ')
          ..write('showFullName: $showFullName, ')
          ..write('showAge: $showAge, ')
          ..write('showGender: $showGender, ')
          ..write('showCity: $showCity, ')
          ..write('showExactLocation: $showExactLocation, ')
          ..write('showPhone: $showPhone, ')
          ..write('showEmail: $showEmail, ')
          ..write('showInterests: $showInterests, ')
          ..write('showOccupation: $showOccupation, ')
          ..write('showBio: $showBio, ')
          ..write('showLookingFor: $showLookingFor, ')
          ..write('allowVideoCall: $allowVideoCall, ')
          ..write('allowDirectChat: $allowDirectChat, ')
          ..write('geoPrecision: $geoPrecision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uid,
    showNickname,
    showFullName,
    showAge,
    showGender,
    showCity,
    showExactLocation,
    showPhone,
    showEmail,
    showInterests,
    showOccupation,
    showBio,
    showLookingFor,
    allowVideoCall,
    allowDirectChat,
    geoPrecision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrivacySettingsTableData &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.showNickname == this.showNickname &&
          other.showFullName == this.showFullName &&
          other.showAge == this.showAge &&
          other.showGender == this.showGender &&
          other.showCity == this.showCity &&
          other.showExactLocation == this.showExactLocation &&
          other.showPhone == this.showPhone &&
          other.showEmail == this.showEmail &&
          other.showInterests == this.showInterests &&
          other.showOccupation == this.showOccupation &&
          other.showBio == this.showBio &&
          other.showLookingFor == this.showLookingFor &&
          other.allowVideoCall == this.allowVideoCall &&
          other.allowDirectChat == this.allowDirectChat &&
          other.geoPrecision == this.geoPrecision);
}

class PrivacySettingsTableCompanion
    extends UpdateCompanion<PrivacySettingsTableData> {
  final Value<int> id;
  final Value<String?> uid;
  final Value<bool> showNickname;
  final Value<bool> showFullName;
  final Value<bool> showAge;
  final Value<bool> showGender;
  final Value<bool> showCity;
  final Value<bool> showExactLocation;
  final Value<bool> showPhone;
  final Value<bool> showEmail;
  final Value<bool> showInterests;
  final Value<bool> showOccupation;
  final Value<bool> showBio;
  final Value<bool> showLookingFor;
  final Value<bool> allowVideoCall;
  final Value<bool> allowDirectChat;
  final Value<String> geoPrecision;
  const PrivacySettingsTableCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.showNickname = const Value.absent(),
    this.showFullName = const Value.absent(),
    this.showAge = const Value.absent(),
    this.showGender = const Value.absent(),
    this.showCity = const Value.absent(),
    this.showExactLocation = const Value.absent(),
    this.showPhone = const Value.absent(),
    this.showEmail = const Value.absent(),
    this.showInterests = const Value.absent(),
    this.showOccupation = const Value.absent(),
    this.showBio = const Value.absent(),
    this.showLookingFor = const Value.absent(),
    this.allowVideoCall = const Value.absent(),
    this.allowDirectChat = const Value.absent(),
    this.geoPrecision = const Value.absent(),
  });
  PrivacySettingsTableCompanion.insert({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.showNickname = const Value.absent(),
    this.showFullName = const Value.absent(),
    this.showAge = const Value.absent(),
    this.showGender = const Value.absent(),
    this.showCity = const Value.absent(),
    this.showExactLocation = const Value.absent(),
    this.showPhone = const Value.absent(),
    this.showEmail = const Value.absent(),
    this.showInterests = const Value.absent(),
    this.showOccupation = const Value.absent(),
    this.showBio = const Value.absent(),
    this.showLookingFor = const Value.absent(),
    this.allowVideoCall = const Value.absent(),
    this.allowDirectChat = const Value.absent(),
    this.geoPrecision = const Value.absent(),
  });
  static Insertable<PrivacySettingsTableData> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<bool>? showNickname,
    Expression<bool>? showFullName,
    Expression<bool>? showAge,
    Expression<bool>? showGender,
    Expression<bool>? showCity,
    Expression<bool>? showExactLocation,
    Expression<bool>? showPhone,
    Expression<bool>? showEmail,
    Expression<bool>? showInterests,
    Expression<bool>? showOccupation,
    Expression<bool>? showBio,
    Expression<bool>? showLookingFor,
    Expression<bool>? allowVideoCall,
    Expression<bool>? allowDirectChat,
    Expression<String>? geoPrecision,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (showNickname != null) 'show_nickname': showNickname,
      if (showFullName != null) 'show_full_name': showFullName,
      if (showAge != null) 'show_age': showAge,
      if (showGender != null) 'show_gender': showGender,
      if (showCity != null) 'show_city': showCity,
      if (showExactLocation != null) 'show_exact_location': showExactLocation,
      if (showPhone != null) 'show_phone': showPhone,
      if (showEmail != null) 'show_email': showEmail,
      if (showInterests != null) 'show_interests': showInterests,
      if (showOccupation != null) 'show_occupation': showOccupation,
      if (showBio != null) 'show_bio': showBio,
      if (showLookingFor != null) 'show_looking_for': showLookingFor,
      if (allowVideoCall != null) 'allow_video_call': allowVideoCall,
      if (allowDirectChat != null) 'allow_direct_chat': allowDirectChat,
      if (geoPrecision != null) 'geo_precision': geoPrecision,
    });
  }

  PrivacySettingsTableCompanion copyWith({
    Value<int>? id,
    Value<String?>? uid,
    Value<bool>? showNickname,
    Value<bool>? showFullName,
    Value<bool>? showAge,
    Value<bool>? showGender,
    Value<bool>? showCity,
    Value<bool>? showExactLocation,
    Value<bool>? showPhone,
    Value<bool>? showEmail,
    Value<bool>? showInterests,
    Value<bool>? showOccupation,
    Value<bool>? showBio,
    Value<bool>? showLookingFor,
    Value<bool>? allowVideoCall,
    Value<bool>? allowDirectChat,
    Value<String>? geoPrecision,
  }) {
    return PrivacySettingsTableCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      showNickname: showNickname ?? this.showNickname,
      showFullName: showFullName ?? this.showFullName,
      showAge: showAge ?? this.showAge,
      showGender: showGender ?? this.showGender,
      showCity: showCity ?? this.showCity,
      showExactLocation: showExactLocation ?? this.showExactLocation,
      showPhone: showPhone ?? this.showPhone,
      showEmail: showEmail ?? this.showEmail,
      showInterests: showInterests ?? this.showInterests,
      showOccupation: showOccupation ?? this.showOccupation,
      showBio: showBio ?? this.showBio,
      showLookingFor: showLookingFor ?? this.showLookingFor,
      allowVideoCall: allowVideoCall ?? this.allowVideoCall,
      allowDirectChat: allowDirectChat ?? this.allowDirectChat,
      geoPrecision: geoPrecision ?? this.geoPrecision,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (showNickname.present) {
      map['show_nickname'] = Variable<bool>(showNickname.value);
    }
    if (showFullName.present) {
      map['show_full_name'] = Variable<bool>(showFullName.value);
    }
    if (showAge.present) {
      map['show_age'] = Variable<bool>(showAge.value);
    }
    if (showGender.present) {
      map['show_gender'] = Variable<bool>(showGender.value);
    }
    if (showCity.present) {
      map['show_city'] = Variable<bool>(showCity.value);
    }
    if (showExactLocation.present) {
      map['show_exact_location'] = Variable<bool>(showExactLocation.value);
    }
    if (showPhone.present) {
      map['show_phone'] = Variable<bool>(showPhone.value);
    }
    if (showEmail.present) {
      map['show_email'] = Variable<bool>(showEmail.value);
    }
    if (showInterests.present) {
      map['show_interests'] = Variable<bool>(showInterests.value);
    }
    if (showOccupation.present) {
      map['show_occupation'] = Variable<bool>(showOccupation.value);
    }
    if (showBio.present) {
      map['show_bio'] = Variable<bool>(showBio.value);
    }
    if (showLookingFor.present) {
      map['show_looking_for'] = Variable<bool>(showLookingFor.value);
    }
    if (allowVideoCall.present) {
      map['allow_video_call'] = Variable<bool>(allowVideoCall.value);
    }
    if (allowDirectChat.present) {
      map['allow_direct_chat'] = Variable<bool>(allowDirectChat.value);
    }
    if (geoPrecision.present) {
      map['geo_precision'] = Variable<String>(geoPrecision.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrivacySettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('showNickname: $showNickname, ')
          ..write('showFullName: $showFullName, ')
          ..write('showAge: $showAge, ')
          ..write('showGender: $showGender, ')
          ..write('showCity: $showCity, ')
          ..write('showExactLocation: $showExactLocation, ')
          ..write('showPhone: $showPhone, ')
          ..write('showEmail: $showEmail, ')
          ..write('showInterests: $showInterests, ')
          ..write('showOccupation: $showOccupation, ')
          ..write('showBio: $showBio, ')
          ..write('showLookingFor: $showLookingFor, ')
          ..write('allowVideoCall: $allowVideoCall, ')
          ..write('allowDirectChat: $allowDirectChat, ')
          ..write('geoPrecision: $geoPrecision')
          ..write(')'))
        .toString();
  }
}

class $ConsentLogTableTable extends ConsentLogTable
    with TableInfo<$ConsentLogTableTable, ConsentLogTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConsentLogTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dataTypeMeta = const VerificationMeta(
    'dataType',
  );
  @override
  late final GeneratedColumn<String> dataType = GeneratedColumn<String>(
    'data_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    action,
    dataType,
    details,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'consent_log_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConsentLogTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    }
    if (data.containsKey('data_type')) {
      context.handle(
        _dataTypeMeta,
        dataType.isAcceptableOrUnknown(data['data_type']!, _dataTypeMeta),
      );
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConsentLogTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConsentLogTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      ),
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      dataType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_type'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $ConsentLogTableTable createAlias(String alias) {
    return $ConsentLogTableTable(attachedDatabase, alias);
  }
}

class ConsentLogTableData extends DataClass
    implements Insertable<ConsentLogTableData> {
  final int id;
  final String? uid;
  final String action;
  final String dataType;
  final String? details;
  final DateTime timestamp;
  const ConsentLogTableData({
    required this.id,
    this.uid,
    required this.action,
    required this.dataType,
    this.details,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    map['action'] = Variable<String>(action);
    map['data_type'] = Variable<String>(dataType);
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  ConsentLogTableCompanion toCompanion(bool nullToAbsent) {
    return ConsentLogTableCompanion(
      id: Value(id),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
      action: Value(action),
      dataType: Value(dataType),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
      timestamp: Value(timestamp),
    );
  }

  factory ConsentLogTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConsentLogTableData(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String?>(json['uid']),
      action: serializer.fromJson<String>(json['action']),
      dataType: serializer.fromJson<String>(json['dataType']),
      details: serializer.fromJson<String?>(json['details']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String?>(uid),
      'action': serializer.toJson<String>(action),
      'dataType': serializer.toJson<String>(dataType),
      'details': serializer.toJson<String?>(details),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  ConsentLogTableData copyWith({
    int? id,
    Value<String?> uid = const Value.absent(),
    String? action,
    String? dataType,
    Value<String?> details = const Value.absent(),
    DateTime? timestamp,
  }) => ConsentLogTableData(
    id: id ?? this.id,
    uid: uid.present ? uid.value : this.uid,
    action: action ?? this.action,
    dataType: dataType ?? this.dataType,
    details: details.present ? details.value : this.details,
    timestamp: timestamp ?? this.timestamp,
  );
  ConsentLogTableData copyWithCompanion(ConsentLogTableCompanion data) {
    return ConsentLogTableData(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      action: data.action.present ? data.action.value : this.action,
      dataType: data.dataType.present ? data.dataType.value : this.dataType,
      details: data.details.present ? data.details.value : this.details,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConsentLogTableData(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('action: $action, ')
          ..write('dataType: $dataType, ')
          ..write('details: $details, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, uid, action, dataType, details, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsentLogTableData &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.action == this.action &&
          other.dataType == this.dataType &&
          other.details == this.details &&
          other.timestamp == this.timestamp);
}

class ConsentLogTableCompanion extends UpdateCompanion<ConsentLogTableData> {
  final Value<int> id;
  final Value<String?> uid;
  final Value<String> action;
  final Value<String> dataType;
  final Value<String?> details;
  final Value<DateTime> timestamp;
  const ConsentLogTableCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.action = const Value.absent(),
    this.dataType = const Value.absent(),
    this.details = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  ConsentLogTableCompanion.insert({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.action = const Value.absent(),
    this.dataType = const Value.absent(),
    this.details = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  static Insertable<ConsentLogTableData> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<String>? action,
    Expression<String>? dataType,
    Expression<String>? details,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (action != null) 'action': action,
      if (dataType != null) 'data_type': dataType,
      if (details != null) 'details': details,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  ConsentLogTableCompanion copyWith({
    Value<int>? id,
    Value<String?>? uid,
    Value<String>? action,
    Value<String>? dataType,
    Value<String?>? details,
    Value<DateTime>? timestamp,
  }) {
    return ConsentLogTableCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      action: action ?? this.action,
      dataType: dataType ?? this.dataType,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (dataType.present) {
      map['data_type'] = Variable<String>(dataType.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConsentLogTableCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('action: $action, ')
          ..write('dataType: $dataType, ')
          ..write('details: $details, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $ChatCacheTableTable extends ChatCacheTable
    with TableInfo<$ChatCacheTableTable, ChatCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otherUidMeta = const VerificationMeta(
    'otherUid',
  );
  @override
  late final GeneratedColumn<String> otherUid = GeneratedColumn<String>(
    'other_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otherNicknameMeta = const VerificationMeta(
    'otherNickname',
  );
  @override
  late final GeneratedColumn<String> otherNickname = GeneratedColumn<String>(
    'other_nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otherAvatarUrlMeta = const VerificationMeta(
    'otherAvatarUrl',
  );
  @override
  late final GeneratedColumn<String> otherAvatarUrl = GeneratedColumn<String>(
    'other_avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageAtMeta = const VerificationMeta(
    'lastMessageAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastMessageAt =
      GeneratedColumn<DateTime>(
        'last_message_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessageMeta = const VerificationMeta(
    'lastMessage',
  );
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
    'last_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageSenderMeta = const VerificationMeta(
    'lastMessageSender',
  );
  @override
  late final GeneratedColumn<String> lastMessageSender =
      GeneratedColumn<String>(
        'last_message_sender',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessageTypeMeta = const VerificationMeta(
    'lastMessageType',
  );
  @override
  late final GeneratedColumn<String> lastMessageType = GeneratedColumn<String>(
    'last_message_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hasUnreadMeta = const VerificationMeta(
    'hasUnread',
  );
  @override
  late final GeneratedColumn<bool> hasUnread = GeneratedColumn<bool>(
    'has_unread',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_unread" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chatId,
    otherUid,
    otherNickname,
    otherAvatarUrl,
    lastMessageAt,
    lastMessage,
    lastMessageSender,
    lastMessageType,
    unreadCount,
    hasUnread,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_cache_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatCacheTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    }
    if (data.containsKey('other_uid')) {
      context.handle(
        _otherUidMeta,
        otherUid.isAcceptableOrUnknown(data['other_uid']!, _otherUidMeta),
      );
    }
    if (data.containsKey('other_nickname')) {
      context.handle(
        _otherNicknameMeta,
        otherNickname.isAcceptableOrUnknown(
          data['other_nickname']!,
          _otherNicknameMeta,
        ),
      );
    }
    if (data.containsKey('other_avatar_url')) {
      context.handle(
        _otherAvatarUrlMeta,
        otherAvatarUrl.isAcceptableOrUnknown(
          data['other_avatar_url']!,
          _otherAvatarUrlMeta,
        ),
      );
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
        _lastMessageAtMeta,
        lastMessageAt.isAcceptableOrUnknown(
          data['last_message_at']!,
          _lastMessageAtMeta,
        ),
      );
    }
    if (data.containsKey('last_message')) {
      context.handle(
        _lastMessageMeta,
        lastMessage.isAcceptableOrUnknown(
          data['last_message']!,
          _lastMessageMeta,
        ),
      );
    }
    if (data.containsKey('last_message_sender')) {
      context.handle(
        _lastMessageSenderMeta,
        lastMessageSender.isAcceptableOrUnknown(
          data['last_message_sender']!,
          _lastMessageSenderMeta,
        ),
      );
    }
    if (data.containsKey('last_message_type')) {
      context.handle(
        _lastMessageTypeMeta,
        lastMessageType.isAcceptableOrUnknown(
          data['last_message_type']!,
          _lastMessageTypeMeta,
        ),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('has_unread')) {
      context.handle(
        _hasUnreadMeta,
        hasUnread.isAcceptableOrUnknown(data['has_unread']!, _hasUnreadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatCacheTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      ),
      otherUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_uid'],
      ),
      otherNickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_nickname'],
      ),
      otherAvatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_avatar_url'],
      ),
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_message_at'],
      ),
      lastMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message'],
      ),
      lastMessageSender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_sender'],
      ),
      lastMessageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_type'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      hasUnread: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_unread'],
      )!,
    );
  }

  @override
  $ChatCacheTableTable createAlias(String alias) {
    return $ChatCacheTableTable(attachedDatabase, alias);
  }
}

class ChatCacheTableData extends DataClass
    implements Insertable<ChatCacheTableData> {
  final int id;
  final String? chatId;
  final String? otherUid;
  final String? otherNickname;
  final String? otherAvatarUrl;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final String? lastMessageSender;
  final String? lastMessageType;
  final int unreadCount;
  final bool hasUnread;
  const ChatCacheTableData({
    required this.id,
    this.chatId,
    this.otherUid,
    this.otherNickname,
    this.otherAvatarUrl,
    this.lastMessageAt,
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageType,
    required this.unreadCount,
    required this.hasUnread,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || chatId != null) {
      map['chat_id'] = Variable<String>(chatId);
    }
    if (!nullToAbsent || otherUid != null) {
      map['other_uid'] = Variable<String>(otherUid);
    }
    if (!nullToAbsent || otherNickname != null) {
      map['other_nickname'] = Variable<String>(otherNickname);
    }
    if (!nullToAbsent || otherAvatarUrl != null) {
      map['other_avatar_url'] = Variable<String>(otherAvatarUrl);
    }
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    }
    if (!nullToAbsent || lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    if (!nullToAbsent || lastMessageSender != null) {
      map['last_message_sender'] = Variable<String>(lastMessageSender);
    }
    if (!nullToAbsent || lastMessageType != null) {
      map['last_message_type'] = Variable<String>(lastMessageType);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['has_unread'] = Variable<bool>(hasUnread);
    return map;
  }

  ChatCacheTableCompanion toCompanion(bool nullToAbsent) {
    return ChatCacheTableCompanion(
      id: Value(id),
      chatId: chatId == null && nullToAbsent
          ? const Value.absent()
          : Value(chatId),
      otherUid: otherUid == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUid),
      otherNickname: otherNickname == null && nullToAbsent
          ? const Value.absent()
          : Value(otherNickname),
      otherAvatarUrl: otherAvatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(otherAvatarUrl),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      lastMessage: lastMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessage),
      lastMessageSender: lastMessageSender == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageSender),
      lastMessageType: lastMessageType == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageType),
      unreadCount: Value(unreadCount),
      hasUnread: Value(hasUnread),
    );
  }

  factory ChatCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatCacheTableData(
      id: serializer.fromJson<int>(json['id']),
      chatId: serializer.fromJson<String?>(json['chatId']),
      otherUid: serializer.fromJson<String?>(json['otherUid']),
      otherNickname: serializer.fromJson<String?>(json['otherNickname']),
      otherAvatarUrl: serializer.fromJson<String?>(json['otherAvatarUrl']),
      lastMessageAt: serializer.fromJson<DateTime?>(json['lastMessageAt']),
      lastMessage: serializer.fromJson<String?>(json['lastMessage']),
      lastMessageSender: serializer.fromJson<String?>(
        json['lastMessageSender'],
      ),
      lastMessageType: serializer.fromJson<String?>(json['lastMessageType']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      hasUnread: serializer.fromJson<bool>(json['hasUnread']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'chatId': serializer.toJson<String?>(chatId),
      'otherUid': serializer.toJson<String?>(otherUid),
      'otherNickname': serializer.toJson<String?>(otherNickname),
      'otherAvatarUrl': serializer.toJson<String?>(otherAvatarUrl),
      'lastMessageAt': serializer.toJson<DateTime?>(lastMessageAt),
      'lastMessage': serializer.toJson<String?>(lastMessage),
      'lastMessageSender': serializer.toJson<String?>(lastMessageSender),
      'lastMessageType': serializer.toJson<String?>(lastMessageType),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'hasUnread': serializer.toJson<bool>(hasUnread),
    };
  }

  ChatCacheTableData copyWith({
    int? id,
    Value<String?> chatId = const Value.absent(),
    Value<String?> otherUid = const Value.absent(),
    Value<String?> otherNickname = const Value.absent(),
    Value<String?> otherAvatarUrl = const Value.absent(),
    Value<DateTime?> lastMessageAt = const Value.absent(),
    Value<String?> lastMessage = const Value.absent(),
    Value<String?> lastMessageSender = const Value.absent(),
    Value<String?> lastMessageType = const Value.absent(),
    int? unreadCount,
    bool? hasUnread,
  }) => ChatCacheTableData(
    id: id ?? this.id,
    chatId: chatId.present ? chatId.value : this.chatId,
    otherUid: otherUid.present ? otherUid.value : this.otherUid,
    otherNickname: otherNickname.present
        ? otherNickname.value
        : this.otherNickname,
    otherAvatarUrl: otherAvatarUrl.present
        ? otherAvatarUrl.value
        : this.otherAvatarUrl,
    lastMessageAt: lastMessageAt.present
        ? lastMessageAt.value
        : this.lastMessageAt,
    lastMessage: lastMessage.present ? lastMessage.value : this.lastMessage,
    lastMessageSender: lastMessageSender.present
        ? lastMessageSender.value
        : this.lastMessageSender,
    lastMessageType: lastMessageType.present
        ? lastMessageType.value
        : this.lastMessageType,
    unreadCount: unreadCount ?? this.unreadCount,
    hasUnread: hasUnread ?? this.hasUnread,
  );
  ChatCacheTableData copyWithCompanion(ChatCacheTableCompanion data) {
    return ChatCacheTableData(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      otherUid: data.otherUid.present ? data.otherUid.value : this.otherUid,
      otherNickname: data.otherNickname.present
          ? data.otherNickname.value
          : this.otherNickname,
      otherAvatarUrl: data.otherAvatarUrl.present
          ? data.otherAvatarUrl.value
          : this.otherAvatarUrl,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      lastMessage: data.lastMessage.present
          ? data.lastMessage.value
          : this.lastMessage,
      lastMessageSender: data.lastMessageSender.present
          ? data.lastMessageSender.value
          : this.lastMessageSender,
      lastMessageType: data.lastMessageType.present
          ? data.lastMessageType.value
          : this.lastMessageType,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      hasUnread: data.hasUnread.present ? data.hasUnread.value : this.hasUnread,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatCacheTableData(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('otherUid: $otherUid, ')
          ..write('otherNickname: $otherNickname, ')
          ..write('otherAvatarUrl: $otherAvatarUrl, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageSender: $lastMessageSender, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('hasUnread: $hasUnread')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chatId,
    otherUid,
    otherNickname,
    otherAvatarUrl,
    lastMessageAt,
    lastMessage,
    lastMessageSender,
    lastMessageType,
    unreadCount,
    hasUnread,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatCacheTableData &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.otherUid == this.otherUid &&
          other.otherNickname == this.otherNickname &&
          other.otherAvatarUrl == this.otherAvatarUrl &&
          other.lastMessageAt == this.lastMessageAt &&
          other.lastMessage == this.lastMessage &&
          other.lastMessageSender == this.lastMessageSender &&
          other.lastMessageType == this.lastMessageType &&
          other.unreadCount == this.unreadCount &&
          other.hasUnread == this.hasUnread);
}

class ChatCacheTableCompanion extends UpdateCompanion<ChatCacheTableData> {
  final Value<int> id;
  final Value<String?> chatId;
  final Value<String?> otherUid;
  final Value<String?> otherNickname;
  final Value<String?> otherAvatarUrl;
  final Value<DateTime?> lastMessageAt;
  final Value<String?> lastMessage;
  final Value<String?> lastMessageSender;
  final Value<String?> lastMessageType;
  final Value<int> unreadCount;
  final Value<bool> hasUnread;
  const ChatCacheTableCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.otherUid = const Value.absent(),
    this.otherNickname = const Value.absent(),
    this.otherAvatarUrl = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageSender = const Value.absent(),
    this.lastMessageType = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.hasUnread = const Value.absent(),
  });
  ChatCacheTableCompanion.insert({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.otherUid = const Value.absent(),
    this.otherNickname = const Value.absent(),
    this.otherAvatarUrl = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageSender = const Value.absent(),
    this.lastMessageType = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.hasUnread = const Value.absent(),
  });
  static Insertable<ChatCacheTableData> custom({
    Expression<int>? id,
    Expression<String>? chatId,
    Expression<String>? otherUid,
    Expression<String>? otherNickname,
    Expression<String>? otherAvatarUrl,
    Expression<DateTime>? lastMessageAt,
    Expression<String>? lastMessage,
    Expression<String>? lastMessageSender,
    Expression<String>? lastMessageType,
    Expression<int>? unreadCount,
    Expression<bool>? hasUnread,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (otherUid != null) 'other_uid': otherUid,
      if (otherNickname != null) 'other_nickname': otherNickname,
      if (otherAvatarUrl != null) 'other_avatar_url': otherAvatarUrl,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastMessageSender != null) 'last_message_sender': lastMessageSender,
      if (lastMessageType != null) 'last_message_type': lastMessageType,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (hasUnread != null) 'has_unread': hasUnread,
    });
  }

  ChatCacheTableCompanion copyWith({
    Value<int>? id,
    Value<String?>? chatId,
    Value<String?>? otherUid,
    Value<String?>? otherNickname,
    Value<String?>? otherAvatarUrl,
    Value<DateTime?>? lastMessageAt,
    Value<String?>? lastMessage,
    Value<String?>? lastMessageSender,
    Value<String?>? lastMessageType,
    Value<int>? unreadCount,
    Value<bool>? hasUnread,
  }) {
    return ChatCacheTableCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      otherUid: otherUid ?? this.otherUid,
      otherNickname: otherNickname ?? this.otherNickname,
      otherAvatarUrl: otherAvatarUrl ?? this.otherAvatarUrl,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      unreadCount: unreadCount ?? this.unreadCount,
      hasUnread: hasUnread ?? this.hasUnread,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (otherUid.present) {
      map['other_uid'] = Variable<String>(otherUid.value);
    }
    if (otherNickname.present) {
      map['other_nickname'] = Variable<String>(otherNickname.value);
    }
    if (otherAvatarUrl.present) {
      map['other_avatar_url'] = Variable<String>(otherAvatarUrl.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (lastMessageSender.present) {
      map['last_message_sender'] = Variable<String>(lastMessageSender.value);
    }
    if (lastMessageType.present) {
      map['last_message_type'] = Variable<String>(lastMessageType.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (hasUnread.present) {
      map['has_unread'] = Variable<bool>(hasUnread.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatCacheTableCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('otherUid: $otherUid, ')
          ..write('otherNickname: $otherNickname, ')
          ..write('otherAvatarUrl: $otherAvatarUrl, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageSender: $lastMessageSender, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('hasUnread: $hasUnread')
          ..write(')'))
        .toString();
  }
}

class $SavedSearchTableTable extends SavedSearchTable
    with TableInfo<$SavedSearchTableTable, SavedSearchTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedSearchTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minAgeMeta = const VerificationMeta('minAge');
  @override
  late final GeneratedColumn<int> minAge = GeneratedColumn<int>(
    'min_age',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxAgeMeta = const VerificationMeta('maxAge');
  @override
  late final GeneratedColumn<int> maxAge = GeneratedColumn<int>(
    'max_age',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String> interests =
      GeneratedColumn<String>(
        'interests',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<List<String>?>(
        $SavedSearchTableTable.$converterinterestsn,
      );
  static const VerificationMeta _lookingForMeta = const VerificationMeta(
    'lookingFor',
  );
  @override
  late final GeneratedColumn<String> lookingFor = GeneratedColumn<String>(
    'looking_for',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _radiusKmMeta = const VerificationMeta(
    'radiusKm',
  );
  @override
  late final GeneratedColumn<double> radiusKm = GeneratedColumn<double>(
    'radius_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    city,
    country,
    minAge,
    maxAge,
    gender,
    interests,
    lookingFor,
    radiusKm,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_search_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedSearchTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('min_age')) {
      context.handle(
        _minAgeMeta,
        minAge.isAcceptableOrUnknown(data['min_age']!, _minAgeMeta),
      );
    }
    if (data.containsKey('max_age')) {
      context.handle(
        _maxAgeMeta,
        maxAge.isAcceptableOrUnknown(data['max_age']!, _maxAgeMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('looking_for')) {
      context.handle(
        _lookingForMeta,
        lookingFor.isAcceptableOrUnknown(data['looking_for']!, _lookingForMeta),
      );
    }
    if (data.containsKey('radius_km')) {
      context.handle(
        _radiusKmMeta,
        radiusKm.isAcceptableOrUnknown(data['radius_km']!, _radiusKmMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedSearchTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedSearchTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      ),
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      minAge: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_age'],
      ),
      maxAge: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_age'],
      ),
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      interests: $SavedSearchTableTable.$converterinterestsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}interests'],
        ),
      ),
      lookingFor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}looking_for'],
      ),
      radiusKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}radius_km'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SavedSearchTableTable createAlias(String alias) {
    return $SavedSearchTableTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterinterests =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $converterinterestsn =
      NullAwareTypeConverter.wrap($converterinterests);
}

class SavedSearchTableData extends DataClass
    implements Insertable<SavedSearchTableData> {
  final int id;
  final String? label;
  final String? city;
  final String? country;
  final int? minAge;
  final int? maxAge;
  final String? gender;
  final List<String>? interests;
  final String? lookingFor;
  final double? radiusKm;
  final DateTime createdAt;
  const SavedSearchTableData({
    required this.id,
    this.label,
    this.city,
    this.country,
    this.minAge,
    this.maxAge,
    this.gender,
    this.interests,
    this.lookingFor,
    this.radiusKm,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || minAge != null) {
      map['min_age'] = Variable<int>(minAge);
    }
    if (!nullToAbsent || maxAge != null) {
      map['max_age'] = Variable<int>(maxAge);
    }
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || interests != null) {
      map['interests'] = Variable<String>(
        $SavedSearchTableTable.$converterinterestsn.toSql(interests),
      );
    }
    if (!nullToAbsent || lookingFor != null) {
      map['looking_for'] = Variable<String>(lookingFor);
    }
    if (!nullToAbsent || radiusKm != null) {
      map['radius_km'] = Variable<double>(radiusKm);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SavedSearchTableCompanion toCompanion(bool nullToAbsent) {
    return SavedSearchTableCompanion(
      id: Value(id),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      minAge: minAge == null && nullToAbsent
          ? const Value.absent()
          : Value(minAge),
      maxAge: maxAge == null && nullToAbsent
          ? const Value.absent()
          : Value(maxAge),
      gender: gender == null && nullToAbsent
          ? const Value.absent()
          : Value(gender),
      interests: interests == null && nullToAbsent
          ? const Value.absent()
          : Value(interests),
      lookingFor: lookingFor == null && nullToAbsent
          ? const Value.absent()
          : Value(lookingFor),
      radiusKm: radiusKm == null && nullToAbsent
          ? const Value.absent()
          : Value(radiusKm),
      createdAt: Value(createdAt),
    );
  }

  factory SavedSearchTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedSearchTableData(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String?>(json['label']),
      city: serializer.fromJson<String?>(json['city']),
      country: serializer.fromJson<String?>(json['country']),
      minAge: serializer.fromJson<int?>(json['minAge']),
      maxAge: serializer.fromJson<int?>(json['maxAge']),
      gender: serializer.fromJson<String?>(json['gender']),
      interests: serializer.fromJson<List<String>?>(json['interests']),
      lookingFor: serializer.fromJson<String?>(json['lookingFor']),
      radiusKm: serializer.fromJson<double?>(json['radiusKm']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String?>(label),
      'city': serializer.toJson<String?>(city),
      'country': serializer.toJson<String?>(country),
      'minAge': serializer.toJson<int?>(minAge),
      'maxAge': serializer.toJson<int?>(maxAge),
      'gender': serializer.toJson<String?>(gender),
      'interests': serializer.toJson<List<String>?>(interests),
      'lookingFor': serializer.toJson<String?>(lookingFor),
      'radiusKm': serializer.toJson<double?>(radiusKm),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SavedSearchTableData copyWith({
    int? id,
    Value<String?> label = const Value.absent(),
    Value<String?> city = const Value.absent(),
    Value<String?> country = const Value.absent(),
    Value<int?> minAge = const Value.absent(),
    Value<int?> maxAge = const Value.absent(),
    Value<String?> gender = const Value.absent(),
    Value<List<String>?> interests = const Value.absent(),
    Value<String?> lookingFor = const Value.absent(),
    Value<double?> radiusKm = const Value.absent(),
    DateTime? createdAt,
  }) => SavedSearchTableData(
    id: id ?? this.id,
    label: label.present ? label.value : this.label,
    city: city.present ? city.value : this.city,
    country: country.present ? country.value : this.country,
    minAge: minAge.present ? minAge.value : this.minAge,
    maxAge: maxAge.present ? maxAge.value : this.maxAge,
    gender: gender.present ? gender.value : this.gender,
    interests: interests.present ? interests.value : this.interests,
    lookingFor: lookingFor.present ? lookingFor.value : this.lookingFor,
    radiusKm: radiusKm.present ? radiusKm.value : this.radiusKm,
    createdAt: createdAt ?? this.createdAt,
  );
  SavedSearchTableData copyWithCompanion(SavedSearchTableCompanion data) {
    return SavedSearchTableData(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      city: data.city.present ? data.city.value : this.city,
      country: data.country.present ? data.country.value : this.country,
      minAge: data.minAge.present ? data.minAge.value : this.minAge,
      maxAge: data.maxAge.present ? data.maxAge.value : this.maxAge,
      gender: data.gender.present ? data.gender.value : this.gender,
      interests: data.interests.present ? data.interests.value : this.interests,
      lookingFor: data.lookingFor.present
          ? data.lookingFor.value
          : this.lookingFor,
      radiusKm: data.radiusKm.present ? data.radiusKm.value : this.radiusKm,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedSearchTableData(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('city: $city, ')
          ..write('country: $country, ')
          ..write('minAge: $minAge, ')
          ..write('maxAge: $maxAge, ')
          ..write('gender: $gender, ')
          ..write('interests: $interests, ')
          ..write('lookingFor: $lookingFor, ')
          ..write('radiusKm: $radiusKm, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    city,
    country,
    minAge,
    maxAge,
    gender,
    interests,
    lookingFor,
    radiusKm,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedSearchTableData &&
          other.id == this.id &&
          other.label == this.label &&
          other.city == this.city &&
          other.country == this.country &&
          other.minAge == this.minAge &&
          other.maxAge == this.maxAge &&
          other.gender == this.gender &&
          other.interests == this.interests &&
          other.lookingFor == this.lookingFor &&
          other.radiusKm == this.radiusKm &&
          other.createdAt == this.createdAt);
}

class SavedSearchTableCompanion extends UpdateCompanion<SavedSearchTableData> {
  final Value<int> id;
  final Value<String?> label;
  final Value<String?> city;
  final Value<String?> country;
  final Value<int?> minAge;
  final Value<int?> maxAge;
  final Value<String?> gender;
  final Value<List<String>?> interests;
  final Value<String?> lookingFor;
  final Value<double?> radiusKm;
  final Value<DateTime> createdAt;
  const SavedSearchTableCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.city = const Value.absent(),
    this.country = const Value.absent(),
    this.minAge = const Value.absent(),
    this.maxAge = const Value.absent(),
    this.gender = const Value.absent(),
    this.interests = const Value.absent(),
    this.lookingFor = const Value.absent(),
    this.radiusKm = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SavedSearchTableCompanion.insert({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.city = const Value.absent(),
    this.country = const Value.absent(),
    this.minAge = const Value.absent(),
    this.maxAge = const Value.absent(),
    this.gender = const Value.absent(),
    this.interests = const Value.absent(),
    this.lookingFor = const Value.absent(),
    this.radiusKm = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  static Insertable<SavedSearchTableData> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? city,
    Expression<String>? country,
    Expression<int>? minAge,
    Expression<int>? maxAge,
    Expression<String>? gender,
    Expression<String>? interests,
    Expression<String>? lookingFor,
    Expression<double>? radiusKm,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (minAge != null) 'min_age': minAge,
      if (maxAge != null) 'max_age': maxAge,
      if (gender != null) 'gender': gender,
      if (interests != null) 'interests': interests,
      if (lookingFor != null) 'looking_for': lookingFor,
      if (radiusKm != null) 'radius_km': radiusKm,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SavedSearchTableCompanion copyWith({
    Value<int>? id,
    Value<String?>? label,
    Value<String?>? city,
    Value<String?>? country,
    Value<int?>? minAge,
    Value<int?>? maxAge,
    Value<String?>? gender,
    Value<List<String>?>? interests,
    Value<String?>? lookingFor,
    Value<double?>? radiusKm,
    Value<DateTime>? createdAt,
  }) {
    return SavedSearchTableCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      city: city ?? this.city,
      country: country ?? this.country,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      lookingFor: lookingFor ?? this.lookingFor,
      radiusKm: radiusKm ?? this.radiusKm,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (minAge.present) {
      map['min_age'] = Variable<int>(minAge.value);
    }
    if (maxAge.present) {
      map['max_age'] = Variable<int>(maxAge.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (interests.present) {
      map['interests'] = Variable<String>(
        $SavedSearchTableTable.$converterinterestsn.toSql(interests.value),
      );
    }
    if (lookingFor.present) {
      map['looking_for'] = Variable<String>(lookingFor.value);
    }
    if (radiusKm.present) {
      map['radius_km'] = Variable<double>(radiusKm.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedSearchTableCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('city: $city, ')
          ..write('country: $country, ')
          ..write('minAge: $minAge, ')
          ..write('maxAge: $maxAge, ')
          ..write('gender: $gender, ')
          ..write('interests: $interests, ')
          ..write('lookingFor: $lookingFor, ')
          ..write('radiusKm: $radiusKm, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTableTable extends AppSettingsTable
    with TableInfo<$AppSettingsTableTable, AppSettingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
    'locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('el'),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _biometricLockEnabledMeta =
      const VerificationMeta('biometricLockEnabled');
  @override
  late final GeneratedColumn<bool> biometricLockEnabled = GeneratedColumn<bool>(
    'biometric_lock_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("biometric_lock_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _screenshotPreventionEnabledMeta =
      const VerificationMeta('screenshotPreventionEnabled');
  @override
  late final GeneratedColumn<bool> screenshotPreventionEnabled =
      GeneratedColumn<bool>(
        'screenshot_prevention_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("screenshot_prevention_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _autoLockMinutesMeta = const VerificationMeta(
    'autoLockMinutes',
  );
  @override
  late final GeneratedColumn<int> autoLockMinutes = GeneratedColumn<int>(
    'auto_lock_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    locale,
    themeMode,
    notificationsEnabled,
    biometricLockEnabled,
    screenshotPreventionEnabled,
    autoLockMinutes,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('locale')) {
      context.handle(
        _localeMeta,
        locale.isAcceptableOrUnknown(data['locale']!, _localeMeta),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('biometric_lock_enabled')) {
      context.handle(
        _biometricLockEnabledMeta,
        biometricLockEnabled.isAcceptableOrUnknown(
          data['biometric_lock_enabled']!,
          _biometricLockEnabledMeta,
        ),
      );
    }
    if (data.containsKey('screenshot_prevention_enabled')) {
      context.handle(
        _screenshotPreventionEnabledMeta,
        screenshotPreventionEnabled.isAcceptableOrUnknown(
          data['screenshot_prevention_enabled']!,
          _screenshotPreventionEnabledMeta,
        ),
      );
    }
    if (data.containsKey('auto_lock_minutes')) {
      context.handle(
        _autoLockMinutesMeta,
        autoLockMinutes.isAcceptableOrUnknown(
          data['auto_lock_minutes']!,
          _autoLockMinutesMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      locale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      biometricLockEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}biometric_lock_enabled'],
      )!,
      screenshotPreventionEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}screenshot_prevention_enabled'],
      )!,
      autoLockMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_lock_minutes'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTableTable createAlias(String alias) {
    return $AppSettingsTableTable(attachedDatabase, alias);
  }
}

class AppSettingsTableData extends DataClass
    implements Insertable<AppSettingsTableData> {
  final int id;
  final String locale;
  final String themeMode;
  final bool notificationsEnabled;
  final bool biometricLockEnabled;
  final bool screenshotPreventionEnabled;
  final int autoLockMinutes;
  final DateTime updatedAt;
  const AppSettingsTableData({
    required this.id,
    required this.locale,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.biometricLockEnabled,
    required this.screenshotPreventionEnabled,
    required this.autoLockMinutes,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['locale'] = Variable<String>(locale);
    map['theme_mode'] = Variable<String>(themeMode);
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    map['biometric_lock_enabled'] = Variable<bool>(biometricLockEnabled);
    map['screenshot_prevention_enabled'] = Variable<bool>(
      screenshotPreventionEnabled,
    );
    map['auto_lock_minutes'] = Variable<int>(autoLockMinutes);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsTableCompanion(
      id: Value(id),
      locale: Value(locale),
      themeMode: Value(themeMode),
      notificationsEnabled: Value(notificationsEnabled),
      biometricLockEnabled: Value(biometricLockEnabled),
      screenshotPreventionEnabled: Value(screenshotPreventionEnabled),
      autoLockMinutes: Value(autoLockMinutes),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsTableData(
      id: serializer.fromJson<int>(json['id']),
      locale: serializer.fromJson<String>(json['locale']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notificationsEnabled'],
      ),
      biometricLockEnabled: serializer.fromJson<bool>(
        json['biometricLockEnabled'],
      ),
      screenshotPreventionEnabled: serializer.fromJson<bool>(
        json['screenshotPreventionEnabled'],
      ),
      autoLockMinutes: serializer.fromJson<int>(json['autoLockMinutes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'locale': serializer.toJson<String>(locale),
      'themeMode': serializer.toJson<String>(themeMode),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'biometricLockEnabled': serializer.toJson<bool>(biometricLockEnabled),
      'screenshotPreventionEnabled': serializer.toJson<bool>(
        screenshotPreventionEnabled,
      ),
      'autoLockMinutes': serializer.toJson<int>(autoLockMinutes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSettingsTableData copyWith({
    int? id,
    String? locale,
    String? themeMode,
    bool? notificationsEnabled,
    bool? biometricLockEnabled,
    bool? screenshotPreventionEnabled,
    int? autoLockMinutes,
    DateTime? updatedAt,
  }) => AppSettingsTableData(
    id: id ?? this.id,
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
    screenshotPreventionEnabled:
        screenshotPreventionEnabled ?? this.screenshotPreventionEnabled,
    autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSettingsTableData copyWithCompanion(AppSettingsTableCompanion data) {
    return AppSettingsTableData(
      id: data.id.present ? data.id.value : this.id,
      locale: data.locale.present ? data.locale.value : this.locale,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      biometricLockEnabled: data.biometricLockEnabled.present
          ? data.biometricLockEnabled.value
          : this.biometricLockEnabled,
      screenshotPreventionEnabled: data.screenshotPreventionEnabled.present
          ? data.screenshotPreventionEnabled.value
          : this.screenshotPreventionEnabled,
      autoLockMinutes: data.autoLockMinutes.present
          ? data.autoLockMinutes.value
          : this.autoLockMinutes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableData(')
          ..write('id: $id, ')
          ..write('locale: $locale, ')
          ..write('themeMode: $themeMode, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('biometricLockEnabled: $biometricLockEnabled, ')
          ..write('screenshotPreventionEnabled: $screenshotPreventionEnabled, ')
          ..write('autoLockMinutes: $autoLockMinutes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    locale,
    themeMode,
    notificationsEnabled,
    biometricLockEnabled,
    screenshotPreventionEnabled,
    autoLockMinutes,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsTableData &&
          other.id == this.id &&
          other.locale == this.locale &&
          other.themeMode == this.themeMode &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.biometricLockEnabled == this.biometricLockEnabled &&
          other.screenshotPreventionEnabled ==
              this.screenshotPreventionEnabled &&
          other.autoLockMinutes == this.autoLockMinutes &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsTableCompanion extends UpdateCompanion<AppSettingsTableData> {
  final Value<int> id;
  final Value<String> locale;
  final Value<String> themeMode;
  final Value<bool> notificationsEnabled;
  final Value<bool> biometricLockEnabled;
  final Value<bool> screenshotPreventionEnabled;
  final Value<int> autoLockMinutes;
  final Value<DateTime> updatedAt;
  const AppSettingsTableCompanion({
    this.id = const Value.absent(),
    this.locale = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.biometricLockEnabled = const Value.absent(),
    this.screenshotPreventionEnabled = const Value.absent(),
    this.autoLockMinutes = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AppSettingsTableCompanion.insert({
    this.id = const Value.absent(),
    this.locale = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.biometricLockEnabled = const Value.absent(),
    this.screenshotPreventionEnabled = const Value.absent(),
    this.autoLockMinutes = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<AppSettingsTableData> custom({
    Expression<int>? id,
    Expression<String>? locale,
    Expression<String>? themeMode,
    Expression<bool>? notificationsEnabled,
    Expression<bool>? biometricLockEnabled,
    Expression<bool>? screenshotPreventionEnabled,
    Expression<int>? autoLockMinutes,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (locale != null) 'locale': locale,
      if (themeMode != null) 'theme_mode': themeMode,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (biometricLockEnabled != null)
        'biometric_lock_enabled': biometricLockEnabled,
      if (screenshotPreventionEnabled != null)
        'screenshot_prevention_enabled': screenshotPreventionEnabled,
      if (autoLockMinutes != null) 'auto_lock_minutes': autoLockMinutes,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AppSettingsTableCompanion copyWith({
    Value<int>? id,
    Value<String>? locale,
    Value<String>? themeMode,
    Value<bool>? notificationsEnabled,
    Value<bool>? biometricLockEnabled,
    Value<bool>? screenshotPreventionEnabled,
    Value<int>? autoLockMinutes,
    Value<DateTime>? updatedAt,
  }) {
    return AppSettingsTableCompanion(
      id: id ?? this.id,
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      screenshotPreventionEnabled:
          screenshotPreventionEnabled ?? this.screenshotPreventionEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (biometricLockEnabled.present) {
      map['biometric_lock_enabled'] = Variable<bool>(
        biometricLockEnabled.value,
      );
    }
    if (screenshotPreventionEnabled.present) {
      map['screenshot_prevention_enabled'] = Variable<bool>(
        screenshotPreventionEnabled.value,
      );
    }
    if (autoLockMinutes.present) {
      map['auto_lock_minutes'] = Variable<int>(autoLockMinutes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('locale: $locale, ')
          ..write('themeMode: $themeMode, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('biometricLockEnabled: $biometricLockEnabled, ')
          ..write('screenshotPreventionEnabled: $screenshotPreventionEnabled, ')
          ..write('autoLockMinutes: $autoLockMinutes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BlockedUserTableTable extends BlockedUserTable
    with TableInfo<$BlockedUserTableTable, BlockedUserTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlockedUserTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _blockedUidMeta = const VerificationMeta(
    'blockedUid',
  );
  @override
  late final GeneratedColumn<String> blockedUid = GeneratedColumn<String>(
    'blocked_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _blockedAtMeta = const VerificationMeta(
    'blockedAt',
  );
  @override
  late final GeneratedColumn<DateTime> blockedAt = GeneratedColumn<DateTime>(
    'blocked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    blockedUid,
    blockedAt,
    reason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocked_user_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockedUserTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    if (data.containsKey('blocked_uid')) {
      context.handle(
        _blockedUidMeta,
        blockedUid.isAcceptableOrUnknown(data['blocked_uid']!, _blockedUidMeta),
      );
    }
    if (data.containsKey('blocked_at')) {
      context.handle(
        _blockedAtMeta,
        blockedAt.isAcceptableOrUnknown(data['blocked_at']!, _blockedAtMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {uid, blockedUid},
  ];
  @override
  BlockedUserTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockedUserTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      blockedUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blocked_uid'],
      )!,
      blockedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}blocked_at'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
    );
  }

  @override
  $BlockedUserTableTable createAlias(String alias) {
    return $BlockedUserTableTable(attachedDatabase, alias);
  }
}

class BlockedUserTableData extends DataClass
    implements Insertable<BlockedUserTableData> {
  final int id;
  final String uid;
  final String blockedUid;
  final DateTime blockedAt;
  final String? reason;
  const BlockedUserTableData({
    required this.id,
    required this.uid,
    required this.blockedUid,
    required this.blockedAt,
    this.reason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uid'] = Variable<String>(uid);
    map['blocked_uid'] = Variable<String>(blockedUid);
    map['blocked_at'] = Variable<DateTime>(blockedAt);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    return map;
  }

  BlockedUserTableCompanion toCompanion(bool nullToAbsent) {
    return BlockedUserTableCompanion(
      id: Value(id),
      uid: Value(uid),
      blockedUid: Value(blockedUid),
      blockedAt: Value(blockedAt),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
    );
  }

  factory BlockedUserTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockedUserTableData(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String>(json['uid']),
      blockedUid: serializer.fromJson<String>(json['blockedUid']),
      blockedAt: serializer.fromJson<DateTime>(json['blockedAt']),
      reason: serializer.fromJson<String?>(json['reason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String>(uid),
      'blockedUid': serializer.toJson<String>(blockedUid),
      'blockedAt': serializer.toJson<DateTime>(blockedAt),
      'reason': serializer.toJson<String?>(reason),
    };
  }

  BlockedUserTableData copyWith({
    int? id,
    String? uid,
    String? blockedUid,
    DateTime? blockedAt,
    Value<String?> reason = const Value.absent(),
  }) => BlockedUserTableData(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    blockedUid: blockedUid ?? this.blockedUid,
    blockedAt: blockedAt ?? this.blockedAt,
    reason: reason.present ? reason.value : this.reason,
  );
  BlockedUserTableData copyWithCompanion(BlockedUserTableCompanion data) {
    return BlockedUserTableData(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      blockedUid: data.blockedUid.present
          ? data.blockedUid.value
          : this.blockedUid,
      blockedAt: data.blockedAt.present ? data.blockedAt.value : this.blockedAt,
      reason: data.reason.present ? data.reason.value : this.reason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockedUserTableData(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('blockedUid: $blockedUid, ')
          ..write('blockedAt: $blockedAt, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uid, blockedUid, blockedAt, reason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockedUserTableData &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.blockedUid == this.blockedUid &&
          other.blockedAt == this.blockedAt &&
          other.reason == this.reason);
}

class BlockedUserTableCompanion extends UpdateCompanion<BlockedUserTableData> {
  final Value<int> id;
  final Value<String> uid;
  final Value<String> blockedUid;
  final Value<DateTime> blockedAt;
  final Value<String?> reason;
  const BlockedUserTableCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.blockedUid = const Value.absent(),
    this.blockedAt = const Value.absent(),
    this.reason = const Value.absent(),
  });
  BlockedUserTableCompanion.insert({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.blockedUid = const Value.absent(),
    this.blockedAt = const Value.absent(),
    this.reason = const Value.absent(),
  });
  static Insertable<BlockedUserTableData> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<String>? blockedUid,
    Expression<DateTime>? blockedAt,
    Expression<String>? reason,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (blockedUid != null) 'blocked_uid': blockedUid,
      if (blockedAt != null) 'blocked_at': blockedAt,
      if (reason != null) 'reason': reason,
    });
  }

  BlockedUserTableCompanion copyWith({
    Value<int>? id,
    Value<String>? uid,
    Value<String>? blockedUid,
    Value<DateTime>? blockedAt,
    Value<String?>? reason,
  }) {
    return BlockedUserTableCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      blockedUid: blockedUid ?? this.blockedUid,
      blockedAt: blockedAt ?? this.blockedAt,
      reason: reason ?? this.reason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (blockedUid.present) {
      map['blocked_uid'] = Variable<String>(blockedUid.value);
    }
    if (blockedAt.present) {
      map['blocked_at'] = Variable<DateTime>(blockedAt.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlockedUserTableCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('blockedUid: $blockedUid, ')
          ..write('blockedAt: $blockedAt, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfileTableTable userProfileTable = $UserProfileTableTable(
    this,
  );
  late final $PrivacySettingsTableTable privacySettingsTable =
      $PrivacySettingsTableTable(this);
  late final $ConsentLogTableTable consentLogTable = $ConsentLogTableTable(
    this,
  );
  late final $ChatCacheTableTable chatCacheTable = $ChatCacheTableTable(this);
  late final $SavedSearchTableTable savedSearchTable = $SavedSearchTableTable(
    this,
  );
  late final $AppSettingsTableTable appSettingsTable = $AppSettingsTableTable(
    this,
  );
  late final $BlockedUserTableTable blockedUserTable = $BlockedUserTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfileTable,
    privacySettingsTable,
    consentLogTable,
    chatCacheTable,
    savedSearchTable,
    appSettingsTable,
    blockedUserTable,
  ];
}

typedef $$UserProfileTableTableCreateCompanionBuilder =
    UserProfileTableCompanion Function({
      Value<int> id,
      Value<String?> uid,
      Value<String?> nickname,
      Value<String?> fullName,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> bio,
      Value<int?> birthYear,
      Value<String?> gender,
      Value<List<String>?> interests,
      Value<List<String>?> occupations,
      Value<String?> lookingFor,
      Value<String?> city,
      Value<String?> country,
      Value<double?> latitudeExact,
      Value<double?> longitudeExact,
      Value<String?> manualLocationText,
      Value<String?> avatarUrl,
      Value<List<String>?> photoUrls,
      Value<bool> allowVideoCall,
      Value<bool> allowDirectChat,
      Value<bool> isPublished,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$UserProfileTableTableUpdateCompanionBuilder =
    UserProfileTableCompanion Function({
      Value<int> id,
      Value<String?> uid,
      Value<String?> nickname,
      Value<String?> fullName,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> bio,
      Value<int?> birthYear,
      Value<String?> gender,
      Value<List<String>?> interests,
      Value<List<String>?> occupations,
      Value<String?> lookingFor,
      Value<String?> city,
      Value<String?> country,
      Value<double?> latitudeExact,
      Value<double?> longitudeExact,
      Value<String?> manualLocationText,
      Value<String?> avatarUrl,
      Value<List<String>?> photoUrls,
      Value<bool> allowVideoCall,
      Value<bool> allowDirectChat,
      Value<bool> isPublished,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$UserProfileTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bio => $composableBuilder(
    column: $table.bio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get interests => $composableBuilder(
    column: $table.interests,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get occupations => $composableBuilder(
    column: $table.occupations,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get lookingFor => $composableBuilder(
    column: $table.lookingFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitudeExact => $composableBuilder(
    column: $table.latitudeExact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitudeExact => $composableBuilder(
    column: $table.longitudeExact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manualLocationText => $composableBuilder(
    column: $table.manualLocationText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get photoUrls => $composableBuilder(
    column: $table.photoUrls,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get allowVideoCall => $composableBuilder(
    column: $table.allowVideoCall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowDirectChat => $composableBuilder(
    column: $table.allowDirectChat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPublished => $composableBuilder(
    column: $table.isPublished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfileTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bio => $composableBuilder(
    column: $table.bio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interests => $composableBuilder(
    column: $table.interests,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occupations => $composableBuilder(
    column: $table.occupations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lookingFor => $composableBuilder(
    column: $table.lookingFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitudeExact => $composableBuilder(
    column: $table.latitudeExact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitudeExact => $composableBuilder(
    column: $table.longitudeExact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manualLocationText => $composableBuilder(
    column: $table.manualLocationText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrls => $composableBuilder(
    column: $table.photoUrls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowVideoCall => $composableBuilder(
    column: $table.allowVideoCall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowDirectChat => $composableBuilder(
    column: $table.allowDirectChat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPublished => $composableBuilder(
    column: $table.isPublished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfileTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get bio =>
      $composableBuilder(column: $table.bio, builder: (column) => column);

  GeneratedColumn<int> get birthYear =>
      $composableBuilder(column: $table.birthYear, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String> get interests =>
      $composableBuilder(column: $table.interests, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String> get occupations =>
      $composableBuilder(
        column: $table.occupations,
        builder: (column) => column,
      );

  GeneratedColumn<String> get lookingFor => $composableBuilder(
    column: $table.lookingFor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<double> get latitudeExact => $composableBuilder(
    column: $table.latitudeExact,
    builder: (column) => column,
  );

  GeneratedColumn<double> get longitudeExact => $composableBuilder(
    column: $table.longitudeExact,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manualLocationText => $composableBuilder(
    column: $table.manualLocationText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String> get photoUrls =>
      $composableBuilder(column: $table.photoUrls, builder: (column) => column);

  GeneratedColumn<bool> get allowVideoCall => $composableBuilder(
    column: $table.allowVideoCall,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowDirectChat => $composableBuilder(
    column: $table.allowDirectChat,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPublished => $composableBuilder(
    column: $table.isPublished,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProfileTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfileTableTable,
          UserProfileTableData,
          $$UserProfileTableTableFilterComposer,
          $$UserProfileTableTableOrderingComposer,
          $$UserProfileTableTableAnnotationComposer,
          $$UserProfileTableTableCreateCompanionBuilder,
          $$UserProfileTableTableUpdateCompanionBuilder,
          (
            UserProfileTableData,
            BaseReferences<
              _$AppDatabase,
              $UserProfileTableTable,
              UserProfileTableData
            >,
          ),
          UserProfileTableData,
          PrefetchHooks Function()
        > {
  $$UserProfileTableTableTableManager(
    _$AppDatabase db,
    $UserProfileTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<String?> fullName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> bio = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<List<String>?> interests = const Value.absent(),
                Value<List<String>?> occupations = const Value.absent(),
                Value<String?> lookingFor = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<double?> latitudeExact = const Value.absent(),
                Value<double?> longitudeExact = const Value.absent(),
                Value<String?> manualLocationText = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<List<String>?> photoUrls = const Value.absent(),
                Value<bool> allowVideoCall = const Value.absent(),
                Value<bool> allowDirectChat = const Value.absent(),
                Value<bool> isPublished = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserProfileTableCompanion(
                id: id,
                uid: uid,
                nickname: nickname,
                fullName: fullName,
                email: email,
                phone: phone,
                bio: bio,
                birthYear: birthYear,
                gender: gender,
                interests: interests,
                occupations: occupations,
                lookingFor: lookingFor,
                city: city,
                country: country,
                latitudeExact: latitudeExact,
                longitudeExact: longitudeExact,
                manualLocationText: manualLocationText,
                avatarUrl: avatarUrl,
                photoUrls: photoUrls,
                allowVideoCall: allowVideoCall,
                allowDirectChat: allowDirectChat,
                isPublished: isPublished,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<String?> fullName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> bio = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<List<String>?> interests = const Value.absent(),
                Value<List<String>?> occupations = const Value.absent(),
                Value<String?> lookingFor = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<double?> latitudeExact = const Value.absent(),
                Value<double?> longitudeExact = const Value.absent(),
                Value<String?> manualLocationText = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<List<String>?> photoUrls = const Value.absent(),
                Value<bool> allowVideoCall = const Value.absent(),
                Value<bool> allowDirectChat = const Value.absent(),
                Value<bool> isPublished = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserProfileTableCompanion.insert(
                id: id,
                uid: uid,
                nickname: nickname,
                fullName: fullName,
                email: email,
                phone: phone,
                bio: bio,
                birthYear: birthYear,
                gender: gender,
                interests: interests,
                occupations: occupations,
                lookingFor: lookingFor,
                city: city,
                country: country,
                latitudeExact: latitudeExact,
                longitudeExact: longitudeExact,
                manualLocationText: manualLocationText,
                avatarUrl: avatarUrl,
                photoUrls: photoUrls,
                allowVideoCall: allowVideoCall,
                allowDirectChat: allowDirectChat,
                isPublished: isPublished,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfileTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfileTableTable,
      UserProfileTableData,
      $$UserProfileTableTableFilterComposer,
      $$UserProfileTableTableOrderingComposer,
      $$UserProfileTableTableAnnotationComposer,
      $$UserProfileTableTableCreateCompanionBuilder,
      $$UserProfileTableTableUpdateCompanionBuilder,
      (
        UserProfileTableData,
        BaseReferences<
          _$AppDatabase,
          $UserProfileTableTable,
          UserProfileTableData
        >,
      ),
      UserProfileTableData,
      PrefetchHooks Function()
    >;
typedef $$PrivacySettingsTableTableCreateCompanionBuilder =
    PrivacySettingsTableCompanion Function({
      Value<int> id,
      Value<String?> uid,
      Value<bool> showNickname,
      Value<bool> showFullName,
      Value<bool> showAge,
      Value<bool> showGender,
      Value<bool> showCity,
      Value<bool> showExactLocation,
      Value<bool> showPhone,
      Value<bool> showEmail,
      Value<bool> showInterests,
      Value<bool> showOccupation,
      Value<bool> showBio,
      Value<bool> showLookingFor,
      Value<bool> allowVideoCall,
      Value<bool> allowDirectChat,
      Value<String> geoPrecision,
    });
typedef $$PrivacySettingsTableTableUpdateCompanionBuilder =
    PrivacySettingsTableCompanion Function({
      Value<int> id,
      Value<String?> uid,
      Value<bool> showNickname,
      Value<bool> showFullName,
      Value<bool> showAge,
      Value<bool> showGender,
      Value<bool> showCity,
      Value<bool> showExactLocation,
      Value<bool> showPhone,
      Value<bool> showEmail,
      Value<bool> showInterests,
      Value<bool> showOccupation,
      Value<bool> showBio,
      Value<bool> showLookingFor,
      Value<bool> allowVideoCall,
      Value<bool> allowDirectChat,
      Value<String> geoPrecision,
    });

class $$PrivacySettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PrivacySettingsTableTable> {
  $$PrivacySettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showNickname => $composableBuilder(
    column: $table.showNickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showFullName => $composableBuilder(
    column: $table.showFullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showAge => $composableBuilder(
    column: $table.showAge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showGender => $composableBuilder(
    column: $table.showGender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showCity => $composableBuilder(
    column: $table.showCity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showExactLocation => $composableBuilder(
    column: $table.showExactLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showPhone => $composableBuilder(
    column: $table.showPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showEmail => $composableBuilder(
    column: $table.showEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showInterests => $composableBuilder(
    column: $table.showInterests,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showOccupation => $composableBuilder(
    column: $table.showOccupation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showBio => $composableBuilder(
    column: $table.showBio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showLookingFor => $composableBuilder(
    column: $table.showLookingFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowVideoCall => $composableBuilder(
    column: $table.allowVideoCall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowDirectChat => $composableBuilder(
    column: $table.allowDirectChat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geoPrecision => $composableBuilder(
    column: $table.geoPrecision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrivacySettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PrivacySettingsTableTable> {
  $$PrivacySettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showNickname => $composableBuilder(
    column: $table.showNickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showFullName => $composableBuilder(
    column: $table.showFullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showAge => $composableBuilder(
    column: $table.showAge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showGender => $composableBuilder(
    column: $table.showGender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showCity => $composableBuilder(
    column: $table.showCity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showExactLocation => $composableBuilder(
    column: $table.showExactLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showPhone => $composableBuilder(
    column: $table.showPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showEmail => $composableBuilder(
    column: $table.showEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showInterests => $composableBuilder(
    column: $table.showInterests,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showOccupation => $composableBuilder(
    column: $table.showOccupation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showBio => $composableBuilder(
    column: $table.showBio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showLookingFor => $composableBuilder(
    column: $table.showLookingFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowVideoCall => $composableBuilder(
    column: $table.allowVideoCall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowDirectChat => $composableBuilder(
    column: $table.allowDirectChat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geoPrecision => $composableBuilder(
    column: $table.geoPrecision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrivacySettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrivacySettingsTableTable> {
  $$PrivacySettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<bool> get showNickname => $composableBuilder(
    column: $table.showNickname,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showFullName => $composableBuilder(
    column: $table.showFullName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showAge =>
      $composableBuilder(column: $table.showAge, builder: (column) => column);

  GeneratedColumn<bool> get showGender => $composableBuilder(
    column: $table.showGender,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showCity =>
      $composableBuilder(column: $table.showCity, builder: (column) => column);

  GeneratedColumn<bool> get showExactLocation => $composableBuilder(
    column: $table.showExactLocation,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showPhone =>
      $composableBuilder(column: $table.showPhone, builder: (column) => column);

  GeneratedColumn<bool> get showEmail =>
      $composableBuilder(column: $table.showEmail, builder: (column) => column);

  GeneratedColumn<bool> get showInterests => $composableBuilder(
    column: $table.showInterests,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showOccupation => $composableBuilder(
    column: $table.showOccupation,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showBio =>
      $composableBuilder(column: $table.showBio, builder: (column) => column);

  GeneratedColumn<bool> get showLookingFor => $composableBuilder(
    column: $table.showLookingFor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowVideoCall => $composableBuilder(
    column: $table.allowVideoCall,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowDirectChat => $composableBuilder(
    column: $table.allowDirectChat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get geoPrecision => $composableBuilder(
    column: $table.geoPrecision,
    builder: (column) => column,
  );
}

class $$PrivacySettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrivacySettingsTableTable,
          PrivacySettingsTableData,
          $$PrivacySettingsTableTableFilterComposer,
          $$PrivacySettingsTableTableOrderingComposer,
          $$PrivacySettingsTableTableAnnotationComposer,
          $$PrivacySettingsTableTableCreateCompanionBuilder,
          $$PrivacySettingsTableTableUpdateCompanionBuilder,
          (
            PrivacySettingsTableData,
            BaseReferences<
              _$AppDatabase,
              $PrivacySettingsTableTable,
              PrivacySettingsTableData
            >,
          ),
          PrivacySettingsTableData,
          PrefetchHooks Function()
        > {
  $$PrivacySettingsTableTableTableManager(
    _$AppDatabase db,
    $PrivacySettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrivacySettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrivacySettingsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PrivacySettingsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<bool> showNickname = const Value.absent(),
                Value<bool> showFullName = const Value.absent(),
                Value<bool> showAge = const Value.absent(),
                Value<bool> showGender = const Value.absent(),
                Value<bool> showCity = const Value.absent(),
                Value<bool> showExactLocation = const Value.absent(),
                Value<bool> showPhone = const Value.absent(),
                Value<bool> showEmail = const Value.absent(),
                Value<bool> showInterests = const Value.absent(),
                Value<bool> showOccupation = const Value.absent(),
                Value<bool> showBio = const Value.absent(),
                Value<bool> showLookingFor = const Value.absent(),
                Value<bool> allowVideoCall = const Value.absent(),
                Value<bool> allowDirectChat = const Value.absent(),
                Value<String> geoPrecision = const Value.absent(),
              }) => PrivacySettingsTableCompanion(
                id: id,
                uid: uid,
                showNickname: showNickname,
                showFullName: showFullName,
                showAge: showAge,
                showGender: showGender,
                showCity: showCity,
                showExactLocation: showExactLocation,
                showPhone: showPhone,
                showEmail: showEmail,
                showInterests: showInterests,
                showOccupation: showOccupation,
                showBio: showBio,
                showLookingFor: showLookingFor,
                allowVideoCall: allowVideoCall,
                allowDirectChat: allowDirectChat,
                geoPrecision: geoPrecision,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<bool> showNickname = const Value.absent(),
                Value<bool> showFullName = const Value.absent(),
                Value<bool> showAge = const Value.absent(),
                Value<bool> showGender = const Value.absent(),
                Value<bool> showCity = const Value.absent(),
                Value<bool> showExactLocation = const Value.absent(),
                Value<bool> showPhone = const Value.absent(),
                Value<bool> showEmail = const Value.absent(),
                Value<bool> showInterests = const Value.absent(),
                Value<bool> showOccupation = const Value.absent(),
                Value<bool> showBio = const Value.absent(),
                Value<bool> showLookingFor = const Value.absent(),
                Value<bool> allowVideoCall = const Value.absent(),
                Value<bool> allowDirectChat = const Value.absent(),
                Value<String> geoPrecision = const Value.absent(),
              }) => PrivacySettingsTableCompanion.insert(
                id: id,
                uid: uid,
                showNickname: showNickname,
                showFullName: showFullName,
                showAge: showAge,
                showGender: showGender,
                showCity: showCity,
                showExactLocation: showExactLocation,
                showPhone: showPhone,
                showEmail: showEmail,
                showInterests: showInterests,
                showOccupation: showOccupation,
                showBio: showBio,
                showLookingFor: showLookingFor,
                allowVideoCall: allowVideoCall,
                allowDirectChat: allowDirectChat,
                geoPrecision: geoPrecision,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrivacySettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrivacySettingsTableTable,
      PrivacySettingsTableData,
      $$PrivacySettingsTableTableFilterComposer,
      $$PrivacySettingsTableTableOrderingComposer,
      $$PrivacySettingsTableTableAnnotationComposer,
      $$PrivacySettingsTableTableCreateCompanionBuilder,
      $$PrivacySettingsTableTableUpdateCompanionBuilder,
      (
        PrivacySettingsTableData,
        BaseReferences<
          _$AppDatabase,
          $PrivacySettingsTableTable,
          PrivacySettingsTableData
        >,
      ),
      PrivacySettingsTableData,
      PrefetchHooks Function()
    >;
typedef $$ConsentLogTableTableCreateCompanionBuilder =
    ConsentLogTableCompanion Function({
      Value<int> id,
      Value<String?> uid,
      Value<String> action,
      Value<String> dataType,
      Value<String?> details,
      Value<DateTime> timestamp,
    });
typedef $$ConsentLogTableTableUpdateCompanionBuilder =
    ConsentLogTableCompanion Function({
      Value<int> id,
      Value<String?> uid,
      Value<String> action,
      Value<String> dataType,
      Value<String?> details,
      Value<DateTime> timestamp,
    });

class $$ConsentLogTableTableFilterComposer
    extends Composer<_$AppDatabase, $ConsentLogTableTable> {
  $$ConsentLogTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataType => $composableBuilder(
    column: $table.dataType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConsentLogTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ConsentLogTableTable> {
  $$ConsentLogTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataType => $composableBuilder(
    column: $table.dataType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConsentLogTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConsentLogTableTable> {
  $$ConsentLogTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get dataType =>
      $composableBuilder(column: $table.dataType, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$ConsentLogTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConsentLogTableTable,
          ConsentLogTableData,
          $$ConsentLogTableTableFilterComposer,
          $$ConsentLogTableTableOrderingComposer,
          $$ConsentLogTableTableAnnotationComposer,
          $$ConsentLogTableTableCreateCompanionBuilder,
          $$ConsentLogTableTableUpdateCompanionBuilder,
          (
            ConsentLogTableData,
            BaseReferences<
              _$AppDatabase,
              $ConsentLogTableTable,
              ConsentLogTableData
            >,
          ),
          ConsentLogTableData,
          PrefetchHooks Function()
        > {
  $$ConsentLogTableTableTableManager(
    _$AppDatabase db,
    $ConsentLogTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConsentLogTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConsentLogTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConsentLogTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> dataType = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => ConsentLogTableCompanion(
                id: id,
                uid: uid,
                action: action,
                dataType: dataType,
                details: details,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> dataType = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => ConsentLogTableCompanion.insert(
                id: id,
                uid: uid,
                action: action,
                dataType: dataType,
                details: details,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConsentLogTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConsentLogTableTable,
      ConsentLogTableData,
      $$ConsentLogTableTableFilterComposer,
      $$ConsentLogTableTableOrderingComposer,
      $$ConsentLogTableTableAnnotationComposer,
      $$ConsentLogTableTableCreateCompanionBuilder,
      $$ConsentLogTableTableUpdateCompanionBuilder,
      (
        ConsentLogTableData,
        BaseReferences<
          _$AppDatabase,
          $ConsentLogTableTable,
          ConsentLogTableData
        >,
      ),
      ConsentLogTableData,
      PrefetchHooks Function()
    >;
typedef $$ChatCacheTableTableCreateCompanionBuilder =
    ChatCacheTableCompanion Function({
      Value<int> id,
      Value<String?> chatId,
      Value<String?> otherUid,
      Value<String?> otherNickname,
      Value<String?> otherAvatarUrl,
      Value<DateTime?> lastMessageAt,
      Value<String?> lastMessage,
      Value<String?> lastMessageSender,
      Value<String?> lastMessageType,
      Value<int> unreadCount,
      Value<bool> hasUnread,
    });
typedef $$ChatCacheTableTableUpdateCompanionBuilder =
    ChatCacheTableCompanion Function({
      Value<int> id,
      Value<String?> chatId,
      Value<String?> otherUid,
      Value<String?> otherNickname,
      Value<String?> otherAvatarUrl,
      Value<DateTime?> lastMessageAt,
      Value<String?> lastMessage,
      Value<String?> lastMessageSender,
      Value<String?> lastMessageType,
      Value<int> unreadCount,
      Value<bool> hasUnread,
    });

class $$ChatCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChatCacheTableTable> {
  $$ChatCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherUid => $composableBuilder(
    column: $table.otherUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherNickname => $composableBuilder(
    column: $table.otherNickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherAvatarUrl => $composableBuilder(
    column: $table.otherAvatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageSender => $composableBuilder(
    column: $table.lastMessageSender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasUnread => $composableBuilder(
    column: $table.hasUnread,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatCacheTableTable> {
  $$ChatCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherUid => $composableBuilder(
    column: $table.otherUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherNickname => $composableBuilder(
    column: $table.otherNickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherAvatarUrl => $composableBuilder(
    column: $table.otherAvatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageSender => $composableBuilder(
    column: $table.lastMessageSender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasUnread => $composableBuilder(
    column: $table.hasUnread,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatCacheTableTable> {
  $$ChatCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get otherUid =>
      $composableBuilder(column: $table.otherUid, builder: (column) => column);

  GeneratedColumn<String> get otherNickname => $composableBuilder(
    column: $table.otherNickname,
    builder: (column) => column,
  );

  GeneratedColumn<String> get otherAvatarUrl => $composableBuilder(
    column: $table.otherAvatarUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageSender => $composableBuilder(
    column: $table.lastMessageSender,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasUnread =>
      $composableBuilder(column: $table.hasUnread, builder: (column) => column);
}

class $$ChatCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatCacheTableTable,
          ChatCacheTableData,
          $$ChatCacheTableTableFilterComposer,
          $$ChatCacheTableTableOrderingComposer,
          $$ChatCacheTableTableAnnotationComposer,
          $$ChatCacheTableTableCreateCompanionBuilder,
          $$ChatCacheTableTableUpdateCompanionBuilder,
          (
            ChatCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $ChatCacheTableTable,
              ChatCacheTableData
            >,
          ),
          ChatCacheTableData,
          PrefetchHooks Function()
        > {
  $$ChatCacheTableTableTableManager(
    _$AppDatabase db,
    $ChatCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> chatId = const Value.absent(),
                Value<String?> otherUid = const Value.absent(),
                Value<String?> otherNickname = const Value.absent(),
                Value<String?> otherAvatarUrl = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<String?> lastMessage = const Value.absent(),
                Value<String?> lastMessageSender = const Value.absent(),
                Value<String?> lastMessageType = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<bool> hasUnread = const Value.absent(),
              }) => ChatCacheTableCompanion(
                id: id,
                chatId: chatId,
                otherUid: otherUid,
                otherNickname: otherNickname,
                otherAvatarUrl: otherAvatarUrl,
                lastMessageAt: lastMessageAt,
                lastMessage: lastMessage,
                lastMessageSender: lastMessageSender,
                lastMessageType: lastMessageType,
                unreadCount: unreadCount,
                hasUnread: hasUnread,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> chatId = const Value.absent(),
                Value<String?> otherUid = const Value.absent(),
                Value<String?> otherNickname = const Value.absent(),
                Value<String?> otherAvatarUrl = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<String?> lastMessage = const Value.absent(),
                Value<String?> lastMessageSender = const Value.absent(),
                Value<String?> lastMessageType = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<bool> hasUnread = const Value.absent(),
              }) => ChatCacheTableCompanion.insert(
                id: id,
                chatId: chatId,
                otherUid: otherUid,
                otherNickname: otherNickname,
                otherAvatarUrl: otherAvatarUrl,
                lastMessageAt: lastMessageAt,
                lastMessage: lastMessage,
                lastMessageSender: lastMessageSender,
                lastMessageType: lastMessageType,
                unreadCount: unreadCount,
                hasUnread: hasUnread,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatCacheTableTable,
      ChatCacheTableData,
      $$ChatCacheTableTableFilterComposer,
      $$ChatCacheTableTableOrderingComposer,
      $$ChatCacheTableTableAnnotationComposer,
      $$ChatCacheTableTableCreateCompanionBuilder,
      $$ChatCacheTableTableUpdateCompanionBuilder,
      (
        ChatCacheTableData,
        BaseReferences<_$AppDatabase, $ChatCacheTableTable, ChatCacheTableData>,
      ),
      ChatCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$SavedSearchTableTableCreateCompanionBuilder =
    SavedSearchTableCompanion Function({
      Value<int> id,
      Value<String?> label,
      Value<String?> city,
      Value<String?> country,
      Value<int?> minAge,
      Value<int?> maxAge,
      Value<String?> gender,
      Value<List<String>?> interests,
      Value<String?> lookingFor,
      Value<double?> radiusKm,
      Value<DateTime> createdAt,
    });
typedef $$SavedSearchTableTableUpdateCompanionBuilder =
    SavedSearchTableCompanion Function({
      Value<int> id,
      Value<String?> label,
      Value<String?> city,
      Value<String?> country,
      Value<int?> minAge,
      Value<int?> maxAge,
      Value<String?> gender,
      Value<List<String>?> interests,
      Value<String?> lookingFor,
      Value<double?> radiusKm,
      Value<DateTime> createdAt,
    });

class $$SavedSearchTableTableFilterComposer
    extends Composer<_$AppDatabase, $SavedSearchTableTable> {
  $$SavedSearchTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minAge => $composableBuilder(
    column: $table.minAge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxAge => $composableBuilder(
    column: $table.maxAge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get interests => $composableBuilder(
    column: $table.interests,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get lookingFor => $composableBuilder(
    column: $table.lookingFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get radiusKm => $composableBuilder(
    column: $table.radiusKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedSearchTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedSearchTableTable> {
  $$SavedSearchTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minAge => $composableBuilder(
    column: $table.minAge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxAge => $composableBuilder(
    column: $table.maxAge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interests => $composableBuilder(
    column: $table.interests,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lookingFor => $composableBuilder(
    column: $table.lookingFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get radiusKm => $composableBuilder(
    column: $table.radiusKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedSearchTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedSearchTableTable> {
  $$SavedSearchTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<int> get minAge =>
      $composableBuilder(column: $table.minAge, builder: (column) => column);

  GeneratedColumn<int> get maxAge =>
      $composableBuilder(column: $table.maxAge, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String> get interests =>
      $composableBuilder(column: $table.interests, builder: (column) => column);

  GeneratedColumn<String> get lookingFor => $composableBuilder(
    column: $table.lookingFor,
    builder: (column) => column,
  );

  GeneratedColumn<double> get radiusKm =>
      $composableBuilder(column: $table.radiusKm, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SavedSearchTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedSearchTableTable,
          SavedSearchTableData,
          $$SavedSearchTableTableFilterComposer,
          $$SavedSearchTableTableOrderingComposer,
          $$SavedSearchTableTableAnnotationComposer,
          $$SavedSearchTableTableCreateCompanionBuilder,
          $$SavedSearchTableTableUpdateCompanionBuilder,
          (
            SavedSearchTableData,
            BaseReferences<
              _$AppDatabase,
              $SavedSearchTableTable,
              SavedSearchTableData
            >,
          ),
          SavedSearchTableData,
          PrefetchHooks Function()
        > {
  $$SavedSearchTableTableTableManager(
    _$AppDatabase db,
    $SavedSearchTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedSearchTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedSearchTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedSearchTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<int?> minAge = const Value.absent(),
                Value<int?> maxAge = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<List<String>?> interests = const Value.absent(),
                Value<String?> lookingFor = const Value.absent(),
                Value<double?> radiusKm = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SavedSearchTableCompanion(
                id: id,
                label: label,
                city: city,
                country: country,
                minAge: minAge,
                maxAge: maxAge,
                gender: gender,
                interests: interests,
                lookingFor: lookingFor,
                radiusKm: radiusKm,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<int?> minAge = const Value.absent(),
                Value<int?> maxAge = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<List<String>?> interests = const Value.absent(),
                Value<String?> lookingFor = const Value.absent(),
                Value<double?> radiusKm = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SavedSearchTableCompanion.insert(
                id: id,
                label: label,
                city: city,
                country: country,
                minAge: minAge,
                maxAge: maxAge,
                gender: gender,
                interests: interests,
                lookingFor: lookingFor,
                radiusKm: radiusKm,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedSearchTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedSearchTableTable,
      SavedSearchTableData,
      $$SavedSearchTableTableFilterComposer,
      $$SavedSearchTableTableOrderingComposer,
      $$SavedSearchTableTableAnnotationComposer,
      $$SavedSearchTableTableCreateCompanionBuilder,
      $$SavedSearchTableTableUpdateCompanionBuilder,
      (
        SavedSearchTableData,
        BaseReferences<
          _$AppDatabase,
          $SavedSearchTableTable,
          SavedSearchTableData
        >,
      ),
      SavedSearchTableData,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableTableCreateCompanionBuilder =
    AppSettingsTableCompanion Function({
      Value<int> id,
      Value<String> locale,
      Value<String> themeMode,
      Value<bool> notificationsEnabled,
      Value<bool> biometricLockEnabled,
      Value<bool> screenshotPreventionEnabled,
      Value<int> autoLockMinutes,
      Value<DateTime> updatedAt,
    });
typedef $$AppSettingsTableTableUpdateCompanionBuilder =
    AppSettingsTableCompanion Function({
      Value<int> id,
      Value<String> locale,
      Value<String> themeMode,
      Value<bool> notificationsEnabled,
      Value<bool> biometricLockEnabled,
      Value<bool> screenshotPreventionEnabled,
      Value<int> autoLockMinutes,
      Value<DateTime> updatedAt,
    });

class $$AppSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get biometricLockEnabled => $composableBuilder(
    column: $table.biometricLockEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get screenshotPreventionEnabled => $composableBuilder(
    column: $table.screenshotPreventionEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoLockMinutes => $composableBuilder(
    column: $table.autoLockMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get biometricLockEnabled => $composableBuilder(
    column: $table.biometricLockEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get screenshotPreventionEnabled => $composableBuilder(
    column: $table.screenshotPreventionEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoLockMinutes => $composableBuilder(
    column: $table.autoLockMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get biometricLockEnabled => $composableBuilder(
    column: $table.biometricLockEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get screenshotPreventionEnabled => $composableBuilder(
    column: $table.screenshotPreventionEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoLockMinutes => $composableBuilder(
    column: $table.autoLockMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTableTable,
          AppSettingsTableData,
          $$AppSettingsTableTableFilterComposer,
          $$AppSettingsTableTableOrderingComposer,
          $$AppSettingsTableTableAnnotationComposer,
          $$AppSettingsTableTableCreateCompanionBuilder,
          $$AppSettingsTableTableUpdateCompanionBuilder,
          (
            AppSettingsTableData,
            BaseReferences<
              _$AppDatabase,
              $AppSettingsTableTable,
              AppSettingsTableData
            >,
          ),
          AppSettingsTableData,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableTableManager(
    _$AppDatabase db,
    $AppSettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<bool> biometricLockEnabled = const Value.absent(),
                Value<bool> screenshotPreventionEnabled = const Value.absent(),
                Value<int> autoLockMinutes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AppSettingsTableCompanion(
                id: id,
                locale: locale,
                themeMode: themeMode,
                notificationsEnabled: notificationsEnabled,
                biometricLockEnabled: biometricLockEnabled,
                screenshotPreventionEnabled: screenshotPreventionEnabled,
                autoLockMinutes: autoLockMinutes,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<bool> biometricLockEnabled = const Value.absent(),
                Value<bool> screenshotPreventionEnabled = const Value.absent(),
                Value<int> autoLockMinutes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AppSettingsTableCompanion.insert(
                id: id,
                locale: locale,
                themeMode: themeMode,
                notificationsEnabled: notificationsEnabled,
                biometricLockEnabled: biometricLockEnabled,
                screenshotPreventionEnabled: screenshotPreventionEnabled,
                autoLockMinutes: autoLockMinutes,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTableTable,
      AppSettingsTableData,
      $$AppSettingsTableTableFilterComposer,
      $$AppSettingsTableTableOrderingComposer,
      $$AppSettingsTableTableAnnotationComposer,
      $$AppSettingsTableTableCreateCompanionBuilder,
      $$AppSettingsTableTableUpdateCompanionBuilder,
      (
        AppSettingsTableData,
        BaseReferences<
          _$AppDatabase,
          $AppSettingsTableTable,
          AppSettingsTableData
        >,
      ),
      AppSettingsTableData,
      PrefetchHooks Function()
    >;
typedef $$BlockedUserTableTableCreateCompanionBuilder =
    BlockedUserTableCompanion Function({
      Value<int> id,
      Value<String> uid,
      Value<String> blockedUid,
      Value<DateTime> blockedAt,
      Value<String?> reason,
    });
typedef $$BlockedUserTableTableUpdateCompanionBuilder =
    BlockedUserTableCompanion Function({
      Value<int> id,
      Value<String> uid,
      Value<String> blockedUid,
      Value<DateTime> blockedAt,
      Value<String?> reason,
    });

class $$BlockedUserTableTableFilterComposer
    extends Composer<_$AppDatabase, $BlockedUserTableTable> {
  $$BlockedUserTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockedUid => $composableBuilder(
    column: $table.blockedUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get blockedAt => $composableBuilder(
    column: $table.blockedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlockedUserTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BlockedUserTableTable> {
  $$BlockedUserTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockedUid => $composableBuilder(
    column: $table.blockedUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get blockedAt => $composableBuilder(
    column: $table.blockedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlockedUserTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlockedUserTableTable> {
  $$BlockedUserTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get blockedUid => $composableBuilder(
    column: $table.blockedUid,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get blockedAt =>
      $composableBuilder(column: $table.blockedAt, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);
}

class $$BlockedUserTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlockedUserTableTable,
          BlockedUserTableData,
          $$BlockedUserTableTableFilterComposer,
          $$BlockedUserTableTableOrderingComposer,
          $$BlockedUserTableTableAnnotationComposer,
          $$BlockedUserTableTableCreateCompanionBuilder,
          $$BlockedUserTableTableUpdateCompanionBuilder,
          (
            BlockedUserTableData,
            BaseReferences<
              _$AppDatabase,
              $BlockedUserTableTable,
              BlockedUserTableData
            >,
          ),
          BlockedUserTableData,
          PrefetchHooks Function()
        > {
  $$BlockedUserTableTableTableManager(
    _$AppDatabase db,
    $BlockedUserTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlockedUserTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlockedUserTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlockedUserTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> blockedUid = const Value.absent(),
                Value<DateTime> blockedAt = const Value.absent(),
                Value<String?> reason = const Value.absent(),
              }) => BlockedUserTableCompanion(
                id: id,
                uid: uid,
                blockedUid: blockedUid,
                blockedAt: blockedAt,
                reason: reason,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> blockedUid = const Value.absent(),
                Value<DateTime> blockedAt = const Value.absent(),
                Value<String?> reason = const Value.absent(),
              }) => BlockedUserTableCompanion.insert(
                id: id,
                uid: uid,
                blockedUid: blockedUid,
                blockedAt: blockedAt,
                reason: reason,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlockedUserTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlockedUserTableTable,
      BlockedUserTableData,
      $$BlockedUserTableTableFilterComposer,
      $$BlockedUserTableTableOrderingComposer,
      $$BlockedUserTableTableAnnotationComposer,
      $$BlockedUserTableTableCreateCompanionBuilder,
      $$BlockedUserTableTableUpdateCompanionBuilder,
      (
        BlockedUserTableData,
        BaseReferences<
          _$AppDatabase,
          $BlockedUserTableTable,
          BlockedUserTableData
        >,
      ),
      BlockedUserTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfileTableTableTableManager get userProfileTable =>
      $$UserProfileTableTableTableManager(_db, _db.userProfileTable);
  $$PrivacySettingsTableTableTableManager get privacySettingsTable =>
      $$PrivacySettingsTableTableTableManager(_db, _db.privacySettingsTable);
  $$ConsentLogTableTableTableManager get consentLogTable =>
      $$ConsentLogTableTableTableManager(_db, _db.consentLogTable);
  $$ChatCacheTableTableTableManager get chatCacheTable =>
      $$ChatCacheTableTableTableManager(_db, _db.chatCacheTable);
  $$SavedSearchTableTableTableManager get savedSearchTable =>
      $$SavedSearchTableTableTableManager(_db, _db.savedSearchTable);
  $$AppSettingsTableTableTableManager get appSettingsTable =>
      $$AppSettingsTableTableTableManager(_db, _db.appSettingsTable);
  $$BlockedUserTableTableTableManager get blockedUserTable =>
      $$BlockedUserTableTableTableManager(_db, _db.blockedUserTable);
}
