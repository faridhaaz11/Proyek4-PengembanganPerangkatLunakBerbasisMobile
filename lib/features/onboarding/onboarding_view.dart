import 'package:flutter/material.dart';

import 'package:logbook_app_001/features/auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int step = 1; // Variabel state untuk melacak langkah onboarding

  void _nextStep() {
    if (step > 2) {
      // Jika step > 3 setelah increment, pindah ke LoginView
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    } else {
      setState(() {
        step++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Judul
            const Text('Halaman Onboarding', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),

            // Nomor step besar
            Text(
              '$step',
              style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 40),

            // Tombol Lanjut
            ElevatedButton(onPressed: _nextStep, child: const Text('Lanjut')),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (step) {
      case 1:
        return const Column(
          children: [
            Icon(Icons.book, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text('Selamat Datang di LogBook App!'),
          ],
        );
      case 2:
        return const Column(
          children: [
            Icon(Icons.edit, size: 100, color: Colors.green),
            SizedBox(height: 20),
            Text('Catat aktivitas harian Anda'),
          ],
        );
      case 3:
        return const Column(
          children: [
            Icon(Icons.login, size: 100, color: Colors.orange),
            SizedBox(height: 20),
            Text('Login untuk memulai'),
          ],
        );
      default:
        return const SizedBox();
    }
  }
}
