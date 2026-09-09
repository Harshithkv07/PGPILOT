import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/student_model.dart';
import '../../data/models/payment_history_model.dart';
import '../../data/models/rent_payment_model.dart';
import '../../data/database/student_repository.dart';
import '../../data/database/room_repository.dart';
import '../../data/database/payment_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which slice of the rent ledger is on screen. Every student falls in
/// exactly one bucket, so the counts always add up to [RentFilter.all].
enum RentFilter { all, unpaid, partial, paid }

extension RentFilterLabel on RentFilter {
  String get label => switch (this) {
        RentFilter.all => 'All',
        RentFilter.unpaid => 'Unpaid',
        RentFilter.partial => 'Partial',
        RentFilter.paid => 'Paid',
      };
}

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
  RentFilter _filter = RentFilter.all;
  String _query = '';

  /// Every student, regardless of the active filter — the revenue totals are
  /// always for the whole PG, not the current view.
  List<StudentModel> get allStudents => _students;
  bool get isLoading => _isLoading;
  RentFilter get filter => _filter;

  /// The students the ledger should show, ordered so the ones still owing
  /// money come first — that is what the screen is normally opened for.
  String get query => _query;

  void setQuery(String value) {
    final next = value.trim();
    if (_query == next) return;
    _query = next;
    notifyListeners();
  }

  bool _matchesQuery(StudentModel s) {
    if (_query.isEmpty) return true;
    final needle = _query.toLowerCase();
    return s.name.toLowerCase().contains(needle) ||
        s.roomNumber.toLowerCase().contains(needle) ||
        s.contact.contains(_query);
  }

  List<StudentModel> get students {
    final visible = _students
        .where((s) => _matches(s, _filter) && _matchesQuery(s))
        .toList();
    visible.sort((a, b) {
      final rank = _chaseRank(a).compareTo(_chaseRank(b));
      if (rank != 0) return rank;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return visible;
  }

  /// Pure predicate, so counting a bucket never disturbs the active filter.
  bool _matches(StudentModel s, RentFilter filter) => switch (filter) {
        RentFilter.all => true,
        RentFilter.unpaid => s.rentStatus != 'Paid' && s.amountPaid <= 0,
        RentFilter.partial => s.rentStatus != 'Paid' && s.amountPaid > 0,
        RentFilter.paid => s.rentStatus == 'Paid',
      };

  /// Nothing paid sorts first, part payments next, settled last.
  int _chaseRank(StudentModel s) {
    if (s.rentStatus == 'Paid') return 2;
    return s.amountPaid > 0 ? 1 : 0;
  }

  void setFilter(RentFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  /// How many students sit in each bucket, for the filter chips.
  int countFor(RentFilter filter) =>
      _students.where((s) => _matches(s, filter)).length;

  /// Total still owed across everyone — the number worth chasing.
  int get totalOutstanding =>
      _students.fold(0, (sum, s) => sum + amountRemainingFor(s));

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

    // Record this instalment on the day it was taken, so the daily cash book
    // can count the cash that actually came in today. The rollup below stays
    // the source of truth for the month.
    if (cashAmount > 0 || upiAmount > 0) {
      await _paymentHistoryRepo.insertInstalment(RentPaymentModel(
        studentId: studentId,
        month: currentMonth,
        paidOn: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        cashAmount: cashAmount,
        upiAmount: upiAmount,
      ));
    }

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
  ///
  /// Returns what was cleared so the action can be undone — wiping a month's
  /// collected rent by mistake was previously unrecoverable.
  Future<PaymentHistoryModel?> revertToPending(int studentId) async {
    PaymentHistoryModel? cleared;
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
        cleared = existing;
        await _paymentHistoryRepo.deletePaymentRecord(existing.id!);
      }
      // The instalments go too, or the cash book would keep counting money
      // that has just been undone.
      await _paymentHistoryRepo.deleteInstalmentsForMonth(studentId, currentMonth);

      await loadStudents();
    } catch (e) {
      debugPrint('Error reverting payment to pending: $e');
    }
    return cleared;
  }

  /// Put back a month that [revertToPending] cleared.
  Future<void> restorePayment(PaymentHistoryModel cleared) async {
    try {
      await recordPayment(
        studentId: cleared.studentId,
        cashAmount: cleared.cashAmount,
        upiAmount: cleared.upiAmount,
        screenshotPath: cleared.screenshotPath,
      );
    } catch (e) {
      debugPrint('Error restoring payment: $e');
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

  // Get students by rent status (unfiltered — used by summary widgets)
  List<StudentModel> getStudentsByStatus(String status) {
    return _students.where((s) => s.rentStatus == status).toList();
  }
}
