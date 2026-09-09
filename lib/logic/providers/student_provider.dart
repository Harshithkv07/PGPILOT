import 'package:flutter/material.dart';
import '../../data/models/student_model.dart';
import '../../data/models/room_config_model.dart';
import '../../data/database/student_repository.dart';
import '../../data/database/room_repository.dart';
import '../../data/database/payment_history_repository.dart';
import '../../data/services/file_storage_service.dart';
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
  final PaymentHistoryRepository _paymentHistoryRepo = PaymentHistoryRepository();
  final FileStorageService _files = FileStorageService();
  
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

  /// Add a student, checking the room exists and has a free bed.
  ///
  /// Returns null on success, or the reason it was refused — "room is full"
  /// and "no such room" are different problems and used to surface the same
  /// misleading capacity message.
  Future<String?> addStudent(StudentModel student) async {
    try {
      final room = await _roomRepo.getRoomByNumber(student.roomNumber);
      if (room == null) {
        return 'Room ${student.roomNumber} does not exist. Add it on the Dashboard first.';
      }

      final currentOccupancy = await _studentRepo.getRoomOccupancy(student.roomNumber);
      if (currentOccupancy >= room.capacity) {
        return 'Room ${student.roomNumber} is full ($currentOccupancy of ${room.capacity} beds taken).';
      }

      await _studentRepo.insertStudent(student);
      await loadStudents();
      return null;
    } catch (e) {
      debugPrint('Error adding student: $e');
      return 'Could not add student.';
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

  /// Save an edited student. Returns null on success, or a message explaining
  /// why the edit was rejected.
  ///
  /// Adding a student has always checked room capacity, but editing one did
  /// not — so changing a room number here could put a fifth person in a
  /// four-bed room, or move them into a room that does not exist (which then
  /// bills them nothing). The check only runs when the room actually changes,
  /// so unrelated edits to someone already in an over-full room still save.
  Future<String?> updateStudent(StudentModel student) async {
    try {
      final current = await _studentRepo.getStudentById(student.id!);
      final movingRoom = current != null && current.roomNumber != student.roomNumber;

      if (movingRoom) {
        final room = await _roomRepo.getRoomByNumber(student.roomNumber);
        if (room == null) {
          return 'Room ${student.roomNumber} does not exist.';
        }
        final occupancy = await _studentRepo.getRoomOccupancy(student.roomNumber);
        if (occupancy >= room.capacity) {
          return 'Room ${student.roomNumber} is full (${room.capacity} beds).';
        }
      }

      await _studentRepo.updateStudent(student);
      await loadStudents();
      return null;
    } catch (e) {
      debugPrint('Error updating student: $e');
      return 'Could not save changes.';
    }
  }

  /// Move [studentId] into [toRoom]. Returns null on success, or the reason it
  /// was refused.
  ///
  /// Rent for the current month is recharged at the new room's rate, so a
  /// student who had fully paid a cheaper room becomes Partial rather than
  /// silently under-billed. Both rooms are recomputed because moving someone
  /// also changes how the EB bill splits for everyone left behind.
  Future<String?> moveStudent(int studentId, String toRoom) async {
    try {
      final student = await _studentRepo.getStudentById(studentId);
      if (student == null) return 'That student no longer exists.';
      if (student.roomNumber == toRoom) return null;

      final room = await _roomRepo.getRoomByNumber(toRoom);
      if (room == null) return 'Room $toRoom does not exist.';

      final occupancy = await _studentRepo.getRoomOccupancy(toRoom);
      if (occupancy >= room.capacity) {
        return 'Room $toRoom is full ($occupancy of ${room.capacity} beds taken).';
      }

      final fromRoom = student.roomNumber;
      await _studentRepo.updateStudent(student.copyWith(roomNumber: toRoom));
      await _recomputeRentStatusFor({fromRoom, toRoom});
      await loadStudents();
      return null;
    } catch (e) {
      debugPrint('Error moving student: $e');
      return 'Could not move that student.';
    }
  }

  /// Exchange the rooms of two students. Used when the destination is full but
  /// the manager wants them to trade places anyway.
  Future<String?> swapStudents(int firstId, int secondId) async {
    try {
      final first = await _studentRepo.getStudentById(firstId);
      final second = await _studentRepo.getStudentById(secondId);
      if (first == null || second == null) return 'One of those students no longer exists.';
      if (first.roomNumber == second.roomNumber) {
        return 'Both students are already in room ${first.roomNumber}.';
      }

      await _studentRepo.swapRooms(
          firstId, second.roomNumber, secondId, first.roomNumber);
      await _recomputeRentStatusFor({first.roomNumber, second.roomNumber});
      await loadStudents();
      return null;
    } catch (e) {
      debugPrint('Error swapping students: $e');
      return 'Could not swap those students.';
    }
  }

  /// Re-derive Paid / Partial / Pending for everyone in [rooms] against what
  /// their room now costs, EB share included.
  Future<void> _recomputeRentStatusFor(Set<String> rooms) async {
    for (final roomNumber in rooms) {
      final room = await _roomRepo.getRoomByNumber(roomNumber);
      if (room == null) continue;

      final occupants = await _studentRepo.getStudentsByRoom(roomNumber);
      if (occupants.isEmpty) continue;

      final ebShare = room.ebBill > 0 ? (room.ebBill / occupants.length).round() : 0;
      final due = room.price + ebShare;

      for (final occupant in occupants) {
        final status = occupant.amountPaid <= 0
            ? 'Pending'
            : (due > 0 && occupant.amountPaid >= due ? 'Paid' : 'Partial');
        if (status != occupant.rentStatus) {
          await _studentRepo.updateStudent(occupant.copyWith(rentStatus: status));
        }
      }
    }
  }

  /// Delete a student along with everything that belongs to them: rent
  /// history, instalments, and the documents stored on disk.
  ///
  /// payment_history declares ON DELETE CASCADE, but sqflite leaves foreign
  /// keys off by default, so those rows were never actually removed — they
  /// piled up pointing at students who no longer exist. The scanned Aadhaar,
  /// photo and payment screenshots were never cleaned up either, so a deleted
  /// student's documents stayed on the device indefinitely.
  Future<void> deleteStudent(int id) async {
    final student = await _studentRepo.getStudentById(id);
    final history = await _paymentHistoryRepo.getStudentPaymentHistory(id);

    await _paymentHistoryRepo.deleteStudentPaymentHistory(id);
    await _paymentHistoryRepo.deleteStudentInstalments(id);
    await _studentRepo.deleteStudent(id);

    // Files last: if anything here fails the database is already consistent,
    // and an orphaned file is a smaller problem than an orphaned record.
    try {
      for (final payment in history) {
        if (payment.screenshotPath != null) {
          await _files.deleteScreenshot(payment.screenshotPath!);
        }
      }
      if (student?.aadharName != null) {
        await _files.deleteAadharCard(student!.aadharName!);
      }
      if (student?.studentPictureName != null) {
        await _files.deleteStudentPicture(student!.studentPictureName!);
      }
    } catch (e) {
      debugPrint('Error removing files for student $id: $e');
    }

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
