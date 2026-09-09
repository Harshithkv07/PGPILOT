// Search on the rent ledger and the room dashboard, plus the advance amount
// behaving like money instead of free text.
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
import 'package:pg_management/logic/providers/room_provider.dart';

void main() {
  late Directory tempDir;
  final studentRepo = StudentRepository();
  final roomRepo = RoomRepository();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('pgpilot_search');
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

    await roomRepo.insertRoom(
        RoomConfigModel(roomNumber: '101', capacity: 3, price: 5000));
    await roomRepo.insertRoom(
        RoomConfigModel(roomNumber: '202', capacity: 2, price: 6000));
    await studentRepo.insertStudent(StudentModel(
        roomNumber: '101', name: 'Asha Rao', contact: '9876500001'));
    await studentRepo.insertStudent(StudentModel(
        roomNumber: '202', name: 'Bhavna Iyer', contact: '9876500002'));
  });

  group('rent ledger search', () {
    test('matches on name, case-insensitively', () async {
      final provider = RentProvider();
      await provider.loadStudents();

      provider.setQuery('asha');
      expect(provider.students.map((s) => s.name), ['Asha Rao']);
    });

    test('matches on room number', () async {
      final provider = RentProvider();
      await provider.loadStudents();

      provider.setQuery('202');
      expect(provider.students.map((s) => s.name), ['Bhavna Iyer']);
    });

    test('matches on contact number', () async {
      final provider = RentProvider();
      await provider.loadStudents();

      provider.setQuery('9876500002');
      expect(provider.students.map((s) => s.name), ['Bhavna Iyer']);
    });

    test('search and filter narrow together', () async {
      final provider = RentProvider();
      await provider.loadStudents();

      provider.setQuery('a');
      provider.setFilter(RentFilter.paid);
      // Both match "a", but neither has paid.
      expect(provider.students, isEmpty);

      provider.setFilter(RentFilter.unpaid);
      expect(provider.students.length, 2);
    });

    test('clearing the query restores everyone', () async {
      final provider = RentProvider();
      await provider.loadStudents();

      provider.setQuery('asha');
      expect(provider.students.length, 1);
      provider.setQuery('');
      expect(provider.students.length, 2);
    });

    test('search never changes the totals', () async {
      final provider = RentProvider();
      await provider.loadStudents();
      final potential = provider.getPotentialRevenue();

      provider.setQuery('asha');
      expect(provider.getPotentialRevenue(), potential);
      expect(provider.totalOutstanding, 11000);
    });
  });

  group('room dashboard search', () {
    test('narrows rooms by number', () async {
      final provider = RoomProvider();
      await provider.loadRooms();

      provider.setQuery('202');
      expect(provider.rooms.map((r) => r.roomNumber), ['202']);
      expect(provider.allRooms.length, 2);
    });

    test('search combines with the availability filter', () async {
      // Fill 202 so it is no longer available.
      await studentRepo.insertStudent(StudentModel(roomNumber: '202', name: 'Chitra'));

      final provider = RoomProvider();
      await provider.loadRooms();

      provider.setFilter('available');
      provider.setQuery('202');
      expect(provider.rooms, isEmpty);

      provider.setQuery('101');
      expect(provider.rooms.map((r) => r.roomNumber), ['101']);
    });

    test('clearing the query restores every room', () async {
      final provider = RoomProvider();
      await provider.loadRooms();

      provider.setQuery('999');
      expect(provider.rooms, isEmpty);
      provider.setQuery('');
      expect(provider.rooms.length, 2);
    });
  });

  group('advance amount', () {
    test('parses a plain number', () {
      final student = StudentModel(
          roomNumber: '101', name: 'Asha', advanceAmount: '5000');
      expect(student.advanceAmountValue, 5000);
    });

    test('tolerates currency symbols and separators already in the data', () {
      final student = StudentModel(
          roomNumber: '101', name: 'Asha', advanceAmount: '₹ 12,500');
      expect(student.advanceAmountValue, 12500);
    });

    test('falls back to zero rather than throwing on junk', () {
      expect(
        StudentModel(roomNumber: '101', name: 'Asha', advanceAmount: 'paid later')
            .advanceAmountValue,
        0,
      );
      expect(
        StudentModel(roomNumber: '101', name: 'Asha').advanceAmountValue,
        0,
      );
    });

    test('advances can now be totalled across students', () {
      final students = [
        StudentModel(roomNumber: '101', name: 'A', advanceAmount: '5000'),
        StudentModel(roomNumber: '101', name: 'B', advanceAmount: '2500.50'),
        StudentModel(roomNumber: '101', name: 'C', advanceAmount: ''),
      ];
      final total =
          students.fold<double>(0, (sum, s) => sum + s.advanceAmountValue);
      expect(total, 7500.50);
    });
  });
}
