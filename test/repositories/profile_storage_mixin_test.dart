import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/data/remote/storage_service.dart';
import 'package:near_me/repositories/profile_storage_mixin.dart';

class MockStorage extends Mock implements StorageService {}
class MockStorageUser extends Mock implements User {}

MockStorageUser _emptyUser() {
  final u = MockStorageUser();
  when(() => u.uid).thenReturn('');
  return u;
}

class _Harness with ProfileStorageMixin {
  _Harness({
    required this.storage,
    User? Function()? storageUserProvider,
    required this.profile,
    required this.publishCalls,
    this.consentLogs,
    this.saveError,
  }) {
    storageOverride = storage;
    this.storageUserProvider = storageUserProvider ?? (() => null);
    consentLogger = consentLogs == null
        ? null
        : (uid, action, dataType) async {
            consentLogs!.add((uid, action, dataType));
          };
  }

final MockStorage storage;
  final UserProfileTableData? profile;
  final Object? saveError;
  final List<int> publishCalls;
  final List<(String, String, String)>? consentLogs;

  @override
  Future<UserProfileTableData?> getProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfileTableData p) async {
    final e = saveError;
    if (e != null) throw e;
  }

  @override
  Future<void> publish() async {
    publishCalls.add(1);
  }
}

const _bytes = [1, 2, 3, 4, 5];

Uint8List _jpeg() => Uint8List.fromList(_bytes);

/// Βοηθητικό: Φτιάχνει ένα UserProfileTableData με συμπλήρωση των required
/// πεδίων (companion μπορεί να έχει nullable) — βάζουμε ένα ελάχιστο.
UserProfileTableData _minProfile({
  String? avatarUrl,
  List<String>? photoUrls,
  List<String>? racy,
  bool published = false,
}) {
  return UserProfileTableData(
    id: 1,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    allowVideoCall: false,
    allowDirectChat: false,
    isPublished: published,
    avatarUrl: avatarUrl,
    avatarRacyLevel: null,
    photoUrls: photoUrls,
    photoRacyLevels: racy,
  );
}

void main() {
  late MockStorage storage;
  late MockStorageUser user;

  setUp(() {
    storage = MockStorage();
    user = MockStorageUser();
    when(() => user.uid).thenReturn('u_test');
  });

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  group('saveAvatar', () {
    test('no user → auth_required', () async {
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => _emptyUser(),
        profile: null,
        publishCalls: [],
      );
      await expectLater(
        h.saveAvatar(_jpeg()),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_required')),
      );
    });

    test('empty bytes → validation_error', () async {
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: null,
        publishCalls: [],
      );
      await expectLater(
        h.saveAvatar(Uint8List(0)),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('επιτυχία → upload + consent logger', () async {
      final logs = <(String, String, String)>[];
      when(() => storage.uploadAvatar('u_test', any()))
          .thenAnswer((_) async => (url: 'https://img', racyLevel: 'RACY'));
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: null,
        publishCalls: [],
        consentLogs: logs,
      );

      final url = await h.saveAvatar(_jpeg());
      expect(url, 'https://img');
      expect(logs, [( 'u_test', 'uploaded_photo', 'avatar')]);
    });

    test('upload throws → storage_error', () async {
      when(() => storage.uploadAvatar('u_test', any()))
          .thenThrow(Exception('boom'));
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: null,
        publishCalls: [],
      );
      await expectLater(
        h.saveAvatar(_jpeg()),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'storage_error')),
      );
    });

    test('save failure → rollback (deleteAvatar + restore)', () async {
      final profile = _minProfile(avatarUrl: 'old');
      when(() => storage.uploadAvatar('u_test', any()))
          .thenAnswer((_) async => (url: 'new', racyLevel: null));
      when(() => storage.deleteAvatar('u_test')).thenAnswer((_) async {});
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: profile,
        publishCalls: [],
        saveError: Exception('save failure'),
      );

      await expectLater(
        h.saveAvatar(_jpeg()),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'storage_error')),
      );
      // rollback: μετά την αποτυχία save, διαγράφεται το uploaded avatar
      verify(() => storage.deleteAvatar('u_test')).called(1);
    });
  });

  group('deleteAvatar', () {
    test('no user → no-op χωρίς throw', () async {
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => _emptyUser(),
        profile: null,
        publishCalls: [],
      );
      await h.deleteAvatar();
      verifyNever(() => storage.deleteAvatar('u_test'));
    });

    test('επιτυχία → deleteAvatar + publish (αν published)', () async {
      when(() => storage.deleteAvatar('u_test')).thenAnswer((_) async {});
      final profile = _minProfile(avatarUrl: 'old', published: true);
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: profile,
        publishCalls: [],
      );
      await h.deleteAvatar();
      verify(() => storage.deleteAvatar('u_test')).called(1);
      expect(h.publishCalls, hasLength(1));
    });
  });

  group('savePhoto', () {
    test('invalid index → validation_error', () async {
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: null,
        publishCalls: [],
      );
      await expectLater(
        h.savePhoto(_jpeg(), -1),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('empty bytes → validation_error', () async {
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: null,
        publishCalls: [],
      );
      await expectLater(
        h.savePhoto(Uint8List(0), 0),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('no user → auth_required', () async {
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => _emptyUser(),
        profile: null,
        publishCalls: [],
      );
      await expectLater(
        h.savePhoto(_jpeg(), 0),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_required')),
      );
    });

    test('επιτυχία → upload + consent', () async {
      final logs = <(String, String, String)>[];
      when(() => storage.uploadPhoto('u_test', 0, any()))
          .thenAnswer((_) async => (url: 'https://p0', racyLevel: null));
      final profile = _minProfile(photoUrls: []);
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: profile,
        publishCalls: [],
        consentLogs: logs,
      );

      final url = await h.savePhoto(_jpeg(), 0);
      expect(url, 'https://p0');
      expect(logs, [( 'u_test', 'uploaded_photo', 'photo')]);
    });

    test('upload throws → storage_error', () async {
      when(() => storage.uploadPhoto('u_test', 0, any()))
          .thenThrow(Exception('boom'));
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: null,
        publishCalls: [],
      );
      await expectLater(
        h.savePhoto(_jpeg(), 0),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'storage_error')),
      );
    });
  });

  group('deletePhoto', () {
    test('invalid index → no-op', () async {
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: _minProfile(),
        publishCalls: [],
      );
      await h.deletePhoto(-1);
      verifyNever(() => storage.deletePhoto('u_test', -1));
    });

    test('no user → no-op', () async {
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => _emptyUser(),
        profile: _minProfile(),
        publishCalls: [],
      );
      await h.deletePhoto(0);
      verifyNever(() => storage.deletePhoto('u_test', 0));
    });

    test('επιτυχία → deletePhoto + publish (αν published)', () async {
      when(() => storage.deletePhoto('u_test', 0)).thenAnswer((_) async {});
      final profile = _minProfile(photoUrls: ['a', 'b'], published: true);
      final h = _Harness(
        storage: storage,
        storageUserProvider: () => user,
        profile: profile,
        publishCalls: [],
      );
      await h.deletePhoto(0);
      verify(() => storage.deletePhoto('u_test', 0)).called(1);
      expect(h.publishCalls, hasLength(1));
    });
  });
}