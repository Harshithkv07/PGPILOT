// The v8 -> v9 upgrade adds the instalment table the daily cash book reads.
// It runs against live PG data, so it is exercised directly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/data/database/database_helper.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pgpilot_migration9');
    dbPath = '${tempDir.path}/test.db';
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('a v8 database gains rent_payments without losing anything', () async {
    // Build a v8-shaped database using the shipped callbacks.
    var db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: DatabaseHelper.onCreate,
        onUpgrade: DatabaseHelper.onUpgrade,
      ),
    );
    // v8's onCreate is today's schema, so drop the new table to get a true v8.
    await db.execute('DROP TABLE rent_payments');
    await db.insert('rooms',
        {'room_number': '101', 'capacity': 2, 'price': 5000, 'eb_bill': 0});
    await db.insert('payment_history', {
      'student_id': 1,
      'month': '2025-08',
      'payment_status': 'Paid',
      'payment_mode': 'Cash',
      'cash_amount': 5000.0,
      'upi_amount': 0.0,
      'amount_due': 5000.0,
    });
    await db.close();

    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 9,
        onUpgrade: DatabaseHelper.onUpgrade,
      ),
    );

    final columns = (await db.rawQuery('PRAGMA table_info(rent_payments)'))
        .map((c) => c['name'])
        .toList();
    expect(columns,
        containsAll(['student_id', 'month', 'paid_on', 'cash_amount', 'upi_amount']));

    // The month rollup is untouched — nothing that reads it changes.
    final history = await db.query('payment_history');
    expect(history.length, 1);
    expect(history.first['cash_amount'], 5000.0);
    expect((await db.query('rooms')).length, 1);

    await db.close();
  });

  test('a fresh database already has rent_payments and its index', () async {
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: DatabaseHelper.onCreate,
        onUpgrade: DatabaseHelper.onUpgrade,
      ),
    );

    await db.insert('rent_payments', {
      'student_id': 1,
      'month': '2026-09',
      'paid_on': '2026-09-09',
      'cash_amount': 1200.0,
      'upi_amount': 0.0,
    });

    final rows = await db.query('rent_payments');
    expect(rows.length, 1);
    expect(rows.first['paid_on'], '2026-09-09');

    final indexes = await db.rawQuery('PRAGMA index_list(rent_payments)');
    expect(indexes.map((i) => i['name']),
        contains('idx_rent_payments_paid_on'));

    await db.close();
  });
}
