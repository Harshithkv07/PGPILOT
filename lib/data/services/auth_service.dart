import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/credentials.dart';

/// Login for the single PG manager who uses this app.
///
/// The username and password used to be compiled into the binary as plain
/// constants, which meant they shipped inside the APK and could never be
/// changed without a rebuild. Credentials now live in preferences as a salted
/// SHA-256 hash, and can be changed from Settings.
///
/// The compiled pair is still honoured as the *initial* credential so existing
/// installs keep working; [isUsingDefaultPassword] reports when it is still in
/// use so the UI can nudge the user to change it.
class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUsername = 'auth_username';
  static const String _keyPasswordHash = 'auth_password_hash';
  static const String _keySalt = 'auth_salt';

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();

  static String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// True while the account still uses the credentials shipped with the app.
  Future<bool> isUsingDefaultPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPasswordHash) == null;
  }

  Future<String> currentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? Credentials.username;
  }

  Future<bool> _verify(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_keyPasswordHash);
    final salt = prefs.getString(_keySalt);
    final storedUser = prefs.getString(_keyUsername);

    // Nothing set yet — fall back to the credentials compiled into the app so
    // existing installs are not locked out by this change.
    if (storedHash == null || salt == null || storedUser == null) {
      return username == Credentials.username && password == Credentials.password;
    }

    return username == storedUser && _hash(password, salt) == storedHash;
  }

  Future<bool> login(String username, String password) async {
    if (!await _verify(username, password)) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    return true;
  }

  /// Change the password (and optionally the username). Returns null on
  /// success or a message explaining the refusal.
  Future<String?> changeCredentials({
    required String currentPassword,
    required String newPassword,
    String? newUsername,
  }) async {
    final username = newUsername?.trim().isNotEmpty == true
        ? newUsername!.trim()
        : await currentUsername();

    if (!await _verify(await currentUsername(), currentPassword)) {
      return 'Current password is incorrect.';
    }
    if (newPassword.length < 4) {
      return 'New password must be at least 4 characters.';
    }

    final prefs = await SharedPreferences.getInstance();
    final salt = _newSalt();
    await prefs.setString(_keySalt, salt);
    await prefs.setString(_keyPasswordHash, _hash(newPassword, salt));
    await prefs.setString(_keyUsername, username);
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }
}
