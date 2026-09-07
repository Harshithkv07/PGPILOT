import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/category_styles.dart';
import '../../logic/providers/accounts_provider.dart';
import '../../logic/providers/rent_provider.dart';
import 'common/empty_state.dart';

class MonthlySummarySheet extends StatefulWidget {
  const MonthlySummarySheet({super.key});

  @override
  State<MonthlySummarySheet> createState() => _MonthlySummarySheetState();
}

class _MonthlySummarySheetState extends State<MonthlySummarySheet> {
  late DateTime _selectedMonth;
  Map<String, double> _categoryTotals = {};
  double _totalExpense = 0;
  double _totalRent = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);

    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
    final accountsProvider = Provider.of<AccountsProvider>(context, listen: false);
    final rentProvider = Provider.of<RentProvider>(context, listen: false);

    _categoryTotals = await accountsProvider.getMonthlyExpenseByCategory(monthStr);
    _totalExpense = await accountsProvider.getMonthlyTotalExpense(monthStr);

    await rentProvider.loadStudents();
    _totalRent = rentProvider.getCollectedRevenue().toDouble();

    if (mounted) setState(() => _isLoading = false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final profit = _totalRent - _totalExpense;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left, color: AppColors.primaryAccent),
              ),
              Text(
                monthLabel,
                style: const TextStyle(fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right, color: AppColors.primaryAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else ...[
            if (_categoryTotals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: EmptyState(icon: Icons.inbox, title: 'No expenses this month'),
              )
            else ...[
              _buildCategoryDonut(),
              const SizedBox(height: AppSpacing.lg),
              ..._buildCategoryRows(),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: AppRadius.lgBorder,
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  _totalRow('Total Expenditure', '₹${_totalExpense.toStringAsFixed(2)}', color: AppColors.errorColor),
                  const SizedBox(height: 8),
                  _totalRow('Total Rent Received', '₹${_totalRent.toStringAsFixed(2)}', color: AppColors.successColor),
                  const Divider(color: AppColors.borderColor, height: 20),
                  _totalRow(
                    profit >= 0 ? 'Profit' : 'Loss',
                    '₹${profit.abs().toStringAsFixed(2)}',
                    color: profit >= 0 ? AppColors.successColor : AppColors.errorColor,
                    bold: true,
                    icon: profit >= 0 ? Icons.trending_up : Icons.trending_down,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryDonut() {
    final sorted = _categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 120,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 34,
          sections: sorted.map((entry) {
            final pct = _totalExpense > 0 ? entry.value / _totalExpense * 100 : 0.0;
            return PieChartSectionData(
              value: entry.value,
              color: CategoryStyles.color(entry.key),
              radius: 22,
              title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryRows() {
    final sorted = _categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((entry) {
      final pct = _totalExpense > 0 ? entry.value / _totalExpense : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CategoryStyles.color(entry.key).withValues(alpha: 0.15),
                borderRadius: AppRadius.smBorder,
              ),
              child: Icon(CategoryStyles.icon(entry.key), color: CategoryStyles.color(entry.key), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '₹${entry.value.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _totalRow(String label, String value, {Color? color, bool bold = false, IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: bold ? 20 : 14),
        ),
      ],
    );
  }
}
