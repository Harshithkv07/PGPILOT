import '../models/payment_history_model.dart';
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
