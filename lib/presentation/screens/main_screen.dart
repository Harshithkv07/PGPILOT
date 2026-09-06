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
import '../widgets/import_students_dialog.dart';
import '../widgets/monthly_summary_sheet.dart';
import '../widgets/monthly_overview_sheet.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final bool showSummarySheet;
  const MainScreen({super.key, this.initialIndex = 0, this.showSummarySheet = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

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
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          final keyMap = {
            LogicalKeyboardKey.digit1: 0,
            LogicalKeyboardKey.digit2: 1,
            LogicalKeyboardKey.digit3: 2,
            LogicalKeyboardKey.digit4: 3,
            LogicalKeyboardKey.digit5: 4,
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
          // Show overview & summary buttons when on Accounts tab
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.calendar_view_month_rounded),
              tooltip: 'Monthly Overview',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MonthlyOverviewScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: 'Monthly Summary',
              onPressed: () {
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
              },
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
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () {
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
                  child: const Icon(
                    Icons.home_work_rounded,
                    size: 36,
                    color: Colors.black,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings & Data',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorColor,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                await Provider.of<AuthProvider>(context, listen: false).logout();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              }
            },
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
