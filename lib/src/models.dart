enum EntryType {
  expense,
  income;

  String get label {
    return switch (this) {
      EntryType.expense => '支出',
      EntryType.income => '收入',
    };
  }

  static EntryType fromName(String value) {
    return EntryType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => EntryType.expense,
    );
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.category,
    required this.date,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final EntryType type;
  final int amountCents;
  final String category;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  LedgerEntry copyWith({
    String? id,
    EntryType? type,
    int? amountCents,
    String? category,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      amountCents: amountCents ?? this.amountCents,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amountCents': amountCents,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LedgerEntry.fromJson(Map<String, Object?> json) {
    return LedgerEntry(
      id: json['id'] as String? ?? '',
      type: EntryType.fromName(json['type'] as String? ?? ''),
      amountCents: (json['amountCents'] as num? ?? 0).round(),
      category: json['category'] as String? ?? '未分类',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      note: json['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class MonthlyBudget {
  const MonthlyBudget({
    required this.monthKey,
    required this.amountCents,
  });

  final String monthKey;
  final int amountCents;

  Map<String, Object?> toJson() {
    return {
      'monthKey': monthKey,
      'amountCents': amountCents,
    };
  }

  factory MonthlyBudget.fromJson(Map<String, Object?> json) {
    return MonthlyBudget(
      monthKey: json['monthKey'] as String? ?? monthKeyFromDate(DateTime.now()),
      amountCents: (json['amountCents'] as num? ?? 0).round(),
    );
  }
}

class LedgerData {
  const LedgerData({
    required this.entries,
    required this.budgets,
  });

  factory LedgerData.empty() {
    return const LedgerData(entries: [], budgets: []);
  }

  final List<LedgerEntry> entries;
  final List<MonthlyBudget> budgets;

  Map<String, Object?> toJson() {
    return {
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'budgets': budgets.map((budget) => budget.toJson()).toList(),
    };
  }

  factory LedgerData.fromJson(Map<String, Object?> json) {
    final rawEntries = json['entries'];
    final rawBudgets = json['budgets'];

    return LedgerData(
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map((item) => LedgerEntry.fromJson(Map<String, Object?>.from(item)))
                .toList()
          : const [],
      budgets: rawBudgets is List
          ? rawBudgets
                .whereType<Map>()
                .map(
                  (item) =>
                      MonthlyBudget.fromJson(Map<String, Object?>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class MonthlySummary {
  const MonthlySummary({
    required this.incomeCents,
    required this.expenseCents,
    required this.budgetCents,
  });

  final int incomeCents;
  final int expenseCents;
  final int budgetCents;

  int get balanceCents => incomeCents - expenseCents;
  int get remainingBudgetCents => budgetCents - expenseCents;

  double get budgetUsage {
    if (budgetCents <= 0) {
      return 0;
    }
    return (expenseCents / budgetCents).clamp(0.0, 1.0).toDouble();
  }
}

String monthKeyFromDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
}
