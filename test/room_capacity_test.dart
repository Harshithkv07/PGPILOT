// Editing a room's size from its card goes through RoomProvider.updateRoomDetails.
// The guard that matters is that a room can never be shrunk below the number of
// students already living in it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/data/database/database_helper.dart';
import 'package:pg_management/data/database/room_repository.dart';
import 'package:pg_management/data/database/student_repository.dart';
import 'package:pg_management/data/models/room_config_model.dart';
import 'package:pg_management/data/models/student_model.dart';
import 'package:pg_management/logic/providers/room_provider.dart';

void main() {
  late Directory tempDir;
  final roomRepo = RoomRepository();
  final studentRepo = StudentRepository();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Test files run in parallel, so point the singleton at a file of this
    // suite's own rather than the shared default.
    tempDir = Directory.systemTemp.createTempSync('pgpilot_rooms');
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
    final db = await DatabaseHelper().database;
    await db.delete('payment_history');
    await db.delete('students');
    await db.delete('rooms');
    await roomRepo.insertRoom(RoomConfigModel(
      roomNumber: '101',
      capacity: 3,
      price: 5000,
      ebBill: 400,
    ));
  });

  test('a room can be resized, repriced and re-billed in one save', () async {
    final provider = RoomProvider();
    await provider.loadRooms();

    final failure = await provider.updateRoomDetails(
      roomNumber: '101',
      capacity: 5,
      price: 6500,
      ebBill: 900,
    );

    expect(failure, isNull);

    final saved = await roomRepo.getRoomByNumber('101');
    expect(saved!.capacity, 5);
    expect(saved.price, 6500);
    expect(saved.ebBill, 900);

    // The provider's in-memory copy is refreshed too, so the card redraws.
    expect(provider.getRoomByNumber('101')!.capacity, 5);
    expect(provider.getTotalCapacity(), 5);
  });

  test('a room can shrink down to exactly its occupancy', () async {
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Asha'));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Bhavna'));

    final provider = RoomProvider();
    await provider.loadRooms();

    final failure = await provider.updateRoomDetails(
      roomNumber: '101',
      capacity: 2,
      price: 5000,
      ebBill: 400,
    );

    expect(failure, isNull);
    expect((await roomRepo.getRoomByNumber('101'))!.capacity, 2);
  });

  test('shrinking below the students living there is refused', () async {
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Asha'));
    await studentRepo.insertStudent(StudentModel(roomNumber: '101', name: 'Bhavna'));

    final provider = RoomProvider();
    await provider.loadRooms();

    final failure = await provider.updateRoomDetails(
      roomNumber: '101',
      capacity: 1,
      price: 5000,
      ebBill: 400,
    );

    expect(failure, contains('already has 2 students'));
    // Nothing was written.
    expect((await roomRepo.getRoomByNumber('101'))!.capacity, 3);
  });

  test('nonsense values are rejected before they reach the database', () async {
    final provider = RoomProvider();
    await provider.loadRooms();

    expect(
      await provider.updateRoomDetails(
          roomNumber: '101', capacity: 0, price: 5000, ebBill: 0),
      contains('at least 1 bed'),
    );
    expect(
      await provider.updateRoomDetails(
          roomNumber: '101', capacity: 3, price: -1, ebBill: 0),
      contains('Rent cannot be negative'),
    );
    expect(
      await provider.updateRoomDetails(
          roomNumber: '101', capacity: 3, price: 5000, ebBill: -50),
      contains('EB bill cannot be negative'),
    );

    final unchanged = await roomRepo.getRoomByNumber('101');
    expect(unchanged!.capacity, 3);
    expect(unchanged.price, 5000);
    expect(unchanged.ebBill, 400);
  });

  test('editing a room that no longer exists reports rather than throws',
      () async {
    final provider = RoomProvider();
    await provider.loadRooms();
    await roomRepo.deleteRoom('101');

    final failure = await provider.updateRoomDetails(
      roomNumber: '101',
      capacity: 4,
      price: 5000,
      ebBill: 0,
    );

    expect(failure, contains('no longer exists'));
  });
}
