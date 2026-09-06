import 'package:flutter/material.dart';
import '../../data/models/student_model.dart';
import '../../data/models/room_config_model.dart';
import '../../data/database/student_repository.dart';
import '../../data/database/room_repository.dart';
import '../../data/services/student_import_service.dart';

/// Outcome of a CSV import, so the UI can tell the user exactly what happened.
class ImportResult {
  final int added;
  final List<String> roomsCreated;
  final List<String> skipped;

  ImportResult({required this.added, required this.roomsCreated, required this.skipped});
}

class StudentProvider with ChangeNotifier {
  final StudentRepository _studentRepo = StudentRepository();
  final RoomRepository _roomRepo = RoomRepository();
  
  List<StudentModel> _students = [];
  List<StudentModel> _filteredStudents = [];
  bool _isLoading = false;

  List<StudentModel> get students => _filteredStudents;
  bool get isLoading => _isLoading;

  // Load all students
  Future<void> loadStudents() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _students = await _studentRepo.getAllStudents();
      _filteredStudents = List.from(_students);
    } catch (e) {
      print('Error loading students: $e');
      _students = [];
      _filteredStudents = [];
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Add student with room capacity validation
  Future<bool> addStudent(StudentModel student) async {
    try {
      // Check room capacity
      final room = await _roomRepo.getRoomByNumber(student.roomNumber);
      if (room == null) {
        print('Room ${student.roomNumber} does not exist');
        return false; // Room doesn't exist
      }
      
      final currentOccupancy = await _studentRepo.getRoomOccupancy(student.roomNumber);
      if (currentOccupancy >= room.capacity) {
        print('Room ${student.roomNumber} is full (${currentOccupancy}/${room.capacity})');
        return false; // Room is full
      }
      
      // Add student
      final id = await _studentRepo.insertStudent(student);
      print('Student added successfully with ID: $id');
      await loadStudents();
      return true;
    } catch (e) {
      print('Error adding student: $e');
      return false;
    }
  }

  /// Bulk-adds students read from a CSV.
  ///
  /// Rooms named in the import that don't exist yet are created automatically,
  /// sized to hold everyone the import puts in them (price 0 — set later via
  /// Set Prices). Existing rooms keep their configured capacity, so anyone who
  /// would overflow one is reported back rather than silently dropped.
  Future<ImportResult> importStudents(List<ImportRow> rows) async {
    final created = <String>[];
    final skipped = <String>[];
    var added = 0;

    try {
      // How many students does the import want in each room?
      final wantedPerRoom = <String, int>{};
      for (final row in rows) {
        wantedPerRoom[row.roomNumber] = (wantedPerRoom[row.roomNumber] ?? 0) + 1;
      }

      // Create any room that doesn't exist yet, big enough for its intake.
      for (final entry in wantedPerRoom.entries) {
        final existing = await _roomRepo.getRoomByNumber(entry.key);
        if (existing == null) {
          await _roomRepo.insertRoom(RoomConfigModel(
            roomNumber: entry.key,
            capacity: entry.value,
            price: 0,
          ));
          created.add(entry.key);
        }
      }

      for (final row in rows) {
        final room = await _roomRepo.getRoomByNumber(row.roomNumber);
        if (room == null) {
          skipped.add('Line ${row.lineNumber}: ${row.name} — room ${row.roomNumber} could not be created');
          continue;
        }

        final occupancy = await _studentRepo.getRoomOccupancy(row.roomNumber);
        if (occupancy >= room.capacity) {
          skipped.add(
              'Line ${row.lineNumber}: ${row.name} — room ${row.roomNumber} is full (${room.capacity} beds)');
          continue;
        }

        await _studentRepo.insertStudent(
          StudentModel(name: row.name, roomNumber: row.roomNumber),
        );
        added++;
      }
    } catch (e) {
      debugPrint('Error importing students: $e');
      skipped.add('Import stopped early: $e');
    }

    await loadStudents();
    created.sort();
    return ImportResult(added: added, roomsCreated: created, skipped: skipped);
  }

  // Update student
  Future<void> updateStudent(StudentModel student) async {
    await _studentRepo.updateStudent(student);
    await loadStudents();
  }

  // Delete student
  Future<void> deleteStudent(int id) async {
    await _studentRepo.deleteStudent(id);
    await loadStudents();
  }

  // Search students
  void searchStudents(String query) {
    if (query.isEmpty) {
      _filteredStudents = List.from(_students);
    } else {
      _filteredStudents = _students.where((student) {
        return student.name.toLowerCase().contains(query.toLowerCase()) ||
               student.contact.contains(query) ||
               student.roomNumber.toString().contains(query);
      }).toList();
    }
    notifyListeners();
  }

  // Get students by room
  Future<List<StudentModel>> getStudentsByRoom(String roomNumber) async {
    return await _studentRepo.getStudentsByRoom(roomNumber);
  }
}
