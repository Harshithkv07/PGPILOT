/// A single rent instalment, recorded when it is taken.
///
/// `payment_history` rolls a month up into one row per student, which cannot
/// answer "how much cash came in on Tuesday". This records each payment as its
/// own row so the daily cash book can be reconciled against real takings.
class RentPaymentModel {
  final int? id;
  final int studentId;

  /// The rent month this instalment settles, YYYY-MM.
  final String month;

  /// The day the money actually changed hands, YYYY-MM-DD. Not the same as
  /// [month]: rent for September can be paid on the 2nd of October.
  final String paidOn;

  final double cashAmount;
  final double upiAmount;

  RentPaymentModel({
    this.id,
    required this.studentId,
    required this.month,
    required this.paidOn,
    this.cashAmount = 0,
    this.upiAmount = 0,
  });

  double get total => cashAmount + upiAmount;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'student_id': studentId,
        'month': month,
        'paid_on': paidOn,
        'cash_amount': cashAmount,
        'upi_amount': upiAmount,
      };

  factory RentPaymentModel.fromMap(Map<String, dynamic> map) => RentPaymentModel(
        id: map['id'] as int?,
        studentId: map['student_id'] as int,
        month: map['month'] as String,
        paidOn: map['paid_on'] as String,
        cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0,
        upiAmount: (map['upi_amount'] as num?)?.toDouble() ?? 0,
      );
}
