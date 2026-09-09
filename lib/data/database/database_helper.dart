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

  /// Overrides where the database file lives. Only set by tests, so suites that
  /// run in parallel each get their own file instead of fighting over one.
  /// Must be set before the first [database] access.
  static String? databasePathOverride;

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
    
    String path =
        databasePathOverride ?? join(await getDatabasesPath(), 'pg_management.db');
    
    final db = await openDatabase(
      path,
      version: 9,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
    return db;
  }

  /// Schema for a brand new database. Static so migration tests can build a
  /// database without going through the singleton's fixed file path.
  static Future<void> onCreate(Database db, int version) async {
    // Create students table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_number TEXT NOT NULL,
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
        amount_paid REAL DEFAULT 0,
        aadhar_card TEXT,
        aadhar_name TEXT,
        student_picture TEXT,
        student_picture_name TEXT
      )
    ''');

    // Create rooms table
    await db.execute('''
      CREATE TABLE rooms (
        room_number TEXT PRIMARY KEY,
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
        cash_amount REAL DEFAULT 0,
        upi_amount REAL DEFAULT 0,
        amount_due REAL DEFAULT 0,
        screenshot_path TEXT,
        paid_date TEXT,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // Create rent_payments table
    await db.execute('''
      CREATE TABLE rent_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        paid_on TEXT NOT NULL,
        cash_amount REAL DEFAULT 0,
        upi_amount REAL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_rent_payments_paid_on ON rent_payments (paid_on)');

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

  /// Steps an existing database up to the current schema version.
  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
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
    if (oldVersion < 7) {
      // room_number becomes TEXT so zero-padded codes like "0002" keep their
      // leading zeros. SQLite can't change a column type in place, so both
      // tables are rebuilt and copied across.
      await db.execute('''
        CREATE TABLE rooms_new (
          room_number TEXT PRIMARY KEY,
          capacity INTEGER NOT NULL,
          price INTEGER NOT NULL,
          eb_bill INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        INSERT INTO rooms_new (room_number, capacity, price, eb_bill)
        SELECT CAST(room_number AS TEXT), capacity, price, eb_bill FROM rooms
      ''');
      await db.execute('DROP TABLE rooms');
      await db.execute('ALTER TABLE rooms_new RENAME TO rooms');

      // payment_history references students(id) ON DELETE CASCADE. Dropping
      // the students table below would wipe it if foreign key enforcement is
      // ever switched on, so stash the rows in a constraint-free table first
      // and put them back afterwards. CREATE TABLE ... AS SELECT carries no
      // foreign key, so the copy is immune to the cascade either way.
      await db.execute('CREATE TABLE ph_backup AS SELECT * FROM payment_history');

      await db.execute('''
        CREATE TABLE students_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          room_number TEXT NOT NULL,
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
      await db.execute('''
        INSERT INTO students_new
          SELECT id, CAST(room_number AS TEXT), name, dob, contact,
                 father_name, father_number, mother_name, mother_number,
                 college, hometown, address, advance_amount,
                 rent_status, payment_mode,
                 aadhar_card, aadhar_name, student_picture, student_picture_name
          FROM students
      ''');
      await db.execute('DROP TABLE students');
      await db.execute('ALTER TABLE students_new RENAME TO students');

      // Restore payment history in case the drop above cascaded it away.
      await db.execute('DELETE FROM payment_history');
      await db.execute('INSERT INTO payment_history SELECT * FROM ph_backup');
      await db.execute('DROP TABLE ph_backup');
    }
    if (oldVersion < 8) {
      // Partial payments: a month's rent can now be settled across several
      // instalments, each split between cash and UPI. students.amount_paid is
      // the running total for the *current* month; the payment_history columns
      // keep the same breakdown for every archived month.
      await db.execute('ALTER TABLE students ADD COLUMN amount_paid REAL DEFAULT 0');
      await db.execute('ALTER TABLE payment_history ADD COLUMN cash_amount REAL DEFAULT 0');
      await db.execute('ALTER TABLE payment_history ADD COLUMN upi_amount REAL DEFAULT 0');
      await db.execute('ALTER TABLE payment_history ADD COLUMN amount_due REAL DEFAULT 0');

      // Students already marked Paid predate amount tracking. Seed them with
      // their room's rent so the ledger doesn't read "0 of 5000 paid" for a
      // month that was in fact settled in full. Archived history rows are left
      // at 0 and rendered as "amount not recorded" rather than invented.
      await db.execute('''
        UPDATE students
           SET amount_paid = COALESCE(
                 (SELECT price FROM rooms WHERE rooms.room_number = students.room_number),
                 0)
         WHERE rent_status = 'Paid'
      ''');
    }
    if (oldVersion < 9) {
      // payment_history keeps one rolled-up row per student per month, so it
      // cannot say how much cash arrived on a given *day*. This records each
      // instalment as it happens, which is what the daily cash book needs.
      // The rollup is left untouched, so nothing that reads it changes.
      await db.execute('''
        CREATE TABLE rent_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          month TEXT NOT NULL,
          paid_on TEXT NOT NULL,
          cash_amount REAL DEFAULT 0,
          upi_amount REAL DEFAULT 0
        )
      ''');
      await db.execute(
          'CREATE INDEX idx_rent_payments_paid_on ON rent_payments (paid_on)');
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
