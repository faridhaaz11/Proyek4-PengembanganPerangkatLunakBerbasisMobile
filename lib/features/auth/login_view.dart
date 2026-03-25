// login_view.dart
import 'dart:async';

import 'package:flutter/material.dart';

// Import Controller
import 'package:logbook_app_001/features/auth/login_controller.dart';
// Import View dari Logbook untuk navigasi

import 'package:logbook_app_001/features/logbook/log_view.dart';

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
  Timer? _timer;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _controller.tickCountdown();
      if (!_controller.isLoginDisabled) {
        timer.cancel();
      }

      if (mounted) setState(() {});
    });

    if (mounted) setState(() {});
  }

  void _handleLogin() {
    final user = _userController.text.trim();
    final pass = _passController.text;
    final result = _controller.attemptLogin(user, pass);

    if (result.status == LoginActionStatus.success) {
      final userRole = result.role ?? _controller.getRole(user);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LogView(username: user, role: userRole),
        ),
      );
    } else {
      final warningMessage = result.message.contains('tidak boleh kosong!');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: warningMessage ? Colors.orange : Colors.red,
        ),
      );

      if (result.shouldStartCountdown) {
        _startCountdown();
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Login",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5B4B8A),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Gambar Login
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/login.png',
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Header Text
                const Text(
                  "Selamat Datang!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B4B8A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Silakan masuk untuk melanjutkan",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),

                const SizedBox(height: 32),

                // Username Field
                TextField(
                  controller: _userController,
                  decoration: InputDecoration(
                    labelText: "Username",
                    hintText: "Masukkan username",
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF5B4B8A),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF5B4B8A),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F6FB),
                  ),
                ),

                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    hintText: "Masukkan password",
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF5B4B8A),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF5B4B8A),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF5B4B8A),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F6FB),
                  ),
                ),

                const SizedBox(height: 24),

                // Tombol Login
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _controller.isLoginDisabled
                        ? null
                        : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4B8A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _controller.isLoginDisabled
                        ? Text(
                            "Tunggu ${_controller.countdown} detik...",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : const Text(
                            "Masuk",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
