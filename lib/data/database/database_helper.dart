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
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _insertMockDataIfNeeded(db);
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

    // Insert default room configurations
    await _insertDefaultRooms(db);
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
  }

  Future<void> _insertDefaultRooms(Database db) async {
    final defaultRooms = [
      {'room_number': 101, 'capacity': 1, 'price': 8000},
      {'room_number': 102, 'capacity': 2, 'price': 6000},
      {'room_number': 103, 'capacity': 2, 'price': 6000},
      {'room_number': 104, 'capacity': 3, 'price': 5000},
      {'room_number': 105, 'capacity': 3, 'price': 5000},
      {'room_number': 201, 'capacity': 1, 'price': 8500},
      {'room_number': 202, 'capacity': 2, 'price': 6500},
      {'room_number': 203, 'capacity': 3, 'price': 5500},
      {'room_number': 204, 'capacity': 4, 'price': 4500},
      {'room_number': 205, 'capacity': 4, 'price': 4500},
    ];

    for (var room in defaultRooms) {
      await db.insert('rooms', room);
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  Future<void> _insertMockDataIfNeeded(Database db) async {
    final studentCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM students'),
    );
    if (studentCount != null && studentCount > 0) {
      return; // Already populated
    }

    // Insert mock students
    final students = [
      {
        'room_number': 101,
        'name': 'Aarav Mehta',
        'dob': '15/08/2003',
        'contact': '9876543210',
        'father_name': 'Rajesh Mehta',
        'father_number': '9876543211',
        'mother_name': 'Sunita Mehta',
        'mother_number': '9876543212',
        'college': 'IIT Bombay',
        'hometown': 'Mumbai',
        'address': 'Flat 402, Sea Breeze, Bandra',
        'advance_amount': '5000',
        'rent_status': 'Paid',
        'payment_mode': 'Google Pay'
      },
      {
        'room_number': 102,
        'name': 'Kabir Sharma',
        'dob': '22/11/2002',
        'contact': '8765432109',
        'father_name': 'Anil Sharma',
        'father_number': '8765432108',
        'mother_name': 'Preeti Sharma',
        'mother_number': '8765432107',
        'college': 'St. Xavier\'s College',
        'hometown': 'Pune',
        'address': '12, Rose Villa, Koregaon Park',
        'advance_amount': '5000',
        'rent_status': 'Pending',
        'payment_mode': '-'
      },
      {
        'room_number': 102,
        'name': 'Rohan Gupta',
        'dob': '05/04/2004',
        'contact': '7654321098',
        'father_name': 'Sanjay Gupta',
        'father_number': '7654321097',
        'mother_name': 'Kiran Gupta',
        'mother_number': '7654321096',
        'college': 'NMIMS',
        'hometown': 'Delhi',
        'address': 'Sector 15, Rohini',
        'advance_amount': '5000',
        'rent_status': 'Paid',
        'payment_mode': 'PhonePe'
      },
      {
        'room_number': 201,
        'name': 'Ishaan Verma',
        'dob': '10/09/2003',
        'contact': '6543210987',
        'father_name': 'Vikram Verma',
        'father_number': '6543210986',
        'mother_name': 'Anita Verma',
        'mother_number': '6543210985',
        'college': 'DJ Sanghvi',
        'hometown': 'Ahmedabad',
        'address': '34, Shanti Nagar',
        'advance_amount': '6000',
        'rent_status': 'Pending',
        'payment_mode': '-'
      },
      {
        'room_number': 203,
        'name': 'Aditya Rao',
        'dob': '18/01/2002',
        'contact': '9988776655',
        'father_name': 'Srinivas Rao',
        'father_number': '9988776654',
        'mother_name': 'Laxmi Rao',
        'mother_number': '9988776653',
        'college': 'IIT Bombay',
        'hometown': 'Hyderabad',
        'address': 'Jubilee Hills',
        'advance_amount': '5000',
        'rent_status': 'Paid',
        'payment_mode': 'Cash'
      }
    ];

    final studentIds = <int>[];
    for (var student in students) {
      final id = await db.insert('students', student);
      studentIds.add(id);
    }

    // Insert payment history
    final paymentHistories = [
      {
        'student_id': studentIds[0],
        'month': '2026-06',
        'payment_status': 'Paid',
        'payment_mode': 'Google Pay',
        'screenshot_path': null,
        'paid_date': '05/06/2026'
      },
      {
        'student_id': studentIds[0],
        'month': '2026-05',
        'payment_status': 'Paid',
        'payment_mode': 'Google Pay',
        'screenshot_path': null,
        'paid_date': '04/05/2026'
      },
      {
        'student_id': studentIds[1],
        'month': '2026-05',
        'payment_status': 'Paid',
        'payment_mode': 'Cash',
        'screenshot_path': null,
        'paid_date': '07/05/2026'
      },
      {
        'student_id': studentIds[2],
        'month': '2026-06',
        'payment_status': 'Paid',
        'payment_mode': 'PhonePe',
        'screenshot_path': null,
        'paid_date': '03/06/2026'
      },
      {
        'student_id': studentIds[2],
        'month': '2026-05',
        'payment_status': 'Paid',
        'payment_mode': 'PhonePe',
        'screenshot_path': null,
        'paid_date': '02/05/2026'
      },
      {
        'student_id': studentIds[4],
        'month': '2026-06',
        'payment_status': 'Paid',
        'payment_mode': 'Cash',
        'screenshot_path': null,
        'paid_date': '10/06/2026'
      },
    ];

    for (var ph in paymentHistories) {
      await db.insert('payment_history', ph);
    }

    // Insert expenses
    final expenses = [
      {
        'date': '2026-06-17',
        'amount': 1500.0,
        'category': 'Utilities',
        'note': 'High-speed WiFi bill',
        'created_at': '2026-06-17 10:00:00'
      },
      {
        'date': '2026-06-18',
        'amount': 1200.0,
        'category': 'Maintenance',
        'note': 'Plumbing repairs room 102',
        'created_at': '2026-06-18 14:30:00'
      },
      {
        'date': '2026-06-19',
        'amount': 3500.0,
        'category': 'Food',
        'note': 'Groceries & Milk supply',
        'created_at': '2026-06-19 09:15:00'
      },
      {
        'date': '2026-06-19',
        'amount': 600.0,
        'category': 'Others',
        'note': 'Cleaning materials',
        'created_at': '2026-06-19 11:45:00'
      }
    ];

    for (var expense in expenses) {
      await db.insert('expenses', expense);
    }

    // Insert daily accounts
    final dailyAccounts = [
      {
        'date': '2026-06-17',
        'opening_balance': 25000.0,
        'closing_balance': 23500.0,
        'is_day_closed': 1
      },
      {
        'date': '2026-06-18',
        'opening_balance': 23500.0,
        'closing_balance': 22300.0,
        'is_day_closed': 1
      },
      {
        'date': '2026-06-19',
        'opening_balance': 22300.0,
        'closing_balance': null,
        'is_day_closed': 0
      }
    ];

    for (var da in dailyAccounts) {
      await db.insert('daily_accounts', da);
    }
  }
}
