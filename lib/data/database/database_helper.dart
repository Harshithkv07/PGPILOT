// Keep this import even though sqflite_common_ffi re-exports the same symbols:
// on Android/iOS it is what installs the default mobile databaseFactory.
// ignore: unnecessary_import
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows/Linux/macOS
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    String path = join(await getDatabasesPath(), 'pg_management.db');
    
    final db = await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create students table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_number INTEGER NOT NULL,
        name TEXT NOT NULL,
        dob TEXT NOT NULL,
        contact TEXT NOT NULL,
        father_name TEXT NOT NULL,
        father_number TEXT NOT NULL,
        mother_name TEXT NOT NULL,
        mother_number TEXT NOT NULL,
        college TEXT NOT NULL,
        hometown TEXT NOT NULL,
        address TEXT NOT NULL,
        advance_amount TEXT NOT NULL,
        rent_status TEXT DEFAULT 'Pending',
        payment_mode TEXT DEFAULT '-',
        aadhar_card TEXT,
        aadhar_name TEXT,
        student_picture TEXT,
        student_picture_name TEXT
      )
    ''');

    // Create rooms table
    await db.execute('''
      CREATE TABLE rooms (
        room_number INTEGER PRIMARY KEY,
        capacity INTEGER NOT NULL,
        price INTEGER NOT NULL,
        eb_bill INTEGER DEFAULT 0
      )
    ''');

    // Create payment history table
    await db.execute('''
      CREATE TABLE payment_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        payment_mode TEXT NOT NULL,
        screenshot_path TEXT,
        paid_date TEXT,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // Create expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // Create daily_accounts table
    await db.execute('''
      CREATE TABLE daily_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        opening_balance REAL NOT NULL,
        closing_balance REAL,
        is_day_closed INTEGER DEFAULT 0
      )
    ''');

  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add payment_history table for version 2
      await db.execute('''
        CREATE TABLE payment_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          month TEXT NOT NULL,
          payment_status TEXT NOT NULL,
          payment_mode TEXT NOT NULL,
          screenshot_path TEXT,
          paid_date TEXT,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add expenses and daily_accounts tables for version 3
      await db.execute('''
        CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          note TEXT DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE daily_accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL UNIQUE,
          opening_balance REAL NOT NULL,
          closing_balance REAL,
          is_day_closed INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE students ADD COLUMN aadhar_card TEXT');
      await db.execute('ALTER TABLE students ADD COLUMN aadhar_name TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE students ADD COLUMN student_picture TEXT');
      await db.execute('ALTER TABLE students ADD COLUMN student_picture_name TEXT');
      await db.execute('ALTER TABLE rooms ADD COLUMN eb_bill INTEGER DEFAULT 0');
    }
    if (oldVersion < 6) {
      // One-time reset: earlier versions seeded demo students, rooms, expenses
      // and daily accounts. Clear them so the app starts genuinely empty.
      await db.delete('payment_history');
      await db.delete('students');
      await db.delete('expenses');
      await db.delete('daily_accounts');
      await db.delete('rooms');
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
