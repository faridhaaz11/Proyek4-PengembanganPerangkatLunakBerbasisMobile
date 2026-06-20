// login_controller.dart
enum LoginActionStatus { success, error }

class LoginActionResult {
  final LoginActionStatus status;
  final String message;
  final bool shouldStartCountdown;
  final String? role;

  const LoginActionResult({
    required this.status,
    required this.message,
    this.shouldStartCountdown = false,
    this.role,
  });
}

class LoginController {
  // Database Multiple Users menggunakan Map<String, String>
  // Key = username, Value = password
  final Map<String, String> _users = {
    'admin': '123',
    'faridha': 'password',
    'user1': 'user123',
  };

  // Peta Peran (RBAC): tentukan role berdasarkan username
  // 'admin' memiliki akses penuh sebagai admin
  final Map<String, String> _roles = {
    'admin': 'admin',
    'faridha': 'user',
    'user1': 'user',
  };

  int _loginAttempts = 0;
  bool _isLoginDisabled = false;
  int _countdown = 0;

  static const int _maxLoginAttempts = 3;
  static const int _lockSeconds = 10;

  // Fungsi pengecekan (Logic-Only)
  // Fungsi untuk mengembalikan true jika username ada dan password cocok
  bool login(String username, String password) {
    // Cek apakah username ada di Map dan passwordnya cocok
    if (_users.containsKey(username) && _users[username] == password) {
      return true;
    }
    return false;
  }

  int get loginAttempts => _loginAttempts;
  bool get isLoginDisabled => _isLoginDisabled;
  int get countdown => _countdown;

  LoginActionResult attemptLogin(String username, String password) {
    final user = username.trim();

    if (user.isEmpty) {
      return const LoginActionResult(
        status: LoginActionStatus.error,
        message: 'Username tidak boleh kosong!',
      );
    }

    if (password.isEmpty) {
      return const LoginActionResult(
        status: LoginActionStatus.error,
        message: 'Password tidak boleh kosong!',
      );
    }

    if (_isLoginDisabled) {
      return LoginActionResult(
        status: LoginActionStatus.error,
        message: 'Terlalu banyak percobaan! Tunggu $_countdown detik.',
      );
    }

    final isSuccess = login(user, password);

    if (isSuccess) {
      _loginAttempts = 0;
      return LoginActionResult(
        status: LoginActionStatus.success,
        message: 'Login berhasil',
        role: getRole(user),
      );
    }

    _loginAttempts++;

    if (_loginAttempts >= _maxLoginAttempts) {
      _isLoginDisabled = true;
      _countdown = _lockSeconds;
      return const LoginActionResult(
        status: LoginActionStatus.error,
        message: 'Terlalu banyak percobaan! Tunggu 10 detik.',
        shouldStartCountdown: true,
      );
    }

    return LoginActionResult(
      status: LoginActionStatus.error,
      message:
          'Login Gagal! Percobaan ke-$_loginAttempts dari $_maxLoginAttempts',
    );
  }

  void tickCountdown() {
    if (!_isLoginDisabled) return;

    if (_countdown > 0) {
      _countdown--;
    }

    if (_countdown <= 0) {
      _countdown = 0;
      _isLoginDisabled = false;
      _loginAttempts = 0;
    }
  }

  /// Mengembalikan peran pengguna berdasarkan username.
  /// Default ke 'Anggota' jika tidak terdaftar.
  String getRole(String username) => _roles[username] ?? 'Anggota';

  // Getter untuk mendapatkan daftar username
  List<String> get availableUsers => _users.keys.toList();
}
