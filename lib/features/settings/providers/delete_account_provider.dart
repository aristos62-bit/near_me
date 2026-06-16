import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../repositories/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

enum DeleteState { idle, loading, success, error, needsReauth }

class DeleteAccountState {
  final DeleteState status;
  final String? errorMessage;
  final String? email;
  const DeleteAccountState({this.status = DeleteState.idle, this.errorMessage, this.email});
}

class DeleteAccountNotifier extends Notifier<DeleteAccountState> {
  @override
  DeleteAccountState build() {
    DebugConfig.log(DebugConfig.providerCreate, 'DeleteAccountNotifier built');
    return const DeleteAccountState();
  }

  AuthRepository get _authRepo => ref.read(authRepositoryProvider);

  Future<void> delete() async {
    DebugConfig.log(DebugConfig.repositoryCall, 'deleteAccountNotifier.delete started');
    state = const DeleteAccountState(status: DeleteState.loading);
    try {
      await _authRepo.deleteAccount();
      DebugConfig.log(DebugConfig.repositoryResult, 'deleteAccountNotifier.delete success');
      state = const DeleteAccountState(status: DeleteState.success);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        final email = _authRepo.currentUser?.email;
        DebugConfig.warn('deleteAccount: needs reauth for $email');
        state = DeleteAccountState(status: DeleteState.needsReauth, email: email);
      } else {
        state = DeleteAccountState(status: DeleteState.error,
            errorMessage: 'Σφάλμα διαγραφής λογαριασμού / Account deletion error');
      }
    } catch (e, s) {
      DebugConfig.error('deleteAccountNotifier.delete failed', data: e, exception: s);
      state = DeleteAccountState(
        status: DeleteState.error,
        errorMessage: 'Σφάλμα διαγραφής λογαριασμού / Account deletion error',
      );
    }
  }

  Future<void> deleteWithPassword(String password) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'deleteAccountNotifier.deleteWithPassword');
    state = const DeleteAccountState(status: DeleteState.loading);
    try {
      await _authRepo.deleteAccount(password: password);
      DebugConfig.log(DebugConfig.repositoryResult, 'deleteAccountNotifier.deleteWithPassword success');
      state = const DeleteAccountState(status: DeleteState.success);
    } catch (e, s) {
      DebugConfig.error('deleteAccountNotifier.deleteWithPassword failed', data: e, exception: s);
      state = DeleteAccountState(
        status: DeleteState.error,
        errorMessage: 'Σφάλμα διαγραφής λογαριασμού / Account deletion error',
      );
    }
  }

  void reset() => state = const DeleteAccountState();
}

final deleteAccountProvider = NotifierProvider<DeleteAccountNotifier, DeleteAccountState>(
  DeleteAccountNotifier.new,
);
