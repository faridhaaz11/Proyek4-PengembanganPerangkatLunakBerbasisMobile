import 'package:flutter/material.dart';

import 'package:logbook_app_001/features/auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int step = 1; // Variabel state untuk melacak langkah onboarding

  // Data onboarding
  final List<Map<String, String>> _onboardingData = [
    {
      'image': 'assets/images/welcome.png',
      'title': 'Selamat Datang!',
      'description':
          'Selamat datang di LogBook App!\nAplikasi pencatat counter yang simpel dan mudah digunakan.',
    },
    {
      'image': 'assets/images/catatAktivitas.png',
      'title': 'Catat Aktivitas',
      'description':
          'Catat setiap aktivitas Anda dengan mudah.\nTambah, kurangi, atau reset counter sesuai kebutuhan.',
    },
    {
      'image': 'assets/images/login.png',
      'title': 'Mulai Sekarang',
      'description':
          'Login dengan akun Anda untuk memulai.\nSemua data tersimpan aman dan dapat diakses kapan saja.',
    },
  ];

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
    final currentData = _onboardingData[step - 1];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginView(),
                      ),
                    );
                  },
                  child: const Text(
                    'Lewati',
                    style: TextStyle(color: Color(0xFF7C6DAF), fontSize: 16),
                  ),
                ),
              ),

              const Spacer(),

              // Image
              Image.asset(
                currentData['image']!,
                height: 250,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                currentData['title']!,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B4B8A),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                currentData['description']!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Page indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: step == index + 1 ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: step == index + 1
                          ? const Color(0xFF7C6DAF)
                          : const Color(0xFFE8E0F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C6DAF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    step < 3 ? 'Lanjut' : 'Mulai',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
