// Cash rent handed over by a student is money in the box, so the daily cash
// book has to know about it. Rent and Accounts used to be entirely separate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/data/database/database_helper.dart';
import 'package:pg_management/data/database/payment_history_repository.dart';
import 'package:pg_management/data/database/room_repository.dart';
import 'package:pg_management/data/database/student_repository.dart';
import 'package:pg_management/data/models/room_config_model.dart';
import 'package:pg_management/data/models/student_model.dart';
import 'package:pg_management/logic/providers/accounts_provider.dart';
import 'package:pg_management/logic/providers/rent_provider.dart';

void main() {
  late Directory tempDir;
  final studentRepo = StudentRepository();
  final roomRepo = RoomRepository();
  final historyRepo = PaymentHistoryRepository();

  final today = DateTime.now();
  final todayStr = DateFormat('yyyy-MM-dd').format(today);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('pgpilot_cashbook');
    DatabaseHelper.databasePathOverride = '${tempDir.path}/pg_management.db';
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseHelper().database;
    await db.delete('rent_payments');
    await db.delete('payment_history');
    await db.delete('students');
    await db.delete('rooms');
    await db.delete('expenses');
    await db.delete('daily_accounts');
  });

  Future<StudentModel> seedStudent() async {
    await roomRepo.insertRoom(
        RoomConfigModel(roomNumber: '101', capacity: 2, price: 5000));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Asha'));
    return (await studentRepo.getAllStudents()).first;
  }

  test('cash rent lands in the day it was taken', () async {
    final student = await seedStudent();
    final rent = RentProvider();
    await rent.loadStudents();

    await rent.recordPayment(studentId: student.id!, cashAmount: 3000);

    expect(await historyRepo.getCashCollectedOn(todayStr), 3000);
  });

  test('UPI rent is excluded — it never enters the cash box', () async {
    final student = await seedStudent();
    final rent = RentProvider();
    await rent.loadStudents();

    await rent.recordPayment(
        studentId: student.id!, cashAmount: 1000, upiAmount: 2500);

    expect(await historyRepo.getCashCollectedOn(todayStr), 1000);
  });

  test('the day balance is opening plus cash rent less spending', () async {
    final student = await seedStudent();
    final rent = RentProvider();
    await rent.loadStudents();

    final accounts = AccountsProvider();
    await accounts.loadDay(today);
    await accounts.setOpeningBalance(2000);
    await accounts.addExpense(500, 'Groceries', '');

    // Before any rent: 2000 - 500.
    expect(accounts.remainingBalance, 1500);

    await rent.recordPayment(studentId: student.id!, cashAmount: 3000);
    await accounts.loadDay(today);

    // 2000 + 3000 - 500.
    expect(accounts.rentCollectedToday, 3000);
    expect(accounts.remainingBalance, 4500);
  });

  test('separate instalments are attributed to their own days', () async {
    final student = await seedStudent();
    final rent = RentProvider();
    await rent.loadStudents();

    await rent.recordPayment(studentId: student.id!, cashAmount: 1200);
    await rent.recordPayment(studentId: student.id!, cashAmount: 800);

    // Both landed today, and both are counted — the rolled-up month row could
    // only ever have shown one date.
    expect(await historyRepo.getCashCollectedOn(todayStr), 2000);
    expect((await historyRepo.getInstalmentsOn(todayStr)).length, 2);
  });

  test('clearing a month removes its cash from the book', () async {
    final student = await seedStudent();
    final rent = RentProvider();
    await rent.loadStudents();

    await rent.recordPayment(studentId: student.id!, cashAmount: 3000);
    expect(await historyRepo.getCashCollectedOn(todayStr), 3000);

    await rent.revertToPending(student.id!);

    // Otherwise the cash book would keep counting money that was undone.
    expect(await historyRepo.getCashCollectedOn(todayStr), 0);
  });

  test('undo restores both the rent record and the cash', () async {
    final student = await seedStudent();
    final rent = RentProvider();
    await rent.loadStudents();

    await rent.recordPayment(
        studentId: student.id!, cashAmount: 2000, upiAmount: 500);
    final cleared = await rent.revertToPending(student.id!);
    expect(cleared, isNotNull);

    await rent.restorePayment(cleared!);

    final restored = rent.allStudents.firstWhere((s) => s.id == student.id);
    expect(restored.amountPaid, 2500);
    expect(await historyRepo.getCashCollectedOn(todayStr), 2000);
  });

  test('deleting a student clears their instalments too', () async {
    final student = await seedStudent();
    final rent = RentProvider();
    await rent.loadStudents();
    await rent.recordPayment(studentId: student.id!, cashAmount: 3000);

    await historyRepo.deleteStudentInstalments(student.id!);

    expect(await historyRepo.getCashCollectedOn(todayStr), 0);
  });

  test('cash totals come back grouped by date for a month', () async {
    final student = await seedStudent();
    final rent = RentProvider();
    await rent.loadStudents();
    await rent.recordPayment(studentId: student.id!, cashAmount: 1500);

    final byDate = await historyRepo
        .getCashCollectedByDate(DateFormat('yyyy-MM').format(today));
    expect(byDate[todayStr], 1500);
  });
}
