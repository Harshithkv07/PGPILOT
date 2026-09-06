import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

class FileStorageService {
  // Get the base directory for screenshots (public directory preferred)
  Future<Directory> _getScreenshotsDirectory() async {
    Directory? baseDir;
    
    try {
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          baseDir = Directory(path.join(downloadDir.path, 'PGPilot', 'Screenshots'));
        } else {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            baseDir = Directory(path.join(extDir.path, 'PGPilot', 'Screenshots'));
          }
        }
      }
    } catch (e) {
      print('Error accessing external storage path: $e');
    }
    
    // Fallback for iOS, Windows, or if above checks failed/threw
    if (baseDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      baseDir = Directory(path.join(appDir.path, 'PGPilot', 'Screenshots'));
    }
    
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    
    return baseDir;
  }

  // Save payment screenshot with organized folder structure
  Future<String> savePaymentScreenshot({
    required String sourcePath,
    required String studentName,
    required String roomNumber,
    String? month, // Optional, defaults to current month
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      // Use provided month or current month
      final targetMonth = month ?? DateFormat('yyyy-MM').format(DateTime.now());
      
      // Create month-specific directory
      final screenshotsDir = await _getScreenshotsDirectory();
      final monthDir = Directory(path.join(screenshotsDir.path, targetMonth));
      
      if (!await monthDir.exists()) {
        await monthDir.create(recursive: true);
      }

      // Generate filename: studentname_roomXXX_timestamp.ext
      final extension = path.extension(sourcePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = studentName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final filename = '${sanitizedName}_room${roomNumber}_$timestamp$extension';
      
      // Copy file to destination
      final targetPath = path.join(monthDir.path, filename);
      await sourceFile.copy(targetPath);
      
      return targetPath;
    } catch (e) {
      print('Error saving payment screenshot: $e');
      rethrow;
    }
  }

  // Delete screenshot file
  Future<void> deleteScreenshot(String screenshotPath) async {
    try {
      final file = File(screenshotPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting screenshot: $e');
    }
  }

  // Get screenshot file if it exists
  Future<File?> getScreenshot(String screenshotPath) async {
    try {
      final file = File(screenshotPath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error getting screenshot: $e');
      return null;
    }
  }

  // Open screenshot in default viewer (cross-platform)
  Future<void> openScreenshot(String screenshotPath) async {
    try {
      final file = File(screenshotPath);
      if (await file.exists()) {
        // Platform-specific opening
        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', screenshotPath]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [screenshotPath]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [screenshotPath]);
        } else if (Platform.isAndroid || Platform.isIOS) {
          // Use open_filex on mobile platforms
          await OpenFilex.open(screenshotPath);
        }
      }
    } catch (e) {
      print('Error opening screenshot: $e');
    }
  }

  // Get all screenshots for a specific month
  Future<List<File>> getMonthScreenshots(String month) async {
    try {
      final screenshotsDir = await _getScreenshotsDirectory();
      final monthDir = Directory(path.join(screenshotsDir.path, month));
      
      if (!await monthDir.exists()) {
        return [];
      }

      final files = await monthDir.list().where((entity) => entity is File).cast<File>().toList();
      return files;
    } catch (e) {
      print('Error getting month screenshots: $e');
      return [];
    }
  }

  // Get the base directory for Aadhar Cards
  Future<Directory> _getAadharDirectory() async {
    Directory? baseDir;
    try {
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          baseDir = Directory(path.join(downloadDir.path, 'PGPilot', 'AadharCards'));
        } else {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            baseDir = Directory(path.join(extDir.path, 'PGPilot', 'AadharCards'));
          }
        }
      }
    } catch (e) {
      print('Error accessing external storage path: $e');
    }
    
    if (baseDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      baseDir = Directory(path.join(appDir.path, 'PGPilot', 'AadharCards'));
    }
    
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    
    return baseDir;
  }

  // Save Aadhar Card
  Future<Map<String, String>> saveAadharCard({
    required String sourcePath,
    required String studentName,
    required String roomNumber,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      final aadharDir = await _getAadharDirectory();
      
      final extension = path.extension(sourcePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = studentName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final filename = '${sanitizedName}_room${roomNumber}_$timestamp$extension';
      
      final targetPath = path.join(aadharDir.path, filename);
      await sourceFile.copy(targetPath);
      
      return {
        'path': targetPath,
        'name': filename,
      };
    } catch (e) {
      print('Error saving Aadhar card: $e');
      rethrow;
    }
  }

  // Get the base directory for Student Pictures
  Future<Directory> _getStudentPicturesDirectory() async {
    Directory? baseDir;
    try {
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          baseDir = Directory(path.join(downloadDir.path, 'PGPilot', 'StudentPictures'));
        } else {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            baseDir = Directory(path.join(extDir.path, 'PGPilot', 'StudentPictures'));
          }
        }
      }
    } catch (e) {
      print('Error accessing external storage path: $e');
    }
    
    if (baseDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      baseDir = Directory(path.join(appDir.path, 'PGPilot', 'StudentPictures'));
    }
    
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    
    return baseDir;
  }

  // Save Student Picture
  Future<Map<String, String>> saveStudentPicture({
    required String sourcePath,
    required String studentName,
    required String roomNumber,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      final picturesDir = await _getStudentPicturesDirectory();
      
      final extension = path.extension(sourcePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = studentName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final filename = '${sanitizedName}_room${roomNumber}_$timestamp$extension';
      
      final targetPath = path.join(picturesDir.path, filename);
      await sourceFile.copy(targetPath);
      
      return {
        'path': targetPath,
        'name': filename,
      };
    } catch (e) {
      print('Error saving student picture: $e');
      rethrow;
    }
  }

  // Delete generic file
  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  // Delete Aadhar Card
  Future<void> deleteAadharCard(String filename) async {
    try {
      final aadharDir = await _getAadharDirectory();
      final targetPath = path.join(aadharDir.path, filename);
      await deleteFile(targetPath);
    } catch (e) {
      print('Error deleting Aadhar card: $e');
    }
  }

  // Delete Student Picture
  Future<void> deleteStudentPicture(String filename) async {
    try {
      final picturesDir = await _getStudentPicturesDirectory();
      final targetPath = path.join(picturesDir.path, filename);
      await deleteFile(targetPath);
    } catch (e) {
      print('Error deleting student picture: $e');
    }
  }
}
