class Budget {
  final int? id;
  final int? userId;
  final int? accountId;
  final String name;
  final double amountLimit;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? category; // optional category filter for the budget
  final DateTime? createdAt;

  Budget({
    this.id,
    this.userId,
    this.accountId,
    required this.name,
    required this.amountLimit,
    required this.periodStart,
    required this.periodEnd,
    this.category,
    this.createdAt,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Budget name cannot be empty');
    }
    if (amountLimit <= 0) {
      throw ArgumentError('Budget amount limit must be > 0');
    }
    if (!periodEnd.isAfter(periodStart)) {
      throw ArgumentError('Budget end date must be after start date');
    }
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      userId: map['user_id'] as int?,
      accountId: map['account_id'] as int?,
      name: map['name'] as String,
      amountLimit: (map['amount_limit'] as num).toDouble(),
      periodStart: DateTime.parse(map['period_start'] as String),
      periodEnd: DateTime.parse(map['period_end'] as String),
      category: map['category'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'account_id': accountId,
      'name': name,
      'amount_limit': amountLimit,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'category': category,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Budget copyWith({
    int? id,
    int? userId,
    int? accountId,
    String? name,
    double? amountLimit,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? category,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      amountLimit: amountLimit ?? this.amountLimit,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Budget(id: $id, userId: $userId, accountId: $accountId, name: $name, amountLimit: $amountLimit, periodStart: $periodStart, periodEnd: $periodEnd, category: $category)';
  }
}

