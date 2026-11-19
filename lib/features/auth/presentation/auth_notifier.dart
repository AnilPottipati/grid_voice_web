import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../users/domain/person.dart';
import '../../users/presentation/users_notifier.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

/// Who Grid is talking as: from the sign-in cookie, or (when the server has
/// sign-in off, for development) a person picked from a list.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_start);
    return const AuthState();
  }

  Future<void> _start() async {
    try {
      final config = await ref.read(serverConfigProvider.future);
      if (config.authRequired) {
        final user = await ref.read(authRepositoryProvider).me();
        state = user == null
            ? const AuthState(
                status: AuthStatus.signedOut,
                authRequired: true,
              )
            : AuthState(
                status: AuthStatus.ready,
                user: user,
                authRequired: true,
              );
        return;
      }
      await _pickDevelopmentUser();
    } on ApiException catch (e) {
      state = AuthState(status: AuthStatus.unreachable, error: e.message);
    } catch (e) {
      state = AuthState(status: AuthStatus.unreachable, error: '$e');
    }
  }

  Future<void> _pickDevelopmentUser() async {
    final settings = ref.read(settingsRepositoryProvider);
    final result = await ref.read(usersRepositoryProvider).search();
    final storedKey = settings.chosenUserKey;
    Person? chosen;
    for (final p in result.people) {
      if (p.key == storedKey) chosen = p;
    }
    chosen ??= result.people.isEmpty ? null : result.people.first;
    if (chosen == null) {
      state = const AuthState(
        status: AuthStatus.unreachable,
        error: 'No users found.',
      );
      return;
    }
    state = AuthState(
      status: AuthStatus.ready,
      user: AuthUser(key: chosen.key, name: chosen.name, role: chosen.role),
    );
  }

  Future<void> login(String login, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await ref.read(authRepositoryProvider).login(login, password);
      state = AuthState(
        status: AuthStatus.ready,
        user: user,
        authRequired: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(status: AuthStatus.signedOut, authRequired: true);
  }

  /// Sign-in off: talk as someone else.
  Future<void> selectPerson(Person p) async {
    await ref.read(settingsRepositoryProvider).saveChosenUser(p.key, p.name);
    state = state.copyWith(
      user: AuthUser(key: p.key, name: p.name, role: p.role),
    );
  }

  /// The server said the session ended while talking.
  void sessionExpired() {
    if (!state.authRequired) return;
    state = const AuthState(
      status: AuthStatus.signedOut,
      authRequired: true,
      error: 'Please sign in again.',
    );
  }

  Future<void> retry() async {
    state = const AuthState();
    ref.invalidate(serverConfigProvider);
    await _start();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
