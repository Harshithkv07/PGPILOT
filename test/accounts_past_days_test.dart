// Days are no longer explicitly "closed": a closing balance is derived from
// what the day opened with less what was spent, and any past day can be filled
// in after the fact. These tests cover both.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/data/database/accounts_repository.dart';
import 'package:pg_management/data/database/database_helper.dart';
import 'package:pg_management/logic/providers/accounts_provider.dart';

String _d(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

void main() {
  late Directory tempDir;
  final repo = AccountsRepository();

  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  final twoDaysAgo = today.subtract(const Duration(days: 2));

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('pgpilot_accounts');
    DatabaseHelper.databasePathOverride = '${tempDir.path}/pg_management.db';
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    final db = await DatabaseHelper().database;
    await db.delete('expenses');
    await db.delete('daily_accounts');
  });

  test('closing balance is derived, with no day needing to be closed', () async {
    final provider = AccountsProvider();
    await provider.loadDay(today);
    await provider.setOpeningBalance(5000);
    await provider.addExpense(1200, 'Groceries', 'vegetables');
    await provider.addExpense(300, 'Groceries', 'milk');

    expect(provider.totalExpensesToday, 1500);
    expect(provider.remainingBalance, 3500);
    // Same number, exposed under the name the rest of the app reads.
    expect(provider.closingBalance, 3500);

    // And it is live: deleting an expense moves it immediately.
    await provider.deleteExpense(provider.expenses.first.id!);
    expect(provider.closingBalance, greaterThan(3500));
  });

  test('a past day with no record can still be started and filled in', () async {
    final provider = AccountsProvider();
    await provider.loadDay(twoDaysAgo);

    expect(provider.todayAccount, isNull);
    expect(provider.isToday, isFalse);

    // Backdating: this used to be impossible — only today could be started.
    await provider.setOpeningBalance(2000);
    await provider.addExpense(750, 'Groceries', 'backfilled');

    expect(provider.todayAccount, isNotNull);
    expect(provider.remainingBalance, 1250);

    // It really landed on that date, not today.
    final stored = await repo.getDailyAccount(_d(twoDaysAgo));
    expect(stored!.openingBalance, 2000);
    expect(await repo.getTotalExpensesForDate(_d(twoDaysAgo)), 750);
    expect(await repo.getDailyAccount(_d(today)), isNull);
  });

  test('carry-forward uses the previous day, closed or not', () async {
    final provider = AccountsProvider();
    await provider.loadDay(yesterday);
    await provider.setOpeningBalance(4000);
    await provider.addExpense(1000, 'Groceries', '');

    // Nothing was "closed" — the suggestion still works.
    await provider.loadDay(today);
    expect(await provider.getPreviousClosingBalance(), 3000);
  });

  test('goToDate jumps to a past day and refuses the future', () async {
    final provider = AccountsProvider();
    await provider.loadDay(today);

    provider.goToDate(twoDaysAgo);
    await Future<void>.delayed(Duration.zero);
    expect(_d(provider.selectedDate), _d(twoDaysAgo));

    final beforeJump = provider.selectedDate;
    provider.goToDate(today.add(const Duration(days: 5)));
    expect(provider.selectedDate, beforeJump);
  });

  test('the balance trend covers every recorded day, not just closed ones',
      () async {
    final provider = AccountsProvider();

    await provider.loadDay(twoDaysAgo);
    await provider.setOpeningBalance(3000);
    await provider.addExpense(500, 'Groceries', '');

    await provider.loadDay(yesterday);
    await provider.setOpeningBalance(2500);
    await provider.addExpense(400, 'Groceries', '');

    final month = DateFormat('yyyy-MM').format(twoDaysAgo);
    // Only assert when the seeded days share the month the trend is read for.
    if (DateFormat('yyyy-MM').format(yesterday) == month) {
      final trend = await provider.getMonthlyClosingTrend(month);
      expect(trend, containsAllInOrder(<double>[2500, 2100]));
    }
  });

  test('expense totals per date come back grouped for the whole month',
      () async {
    final provider = AccountsProvider();
    await provider.loadDay(today);
    await provider.setOpeningBalance(1000);
    await provider.addExpense(120, 'Groceries', '');
    await provider.addExpense(80, 'Groceries', '');

    final totals = await repo.getExpenseTotalsByDate(
        DateFormat('yyyy-MM').format(today));
    expect(totals[_d(today)], 200);
  });
}
