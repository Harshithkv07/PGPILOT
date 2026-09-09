import '../models/payment_history_model.dart';
import '../models/rent_payment_model.dart';
import 'database_helper.dart';

class PaymentHistoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Insert a new payment record
  Future<int> insertPaymentRecord(PaymentHistoryModel payment) async {
    final db = await _dbHelper.database;
    return await db.insert('payment_history', payment.toMap());
  }

  // Get all payment history for a student
  Future<List<PaymentHistoryModel>> getStudentPaymentHistory(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_history',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'month DESC',
    );
    return List.generate(maps.length, (i) => PaymentHistoryModel.fromMap(maps[i]));
  }

  // Get payment record for specific month
  Future<PaymentHistoryModel?> getPaymentForMonth(int studentId, String month) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_history',
      where: 'student_id = ? AND month = ?',
      whereArgs: [studentId, month],
    );
    
    if (maps.isEmpty) return null;
    return PaymentHistoryModel.fromMap(maps.first);
  }

  // Update payment record
  Future<int> updatePaymentRecord(PaymentHistoryModel payment) async {
    final db = await _dbHelper.database;
    return await db.update(
      'payment_history',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  // Update or insert payment record
  Future<void> upsertPaymentRecord(PaymentHistoryModel payment) async {
    final existing = await getPaymentForMonth(payment.studentId, payment.month);
    
    if (existing != null) {
      // Update existing record
      await updatePaymentRecord(payment.copyWith(id: existing.id));
    } else {
      // Insert new record
      await insertPaymentRecord(payment);
    }
  }

  // Delete payment record
  Future<int> deletePaymentRecord(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'payment_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete all payment records for a student
  Future<int> deleteStudentPaymentHistory(int studentId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'payment_history',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  // ─── Instalments (rent_payments) ───

  /// Record one instalment on the day it was taken.
  Future<int> insertInstalment(RentPaymentModel payment) async {
    final db = await _dbHelper.database;
    return await db.insert('rent_payments', payment.toMap());
  }

  /// Drop a student's instalments for a month — used when a month's payments
  /// are cleared, so the cash book stops counting money that was undone.
  Future<int> deleteInstalmentsForMonth(int studentId, String month) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'rent_payments',
      where: 'student_id = ? AND month = ?',
      whereArgs: [studentId, month],
    );
  }

  Future<int> deleteStudentInstalments(int studentId) async {
    final db = await _dbHelper.database;
    return await db.delete('rent_payments',
        where: 'student_id = ?', whereArgs: [studentId]);
  }

  /// Cash rent taken on [date] (YYYY-MM-DD). Only cash: UPI never enters the
  /// physical cash box, so counting it would break the day's reconciliation.
  Future<double> getCashCollectedOn(String date) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(cash_amount), 0) as total FROM rent_payments WHERE paid_on = ?',
      [date],
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Cash rent taken on each day of [month] (YYYY-MM), keyed by date.
  Future<Map<String, double>> getCashCollectedByDate(String month) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT paid_on, SUM(cash_amount) as total FROM rent_payments '
      'WHERE paid_on LIKE ? GROUP BY paid_on',
      ['$month%'],
    );
    return {
      for (final row in rows)
        row['paid_on'] as String: (row['total'] as num).toDouble(),
    };
  }

  /// Every instalment taken on [date], newest first — the detail behind the
  /// day's rent line.
  Future<List<RentPaymentModel>> getInstalmentsOn(String date) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'rent_payments',
      where: 'paid_on = ?',
      whereArgs: [date],
      orderBy: 'id DESC',
    );
    return maps.map(RentPaymentModel.fromMap).toList();
  }

  // Get payment statistics
  Future<Map<String, int>> getPaymentStats(int studentId) async {
    final history = await getStudentPaymentHistory(studentId);
    final paid = history.where((p) => p.paymentStatus == 'Paid').length;
    final partial = history.where((p) => p.paymentStatus == 'Partial').length;
    final pending = history.where((p) => p.paymentStatus == 'Pending').length;

    return {
      'total': history.length,
      'paid': paid,
      'partial': partial,
      'pending': pending,
    };
  }
}
