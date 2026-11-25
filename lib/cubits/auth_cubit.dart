import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api.dart';
import '../core/api_client.dart';
import '../core/push_service.dart';
import '../models/models.dart';

enum AuthStatus { unknown, signedIn, signedOut }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? message; // e.g. "Your session has expired"

  const AuthState(this.status, {this.user, this.message});
}

/// Holds the signed-in user. The bearer token is kept in secure storage by [ApiClient].
class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState(AuthStatus.unknown)) {
    // Any 401 from the API means the session ended → back to login.
    ApiClient.instance.onUnauthorized = () {
      if (state.status == AuthStatus.signedIn) _signedOut('Your session has expired. Please sign in again.');
    };
  }

  User get user => state.user!;

  /// App start: restore the saved session if it is still valid.
  Future<void> restore() async {
    final token = await ApiClient.instance.loadToken();
    if (token == null) return emit(const AuthState(AuthStatus.signedOut));
    try {
      final me = await Api.me();
      emit(AuthState(AuthStatus.signedIn, user: me));
      PushService.instance.registerDevice();
    } on ApiException catch (e) {
      if (e.status == 401) {
        await ApiClient.instance.saveToken(null);
        emit(const AuthState(AuthStatus.signedOut));
      } else {
        // Offline: stay on login and show the reason.
        emit(AuthState(AuthStatus.signedOut, message: e.message));
      }
    }
  }

  /// Throws [ApiException] with the server message on failure (shown in the form).
  Future<void> login(String email, String password) async {
    final user = await Api.login(email.trim(), password);
    emit(AuthState(AuthStatus.signedIn, user: user));
    PushService.instance.registerDevice();
  }

  Future<void> refreshUser() async {
    try {
      emit(AuthState(AuthStatus.signedIn, user: await Api.me()));
    } catch (_) {}
  }

  Future<void> logout() async {
    await PushService.instance.unregisterDevice(); // stop pushes to this phone
    try {
      await Api.logout();
    } catch (_) {
      await ApiClient.instance.saveToken(null);
    }
    _signedOut(null);
  }

  void _signedOut(String? message) {
    ApiClient.instance.saveToken(null);
    emit(AuthState(AuthStatus.signedOut, message: message));
  }
}
