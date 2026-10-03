import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/settings/utils/phone_unlink_cleanup.dart';
import 'package:near_me/repositories/profile_repository.dart';

/// Unit tests για `clearLocalPhone` (SPoT καθαρισμού μετά από unlink).
class _MockProfileRepository extends Mock implements ProfileRepository {}

UserProfileTableData _profile({String? phone, bool published = false}) =>
    UserProfileTableData(
      id: 0,
      uid: 'me',
      nickname: 'Nikos',
      bio: '',
      birthYear: 1990,
      gender: '',
      interests: const [],
      occupations: const [],
      lookingFor: '',
      city: '',
      country: '',
      avatarUrl: '',
      photoUrls: const [],
      allowVideoCall: false,
      allowDirectChat: false,
      isPublished: published,
      phone: phone,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_profile());
  });

  group('clearLocalPhone', () {
    test('null profile → no-op', () async {
      final repo = _MockProfileRepository();
      when(() => repo.getProfile()).thenAnswer((_) async => null);
      await clearLocalPhone(repo);
      verifyNever(() => repo.saveProfile(any()));
      verifyNever(() => repo.publish());
    });

    test('null phone → no-op', () async {
      final repo = _MockProfileRepository();
      when(() => repo.getProfile()).thenAnswer((_) async => _profile());
      await clearLocalPhone(repo);
      verifyNever(() => repo.saveProfile(any()));
    });

    test('empty phone → no-op', () async {
      final repo = _MockProfileRepository();
      when(() => repo.getProfile())
          .thenAnswer((_) async => _profile(phone: ''));
      await clearLocalPhone(repo);
      verifyNever(() => repo.saveProfile(any()));
    });

    test('phone + unpublished → save με null, χωρίς publish', () async {
      final repo = _MockProfileRepository();
      when(() => repo.getProfile())
          .thenAnswer((_) async => _profile(phone: '+301'));
      when(() => repo.saveProfile(any())).thenAnswer((_) async {});
      await clearLocalPhone(repo);
      final saved = verify(() => repo.saveProfile(captureAny())).captured.single
          as UserProfileTableData;
      expect(saved.phone, isNull);
      verifyNever(() => repo.publish());
    });

    test('phone + published → save + publish', () async {
      final repo = _MockProfileRepository();
      when(() => repo.getProfile())
          .thenAnswer((_) async => _profile(phone: '+301', published: true));
      when(() => repo.saveProfile(any())).thenAnswer((_) async {});
      when(() => repo.publish()).thenAnswer((_) async {});
      await clearLocalPhone(repo);
      verify(() => repo.saveProfile(any())).called(1);
      verify(() => repo.publish()).called(1);
    });

    test('save throw → διαδίδεται (πιάνει ο caller)', () async {
      final repo = _MockProfileRepository();
      when(() => repo.getProfile())
          .thenAnswer((_) async => _profile(phone: '+301'));
      when(() => repo.saveProfile(any())).thenThrow(Exception('db'));
      await expectLater(clearLocalPhone(repo), throwsException);
      verifyNever(() => repo.publish());
    });

    test('publish throw → διαδίδεται (πιάνει ο caller)', () async {
      final repo = _MockProfileRepository();
      when(() => repo.getProfile())
          .thenAnswer((_) async => _profile(phone: '+301', published: true));
      when(() => repo.saveProfile(any())).thenAnswer((_) async {});
      when(() => repo.publish()).thenThrow(Exception('net'));
      await expectLater(clearLocalPhone(repo), throwsException);
    });
  });
}
