import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_strings.dart';
import '../../logic/providers/auth_provider.dart';
import '../../logic/providers/rent_provider.dart';
import '../../logic/providers/room_provider.dart';
import 'accounts_screen.dart';
import 'add_student_screen.dart';
import 'dashboard_screen.dart';
import 'students_list_screen.dart';
import 'rent_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import '../widgets/common/premium_bottom_nav.dart';
import '../widgets/common/type_to_confirm_dialog.dart';
import '../widgets/import_students_dialog.dart';
import '../widgets/monthly_summary_sheet.dart';
import '../widgets/monthly_overview_sheet.dart';

class MainScreen extends StatefulWidget {
  /// Defaults to the Room Dashboard. Accounts prompts for an opening balance
  /// the moment it opens, which is the wrong first thing to show someone who
  /// has not set up a single room yet.
  static const int dashboardTab = 1;

  final int initialIndex;
  final bool showSummarySheet;
  const MainScreen({
    super.key,
    this.initialIndex = dashboardTab,
    this.showSummarySheet = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  /// Owned once, not rebuilt: a fresh FocusNode per build stole focus from
  /// whatever text field the user was typing in.
  final FocusNode _shortcutFocus = FocusNode();

  final List<Widget> _screens = [
    const AccountsScreen(),
    const DashboardScreen(),
    const StudentsListScreen(),
    const RentScreen(),
  ];

  final List<String> _titles = [
    'Accounts',
    'Room Dashboard',
    'Students List',
    'Rent Management',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (widget.showSummarySheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (_, scrollController) =>
                const MonthlySummarySheet(),
          ),
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCalendarAndMonth();
    });
  }

  Future<void> _initCalendarAndMonth() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await [
          Permission.calendar,
          Permission.storage,
        ].request();
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }

    if (mounted) {
      final rentProvider = Provider.of<RentProvider>(context, listen: false);
      await rentProvider.checkAndHandleMonthTransition();
      await rentProvider.loadStudents();
      if (mounted) {
        await Provider.of<RoomProvider>(context, listen: false).loadRooms();
      }
    }
  }

  @override
  void dispose() {
    _shortcutFocus.dispose();
    super.dispose();
  }

  /// Calendar of days with their spend — was "Monthly Overview", which read as
  /// a near-synonym of the Month Report beside it.
  void _openDayCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MonthlyOverviewScreen()),
    );
  }

  /// Month totals by category — was "Monthly Summary".
  void _openMonthReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => const MonthlySummarySheet(),
      ),
    );
  }

  Future<void> _onMenuSelected(String value) async {
    switch (value) {
      case 'new-month':
        await _startNewMonth();
      case 'settings':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      case 'about':
        _showAbout();
      case 'logout':
        await _confirmLogout();
    }
  }

  /// Resets every student's rent for the month. Irreversible and easy to fire
  /// by accident, so it asks for a word to be typed rather than accepting a
  /// single tap.
  Future<void> _startNewMonth() async {
    final rentProvider = Provider.of<RentProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const TypeToConfirmDialog(
        title: 'Start New Month',
        message:
            'This archives the current month and resets every student to Pending with ₹0 paid. '
            'It cannot be undone.',
        requiredWord: 'START',
        actionLabel: 'Start New Month',
      ),
    );

    if (confirmed != true) return;
    await rentProvider.startNewMonth();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New month started. All statuses reset to pending.'),
        backgroundColor: AppColors.successColor,
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppStrings.appName,
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: AppRadius.mdBorder,
        ),
        child: const Icon(Icons.home_work_rounded, size: 36, color: Colors.black),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _shortcutFocus,
      // Focused once on mount rather than on every build, so a text field that
      // takes focus keeps it — and typing digits there no longer flips tabs.
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Only as many shortcuts as there are tabs — digit5 used to select a
          // fifth screen that does not exist and crashed with a RangeError.
          // Not const: LogicalKeyboardKey has no primitive equality, so it
          // cannot be a const map key.
          final keyMap = {
            LogicalKeyboardKey.digit1: 0,
            LogicalKeyboardKey.digit2: 1,
            LogicalKeyboardKey.digit3: 2,
            LogicalKeyboardKey.digit4: 3,
          };
          if (keyMap.containsKey(event.logicalKey)) {
            setState(() {
              _currentIndex = keyMap[event.logicalKey]!;
            });
          } else if (event.logicalKey == LogicalKeyboardKey.keyO) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MonthlyOverviewScreen(),
              ),
            );
          } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => DraggableScrollableSheet(
                initialChildSize: 0.7,
                maxChildSize: 0.9,
                minChildSize: 0.4,
                builder: (_, scrollController) =>
                    const MonthlySummarySheet(),
              ),
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_currentIndex]),
        actions: [
          // Contextual actions for the current tab come first; the app-wide
          // ones live behind a single overflow so the bar never carries five
          // competing icons (and Logout no longer sits a thumb-width from
          // Settings).
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.calendar_view_month_rounded),
              tooltip: 'Day Calendar',
              onPressed: _openDayCalendar,
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: 'Month Report',
              onPressed: _openMonthReport,
            ),
          ],
          if (_currentIndex == 2) ...[
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import Students from CSV',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const ImportStudentsDialog(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Add New Student',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddStudentScreen()),
                );
              },
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            color: AppColors.cardBackground,
            onSelected: _onMenuSelected,
            itemBuilder: (_) => [
              // Resetting every student's rent is rare and destructive, so it
              // belongs here rather than as a permanent button on the ledger.
              if (_currentIndex == 3)
                const PopupMenuItem(
                  value: 'new-month',
                  child: Row(children: [
                    Icon(Icons.event_repeat, size: 18, color: AppColors.warningColor),
                    SizedBox(width: 10),
                    Text('Start new month'),
                  ]),
                ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Text('Settings & Data'),
                ]),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Text('About'),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18, color: AppColors.errorColor),
                  SizedBox(width: 10),
                  Text('Logout', style: TextStyle(color: AppColors.errorColor)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: PremiumBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavDestination(
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet,
            label: 'Accounts',
          ),
          NavDestination(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: 'Dashboard',
          ),
          NavDestination(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            label: 'Students',
          ),
          NavDestination(
            icon: Icons.payment_outlined,
            activeIcon: Icons.payment,
            label: 'Rent',
          ),
        ],
      ),
    ),
    );
  }
}
