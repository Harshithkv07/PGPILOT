// Drives RentProvider against a real (temporary) database to check that rent
// can be settled across several instalments, each split between cash and UPI.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/data/database/database_helper.dart';
import 'package:pg_management/data/database/payment_history_repository.dart';
import 'package:pg_management/data/database/room_repository.dart';
import 'package:pg_management/data/database/student_repository.dart';
import 'package:pg_management/data/models/room_config_model.dart';
import 'package:pg_management/data/models/student_model.dart';
import 'package:pg_management/logic/providers/rent_provider.dart';

void main() {
  late Directory tempDir;
  final studentRepo = StudentRepository();
  final roomRepo = RoomRepository();
  final historyRepo = PaymentHistoryRepository();

  setUpAll(() async {
    // startNewMonth writes the active month to SharedPreferences, which needs
    // the services binding up.
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Test files run in parallel, so point the singleton at a file of this
    // suite's own rather than the shared default.
    tempDir = Directory.systemTemp.createTempSync('pgpilot_payments');
    DatabaseHelper.databasePathOverride = '${tempDir.path}/pg_management.db';
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    // Windows can still hold the sqlite file briefly after close(); a temp
    // directory left behind is harmless, a failed teardown is not.
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseHelper().database;
    await db.delete('payment_history');
    await db.delete('students');
    await db.delete('rooms');
  });

  /// A 2-sharing room at ₹5000 with a ₹400 EB bill, and one student in it.
  /// Their share works out to ₹5000 + ₹200 = ₹5200.
  Future<StudentModel> seedStudent() async {
    await roomRepo.insertRoom(RoomConfigModel(
      roomNumber: '101',
      capacity: 2,
      price: 5000,
      ebBill: 400,
    ));
    // Two occupants so the EB bill splits in half.
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Asha'));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Bhavna'));
    return (await studentRepo.getAllStudents()).first;
  }

  test('amount due includes the student\'s share of the EB bill', () async {
    await seedStudent();
    final provider = RentProvider();
    await provider.loadStudents();

    expect(provider.amountDueFor(provider.students.first), 5200);
    expect(provider.getPotentialRevenue(), 10400); // both occupants
    expect(provider.getCollectedRevenue(), 0);
  });

  test('a part payment leaves the student Partial with a balance', () async {
    final student = await seedStudent();
    final provider = RentProvider();
    await provider.loadStudents();

    await provider.recordPayment(studentId: student.id!, cashAmount: 2000);

    final updated = provider.students.firstWhere((s) => s.id == student.id);
    expect(updated.rentStatus, 'Partial');
    expect(updated.paymentMode, 'Cash');
    expect(updated.amountPaid, 2000);
    expect(provider.amountRemainingFor(updated), 3200);
    expect(provider.getCollectedRevenue(), 2000);
  });

  test('instalments accumulate and flip to Paid once the rent is covered',
      () async {
    final student = await seedStudent();
    final provider = RentProvider();
    await provider.loadStudents();

    await provider.recordPayment(studentId: student.id!, cashAmount: 2000);
    await provider.recordPayment(studentId: student.id!, upiAmount: 1200);

    var updated = provider.students.firstWhere((s) => s.id == student.id);
    expect(updated.rentStatus, 'Partial');
    expect(updated.paymentMode, 'Cash + UPI');
    expect(updated.amountPaid, 3200);

    await provider.recordPayment(studentId: student.id!, upiAmount: 2000);

    updated = provider.students.firstWhere((s) => s.id == student.id);
    expect(updated.rentStatus, 'Paid');
    expect(updated.amountPaid, 5200);
    expect(provider.amountRemainingFor(updated), 0);

    // History keeps the split, so the ledger can say where each rupee came from.
    final record = await historyRepo.getStudentPaymentHistory(student.id!);
    expect(record.length, 1);
    expect(record.first.cashAmount, 2000);
    expect(record.first.upiAmount, 3200);
    expect(record.first.amountDue, 5200);
    expect(record.first.paymentStatus, 'Paid');
  });

  test('a UPI screenshot survives a later cash instalment', () async {
    final student = await seedStudent();
    final provider = RentProvider();
    await provider.loadStudents();

    await provider.recordPayment(
      studentId: student.id!,
      upiAmount: 1000,
      screenshotPath: 'C:/proof/upi.png',
    );
    await provider.recordPayment(studentId: student.id!, cashAmount: 500);

    final record = (await historyRepo.getStudentPaymentHistory(student.id!)).first;
    expect(record.screenshotPath, 'C:/proof/upi.png');
  });

  test('reverting clears the money as well as the status', () async {
    final student = await seedStudent();
    final provider = RentProvider();
    await provider.loadStudents();

    await provider.recordPayment(studentId: student.id!, cashAmount: 2000);
    await provider.revertToPending(student.id!);

    final updated = provider.students.firstWhere((s) => s.id == student.id);
    expect(updated.rentStatus, 'Pending');
    expect(updated.paymentMode, '-');
    expect(updated.amountPaid, 0);
    expect(provider.getCollectedRevenue(), 0);
    expect(await historyRepo.getStudentPaymentHistory(student.id!), isEmpty);
  });

  test('starting a new month archives the split and zeroes the students',
      () async {
    final student = await seedStudent();
    final provider = RentProvider();
    await provider.loadStudents();

    await provider.recordPayment(
        studentId: student.id!, cashAmount: 1500, upiAmount: 500);
    await provider.startNewMonth();

    final updated = provider.students.firstWhere((s) => s.id == student.id);
    expect(updated.rentStatus, 'Pending');
    expect(updated.amountPaid, 0);

    final archived = (await historyRepo.getStudentPaymentHistory(student.id!)).first;
    expect(archived.paymentStatus, 'Partial');
    expect(archived.amountPaid, 2000);
    expect(archived.cashAmount, 1500);
    expect(archived.upiAmount, 500);
  });
}
