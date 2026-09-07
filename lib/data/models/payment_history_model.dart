class PaymentHistoryModel {
  final int? id;
  final int studentId;
  final String month; // Format: YYYY-MM
  final String paymentStatus; // 'Paid', 'Partial' or 'Pending'
  final String paymentMode; // 'Cash', 'UPI', 'Cash + UPI', or '-'
  final double cashAmount;
  final double upiAmount;
  final double amountDue;
  final String? screenshotPath;
  final String? paidDate; // Format: DD/MM/YYYY

  PaymentHistoryModel({
    this.id,
    required this.studentId,
    required this.month,
    required this.paymentStatus,
    required this.paymentMode,
    this.cashAmount = 0,
    this.upiAmount = 0,
    this.amountDue = 0,
    this.screenshotPath,
    this.paidDate,
  });

  /// Total settled for the month, however it was split.
  double get amountPaid => cashAmount + upiAmount;

  /// Still owed for the month. Zero once the rent is fully settled.
  double get amountRemaining {
    final remaining = amountDue - amountPaid;
    return remaining > 0 ? remaining : 0;
  }

  /// Months archived before partial-payment tracking existed carry no
  /// breakdown, so the UI shows the status alone instead of "₹0 paid".
  bool get hasAmountDetail => amountPaid > 0 || amountDue > 0;

  /// Derives the mode label from the split, so it always matches the amounts.
  static String modeFor(double cashAmount, double upiAmount) {
    if (cashAmount > 0 && upiAmount > 0) return 'Cash + UPI';
    if (cashAmount > 0) return 'Cash';
    if (upiAmount > 0) return 'UPI';
    return '-';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'month': month,
      'payment_status': paymentStatus,
      'payment_mode': paymentMode,
      'cash_amount': cashAmount,
      'upi_amount': upiAmount,
      'amount_due': amountDue,
      'screenshot_path': screenshotPath,
      'paid_date': paidDate,
    };
  }

  factory PaymentHistoryModel.fromMap(Map<String, dynamic> map) {
    return PaymentHistoryModel(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      month: map['month'] as String,
      paymentStatus: map['payment_status'] as String,
      paymentMode: map['payment_mode'] as String,
      cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0,
      upiAmount: (map['upi_amount'] as num?)?.toDouble() ?? 0,
      amountDue: (map['amount_due'] as num?)?.toDouble() ?? 0,
      screenshotPath: map['screenshot_path'] as String?,
      paidDate: map['paid_date'] as String?,
    );
  }

  PaymentHistoryModel copyWith({
    int? id,
    int? studentId,
    String? month,
    String? paymentStatus,
    String? paymentMode,
    double? cashAmount,
    double? upiAmount,
    double? amountDue,
    String? screenshotPath,
    String? paidDate,
  }) {
    return PaymentHistoryModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      month: month ?? this.month,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMode: paymentMode ?? this.paymentMode,
      cashAmount: cashAmount ?? this.cashAmount,
      upiAmount: upiAmount ?? this.upiAmount,
      amountDue: amountDue ?? this.amountDue,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      paidDate: paidDate ?? this.paidDate,
    );
  }
}
