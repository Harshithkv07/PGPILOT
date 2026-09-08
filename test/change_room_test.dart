// Moving a student between rooms, including the swap path used when the
// destination is full, and the mid-month re-pricing that follows a move.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/data/database/database_helper.dart';
import 'package:pg_management/data/database/room_repository.dart';
import 'package:pg_management/data/database/student_repository.dart';
import 'package:pg_management/data/models/room_config_model.dart';
import 'package:pg_management/data/models/student_model.dart';
import 'package:pg_management/logic/providers/student_provider.dart';

void main() {
  late Directory tempDir;
  final studentRepo = StudentRepository();
  final roomRepo = RoomRepository();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('pgpilot_changeroom');
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
    // 101: cheap, has room. 102: pricier single, occupied. 103: empty.
    await roomRepo.insertRoom(
        RoomConfigModel(roomNumber: '101', capacity: 3, price: 5000));
    await roomRepo.insertRoom(
        RoomConfigModel(roomNumber: '102', capacity: 1, price: 6000));
    await roomRepo.insertRoom(
        RoomConfigModel(roomNumber: '103', capacity: 2, price: 4000));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Asha'));
    await studentRepo.insertStudent(StudentModel(roomNumber: '102', name: 'Bhavna'));
  });

  Future<StudentModel> byName(String name) async =>
      (await studentRepo.getAllStudents()).firstWhere((s) => s.name == name);

  test('a student moves into a room with a free bed', () async {
    final provider = StudentProvider();
    await provider.loadStudents();

    final failure = await provider.moveStudent((await byName('Asha')).id!, '103');

    expect(failure, isNull);
    expect((await byName('Asha')).roomNumber, '103');
  });

  test('moving into a full room is refused and nothing changes', () async {
    final provider = StudentProvider();
    await provider.loadStudents();

    final failure = await provider.moveStudent((await byName('Asha')).id!, '102');

    expect(failure, contains('is full'));
    expect((await byName('Asha')).roomNumber, '101');
    expect((await byName('Bhavna')).roomNumber, '102');
  });

  test('moving into a room that does not exist is refused', () async {
    final provider = StudentProvider();
    await provider.loadStudents();

    expect(
      await provider.moveStudent((await byName('Asha')).id!, '999'),
      contains('does not exist'),
    );
  });

  test('moving to the same room is a no-op, not an error', () async {
    final provider = StudentProvider();
    await provider.loadStudents();

    expect(await provider.moveStudent((await byName('Asha')).id!, '101'), isNull);
    expect((await byName('Asha')).roomNumber, '101');
  });

  test('a swap exchanges both rooms even though each is full for the other',
      () async {
    final provider = StudentProvider();
    await provider.loadStudents();

    final failure = await provider.swapStudents(
        (await byName('Asha')).id!, (await byName('Bhavna')).id!);

    expect(failure, isNull);
    expect((await byName('Asha')).roomNumber, '102');
    expect((await byName('Bhavna')).roomNumber, '101');
  });

  test('swapping two students in the same room is refused', () async {
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Chitra'));
    final provider = StudentProvider();
    await provider.loadStudents();

    expect(
      await provider.swapStudents(
          (await byName('Asha')).id!, (await byName('Chitra')).id!),
      contains('already in room'),
    );
  });

  test('moving to a pricier room re-bills the month and drops Paid to Partial',
      () async {
    // Asha has fully paid her ₹5000 room.
    await studentRepo.updateStudent((await byName('Asha')).copyWith(
      rentStatus: 'Paid',
      paymentMode: 'Cash',
      amountPaid: 5000,
    ));

    final provider = StudentProvider();
    await provider.loadStudents();
    // Free up the ₹6000 single first.
    await provider.moveStudent((await byName('Bhavna')).id!, '103');
    await provider.moveStudent((await byName('Asha')).id!, '102');

    final asha = await byName('Asha');
    expect(asha.roomNumber, '102');
    // ₹5000 paid against a ₹6000 room is no longer settled.
    expect(asha.rentStatus, 'Partial');
    expect(asha.amountPaid, 5000);
  });

  test('moving to a cheaper room can settle the month outright', () async {
    await studentRepo.updateStudent((await byName('Asha')).copyWith(
      rentStatus: 'Partial',
      paymentMode: 'Cash',
      amountPaid: 4000,
    ));

    final provider = StudentProvider();
    await provider.loadStudents();
    // ₹4000 paid, moving into the ₹4000 room covers it in full.
    await provider.moveStudent((await byName('Asha')).id!, '103');

    expect((await byName('Asha')).rentStatus, 'Paid');
  });

  test('a move re-splits the EB bill for those left behind', () async {
    // 101 carries a ₹600 EB bill shared by three students -> ₹200 each.
    await roomRepo.updateRoom(RoomConfigModel(
        roomNumber: '101', capacity: 3, price: 5000, ebBill: 600));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Chitra'));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Divya'));

    // Chitra paid exactly her share at three-way split: 5000 + 200.
    await studentRepo.updateStudent((await byName('Chitra')).copyWith(
      rentStatus: 'Paid',
      paymentMode: 'Cash',
      amountPaid: 5200,
    ));

    final provider = StudentProvider();
    await provider.loadStudents();
    await provider.moveStudent((await byName('Asha')).id!, '103');

    // Two left in 101 -> ₹300 EB each -> ₹5300 due, so ₹5200 no longer covers it.
    expect((await byName('Chitra')).rentStatus, 'Partial');
  });
}
