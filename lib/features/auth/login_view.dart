// login_view.dart
import 'dart:async';

import 'package:flutter/material.dart';

// Import Controller
import 'package:logbook_app_001/features/auth/login_controller.dart';
// Import View dari Logbook untuk navigasi
import 'package:logbook_app_001/features/logbook/counter_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Inisialisasi Otak dan Controller Input
  final LoginController _controller = LoginController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // State untuk Show/Hide Password
  bool _obscurePassword = true;

  // State untuk batas percobaan login
  int _loginAttempts = 0;
  bool _isLoginDisabled = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _isLoginDisabled = true;
      _countdown = 10;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        setState(() {
          _isLoginDisabled = false;
          _loginAttempts = 0; // Reset percobaan setelah countdown selesai
        });
      }
    });
  }

  void _handleLogin() {
    String user = _userController.text.trim();
    String pass = _passController.text;

    // Validasi field tidak boleh kosong
    if (user.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Username tidak boleh kosong!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password tidak boleh kosong!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool isSuccess = _controller.login(user, pass);

    if (isSuccess) {
      // Reset attempts on success
      _loginAttempts = 0;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CounterView(username: user)),
      );
    } else {
      setState(() {
        _loginAttempts++;
      });

      // Cek apakah sudah 3 kali gagal
      if (_loginAttempts >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Terlalu banyak percobaan! Tunggu 10 detik."),
            backgroundColor: Colors.red,
          ),
        );
        _startCountdown();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Gagal! Percobaan ke-$_loginAttempts dari 3"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login Gatekeeper"),
        backgroundColor: const Color(0xFFE8E0F0),
        foregroundColor: const Color(0xFF5B4B8A),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: "Username",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              obscureText: _obscurePassword, // Kontrol show/hide
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock),
                // Ikon mata untuk Show/Hide Password
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Login dengan kondisi disabled
            ElevatedButton(
              onPressed: _isLoginDisabled ? null : _handleLogin,
              child: _isLoginDisabled
                  ? Text("Tunggu $_countdown detik...")
                  : const Text("Masuk"),
            ),

            // Info akun untuk testing
            const SizedBox(height: 30),
            const Text(
              "Akun tersedia:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text("admin / 123"),
            const Text("faridha / password"),
            const Text("user1 / user123"),
          ],
        ),
      ),
    );
  }
}
