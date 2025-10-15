class Transaction {
  final int? id;
  final int accountId;
  final String type; // 'income' or 'expense'
  final double amount;
  final String? category;
  final String? description;
  final DateTime date;

  Transaction({
    this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    this.category,
    this.description,
    DateTime? date,
  }) : date = date ?? DateTime.now() {
    // Validate transaction type
    if (type != 'income' && type != 'expense') {
      throw ArgumentError('Transaction type must be either "income" or "expense"');
    }
    // Validate amount
    if (amount < 0) {
      throw ArgumentError('Transaction amount must be positive');
    }
  }

  // Convert from database map
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String?,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'account_id': accountId,
      'type': type,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
    };
  }

  // Copy with modifications
  Transaction copyWith({
    int? id,
    int? accountId,
    String? type,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  @override
  String toString() {
    return 'Transaction(id: $id, accountId: $accountId, type: $type, amount: $amount, category: $category, description: $description, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.accountId == accountId &&
        other.type == type &&
        other.amount == amount &&
        other.category == category &&
        other.description == description &&
        other.date == date;
  }

  @override
  int get hashCode {
    return Object.hash(id, accountId, type, amount, category, description, date);
  }
}
