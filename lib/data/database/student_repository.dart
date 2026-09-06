import '../models/student_model.dart';
import 'database_helper.dart';

class StudentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Insert a new student
  Future<int> insertStudent(StudentModel student) async {
    final db = await _dbHelper.database;
    return await db.insert('students', student.toMap());
  }

  // Get all students
  Future<List<StudentModel>> getAllStudents() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('students');
    return List.generate(maps.length, (i) => StudentModel.fromMap(maps[i]));
  }

  // Get student by ID
  Future<StudentModel?> getStudentById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    return StudentModel.fromMap(maps.first);
  }

  // Get students by room number
  Future<List<StudentModel>> getStudentsByRoom(String roomNumber) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'room_number = ?',
      whereArgs: [roomNumber],
    );
    return List.generate(maps.length, (i) => StudentModel.fromMap(maps[i]));
  }

  // Search students by name, contact, or room number
  Future<List<StudentModel>> searchStudents(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'name LIKE ? OR contact LIKE ? OR CAST(room_number AS TEXT) LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => StudentModel.fromMap(maps[i]));
  }

  // Get students by rent status
  Future<List<StudentModel>> getStudentsByRentStatus(String status) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'rent_status = ?',
      whereArgs: [status],
    );
    return List.generate(maps.length, (i) => StudentModel.fromMap(maps[i]));
  }

  // Update student
  Future<int> updateStudent(StudentModel student) async {
    final db = await _dbHelper.database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  // Delete student
  Future<int> deleteStudent(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get count of students in a room
  Future<int> getRoomOccupancy(String roomNumber) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM students WHERE room_number = ?',
      [roomNumber],
    );
    return result.first['count'] as int;
  }

  // Update rent status for all students
  Future<void> resetAllRentStatus() async {
    final db = await _dbHelper.database;
    await db.update(
      'students',
      {'rent_status': 'Pending', 'payment_mode': '-'},
    );
  }
}
