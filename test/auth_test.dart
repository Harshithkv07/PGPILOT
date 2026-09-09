// Login credentials moved out of the compiled binary and into preferences as a
// salted hash. Existing installs must keep working, and the password must
// actually change when asked.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pg_management/core/constants/credentials.dart';
import 'package:pg_management/data/services/auth_service.dart';

void main() {
  late AuthService auth;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    auth = AuthService();
  });

  test('the shipped credentials still work before anything is changed',
      () async {
    expect(await auth.isUsingDefaultPassword(), isTrue);
    expect(
      await auth.login(Credentials.username, Credentials.password),
      isTrue,
    );
    expect(await auth.isLoggedIn(), isTrue);
  });

  test('a wrong password is rejected', () async {
    expect(await auth.login(Credentials.username, 'not-the-password'), isFalse);
    expect(await auth.isLoggedIn(), isFalse);
  });

  test('changing the password replaces the shipped one', () async {
    final failure = await auth.changeCredentials(
      currentPassword: Credentials.password,
      newPassword: 'freshsecret',
    );
    expect(failure, isNull);

    expect(await auth.isUsingDefaultPassword(), isFalse);
    expect(await auth.login(Credentials.username, 'freshsecret'), isTrue);
    // The old one no longer opens the app.
    expect(await auth.login(Credentials.username, Credentials.password), isFalse);
  });

  test('the wrong current password blocks a change', () async {
    final failure = await auth.changeCredentials(
      currentPassword: 'wrong',
      newPassword: 'freshsecret',
    );
    expect(failure, contains('incorrect'));
    // Unchanged.
    expect(await auth.login(Credentials.username, Credentials.password), isTrue);
  });

  test('a too-short password is refused', () async {
    final failure = await auth.changeCredentials(
      currentPassword: Credentials.password,
      newPassword: 'ab',
    );
    expect(failure, contains('at least'));
  });

  test('the password is never stored in plain text', () async {
    await auth.changeCredentials(
      currentPassword: Credentials.password,
      newPassword: 'freshsecret',
    );

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('auth_password_hash');
    expect(stored, isNotNull);
    expect(stored, isNot(contains('freshsecret')));
    // SHA-256, hex encoded.
    expect(stored!.length, 64);
    expect(prefs.getString('auth_salt'), isNotNull);
  });

  test('two accounts with the same password get different hashes', () async {
    await auth.changeCredentials(
      currentPassword: Credentials.password,
      newPassword: 'samepassword',
    );
    final prefs = await SharedPreferences.getInstance();
    final firstHash = prefs.getString('auth_password_hash');

    // A fresh install choosing the same password.
    SharedPreferences.setMockInitialValues({});
    final other = AuthService();
    await other.changeCredentials(
      currentPassword: Credentials.password,
      newPassword: 'samepassword',
    );
    final secondPrefs = await SharedPreferences.getInstance();

    // Salted, so identical passwords do not produce identical hashes.
    expect(secondPrefs.getString('auth_password_hash'), isNot(firstHash));
  });

  test('the username can be changed alongside the password', () async {
    final failure = await auth.changeCredentials(
      currentPassword: Credentials.password,
      newPassword: 'freshsecret',
      newUsername: 'manager',
    );
    expect(failure, isNull);

    expect(await auth.currentUsername(), 'manager');
    expect(await auth.login('manager', 'freshsecret'), isTrue);
    expect(await auth.login(Credentials.username, 'freshsecret'), isFalse);
  });

  test('logging out clears the session but not the credentials', () async {
    await auth.login(Credentials.username, Credentials.password);
    await auth.logout();

    expect(await auth.isLoggedIn(), isFalse);
    expect(await auth.login(Credentials.username, Credentials.password), isTrue);
  });
}
