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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LogBook: Versi SRP")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Total Hitungan:"),
            Text('${_controller.value}', style: const TextStyle(fontSize: 40)),

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
                decoration: const InputDecoration(border: OutlineInputBorder()),
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
              height: 200,
              child: _controller.history.isEmpty
                  ? const Center(child: Text("Belum ada aktivitas"))
                  : ListView.builder(
                      itemCount: _controller.history.length,
                      itemBuilder: (context, index) {
                        final item = _controller.history[index];
                        IconData icon = Icons.history;

                        if (item.contains("Menambah")) {
                          icon = Icons.add_circle;
                        } else if (item.contains("Mengurangi")) {
                          icon = Icons.remove_circle;
                        } else if (item.contains("Reset")) {
                          icon = Icons.refresh;
                        }

                        return Card(
                          child: ListTile(
                            leading: Icon(icon, color: Colors.blue),
                            title: Text(
                              item,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "reset",
            onPressed: () => setState(() => _controller.reset()),
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
