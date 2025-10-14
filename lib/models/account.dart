class Account {
  final int? id;
  final int userId;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final DateTime createdAt;

  Account({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.balance = 0.0,
    this.currency = 'TND',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    // Validate name
    if (name.trim().isEmpty) {
      throw ArgumentError('Account name cannot be empty');
    }
    // Validate type
    if (type.trim().isEmpty) {
      throw ArgumentError('Account type cannot be empty');
    }
  }

  // Convert from database map
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      name: map['name'] as String,
      type: map['type'] as String,
      balance: (map['balance'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'TND',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'balance': balance,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Copy with modifications
  Account copyWith({
    int? id,
    int? userId,
    String? name,
    String? type,
    double? balance,
    String? currency,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, userId: $userId, name: $name, type: $type, balance: $balance, currency: $currency, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account &&
        other.id == id &&
        other.userId == userId &&
        other.name == name &&
        other.type == type &&
        other.balance == balance &&
        other.currency == currency &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, userId, name, type, balance, currency, createdAt);
  }
}
