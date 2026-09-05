import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/category_styles.dart';
import '../../logic/providers/accounts_provider.dart';
import '../../data/models/expense_model.dart';
import '../widgets/common/premium_card.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/section_header.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _initialLoadDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoadDone) {
      _initialLoadDone = true;
      final provider = Provider.of<AccountsProvider>(context, listen: false);
      provider.loadDay().then((_) => _checkDaySetup());
    }
  }

  void _checkDaySetup() {
    final provider = Provider.of<AccountsProvider>(context, listen: false);
    if (provider.todayAccount == null && provider.isToday) {
      _showOpeningBalanceDialog(isFirstTime: true);
    }
  }

  void _showOpeningBalanceDialog({bool isFirstTime = false}) async {
    final provider = Provider.of<AccountsProvider>(context, listen: false);
    final prevBalance = await provider.getPreviousClosingBalance();
    final controller = TextEditingController(
      text: prevBalance?.toStringAsFixed(2) ?? '',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !isFirstTime,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: AppColors.primaryAccent),
            const SizedBox(width: 10),
            const Text('Opening Balance'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prevBalance != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: AppRadius.mdBorder,
                  border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.primaryAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yesterday\'s closing: ₹${prevBalance.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Enter Opening Balance',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          if (!isFirstTime)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          if (isFirstTime && prevBalance != null)
            TextButton(
              onPressed: () {
                provider.setOpeningBalance(prevBalance);
                Navigator.pop(ctx);
              },
              child: const Text('Use Yesterday\'s'),
            ),
          ElevatedButton.icon(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 0) {
                provider.setOpeningBalance(val);
                Navigator.pop(ctx);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog([ExpenseModel? existing]) {
    final provider = Provider.of<AccountsProvider>(context, listen: false);
    final amountCtrl = TextEditingController(text: existing?.amount.toStringAsFixed(2) ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String selectedCategory = existing?.category ?? ExpenseModel.categories[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(existing == null ? Icons.add_circle : Icons.edit, color: AppColors.goldAccent),
              const SizedBox(width: 10),
              Text(existing == null ? 'Add Expense' : 'Edit Expense'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  dropdownColor: AppColors.cardBackground,
                  items: ExpenseModel.categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                Icon(CategoryStyles.icon(c), size: 20, color: CategoryStyles.color(c)),
                                const SizedBox(width: 8),
                                Text(c),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Vegetables for dinner',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text);
                if (amt != null && amt > 0) {
                  if (existing != null) {
                    provider.updateExpense(existing.copyWith(
                      amount: amt,
                      category: selectedCategory,
                      note: noteCtrl.text.trim(),
                    ));
                  } else {
                    provider.addExpense(amt, selectedCategory, noteCtrl.text.trim());
                  }
                  Navigator.pop(ctx);
                }
              },
              icon: Icon(existing == null ? Icons.add : Icons.save),
              label: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCloseDay() {
    final provider = Provider.of<AccountsProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_clock, color: AppColors.goldAccent),
            const SizedBox(width: 10),
            const Text('Close Day'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow('Opening Balance', '₹${provider.todayAccount!.openingBalance.toStringAsFixed(2)}'),
            _summaryRow('Total Expenses', '- ₹${provider.totalExpensesToday.toStringAsFixed(2)}', color: AppColors.errorColor),
            const Divider(color: AppColors.borderColor),
            _summaryRow(
              'Closing Balance',
              '₹${provider.remainingBalance.toStringAsFixed(2)}',
              color: provider.remainingBalance >= 0 ? AppColors.successColor : AppColors.errorColor,
              bold: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.goldAccent.withValues(alpha: 0.1),
                borderRadius: AppRadius.smBorder,
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.goldAccent, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This closing balance will be suggested as tomorrow\'s opening balance.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldAccent, foregroundColor: Colors.black),
            onPressed: () {
              provider.closeDay();
              Navigator.pop(ctx);
            },
            child: const Text('Confirm & Close'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _buildDateNavBar(provider),
            Expanded(
              child: provider.todayAccount == null
                  ? _buildNoAccountView(provider)
                  : _buildDayView(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateNavBar(AccountsProvider provider) {
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(provider.selectedDate);
    final isToday = provider.isToday;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border(bottom: BorderSide(color: AppColors.borderColorSubtle)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => provider.goToPreviousDay(),
            icon: const Icon(Icons.chevron_left, color: AppColors.primaryAccent),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withValues(alpha: 0.2),
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryAccent, letterSpacing: 1),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: provider.canGoToNextDay ? () => provider.goToNextDay() : null,
            icon: Icon(
              Icons.chevron_right,
              color: provider.canGoToNextDay ? AppColors.primaryAccent : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccountView(AccountsProvider provider) {
    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: provider.isToday ? 'No account started for today' : 'No account record for this day',
      action: provider.isToday
          ? ElevatedButton.icon(
              onPressed: () => _showOpeningBalanceDialog(isFirstTime: true),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Day'),
            )
          : null,
    );
  }

  Widget _buildDayView(AccountsProvider provider) {
    final isClosed = provider.isDayClosed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildBalanceCard(
                  'Opening',
                  provider.todayAccount!.openingBalance,
                  Icons.account_balance,
                  AppColors.primaryAccent,
                  onEdit: isClosed ? null : () => _showOpeningBalanceDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard(
                  'Remaining',
                  isClosed ? provider.todayAccount!.closingBalance ?? 0 : provider.remainingBalance,
                  Icons.savings,
                  provider.remainingBalance >= 0 ? AppColors.successColor : AppColors.errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            gradient: LinearGradient(
              colors: [AppColors.secondaryAccent.withValues(alpha: 0.2), AppColors.cardBackground],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Spent Today', style: TextStyle(color: AppColors.textSecondary)),
                Text(
                  '₹${provider.totalExpensesToday.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.errorColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _BalanceSparkline(provider: provider),
          const SizedBox(height: 16),

          if (isClosed)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.goldAccent.withValues(alpha: 0.1),
                borderRadius: AppRadius.mdBorder,
                border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.goldAccent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'This day has been closed',
                      style: TextStyle(color: AppColors.goldAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (provider.isToday)
                    TextButton(
                      onPressed: () => provider.reopenDay(),
                      child: const Text('Undo', style: TextStyle(color: AppColors.goldAccent)),
                    ),
                ],
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expenses (${provider.expenses.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              if (!isClosed)
                ElevatedButton.icon(
                  onPressed: () => _showAddExpenseDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (provider.expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(icon: Icons.receipt_long, title: 'No expenses yet'),
            )
          else
            ...provider.expenses.map((e) => _buildExpenseTile(e, isClosed)),

          if (!isClosed && provider.todayAccount != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmCloseDay(),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Close Day & Calculate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String label, double amount, IconData icon, Color color, {VoidCallback? onEdit}) {
    return PremiumCard(
      borderColor: color.withValues(alpha: 0.3),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              if (onEdit != null)
                InkWell(
                  onTap: onEdit,
                  child: const Icon(Icons.edit, color: AppColors.textMuted, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(fontFamily: 'Sora', fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(ExpenseModel expense, bool isClosed) {
    final timeStr = expense.createdAt.length >= 16 ? expense.createdAt.substring(11, 16) : '';

    return Dismissible(
      key: Key('expense-${expense.id}'),
      direction: isClosed ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.errorColor.withValues(alpha: 0.2),
          borderRadius: AppRadius.mdBorder,
        ),
        child: const Icon(Icons.delete, color: AppColors.errorColor),
      ),
      onDismissed: (_) {
        Provider.of<AccountsProvider>(context, listen: false).deleteExpense(expense.id!);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PremiumCard(
          padding: const EdgeInsets.all(14),
          onTap: isClosed ? null : () => _showAddExpenseDialog(expense),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CategoryStyles.color(expense.category).withValues(alpha: 0.15),
                  borderRadius: AppRadius.smBorder,
                ),
                child: Icon(CategoryStyles.icon(expense.category), color: CategoryStyles.color(expense.category), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.category, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (expense.note.isNotEmpty)
                      Text(
                        expense.note,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '- ₹${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.errorColor, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (timeStr.isNotEmpty)
                    Text(timeStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small sparkline of the current month's daily closing balances —
/// gives the accounts screen a quick trend visual instead of only numbers.
class _BalanceSparkline extends StatelessWidget {
  final AccountsProvider provider;

  const _BalanceSparkline({required this.provider});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: provider.getDailyAccountsForMonth(),
      builder: (context, snapshot) {
        final accounts = (snapshot.data ?? [])
            .where((a) => a.closingBalance != null)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        if (accounts.length < 2) return const SizedBox.shrink();

        final spots = <FlSpot>[
          for (var i = 0; i < accounts.length; i++) FlSpot(i.toDouble(), accounts[i].closingBalance!),
        ];

        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'BALANCE TREND THIS MONTH', icon: Icons.show_chart_rounded),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 90,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.primaryAccent,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primaryAccent.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
