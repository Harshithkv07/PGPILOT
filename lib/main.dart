import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'logic/providers/auth_provider.dart';
import 'logic/providers/student_provider.dart';
import 'logic/providers/room_provider.dart';
import 'logic/providers/rent_provider.dart';
import 'logic/providers/accounts_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/widgets/monthly_overview_sheet.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool useSlideshow = !kIsWeb && File('slideshow_mode.txt').existsSync();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => RentProvider()),
        ChangeNotifierProvider(create: (_) => AccountsProvider()),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: useSlideshow ? const SlideshowWidget() : const SplashScreen(),
      ),
    );
  }
}

class SlideshowWidget extends StatefulWidget {
  const SlideshowWidget({super.key});

  @override
  State<SlideshowWidget> createState() => _SlideshowWidgetState();
}

class _SlideshowWidgetState extends State<SlideshowWidget> {
  int _step = 0;

  void _nextStep() {
    if (mounted) {
      setState(() {
        _step++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextStep();
          }
        }
      },
      child: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    switch (_step) {
      case 0:
        return const LoginScreen();
      case 1:
        return const WelcomeScreen();
      case 2:
        return const MainScreen(initialIndex: 0);
      case 3:
        return const MonthlyOverviewScreen();
      case 4:
        return const MainScreen(initialIndex: 0, showSummarySheet: true);
      case 5:
        return const MainScreen(initialIndex: 1);
      case 6:
        return const MainScreen(initialIndex: 2);
      case 7:
        return const MainScreen(initialIndex: 3);
      case 8:
        return const MainScreen(initialIndex: 3);
      default:
        return const Scaffold(
          body: Center(
            child: Text(
              'Slideshow Completed Successfully',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
        );
    }
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.checkLoginStatus();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => authProvider.isLoggedIn
              ? const WelcomeScreen()
              : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
