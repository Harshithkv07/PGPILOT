import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student_model.dart';
import '../models/room_config_model.dart';

class ExcelService {
  Future<String> exportStudentsToExcel(
    List<StudentModel> students,
    Map<String, RoomConfigModel> roomsMap,
  ) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Students'];

    // Add headers
    sheetObject.appendRow([
      TextCellValue('Room No'),
      TextCellValue('Student Name'),
      TextCellValue('DOB'),
      TextCellValue('Contact'),
      TextCellValue('Father Name'),
      TextCellValue('Father Number'),
      TextCellValue('Mother Name'),
      TextCellValue('Mother Number'),
      TextCellValue('College/Workplace'),
      TextCellValue('Hometown'),
      TextCellValue('Address'),
      TextCellValue('Advance Amount'),
      TextCellValue('Aadhar Card'),
      TextCellValue('Student Picture'),
      TextCellValue('Room Capacity'),
      TextCellValue('Room Price'),
      TextCellValue('EB Bill'),
      TextCellValue('Rent Status'),
      TextCellValue('Payment Mode'),
      TextCellValue('Paid This Month'),
      TextCellValue('Balance Due'),
    ]);

    // Add student data
    for (var student in students) {
      final room = roomsMap[student.roomNumber];
      sheetObject.appendRow([
        TextCellValue(student.roomNumber),
        TextCellValue(student.name),
        TextCellValue(student.dob),
        TextCellValue(student.contact),
        TextCellValue(student.fatherName),
        TextCellValue(student.fatherNumber),
        TextCellValue(student.motherName),
        TextCellValue(student.motherNumber),
        TextCellValue(student.college),
        TextCellValue(student.hometown),
        TextCellValue(student.address),
        TextCellValue(student.advanceAmount),
        TextCellValue(student.aadharName != null ? 'Attached' : 'Pending'),
        TextCellValue(student.studentPictureName != null ? 'Attached' : 'Pending'),
        IntCellValue(room?.capacity ?? 0),
        IntCellValue(room?.price ?? 0),
        IntCellValue(room?.ebBill ?? 0),
        TextCellValue(student.rentStatus),
        TextCellValue(student.paymentMode),
        IntCellValue(student.amountPaid.round()),
        IntCellValue(_balanceDue(student, room)),
      ]);
    }

    // Save file
    Directory? baseDir;
    try {
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          baseDir = Directory('${downloadDir.path}/PGPilot');
        } else {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            baseDir = Directory('${extDir.path}/PGPilot');
          }
        }
      }
    } catch (e) {
      print('Error accessing external storage path: $e');
    }

    if (baseDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      baseDir = Directory('${appDir.path}/PGPilot');
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${baseDir.path}/students_$timestamp.xlsx';
    
    final fileBytes = excel.save();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }

    return filePath;
  }

  /// What a student still owes this month: room rent (EB bill excluded, since
  /// the per-head share depends on how many people share the room) minus what
  /// has been paid so far. Never negative.
  int _balanceDue(StudentModel student, RoomConfigModel? room) {
    final due = (room?.price ?? 0) - student.amountPaid;
    return due > 0 ? due.round() : 0;
  }
}
