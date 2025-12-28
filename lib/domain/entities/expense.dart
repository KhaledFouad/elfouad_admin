class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime createdAtUtc; // نخزّنه/نقرأه UTC
  final String? notes;
  final String? category;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.createdAtUtc,
    this.notes,
    this.category,
  });

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? createdAtUtc,
    String? notes,
    String? category,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      notes: notes ?? this.notes,
      category: category ?? this.category,
    );
  }
}
