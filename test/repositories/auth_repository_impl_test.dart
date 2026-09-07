import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/repositories/auth_repository.dart';
import 'package:near_me/repositories/auth_repository_impl.dart';
import 'package:drift/native.dart';

class MockAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockUserCredential extends Mock implements UserCredential {}
class MockPhoneAuthCredential extends Mock implements PhoneAuthCredential {}
class FakeCredential extends Fake implements AuthCredential {}

void main() {
  late MockAuth auth;
  late MockUser user;
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late AuthRepositoryImpl repo;

  const uid = 'u_test';

  setUpAll(() {
    registerFallbackValue(FakeCredential());
    registerFallbackValue(const Duration(seconds: 60));
  });

  setUp(() async {
    auth = MockAuth();
    user = MockUser();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    repo = AuthRepositoryImpl(auth, db: db, firestore: firestore);

    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn(uid);
    when(() => user.isAnonymous).thenReturn(false);
    when(() => user.emailVerified).thenReturn(false);
    when(() => user.phoneNumber).thenReturn(null);
  });

  tearDown(() async {
    await db.close();
  });

  group('canUserCommunicate', () {
    test('null → false', () {
      expect(AuthRepository.canUserCommunicate(null), isFalse);
    });

    test('anonymous → false', () {
      when(() => user.isAnonymous).thenReturn(true);
      expect(AuthRepository.canUserCommunicate(user), isFalse);
    });

    test('non-anon + emailVerified → true', () {
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.emailVerified).thenReturn(true);
      when(() => user.phoneNumber).thenReturn(null);
      expect(AuthRepository.canUserCommunicate(user), isTrue);
    });

    test('non-anon + phone → true (χωρίς email verify)', () {
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.emailVerified).thenReturn(false);
      when(() => user.phoneNumber).thenReturn('+306900000000');
      expect(AuthRepository.canUserCommunicate(user), isTrue);
    });

    test('non-anon + τίποτα → false', () {
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.emailVerified).thenReturn(false);
      when(() => user.phoneNumber).thenReturn(null);
      expect(AuthRepository.canUserCommunicate(user), isFalse);
    });
  });

  group('signInAnonymously / email sign-in / create', () {
    test('signInAnonymously → επιστρέφει user', () async {
      final cred = MockUserCredential();
      when(() => cred.user).thenReturn(user);
      when(() => auth.signInAnonymously()).thenAnswer((_) async => cred);

      final result = await repo.signInAnonymously();
      expect(result, same(user));
    });

    test('signInWithEmailAndPassword → επιστρέφει user', () async {
      final cred = MockUserCredential();
      when(() => cred.user).thenReturn(user);
      when(() => auth.signInWithEmailAndPassword(
              email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => cred);

      final result =
          await repo.signInWithEmailAndPassword('a@b.c', 'pass');
      expect(result, same(user));
    });

    test('createUserWithEmailAndPassword → επιστρέφει user', () async {
      final cred = MockUserCredential();
      when(() => cred.user).thenReturn(user);
      when(() => auth.createUserWithEmailAndPassword(
              email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => cred);

      final result =
          await repo.createUserWithEmailAndPassword('a@b.c', 'pass');
      expect(result, same(user));
    });
  });

  group('linkWithEmailAndPassword', () {
    test('no user → auth_error', () async {
      when(() => auth.currentUser).thenReturn(null);
      await expectLater(
        repo.linkWithEmailAndPassword('a@b.c', 'pass'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('επιτυχία → linkWithCredential καλείται', () async {
      when(() => user.linkWithCredential(any()))
          .thenAnswer((_) async => MockUserCredential());
      await repo.linkWithEmailAndPassword('a@b.c', 'pass');
      verify(() => user.linkWithCredential(any())).called(1);
    });
  });

  group('sendEmailVerification', () {
    test('no user → auth_error', () async {
      when(() => auth.currentUser).thenReturn(null);
      await expectLater(
        repo.sendEmailVerification(),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('επιτυχία → sendEmailVerification καλείται', () async {
      when(() => user.sendEmailVerification()).thenAnswer((_) async {});
      await repo.sendEmailVerification();
      verify(() => user.sendEmailVerification()).called(1);
    });
  });

  group('sendPasswordResetEmail', () {
    test('επιτυχία → sendPasswordResetEmail καλείται', () async {
      when(() => auth.sendPasswordResetEmail(email: any(named: 'email')))
          .thenAnswer((_) async {});
      await repo.sendPasswordResetEmail('a@b.c');
      verify(() => auth.sendPasswordResetEmail(email: 'a@b.c')).called(1);
    });
  });

  group('getters/streams', () {
    test('currentUser / isAnonymous / isEmailVerified / isPhoneVerified',
        () {
      when(() => user.isAnonymous).thenReturn(true);
      when(() => user.emailVerified).thenReturn(true);
      when(() => user.phoneNumber).thenReturn('+306900000000');

      expect(repo.currentUser, same(user));
      expect(repo.isAnonymous, isTrue);
      expect(repo.isEmailVerified, isTrue);
      expect(repo.isPhoneVerified, isTrue);
    });

    test('authStateChanges → stream emit user', () async {
      when(() => auth.authStateChanges())
          .thenAnswer((_) => Stream.value(user));
      final emitted = await repo.authStateChanges().first;
      expect(emitted, same(user));
    });

    test('reloadUser → reload καλείται', () async {
      when(() => user.reload()).thenAnswer((_) async {});
      await repo.reloadUser();
      verify(() => user.reload()).called(1);
    });
  });

  group('sendPhoneOtp', () {
    test('codeSent → επιστρέφει vId', () async {
      when(() => auth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            verificationCompleted: any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
            timeout: any(named: 'timeout'),
          )).thenAnswer((inv) async {
        (inv.namedArguments[#codeSent] as PhoneCodeSent)('vid123', 60);
      });

      final vId = await repo.sendPhoneOtp('+306900000000');
      expect(vId, 'vid123');
    });

    test('verificationCompleted (auto) → link + AUTO_VERIFIED', () async {
      when(() => user.linkWithCredential(any()))
          .thenAnswer((_) async => MockUserCredential());
      when(() => auth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            verificationCompleted: any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
            timeout: any(named: 'timeout'),
          )).thenAnswer((inv) async {
        (inv.namedArguments[#verificationCompleted]
            as PhoneVerificationCompleted)(MockPhoneAuthCredential());
      });

      final vId = await repo.sendPhoneOtp('+306900000000');
      expect(vId, 'AUTO_VERIFIED');
      verify(() => user.linkWithCredential(any())).called(1);
    });

    test('verificationFailed → mapped AppException', () async {
      when(() => auth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            verificationCompleted: any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
            timeout: any(named: 'timeout'),
          )).thenAnswer((inv) async {
        final failed =
            inv.namedArguments[#verificationFailed] as PhoneVerificationFailed;
        Future<void>.microtask(
          () => failed(FirebaseAuthException(code: 'invalid-phone-number')),
        );
      });

      try {
        await repo.sendPhoneOtp('+306900000000');
        fail('expected exception');
      } catch (e) {
        expect(e, isA<AppException>());
        expect((e as AppException).code, 'auth/invalid-phone');
      }
    });
  });

  group('verifyPhoneOtp', () {
    test('no user → auth_required', () async {
      when(() => auth.currentUser).thenReturn(null);
      await expectLater(
        repo.verifyPhoneOtp('vid', '1234'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_required')),
      );
    });

    test('επιτυχία → link + reload', () async {
      when(() => user.linkWithCredential(any()))
          .thenAnswer((_) async => MockUserCredential());
      when(() => user.reload()).thenAnswer((_) async {});
      await repo.verifyPhoneOtp('vid', '1234');
      verify(() => user.linkWithCredential(any())).called(1);
      verify(() => user.reload()).called(1);
    });

    test('λάθος → mapped auth_error', () async {
      when(() => user.linkWithCredential(any()))
          .thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));
      await expectLater(
        repo.verifyPhoneOtp('vid', 'xxxx'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth/invalid-code')),
      );
    });
  });

  group('unlinkPhone', () {
    test('no user → auth_error', () async {
      when(() => auth.currentUser).thenReturn(null);
      await expectLater(
        repo.unlinkPhone(),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('no-such-provider → treated as success', () async {
      when(() => user.unlink('phone'))
          .thenThrow(FirebaseAuthException(code: 'no-such-provider'));
      await repo.unlinkPhone();
      verify(() => user.unlink('phone')).called(1);
    });

    test('άλλο FirebaseAuthException → auth_error', () async {
      when(() => user.unlink('phone')).thenThrow(
          FirebaseAuthException(code: 'network-request-failed'));
      await expectLater(
        repo.unlinkPhone(),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'auth_error')),
      );
    });

    test('επιτυχία → unlinked + reload', () async {
      when(() => user.unlink('phone')).thenAnswer((_) async => MockUser());
      when(() => user.reload()).thenAnswer((_) async {});
      await repo.unlinkPhone();
      verify(() => user.unlink('phone')).called(1);
      verify(() => user.reload()).called(1);
    });
  });
}