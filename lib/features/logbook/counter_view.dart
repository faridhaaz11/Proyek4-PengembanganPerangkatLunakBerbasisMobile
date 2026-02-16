import 'package:flutter/material.dart';

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
  bool _isLoading = true; // State untuk loading

  @override
  void initState() {
    super.initState();
    _controller.setUsername(widget.username); // Set username untuk history
    _loadData(); // Load data saat halaman dibuka
  }

  // Fungsi untuk load data dari SharedPreferences
  Future<void> _loadData() async {
    await _controller.loadAllData();
    setState(() {
      _isLoading = false;
    });
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

  // Fungsi untuk reset dengan async
  Future<void> _handleReset() async {
    await _controller.reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan loading indicator saat data sedang dimuat
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Logbook: ${widget.username}"),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Logbook: ${widget.username}"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text("Selamat Datang, ${widget.username}!"),
              const SizedBox(height: 10),
              const Text("Total Hitungan Anda:"),
              Text(
                '${_controller.value}',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),

              // Tombol aksi
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _handleDecrement,
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _handleReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _handleIncrement,
                    child: const Icon(Icons.add),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const Text(
                "Riwayat Aktivitas:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Tampilkan riwayat
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _controller.history.isEmpty
                    ? const Center(child: Text("Belum ada aktivitas"))
                    : ListView.builder(
                        itemCount: _controller.history.length,
                        itemBuilder: (context, index) {
                          // Tampilkan dari yang terbaru
                          final reversedIndex =
                              _controller.history.length - 1 - index;
                          final item = _controller.history[reversedIndex];

                          IconData icon = Icons.history;
                          Color iconColor = Colors.grey;

                          if (item.contains("menambah")) {
                            icon = Icons.add_circle;
                            iconColor = Colors.green;
                          } else if (item.contains("mengurangi")) {
                            icon = Icons.remove_circle;
                            iconColor = Colors.red;
                          } else if (item.contains("reset")) {
                            icon = Icons.refresh;
                            iconColor = Colors.orange;
                          }

                          return ListTile(
                            leading: Icon(icon, color: iconColor),
                            title: Text(
                              item,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleIncrement,
        child: const Icon(Icons.add),
      ),
    );
  }
}
