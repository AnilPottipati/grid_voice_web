import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/users_repository.dart';
import '../domain/person.dart';

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(ref.watch(apiClientProvider)),
);

class UsersState {
  const UsersState({
    this.result = const UsersResult(),
    this.query = '',
    this.role = '',
    this.loading = false,
    this.error,
  });

  final UsersResult result;
  final String query;
  final String role;
  final bool loading;
  final String? error;

  UsersState copyWith({
    UsersResult? result,
    String? query,
    String? role,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => UsersState(
    result: result ?? this.result,
    query: query ?? this.query,
    role: role ?? this.role,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

/// The searchable list of people to talk as (only when sign-in is off).
class UsersNotifier extends Notifier<UsersState> {
  Timer? _debounce;

  @override
  UsersState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(_load);
    return const UsersState(loading: true);
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _load);
  }

  void setRole(String role) {
    state = state.copyWith(role: role);
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final r = await ref
          .read(usersRepositoryProvider)
          .search(query: state.query, role: state.role);
      state = state.copyWith(result: r, loading: false);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }
}

final usersProvider = NotifierProvider<UsersNotifier, UsersState>(
  UsersNotifier.new,
);
