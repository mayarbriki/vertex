class Category {
  final int? id;
  final String name;
  final String type; // 'income' or 'expense'

  Category({
    this.id,
    required this.name,
    required this.type,
  }) {
    // Validate category type
    if (type != 'income' && type != 'expense') {
      throw ArgumentError('Category type must be either "income" or "expense"');
    }
    // Validate name
    if (name.trim().isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }
  }

  // Convert from database map
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
    };
  }

  // Copy with modifications
  Category copyWith({
    int? id,
    String? name,
    String? type,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
    );
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  @override
  String toString() {
    return 'Category(id: $id, name: $name, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, type);
  }
}
