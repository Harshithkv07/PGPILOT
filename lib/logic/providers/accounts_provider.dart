import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/daily_account_model.dart';
import '../../data/database/accounts_repository.dart';
import '../../data/database/payment_history_repository.dart';

class AccountsProvider with ChangeNotifier {
  final AccountsRepository _repo = AccountsRepository();
  final PaymentHistoryRepository _rentRepo = PaymentHistoryRepository();

  DateTime _selectedDate = DateTime.now();
  DailyAccountModel? _todayAccount;
  List<ExpenseModel> _expenses = [];
  bool _isLoading = false;

  DateTime get selectedDate => _selectedDate;
  DailyAccountModel? get todayAccount => _todayAccount;
  List<ExpenseModel> get expenses => _expenses;
  bool get isLoading => _isLoading;

  String get selectedDateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get selectedMonthStr => DateFormat('yyyy-MM').format(_selectedDate);

  double get totalExpensesToday =>
      _expenses.fold(0, (sum, e) => sum + e.amount);

  /// Cash rent taken on the selected day.
  ///
  /// Rent and the cash book used to be entirely separate: cash handed over by a
  /// student is money in the box, but the day's balance never knew about it.
  /// UPI is deliberately excluded — it never touches the cash box.
  double _rentCollectedToday = 0;
  double get rentCollectedToday => _rentCollectedToday;

  double get remainingBalance {
    if (_todayAccount == null) return 0;
    return _todayAccount!.openingBalance + _rentCollectedToday - totalExpensesToday;
  }

  /// The day's running balance: what it opened with, less what has been spent.
  /// Days are never "closed" — this is always live, for today and for any past
  /// day the user browses back to.
  double get closingBalance => remainingBalance;

  /// Load account and expenses for the selected date.
  Future<void> loadDay([DateTime? date]) async {
    if (date != null) _selectedDate = date;
    _isLoading = true;
    notifyListeners();

    final dateStr = selectedDateStr;
    _todayAccount = await _repo.getDailyAccount(dateStr);
    _expenses = await _repo.getExpensesForDate(dateStr);
    _rentCollectedToday = await _rentRepo.getCashCollectedOn(dateStr);

    _isLoading = false;
    notifyListeners();
  }

  /// The closing balance of the last day on record before the selected one,
  /// offered as the opening balance when starting a new day.
  Future<double?> getPreviousClosingBalance() async {
    final previous = await _repo.getPreviousDay(selectedDateStr);
    if (previous == null) return null;
    // Same arithmetic as the day view, cash rent included, so the suggested
    // opening balance matches what that day actually ended on.
    final spent = await _repo.getTotalExpensesForDate(previous.date);
    final rent = await _rentRepo.getCashCollectedOn(previous.date);
    return previous.openingBalance + rent - spent;
  }

  /// Get previous day (closed or open).
  Future<DailyAccountModel?> getPreviousDay() async {
    return await _repo.getPreviousDay(selectedDateStr);
  }

  /// Create or update the opening balance for the selected day.
  Future<void> setOpeningBalance(double amount) async {
    final dateStr = selectedDateStr;

    if (_todayAccount == null) {
      final id = await _repo.insertDailyAccount(DailyAccountModel(
        date: dateStr,
        openingBalance: amount,
      ));
      _todayAccount = DailyAccountModel(
        id: id,
        date: dateStr,
        openingBalance: amount,
      );
    } else {
      final updated = _todayAccount!.copyWith(openingBalance: amount);
      await _repo.updateDailyAccount(updated);
      _todayAccount = updated;
    }
    notifyListeners();
  }

  /// Add a new expense.
  Future<void> addExpense(double amount, String category, String note) async {
    final expense = ExpenseModel(
      date: selectedDateStr,
      amount: amount,
      category: category,
      note: note,
      createdAt: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    );
    final id = await _repo.insertExpense(expense);
    _expenses.insert(0, expense.copyWith(id: id));
    notifyListeners();
  }

  /// Update an existing expense.
  Future<void> updateExpense(ExpenseModel expense) async {
    await _repo.updateExpense(expense);
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      _expenses[idx] = expense;
      notifyListeners();
    }
  }

  /// Delete an expense.
  Future<void> deleteExpense(int id) async {
    await _repo.deleteExpense(id);
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ─── Navigation ───

  /// Jump straight to a date instead of stepping a day at a time. Future
  /// dates are ignored — there is nothing to record against them yet.
  void goToDate(DateTime date) {
    final now = DateTime.now();
    final target = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (target.isAfter(today)) return;
    loadDay(target);
  }

  void goToPreviousDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    loadDay();
  }

  void goToNextDay() {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    if (tomorrow.isAfter(DateTime.now())) return; // Can't go to future
    _selectedDate = tomorrow;
    loadDay();
  }

  bool get canGoToNextDay {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final tomorrowDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    return !tomorrowDate.isAfter(todayDate);
  }

  bool get isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // ─── Monthly Summary ───

  Future<Map<String, double>> getMonthlyExpenseByCategory(
      [String? month]) async {
    return _repo.getMonthlyExpenseByCategory(month ?? selectedMonthStr);
  }

  Future<double> getMonthlyTotalExpense([String? month]) async {
    return _repo.getMonthlyTotalExpense(month ?? selectedMonthStr);
  }

  Future<List<DailyAccountModel>> getDailyAccountsForMonth(
      [String? month]) async {
    return _repo.getDailyAccountsForMonth(month ?? selectedMonthStr);
  }

  /// Each recorded day's closing balance for the month, oldest first.
  ///
  /// Closing balances are derived (opening less that day's spend) instead of
  /// stored, so the trend covers every day that has an opening balance rather
  /// than only days someone remembered to close.
  Future<List<double>> getMonthlyClosingTrend([String? month]) async {
    final target = month ?? selectedMonthStr;
    final accounts = await _repo.getDailyAccountsForMonth(target);
    final spentByDate = await _repo.getExpenseTotalsByDate(target);

    final rentByDate = await _rentRepo.getCashCollectedByDate(target);

    final sorted = [...accounts]..sort((a, b) => a.date.compareTo(b.date));
    return [
      for (final account in sorted)
        account.openingBalance +
            (rentByDate[account.date] ?? 0) -
            (spentByDate[account.date] ?? 0),
    ];
  }
}
