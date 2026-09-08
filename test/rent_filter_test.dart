// The rent ledger's filter: one tap should answer "who still owes me money?".
// Buckets must be mutually exclusive and add up, and the default ordering must
// put the people worth chasing at the top.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/data/database/database_helper.dart';
import 'package:pg_management/data/database/room_repository.dart';
import 'package:pg_management/data/database/student_repository.dart';
import 'package:pg_management/data/models/room_config_model.dart';
import 'package:pg_management/data/models/student_model.dart';
import 'package:pg_management/logic/providers/rent_provider.dart';

void main() {
  late Directory tempDir;
  final studentRepo = StudentRepository();
  final roomRepo = RoomRepository();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('pgpilot_rentfilter');
    DatabaseHelper.databasePathOverride = '${tempDir.path}/pg_management.db';
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseHelper().database;
    await db.delete('payment_history');
    await db.delete('students');
    await db.delete('rooms');
  });

  /// Three students in a ₹5000 room (no EB): one who has paid nothing, one who
  /// part-paid, and one who is settled.
  Future<RentProvider> seedLedger() async {
    await roomRepo.insertRoom(
        RoomConfigModel(roomNumber: '101', capacity: 5, price: 5000));
    // Deliberately out of alphabetical order to prove the sort does something.
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Zara'));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Asha'));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Meera'));

    final provider = RentProvider();
    await provider.loadStudents();

    final asha = provider.allStudents.firstWhere((s) => s.name == 'Asha');
    final meera = provider.allStudents.firstWhere((s) => s.name == 'Meera');

    await provider.recordPayment(studentId: asha.id!, cashAmount: 2000);
    await provider.recordPayment(studentId: meera.id!, cashAmount: 5000);
    return provider;
  }

  test('each bucket counts correctly and the buckets add up', () async {
    final provider = await seedLedger();

    expect(provider.countFor(RentFilter.all), 3);
    expect(provider.countFor(RentFilter.unpaid), 1); // Zara
    expect(provider.countFor(RentFilter.partial), 1); // Asha
    expect(provider.countFor(RentFilter.paid), 1); // Meera

    final sum = provider.countFor(RentFilter.unpaid) +
        provider.countFor(RentFilter.partial) +
        provider.countFor(RentFilter.paid);
    expect(sum, provider.countFor(RentFilter.all));
  });

  test('the Unpaid filter shows only people who have paid nothing', () async {
    final provider = await seedLedger();

    provider.setFilter(RentFilter.unpaid);
    expect(provider.students.map((s) => s.name), ['Zara']);
  });

  test('the Partial filter shows part payers', () async {
    final provider = await seedLedger();

    provider.setFilter(RentFilter.partial);
    expect(provider.students.map((s) => s.name), ['Asha']);
  });

  test('the Paid filter shows only settled students', () async {
    final provider = await seedLedger();

    provider.setFilter(RentFilter.paid);
    expect(provider.students.map((s) => s.name), ['Meera']);
  });

  test('the default view leads with whoever owes the most attention', () async {
    final provider = await seedLedger();

    // Nothing paid first, then part payers, then settled.
    expect(provider.students.map((s) => s.name), ['Zara', 'Asha', 'Meera']);
  });

  test('total outstanding sums what is actually still owed', () async {
    final provider = await seedLedger();

    // Zara owes 5000, Asha owes 3000, Meera owes nothing.
    expect(provider.totalOutstanding, 8000);
  });

  test('filtering never affects the revenue totals', () async {
    final provider = await seedLedger();

    final potential = provider.getPotentialRevenue();
    final collected = provider.getCollectedRevenue();

    provider.setFilter(RentFilter.paid);
    expect(provider.students.length, 1);
    expect(provider.getPotentialRevenue(), potential);
    expect(provider.getCollectedRevenue(), collected);
    expect(provider.totalOutstanding, 8000);
  });

  test('recording a payment moves a student between buckets', () async {
    final provider = await seedLedger();
    final zara = provider.allStudents.firstWhere((s) => s.name == 'Zara');

    await provider.recordPayment(studentId: zara.id!, upiAmount: 5000);

    expect(provider.countFor(RentFilter.unpaid), 0);
    expect(provider.countFor(RentFilter.paid), 2);
    expect(provider.totalOutstanding, 3000);
  });

  test('filter labels are the ones shown on the chips', () {
    expect(RentFilter.all.label, 'All');
    expect(RentFilter.unpaid.label, 'Unpaid');
    expect(RentFilter.partial.label, 'Partial');
    expect(RentFilter.paid.label, 'Paid');
  });
}
