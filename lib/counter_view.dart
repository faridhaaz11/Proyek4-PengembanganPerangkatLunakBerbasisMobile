import 'package:flutter/material.dart';
import 'counter_controller.dart';

class CounterView extends StatefulWidget {
  const CounterView({super.key});
  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {
  final CounterController _controller = CounterController();
  final TextEditingController _stepInput = TextEditingController(text: '1');

  // Fungsi untuk menampilkan dialog konfirmasi reset
  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Reset'),
          content: const Text('Apakah Anda yakin ingin mereset counter ke 0?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _controller.reset());
                // Tampilkan SnackBar setelah reset berhasil
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Counter berhasil direset!'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _stepInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LogBook: SRP Version")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Total Hitungan:"),
              Text(
                '${_controller.value}',
                style: const TextStyle(fontSize: 40),
              ),

              const SizedBox(height: 20),

              const Text("Step:"),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _stepInput,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final step = int.tryParse(value) ?? 1;
                    _controller.setStep(step);
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              const Text(
                "Riwayat Aktivitas:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Tampilkan riwayat
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                height: 350,
                child: _controller.history.isEmpty
                    ? const Center(child: Text("Belum ada aktivitas"))
                    : ListView.builder(
                        itemCount: _controller.history.length,
                        itemBuilder: (context, index) {
                          final item = _controller.history[index];
                          IconData icon = Icons.history;
                          Color iconColor = Colors.grey;
                          Color? cardColor;

                          if (item.contains("Menambah")) {
                            icon = Icons.add_circle;
                            iconColor = Colors.green;
                            cardColor = Colors.green.shade50;
                          } else if (item.contains("Mengurangi")) {
                            icon = Icons.remove_circle;
                            iconColor = Colors.red;
                            cardColor = Colors.red.shade50;
                          } else if (item.contains("Reset")) {
                            icon = Icons.refresh;
                            iconColor = Colors.blue;
                            cardColor = Colors.blue.shade50;
                          }

                          return Card(
                            color: cardColor,
                            child: ListTile(
                              leading: Icon(icon, color: iconColor),
                              title: Text(
                                item,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20), // Jarak minimal ke tombol FAB
            ],
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "reset",
            onPressed: () => _showResetConfirmation(),
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            heroTag: "minus",
            onPressed: () => setState(() => _controller.decrement()),
            child: const Icon(Icons.remove),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            heroTag: "plus",
            onPressed: () => setState(() => _controller.increment()),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
