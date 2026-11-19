class Person {
  const Person({required this.key, required this.name, this.role});

  factory Person.fromJson(Map<String, dynamic> j) => Person(
    key: '${j['key']}',
    name: '${j['name']}',
    role: j['role'] == null ? null : '${j['role']}',
  );

  final String key;
  final String name;
  final String? role;
}

class RoleCount {
  const RoleCount(this.role, this.count);

  final String role;
  final int count;
}

class UsersResult {
  const UsersResult({
    this.people = const [],
    this.roles = const [],
    this.total = 0,
  });

  factory UsersResult.fromJson(Map<String, dynamic> j) => UsersResult(
    total: (j['total'] as num?)?.toInt() ?? 0,
    people: [
      for (final p in (j['people'] as List? ?? const []))
        Person.fromJson(p as Map<String, dynamic>),
    ],
    roles: [
      for (final r in (j['roles'] as List? ?? const []))
        RoleCount(
          '${(r as Map)['role']}',
          (r['count'] as num?)?.toInt() ?? 0,
        ),
    ],
  );

  final List<Person> people;
  final List<RoleCount> roles;
  final int total;
}
