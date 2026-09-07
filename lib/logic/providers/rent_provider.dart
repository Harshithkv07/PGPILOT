import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/student_model.dart';
import '../../data/models/payment_history_model.dart';
import '../../data/database/student_repository.dart';
import '../../data/database/room_repository.dart';
import '../../data/database/payment_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RentProvider with ChangeNotifier {
  final StudentRepository _studentRepo = StudentRepository();
  final RoomRepository _roomRepo = RoomRepository();
  final PaymentHistoryRepository _paymentHistoryRepo = PaymentHistoryRepository();

  List<StudentModel> _students = [];

  /// Room number -> what one student in that room owes this month, i.e. the
  /// room rent plus their share of the room's EB bill. Rebuilt on every load so
  /// the ledger, the revenue ring and the payment dialog all agree on the
  /// amount due.
  final Map<String, int> _dueByRoom = {};

  bool _isLoading = false;

  List<StudentModel> get students => _students;
  bool get isLoading => _isLoading;

  // Load all students for rent tracking
  Future<void> loadStudents() async {
    _isLoading = true;
    notifyListeners();

    _students = await _studentRepo.getAllStudents();
    await _rebuildDueMap();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _rebuildDueMap() async {
    _dueByRoom.clear();
    final rooms = await _roomRepo.getAllRooms();

    for (final room in rooms) {
      final occupants =
          _students.where((s) => s.roomNumber == room.roomNumber).length;
      final ebShare =
          (occupants > 0 && room.ebBill > 0) ? (room.ebBill / occupants).round() : 0;
      _dueByRoom[room.roomNumber] = room.price + ebShare;
    }
  }

  /// Rent owed by [student] for the current month, EB share included.
  int amountDueFor(StudentModel student) => _dueByRoom[student.roomNumber] ?? 0;

  /// Still outstanding for [student] this month, never negative.
  int amountRemainingFor(StudentModel student) {
    final remaining = amountDueFor(student) - student.amountPaid;
    return remaining > 0 ? remaining.round() : 0;
  }

  // Total rent billed across every student this month
  int getPotentialRevenue() =>
      _students.fold(0, (sum, s) => sum + amountDueFor(s));

  // Total actually received this month, part payments included
  int getCollectedRevenue() =>
      _students.fold(0, (sum, s) => sum + s.amountPaid.round());

  /// Record a payment towards [studentId]'s rent for the current month. The
  /// amounts are *added* to whatever was paid earlier, so a student can settle
  /// their rent over several instalments, each split between cash and UPI.
  ///
  /// Returns the student's new total for the month.
  Future<double> recordPayment({
    required int studentId,
    double cashAmount = 0,
    double upiAmount = 0,
    String? screenshotPath,
  }) async {
    final student = _students.firstWhere((s) => s.id == studentId);
    final due = amountDueFor(student).toDouble();

    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final existing =
        await _paymentHistoryRepo.getPaymentForMonth(studentId, currentMonth);

    // The history row holds the authoritative breakdown; the student row keeps
    // the running total so the ledger renders without a per-row query.
    final newCash = (existing?.cashAmount ?? 0) + cashAmount;
    final newUpi = (existing?.upiAmount ?? 0) + upiAmount;
    final newTotal = newCash + newUpi;

    final status = (due > 0 && newTotal >= due)
        ? 'Paid'
        : (newTotal > 0 ? 'Partial' : 'Pending');
    final mode = PaymentHistoryModel.modeFor(newCash, newUpi);

    await _studentRepo.updateStudent(student.copyWith(
      rentStatus: status,
      paymentMode: mode,
      amountPaid: newTotal,
    ));

    await _paymentHistoryRepo.upsertPaymentRecord(PaymentHistoryModel(
      studentId: studentId,
      month: currentMonth,
      paymentStatus: status,
      paymentMode: mode,
      cashAmount: newCash,
      upiAmount: newUpi,
      amountDue: due,
      // Keep the earlier screenshot when this instalment came without one.
      screenshotPath: screenshotPath ?? existing?.screenshotPath,
      paidDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
    ));

    await loadStudents();
    return newTotal;
  }

  /// Clear this month's payments for a student and put them back to Pending.
  Future<void> revertToPending(int studentId) async {
    try {
      final student = _students.firstWhere((s) => s.id == studentId);
      final updatedStudent = student.copyWith(
        rentStatus: 'Pending',
        paymentMode: '-',
        amountPaid: 0,
      );

      await _studentRepo.updateStudent(updatedStudent);

      // Delete payment history record for the current month
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      final existing =
          await _paymentHistoryRepo.getPaymentForMonth(studentId, currentMonth);
      if (existing != null) {
        await _paymentHistoryRepo.deletePaymentRecord(existing.id!);
      }

      await loadStudents();
    } catch (e) {
      print('Error reverting payment to pending: $e');
    }
  }

  /// Snapshot of a student's current-month state, written into payment_history
  /// when the month rolls over.
  PaymentHistoryModel _archiveRecordFor(StudentModel student, String month) {
    // The student row only carries a combined total, so the mode recorded on it
    // decides which column the money lands in. A 'Cash + UPI' month whose
    // instalments were never written to history can't be split apart again, so
    // it is filed under cash rather than dropped.
    final isUpiOnly = student.paymentMode == 'UPI';

    return PaymentHistoryModel(
      studentId: student.id!,
      month: month,
      paymentStatus: student.rentStatus,
      paymentMode: student.paymentMode,
      cashAmount: isUpiOnly ? 0 : student.amountPaid,
      upiAmount: isUpiOnly ? student.amountPaid : 0,
      amountDue: amountDueFor(student).toDouble(),
      paidDate: student.amountPaid > 0
          ? DateFormat('dd/MM/yyyy').format(DateTime.now())
          : null,
    );
  }

  // Start new month (archive current month status and reset all to pending)
  Future<void> startNewMonth() async {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    // Archive current active states if they don't already have history records
    for (var student in _students) {
      final existing =
          await _paymentHistoryRepo.getPaymentForMonth(student.id!, currentMonth);
      if (existing == null) {
        await _paymentHistoryRepo
            .upsertPaymentRecord(_archiveRecordFor(student, currentMonth));
      }
    }

    await _studentRepo.resetAllRentStatus();

    // Update last active month in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_active_rent_month', currentMonth);
    } catch (e) {
      print('Error saving last active month: $e');
    }

    await loadStudents();
  }

  // Automatically check if the calendar month has transitioned and handle it by archiving and resetting
  Future<void> checkAndHandleMonthTransition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      final lastActiveMonth = prefs.getString('last_active_rent_month');

      if (lastActiveMonth == null) {
        // First run or fresh database: initialize the active month to the current month
        await prefs.setString('last_active_rent_month', currentMonth);
        return;
      }

      if (lastActiveMonth != currentMonth) {
        // A new month has transitioned!
        // Load latest students from DB to make sure we archive actual data
        _students = await _studentRepo.getAllStudents();
        await _rebuildDueMap();

        // 1. Archive the final status of all students for the last active month
        for (var student in _students) {
          final existing = await _paymentHistoryRepo.getPaymentForMonth(
              student.id!, lastActiveMonth);
          if (existing == null) {
            await _paymentHistoryRepo
                .upsertPaymentRecord(_archiveRecordFor(student, lastActiveMonth));
          }
        }

        // 2. Reset student statuses to pending for the new month
        await _studentRepo.resetAllRentStatus();

        // 3. Update the last active rent month to the current month
        await prefs.setString('last_active_rent_month', currentMonth);

        // 4. Reload students list
        await loadStudents();
      }
    } catch (e) {
      print('Error handling month transition: $e');
    }
  }

  // Get students by rent status
  List<StudentModel> getStudentsByStatus(String status) {
    return _students.where((s) => s.rentStatus == status).toList();
  }
}
