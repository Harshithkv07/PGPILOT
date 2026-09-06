class ExpenseModel {
  final int? id;
  final String date; // YYYY-MM-DD
  final double amount;
  final String category;
  final String note;
  final String createdAt;

  static const List<String> categories = [
    'Vegetables and Provision',
    'Staff Advance',
    'Staff Salaries',
    'Snacks',
    'Chicken',
    'Maintenance',
    'Waste Removal',
    'EB',
    'Wifi Bill',
    'Returned to Student',
  ];

  ExpenseModel({
    this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'category': category,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'],
      date: map['date'],
      amount: (map['amount'] as num).toDouble(),
      category: map['category'],
      note: map['note'] ?? '',
      createdAt: map['created_at'] ?? '',
    );
  }

  ExpenseModel copyWith({
    int? id,
    String? date,
    double? amount,
    String? category,
    String? note,
    String? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
