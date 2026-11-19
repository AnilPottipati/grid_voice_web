/// The person Grid is talking as.
class AuthUser {
  const AuthUser({required this.key, required this.name, this.role});

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    key: '${j['id']}',
    name: '${j['name']}',
    role: j['role'] == null ? null : '${j['role']}',
  );

  final String key;
  final String name;
  final String? role;

  String get roleLabel =>
      role == null ? '' : role!.replaceAll('_', ' ').toLowerCase();
}

enum AuthStatus {
  /// Asking the server who we are.
  loading,

  /// Sign-in is on and nobody is signed in.
  signedOut,

  /// Ready to talk. With sign-in off this means a person was picked.
  ready,

  /// The server (or its user list) could not be reached.
  unreachable,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.loading,
    this.user,
    this.authRequired = false,
    this.busy = false,
    this.error,
  });

  final AuthStatus status;
  final AuthUser? user;
  final bool authRequired;

  /// A sign-in call is running.
  final bool busy;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool clearUser = false,
    bool? authRequired,
    bool? busy,
    String? error,
    bool clearError = false,
  }) => AuthState(
    status: status ?? this.status,
    user: clearUser ? null : (user ?? this.user),
    authRequired: authRequired ?? this.authRequired,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}
