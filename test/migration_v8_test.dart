// The v8 migration runs against live PG data, so it is exercised directly:
// build a v7-shaped database, upgrade it with the shipped callback, and check
// that the partial-payment columns arrive and existing rows survive intact.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/data/database/database_helper.dart';
import 'package:pg_management/data/models/payment_history_model.dart';
import 'package:pg_management/data/models/student_model.dart';

/// Creates a database with the schema as it stood at version 7.
Future<Database> _openV7(String path) async {
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(version: 7),
  );
  await db.execute('''
    CREATE TABLE rooms (
      room_number TEXT PRIMARY KEY,
      capacity INTEGER NOT NULL,
      price INTEGER NOT NULL,
      eb_bill INTEGER DEFAULT 0
    )''');
  await db.execute('''
    CREATE TABLE students (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_number TEXT NOT NULL, name TEXT NOT NULL, dob TEXT NOT NULL,
      contact TEXT NOT NULL, father_name TEXT NOT NULL, father_number TEXT NOT NULL,
      mother_name TEXT NOT NULL, mother_number TEXT NOT NULL, college TEXT NOT NULL,
      hometown TEXT NOT NULL, address TEXT NOT NULL, advance_amount TEXT NOT NULL,
      rent_status TEXT DEFAULT 'Pending', payment_mode TEXT DEFAULT '-',
      aadhar_card TEXT, aadhar_name TEXT, student_picture TEXT, student_picture_name TEXT
    )''');
  await db.execute('''
    CREATE TABLE payment_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL,
      month TEXT NOT NULL, payment_status TEXT NOT NULL, payment_mode TEXT NOT NULL,
      screenshot_path TEXT, paid_date TEXT
    )''');
  return db;
}

Map<String, Object?> _student(String name, String status, String mode) => {
      'room_number': '101',
      'name': name,
      'dob': '',
      'contact': '',
      'father_name': '',
      'father_number': '',
      'mother_name': '',
      'mother_number': '',
      'college': '',
      'hometown': '',
      'address': '',
      'advance_amount': '',
      'rent_status': status,
      'payment_mode': mode,
    };

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pgpilot_migration');
    dbPath = '${tempDir.path}/test.db';
  });

  tearDown(() {
    // Windows can still hold the sqlite file briefly after close(); a temp
    // directory left behind is harmless, a failed teardown is not.
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('v7 database upgrades to v8 with partial-payment columns', () async {
    var db = await _openV7(dbPath);
    await db.insert('rooms',
        {'room_number': '101', 'capacity': 3, 'price': 5000, 'eb_bill': 300});
    await db.insert('students', _student('Already Paid', 'Paid', 'Cash'));
    await db.insert('students', _student('Still Pending', 'Pending', '-'));
    await db.insert('payment_history', {
      'student_id': 1,
      'month': '2025-08',
      'payment_status': 'Paid',
      'payment_mode': 'Cash',
    });
    await db.close();

    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 8,
        onUpgrade: DatabaseHelper.onUpgrade,
      ),
    );

    final studentColumns = (await db.rawQuery('PRAGMA table_info(students)'))
        .map((c) => c['name'])
        .toList();
    expect(studentColumns, contains('amount_paid'));

    final historyColumns =
        (await db.rawQuery('PRAGMA table_info(payment_history)'))
            .map((c) => c['name'])
            .toList();
    expect(historyColumns, containsAll(['cash_amount', 'upi_amount', 'amount_due']));

    // Rows already marked Paid are backfilled with their room's rent so the
    // ledger doesn't read "₹0 of ₹5000 paid" for a settled month.
    final rows = await db.query('students', orderBy: 'id');
    expect(rows.length, 2);
    expect(StudentModel.fromMap(rows[0]).amountPaid, 5000);
    expect(StudentModel.fromMap(rows[1]).amountPaid, 0);

    // Archived history survives, with zeroed amounts it can render as
    // "amount not recorded" rather than a fabricated figure.
    final history = await db.query('payment_history');
    expect(history.length, 1);
    final archived = PaymentHistoryModel.fromMap(history.first);
    expect(archived.paymentStatus, 'Paid');
    expect(archived.hasAmountDetail, isFalse);

    await db.close();
  });

  test('a fresh v8 database has the partial-payment columns', () async {
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: DatabaseHelper.onCreate,
        onUpgrade: DatabaseHelper.onUpgrade,
      ),
    );

    await db.insert('students', {
      ..._student('New Student', 'Partial', 'Cash + UPI'),
      'amount_paid': 3500.0,
    });
    await db.insert('payment_history', {
      'student_id': 1,
      'month': '2025-09',
      'payment_status': 'Partial',
      'payment_mode': 'Cash + UPI',
      'cash_amount': 2000.0,
      'upi_amount': 1500.0,
      'amount_due': 5100.0,
    });

    final student = StudentModel.fromMap((await db.query('students')).first);
    expect(student.amountPaid, 3500);
    expect(student.rentStatus, 'Partial');

    final payment =
        PaymentHistoryModel.fromMap((await db.query('payment_history')).first);
    expect(payment.amountPaid, 3500);
    expect(payment.amountRemaining, 1600);
    expect(payment.hasAmountDetail, isTrue);

    await db.close();
  });

  test('mode label follows the cash/UPI split', () {
    expect(PaymentHistoryModel.modeFor(0, 0), '-');
    expect(PaymentHistoryModel.modeFor(500, 0), 'Cash');
    expect(PaymentHistoryModel.modeFor(0, 500), 'UPI');
    expect(PaymentHistoryModel.modeFor(200, 300), 'Cash + UPI');
  });

  test('amountRemaining never goes negative on an overpayment', () {
    final overpaid = PaymentHistoryModel(
      studentId: 1,
      month: '2025-09',
      paymentStatus: 'Paid',
      paymentMode: 'Cash',
      cashAmount: 6000,
      amountDue: 5000,
    );
    expect(overpaid.amountRemaining, 0);
  });
}
