/// The credentials the app ships with.
///
/// These are only the *initial* login. Once a password is set from Settings it
/// is stored as a salted hash in preferences and these constants stop being
/// used — see [AuthService]. They are compiled into the binary, so treat them
/// as public and change the password in-app after installing.
class Credentials {
  static const String username = 'admin';
  static const String password = 'admin';
}
