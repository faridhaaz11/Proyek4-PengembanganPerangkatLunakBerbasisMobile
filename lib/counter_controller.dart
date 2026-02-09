class CounterController {
  int _counter = 0; // Variabel private (Enkapsulasi)
  int _step = 1; // default
  final List<String> _history = []; // List untuk menyimpan riwayat

  int get value => _counter; // Getter untuk akses data
  int get step => _step;
  List<String> get history => _history; // Getter untuk akses riwayat

  void setStep(int value) {
    if (value > 0) _step = value;
  }

  // Fungsi private untuk menambahkan riwayat dan membatasinya
  void _addHistory(String action) {
    final now = DateTime.now();
    final time =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    _history.add("$action pada jam $time");

    // Batasi hanya 5 riwayat terakhir
    if (_history.length > 5) {
      _history.removeAt(0); // Hapus data paling lama
    }
  }

  void increment() {
    _counter += _step;
    _addHistory("Menambah nilai sebesar $_step");
  }

  void decrement() {
    if (_counter >= _step) {
      _counter -= _step;
      _addHistory("Mengurangi nilai sebesar $_step");
    }
  }

  void reset() {
    _counter = 0;
    _addHistory("Reset counter ke 0");
  }
}
