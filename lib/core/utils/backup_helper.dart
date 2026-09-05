import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class BackupHelper {
  // Get the default backup directory
  static Future<String> getBackupDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docsDir.path, 'PGPilot_Backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  // Generate a filename based on current timestamp
  static String generateBackupFilename() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy_MM_dd_HH_mm_ss');
    return 'pgpilot_backup_${formatter.format(now)}.db';
  }

  // Export database to a file
  static Future<bool> exportDatabase(String outputPath) async {
    try {
      final dbPath = p.join(await getDatabasesPath(), 'pg_management.db');
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) {
        print('Database file does not exist');
        return false;
      }
      
      await dbFile.copy(outputPath);
      return true;
    } catch (e) {
      print('Backup exception: $e');
      return false;
    }
  }

  // Import database from a file
  static Future<bool> importDatabase(String inputPath) async {
    try {
      final file = File(inputPath);
      if (!await file.exists()) {
        print('Import file does not exist.');
        return false;
      }

      final dbPath = p.join(await getDatabasesPath(), 'pg_management.db');
      final dbFile = File(dbPath);
      
      // Copy over the existing db
      await file.copy(dbFile.path);
      return true;
    } catch (e) {
      print('Import exception: $e');
      return false;
    }
  }

  // Run automated daily backup
  static Future<void> runAutomatedBackup() async {
    try {
      final backupDirPath = await getBackupDirectory();
      final backupDir = Directory(backupDirPath);
      
      // Get all existing backups
      final List<FileSystemEntity> entities = await backupDir.list().toList();
      final List<File> backupFiles = entities.whereType<File>().where((f) => f.path.endsWith('.db')).toList();
      
      // Sort by modified time descending
      backupFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // Check if we need to backup (if no backup in the last 24 hours)
      bool needsBackup = true;
      if (backupFiles.isNotEmpty) {
        final lastBackup = backupFiles.first;
        final difference = DateTime.now().difference(lastBackup.lastModifiedSync());
        if (difference.inHours < 24) {
          needsBackup = false;
        }
      }

      if (needsBackup) {
        final filename = generateBackupFilename();
        final success = await exportDatabase(p.join(backupDirPath, filename));
        if (success) {
          print('Automated backup completed: $filename');
          
          // Cleanup old backups (keep last 7)
          if (backupFiles.length >= 7) {
            for (int i = 6; i < backupFiles.length; i++) {
              await backupFiles[i].delete();
              print('Deleted old backup: ${backupFiles[i].path}');
            }
          }
        }
      }
    } catch (e) {
      print('Automated backup error: $e');
    }
  }
}
