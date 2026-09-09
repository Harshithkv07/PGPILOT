import 'package:flutter/material.dart';
import '../../data/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoggedIn = false;
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // Check login status on app start
  Future<void> checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();
    
    _isLoggedIn = await _authService.isLoggedIn();
    
    _isLoading = false;
    notifyListeners();
  }

  // Login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    
    final success = await _authService.login(username, password);
    
    if (success) {
      _isLoggedIn = true;
    }
    
    _isLoading = false;
    notifyListeners();
    
    return success;
  }

  /// True while the login still uses the password shipped with the app.
  Future<bool> isUsingDefaultPassword() => _authService.isUsingDefaultPassword();

  Future<String> currentUsername() => _authService.currentUsername();

  /// Change the login password. Returns null on success, or the reason it was
  /// refused.
  Future<String?> changeCredentials({
    required String currentPassword,
    required String newPassword,
    String? newUsername,
  }) =>
      _authService.changeCredentials(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newUsername: newUsername,
      );

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _isLoggedIn = false;
    notifyListeners();
  }
}
