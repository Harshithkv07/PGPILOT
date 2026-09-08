// Editing a student used to be the one path that bypassed room-capacity checks
// and quietly dropped collected rent. Both are pinned here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/data/database/database_helper.dart';
import 'package:pg_management/data/database/payment_history_repository.dart';
import 'package:pg_management/data/database/room_repository.dart';
import 'package:pg_management/data/database/student_repository.dart';
import 'package:pg_management/data/models/payment_history_model.dart';
import 'package:pg_management/data/models/room_config_model.dart';
import 'package:pg_management/data/models/student_model.dart';
import 'package:pg_management/logic/providers/student_provider.dart';

void main() {
  late Directory tempDir;
  final studentRepo = StudentRepository();
  final roomRepo = RoomRepository();
  final historyRepo = PaymentHistoryRepository();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('pgpilot_studentupdate');
    DatabaseHelper.databasePathOverride = '${tempDir.path}/pg_management.db';
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    final db = await DatabaseHelper().database;
    await db.delete('payment_history');
    await db.delete('students');
    await db.delete('rooms');
    // 101 has a free bed; 102 is a single that is already occupied.
    await roomRepo.insertRoom(
        RoomConfigModel(roomNumber: '101', capacity: 2, price: 5000));
    await roomRepo.insertRoom(
        RoomConfigModel(roomNumber: '102', capacity: 1, price: 6000));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Asha'));
    await studentRepo.insertStudent(StudentModel(roomNumber: '102', name: 'Bhavna'));
  });

  Future<StudentModel> asha() async =>
      (await studentRepo.getAllStudents()).firstWhere((s) => s.name == 'Asha');

  test('moving a student into a room with space succeeds', () async {
    final provider = StudentProvider();
    await provider.loadStudents();

    final failure =
        await provider.updateStudent((await asha()).copyWith(roomNumber: '101'));
    expect(failure, isNull);
  });

  test('moving a student into a full room is refused', () async {
    final provider = StudentProvider();
    await provider.loadStudents();

    final failure =
        await provider.updateStudent((await asha()).copyWith(roomNumber: '102'));

    expect(failure, contains('is full'));
    // Nothing moved.
    expect((await asha()).roomNumber, '101');
  });

  test('moving a student into a room that does not exist is refused', () async {
    final provider = StudentProvider();
    await provider.loadStudents();

    final failure =
        await provider.updateStudent((await asha()).copyWith(roomNumber: '999'));

    expect(failure, contains('does not exist'));
    expect((await asha()).roomNumber, '101');
  });

  test('editing other details in an over-full room still saves', () async {
    // Force 101 over its capacity, the way older data or a shrunk room could.
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Chitra'));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Divya'));

    final provider = StudentProvider();
    await provider.loadStudents();

    // Same room, so the capacity guard must not block an unrelated edit.
    final failure = await provider
        .updateStudent((await asha()).copyWith(contact: '9999999999'));

    expect(failure, isNull);
    expect((await asha()).contact, '9999999999');
  });

  test('deleting a student takes their rent history with them', () async {
    final target = await asha();
    await historyRepo.insertPaymentRecord(PaymentHistoryModel(
      studentId: target.id!,
      month: '2025-08',
      paymentStatus: 'Paid',
      paymentMode: 'Cash',
      cashAmount: 5000,
      amountDue: 5000,
    ));
    expect(await historyRepo.getStudentPaymentHistory(target.id!), isNotEmpty);

    final provider = StudentProvider();
    await provider.loadStudents();
    await provider.deleteStudent(target.id!);

    // sqflite runs with foreign keys off, so the declared ON DELETE CASCADE
    // never fired and these rows used to outlive the student.
    expect(await historyRepo.getStudentPaymentHistory(target.id!), isEmpty);
  });

  test('an edit preserves rent already collected this month', () async {
    final withPayment = (await asha()).copyWith(
      rentStatus: 'Partial',
      paymentMode: 'Cash',
      amountPaid: 2000,
    );
    await studentRepo.updateStudent(withPayment);

    final provider = StudentProvider();
    await provider.loadStudents();

    // An edit that touches only the phone number must not disturb the money.
    final failure = await provider
        .updateStudent(withPayment.copyWith(contact: '8888888888'));

    expect(failure, isNull);
    final saved = await asha();
    expect(saved.amountPaid, 2000);
    expect(saved.rentStatus, 'Partial');
  });
}
