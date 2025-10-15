class User {
  final int? id;
  final String name;
  final String email;
  final String? password;
  final DateTime createdAt;
  final bool isActive;

  User({
    this.id,
    required this.name,
    required this.email,
    this.password,
    DateTime? createdAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now() {
    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      throw ArgumentError('Invalid email format');
    }
    // Validate name
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }
  }

  // Convert from database map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      password: map['password'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      isActive: (map['is_active'] as int) == 1,
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      if (password != null) 'password': password,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  // Copy with modifications
  User copyWith({
    int? id,
    String? name,
    String? email,
    String? password,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, createdAt: $createdAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.createdAt == createdAt &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, email, createdAt, isActive);
  }
}
