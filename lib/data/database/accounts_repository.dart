import '../models/expense_model.dart';
import '../models/daily_account_model.dart';
import 'database_helper.dart';

class AccountsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Daily Account Operations ───

  Future<DailyAccountModel?> getDailyAccount(String date) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'daily_accounts',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isEmpty) return null;
    return DailyAccountModel.fromMap(maps.first);
  }

  Future<int> insertDailyAccount(DailyAccountModel account) async {
    final db = await _dbHelper.database;
    return await db.insert('daily_accounts', account.toMap());
  }

  Future<int> updateDailyAccount(DailyAccountModel account) async {
    final db = await _dbHelper.database;
    return await db.update(
      'daily_accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  /// Get the most recent day before [date].
  Future<DailyAccountModel?> getPreviousDay(String date) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'daily_accounts',
      where: 'date < ?',
      whereArgs: [date],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailyAccountModel.fromMap(maps.first);
  }

  // ─── Expense Operations ───

  Future<int> insertExpense(ExpenseModel expense) async {
    final db = await _dbHelper.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<int> updateExpense(ExpenseModel expense) async {
    final db = await _dbHelper.database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ExpenseModel>> getExpensesForDate(String date) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'expenses',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => ExpenseModel.fromMap(m)).toList();
  }

  Future<double> getTotalExpensesForDate(String date) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE date = ?',
      [date],
    );
    return (result.first['total'] as num).toDouble();
  }

  /// A day's closing balance, derived rather than stored: whatever it opened
  /// with, less everything spent that day. Days are no longer explicitly
  /// "closed", so this is always live and always correct.
  Future<double?> getClosingBalanceFor(String date) async {
    final account = await getDailyAccount(date);
    if (account == null) return null;
    final spent = await getTotalExpensesForDate(date);
    return account.openingBalance - spent;
  }

  /// Closing balance of the most recent day on record before [date], for
  /// carrying a balance forward into a day that hasn't been started yet.
  Future<double?> getPreviousClosingBalance(String date) async {
    final previous = await getPreviousDay(date);
    if (previous == null) return null;
    final spent = await getTotalExpensesForDate(previous.date);
    return previous.openingBalance - spent;
  }

  // ─── Monthly Summary Operations ───

  /// Total spent on each day of [month], keyed by YYYY-MM-DD. One grouped
  /// query instead of a per-day round trip.
  Future<Map<String, double>> getExpenseTotalsByDate(String month) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT date, SUM(amount) as total FROM expenses WHERE date LIKE ? GROUP BY date',
      ['$month%'],
    );
    return {
      for (final row in rows) row['date'] as String: (row['total'] as num).toDouble(),
    };
  }


  /// Returns a map of category → total amount for the given month (YYYY-MM).
  Future<Map<String, double>> getMonthlyExpenseByCategory(String month) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      "SELECT category, SUM(amount) as total FROM expenses WHERE date LIKE ? GROUP BY category",
      ['$month%'],
    );

    final Map<String, double> summary = {};
    for (var row in results) {
      summary[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return summary;
  }

  /// Returns total expenses for the given month (YYYY-MM).
  Future<double> getMonthlyTotalExpense(String month) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE date LIKE ?",
      ['$month%'],
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Get all daily accounts in a month for calendar/history view.
  Future<List<DailyAccountModel>> getDailyAccountsForMonth(String month) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'daily_accounts',
      where: "date LIKE ?",
      whereArgs: ['$month%'],
      orderBy: 'date ASC',
    );
    return maps.map((m) => DailyAccountModel.fromMap(m)).toList();
  }
}
