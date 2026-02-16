// login_controller.dart
class LoginController {
  // Database Multiple Users menggunakan Map<String, String>
  // Key = username, Value = password
  final Map<String, String> _users = {
    'admin': '123',
    'faridha': 'password',
    'user1': 'user123',
  };

  // Fungsi pengecekan (Logic-Only)
  // Fungsi untuk mengembalikan true jika username ada dan password cocok
  bool login(String username, String password) {
    // Cek apakah username ada di Map dan passwordnya cocok
    if (_users.containsKey(username) && _users[username] == password) {
      return true;
    }
    return false;
  }

  // Getter untuk mendapatkan daftar username
  List<String> get availableUsers => _users.keys.toList();
}
