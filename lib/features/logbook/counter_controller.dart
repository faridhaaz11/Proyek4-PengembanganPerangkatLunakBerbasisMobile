import 'package:shared_preferences/shared_preferences.dart';

class CounterController {
  int _counter = 0; // Variabel private (Enkapsulasi)
  int _step = 1; // default
  final List<String> _history = []; // List untuk menyimpan riwayat
  String _username = ''; // Username untuk history log

  int get value => _counter; // Getter untuk akses data
  int get step => _step;
  List<String> get history => _history; // Getter untuk akses riwayat

  // Set username untuk history log
  void setUsername(String username) {
    _username = username;
  }

  void setStep(int value) {
    if (value > 0) _step = value;
  }

  // ============== DATA PERSISTENCE ==============

  // Key unik per user
  String get _counterKey => 'last_counter_$_username';
  String get _historyKey => 'history_log_$_username';

  // Fungsi untuk menyimpan angka terakhir
  Future<void> saveLastValue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_counterKey, _counter);
  }

  // Fungsi untuk membaca angka terakhir
  Future<int> loadLastValue() async {
    final prefs = await SharedPreferences.getInstance();
    _counter = prefs.getInt(_counterKey) ?? 0;
    return _counter;
  }

  // Fungsi untuk menyimpan riwayat ke SharedPreferences
  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _history);
  }

  // Fungsi untuk membaca riwayat dari SharedPreferences
  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHistory = prefs.getStringList(_historyKey);
    if (savedHistory != null) {
      _history.clear();
      // Ambil hanya 5 riwayat terakhir jika data lama lebih dari 5
      if (savedHistory.length > 5) {
        _history.addAll(savedHistory.sublist(savedHistory.length - 5));
      } else {
        _history.addAll(savedHistory);
      }
    }
  }

  // Fungsi untuk load semua data (counter + history)
  Future<void> loadAllData() async {
    await loadLastValue();
    await loadHistory();
  }

  // Fungsi untuk save semua data (counter + history)
  Future<void> saveAllData() async {
    await saveLastValue();
    await saveHistory();
  }

  // ============== HISTORY LOGGING ==============

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

  // ============== COUNTER OPERATIONS ==============

  Future<void> increment() async {
    _counter += _step;
    _addHistory("$_username menambahkan nilai sebesar $_step");
    await saveAllData(); // Auto save setelah perubahan
  }

  Future<void> decrement() async {
    _counter -= _step;
    _addHistory("$_username mengurangi nilai sebesar $_step");
    await saveAllData(); // Auto save setelah perubahan
  }

  Future<void> reset() async {
    _counter = 0;
    _addHistory("$_username mereset counter ke 0");
    await saveAllData(); // Auto save setelah perubahan
  }
}
