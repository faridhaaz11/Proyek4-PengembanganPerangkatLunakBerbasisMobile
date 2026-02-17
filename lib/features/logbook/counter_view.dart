import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:logbook_app_001/features/logbook/counter_controller.dart';
import 'package:logbook_app_001/features/onboarding/onboarding_view.dart';

class CounterView extends StatefulWidget {
  // Tambahkan variabel final untuk menampung nama
  final String username;

  // Update Constructor agar mewajibkan (required) kiriman nama
  const CounterView({super.key, required this.username});

  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {
  final CounterController _controller = CounterController();
  final TextEditingController _stepController = TextEditingController();
  bool _isLoading = true; // State untuk loading

  // Fungsi untuk mendapatkan salam berdasarkan waktu
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      return 'Selamat Pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.setUsername(widget.username); // Set username untuk history
    _stepController.text = _controller.step.toString();
    _loadData(); // Load data saat halaman dibuka
  }

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  // Fungsi untuk load data dari SharedPreferences
  Future<void> _loadData() async {
    await _controller.loadAllData();
    _stepController.text = _controller.step.toString();
    setState(() {
      _isLoading = false;
    });
  }

  // Fungsi untuk update step
  void _updateStep(String value) {
    final step = int.tryParse(value);
    if (step != null && step > 0) {
      _controller.setStep(step);
    }
  }

  // Fungsi untuk increment dengan async
  Future<void> _handleIncrement() async {
    await _controller.increment();
    setState(() {});
  }

  // Fungsi untuk decrement dengan async
  Future<void> _handleDecrement() async {
    await _controller.decrement();
    setState(() {});
  }

  // Fungsi untuk reset dengan konfirmasi dan snackbar
  Future<void> _handleReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Konfirmasi Reset"),
          content: const Text("Apakah Anda yakin ingin mereset counter ke 0?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Ya, Reset",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _controller.reset();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Counter berhasil direset!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan loading indicator saat data sedang dimuat
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF7ECEC1),
        appBar: AppBar(
          title: Text("LogBook: ${widget.username}"),
          backgroundColor: const Color(0xFFE8E0F0),
          foregroundColor: const Color(0xFF5B4B8A),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF7ECEC1),
      appBar: AppBar(
        title: Text("LogBook: ${widget.username}"),
        backgroundColor: const Color(0xFFE8E0F0),
        foregroundColor: const Color(0xFF5B4B8A),
        elevation: 0,
        actions: [
          // Tombol logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Konfirmasi Logout"),
                    content: const Text(
                      "Apakah Anda yakin? Data sudah tersimpan otomatis.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Batal"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingView(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Ya, Keluar",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Welcome Banner
            Container(
              width: double.infinity,
              color: const Color(0xFFE8E0F0),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                '${_getGreeting()}, ${widget.username}!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5B4B8A),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Fixed Header Section (Total Hitungan + Step)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Total Hitungan
                  const Text(
                    "Total Hitungan:",
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  Text(
                    '${_controller.value}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Step Input
                  const Text(
                    "Step:",
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 70,
                    height: 40,
                    child: TextField(
                      controller: _stepController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                      ),
                      onChanged: _updateStep,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Riwayat Aktivitas Title
                  const Text(
                    "Riwayat Aktivitas:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable History Section
            Expanded(
              child: Container(
                color: Colors.white,
                child: _controller.history.isEmpty
                    ? const Center(
                        child: Text(
                          "Belum ada aktivitas",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        itemCount: _controller.history.length,
                        itemBuilder: (context, index) {
                          // Tampilkan dari yang terbaru
                          final reversedIndex =
                              _controller.history.length - 1 - index;
                          final item = _controller.history[reversedIndex];

                          IconData icon = Icons.history;
                          Color iconColor = Colors.grey;
                          Color bgColor = Colors.grey.shade100;

                          if (item.contains("menambahkan")) {
                            icon = Icons.add_circle;
                            iconColor = Colors.green;
                            bgColor = const Color(0xFFE8F5E9);
                          } else if (item.contains("mengurangi")) {
                            icon = Icons.remove_circle;
                            iconColor = Colors.red;
                            bgColor = const Color(0xFFFFEBEE);
                          } else if (item.contains("mereset")) {
                            icon = Icons.change_circle;
                            iconColor = Colors.blue;
                            bgColor = const Color(0xFFE3F2FD);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(icon, color: iconColor, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCircleButton(
            icon: Icons.refresh,
            color: const Color(0xFF7C6DAF),
            onPressed: _handleReset,
          ),
          const SizedBox(width: 12),
          _buildCircleButton(
            icon: Icons.remove,
            color: const Color(0xFF7C6DAF),
            onPressed: _handleDecrement,
          ),
          const SizedBox(width: 12),
          _buildCircleButton(
            icon: Icons.add,
            color: const Color(0xFF7C6DAF),
            onPressed: _handleIncrement,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE8E0F0),
        foregroundColor: const Color(0xFF5B4B8A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(16),
        elevation: 0,
      ),
      child: Icon(icon, size: 24),
    );
  }
}
