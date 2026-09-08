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
    if (!mounted) return;
    final provider = Provider.of<AccountsProvider>(context, listen: false);
    if (provider.todayAccount == null && provider.isToday) {
      _showOpeningBalanceDialog(isFirstTime: true);
    }
  }

  /// Opening-balance entry. Works for any day the user has navigated to, so a
  /// day that was missed can be filled in after the fact.
  void _showOpeningBalanceDialog({bool isFirstTime = false}) async {
    final provider = Provider.of<AccountsProvider>(context, listen: false);
    final prevBalance = await provider.getPreviousClosingBalance();
    final isToday = provider.isToday;
    final dayLabel = DateFormat('EEE, dd MMM').format(provider.selectedDate);
    final controller = TextEditingController(
      text: prevBalance?.toStringAsFixed(2) ?? '',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: AppColors.primaryAccent),
            const SizedBox(width: 10),
            const Expanded(child: Text('Opening Balance')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isToday)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.warningColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mdBorder,
                  border: Border.all(color: AppColors.warningColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 18, color: AppColors.warningColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recording for $dayLabel, not today.',
                        style: const TextStyle(color: AppColors.warningColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
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
                        'Previous day ended at ${_money(prevBalance)}',
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
          // Always escapable — the empty state offers the same action, so the
          // app is never blocked behind this dialog on launch.
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
              child: const Text('Carry Forward'),
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
    final isToday = provider.isToday;
    final dayLabel = DateFormat('EEE, dd MMM').format(provider.selectedDate);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(existing == null ? Icons.add_circle : Icons.edit, color: AppColors.goldAccent),
              const SizedBox(width: 10),
              Expanded(child: Text(existing == null ? 'Add Expense' : 'Edit Expense')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Backdating is allowed, so say plainly which day is being
                // written to whenever it is not today.
                if (!isToday)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.warningColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.smBorder,
                      border: Border.all(color: AppColors.warningColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 16, color: AppColors.warningColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Adding to $dayLabel',
                            style: const TextStyle(color: AppColors.warningColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  dropdownColor: AppColors.cardBackground,
                  items: ExpenseModel.categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                Icon(CategoryStyles.icon(c), size: 20, color: CategoryStyles.color(c)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(c, overflow: TextOverflow.ellipsis),
                                ),
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

  static String _money(double amount) => '₹${amount.toStringAsFixed(2)}';

  Future<void> _pickDate(AccountsProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Jump to a day',
    );
    if (picked != null) provider.goToDate(picked);
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
            tooltip: 'Previous day',
          ),
          // The date itself is the control for jumping to any past day, rather
          // than stepping back one chevron press at a time.
          Expanded(
            child: InkWell(
              onTap: () => _pickDate(provider),
              borderRadius: AppRadius.mdBorder,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.expand_more, size: 18, color: AppColors.primaryAccent),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isToday ? AppColors.primaryAccent : AppColors.warningColor)
                            .withValues(alpha: 0.2),
                        borderRadius: AppRadius.smBorder,
                      ),
                      child: Text(
                        isToday ? 'TODAY' : 'PAST DAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isToday ? AppColors.primaryAccent : AppColors.warningColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: provider.canGoToNextDay ? () => provider.goToNextDay() : null,
            icon: Icon(
              Icons.chevron_right,
              color: provider.canGoToNextDay ? AppColors.primaryAccent : AppColors.textMuted,
            ),
            tooltip: 'Next day',
          ),
          if (!isToday)
            IconButton(
              onPressed: () => provider.goToDate(DateTime.now()),
              icon: const Icon(Icons.today, color: AppColors.primaryAccent),
              tooltip: 'Back to today',
            ),
        ],
      ),
    );
  }

  Widget _buildNoAccountView(AccountsProvider provider) {
    final dayLabel = DateFormat('EEE, dd MMM').format(provider.selectedDate);

    // A day that was never started can now be filled in whenever it was —
    // past days are no longer read-only.
    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: provider.isToday
          ? 'No account started for today'
          : 'No account recorded for $dayLabel',
      subtitle: provider.isToday
          ? 'Set an opening balance to start tracking.'
          : 'You can still fill this day in.',
      action: ElevatedButton.icon(
        onPressed: () => _showOpeningBalanceDialog(isFirstTime: true),
        icon: Icon(provider.isToday ? Icons.play_arrow : Icons.edit_calendar),
        label: Text(provider.isToday ? 'Start Day' : 'Record This Day'),
      ),
    );
  }

  Widget _buildDayView(AccountsProvider provider) {
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
                  onEdit: () => _showOpeningBalanceDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard(
                  'Remaining',
                  provider.remainingBalance,
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
                Text(
                  provider.isToday ? 'Total Spent Today' : 'Total Spent This Day',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  _money(provider.totalExpensesToday),
                  style: const TextStyle(
                      color: AppColors.errorColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _BalanceSparkline(provider: provider),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expenses (${provider.expenses.length})',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddExpenseDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
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
            ...provider.expenses.map(_buildExpenseTile),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String label, double amount, IconData icon, Color color,
      {VoidCallback? onEdit}) {
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
                  borderRadius: AppRadius.smBorder,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit, color: AppColors.textSecondary, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(amount),
              style: TextStyle(
                  fontFamily: 'Sora', fontSize: 20, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(ExpenseModel expense) {
    final timeStr = expense.createdAt.length >= 16 ? expense.createdAt.substring(11, 16) : '';

    return Dismissible(
      key: Key('expense-${expense.id}'),
      direction: DismissDirection.endToStart,
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
      confirmDismiss: (_) async {
        // Swipe-to-delete is easy to trigger by accident on a phone, and an
        // expense deleted silently is money that quietly vanishes.
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Expense'),
                content: Text(
                    'Remove ${expense.category} of ${_money(expense.amount)} from this day?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        Provider.of<AccountsProvider>(context, listen: false).deleteExpense(expense.id!);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PremiumCard(
          padding: const EdgeInsets.all(14),
          onTap: () => _showAddExpenseDialog(expense),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CategoryStyles.color(expense.category).withValues(alpha: 0.15),
                  borderRadius: AppRadius.smBorder,
                ),
                child: Icon(CategoryStyles.icon(expense.category),
                    color: CategoryStyles.color(expense.category), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.category,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    '- ${_money(expense.amount)}',
                    style: const TextStyle(
                        color: AppColors.errorColor, fontWeight: FontWeight.bold, fontSize: 15),
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
///
/// Closing balances are derived (opening less that day's spend) rather than
/// stored, so the trend fills in as soon as a day has an opening balance.
class _BalanceSparkline extends StatelessWidget {
  final AccountsProvider provider;

  const _BalanceSparkline({required this.provider});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<double>>(
      future: provider.getMonthlyClosingTrend(),
      builder: (context, snapshot) {
        final balances = snapshot.data ?? const <double>[];
        if (balances.length < 2) return const SizedBox.shrink();

        final spots = <FlSpot>[
          for (var i = 0; i < balances.length; i++) FlSpot(i.toDouble(), balances[i]),
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
