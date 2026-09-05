import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../logic/providers/accounts_provider.dart';
import '../../data/models/daily_account_model.dart';
import '../../data/database/accounts_repository.dart';
import 'common/empty_state.dart';

class MonthlyOverviewScreen extends StatefulWidget {
  const MonthlyOverviewScreen({super.key});

  @override
  State<MonthlyOverviewScreen> createState() => _MonthlyOverviewScreenState();
}

class _MonthlyOverviewScreenState extends State<MonthlyOverviewScreen> {
  late DateTime _selectedMonth;
  List<_DayCardData> _days = [];
  bool _isLoading = true;

  final AccountsRepository _repo = AccountsRepository();

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _isLoading = true);

    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
    final accounts = await _repo.getDailyAccountsForMonth(monthStr);

    // Build a map of date -> account for quick lookup
    final accountMap = <String, DailyAccountModel>{};
    for (var acc in accounts) {
      accountMap[acc.date] = acc;
    }

    // Generate all days of the month
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();

    final List<_DayCardData> days = [];
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      // Don't show future dates
      if (date.isAfter(DateTime(now.year, now.month, now.day))) break;

      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final account = accountMap[dateStr];
      double totalExpense = 0;
      if (account != null) {
        totalExpense = await _repo.getTotalExpensesForDate(dateStr);
      }
      days.add(_DayCardData(
        date: date,
        account: account,
        totalExpense: totalExpense,
      ));
    }

    setState(() {
      _days = days;
      _isLoading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadMonth();
  }

  void _onDayTapped(_DayCardData day) {
    final provider = Provider.of<AccountsProvider>(context, listen: false);
    provider.loadDay(day.date);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Overview'),
      ),
      body: Column(
        children: [
          // Month picker
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.secondaryBackground,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left,
                      color: AppColors.primaryAccent),
                ),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right,
                      color: AppColors.primaryAccent),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _days.isEmpty
                    ? const EmptyState(icon: Icons.calendar_today, title: 'No days to show')
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: _days.length,
                          itemBuilder: (ctx, i) => _buildDayCard(_days[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(_DayCardData day) {
    final dayNum = DateFormat('dd').format(day.date);
    final weekday = DateFormat('EEE').format(day.date);

    return InkWell(
      onTap: () => _onDayTapped(day),
      borderRadius: AppRadius.mdBorder,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: AppRadius.mdBorder,
          border: Border.all(color: AppColors.borderColorSubtle),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Weekday
            Text(
              weekday,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            // Day number
            Text(
              dayNum,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // Total expense
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '₹${day.totalExpense.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: day.totalExpense > 0
                      ? AppColors.errorColor
                      : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCardData {
  final DateTime date;
  final DailyAccountModel? account;
  final double totalExpense;

  _DayCardData({
    required this.date,
    this.account,
    required this.totalExpense,
  });
}
