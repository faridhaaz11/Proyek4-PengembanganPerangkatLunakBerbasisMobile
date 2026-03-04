import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart'; // Tetap kita gunakan untuk presisi waktu
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

class LogHelper {
  // Buffer untuk log yang masuk sebelum plugin path_provider siap
  static final List<String> _earlyBuffer = [];
  static bool _pluginReady = false;

  /// Dipanggil dari main.dart setelah runApp() agar plugin siap
  static void markPluginReady() {
    _pluginReady = true;
    if (_earlyBuffer.isNotEmpty) {
      final buffered = List<String>.from(_earlyBuffer);
      _earlyBuffer.clear();
      for (final line in buffered) {
        _appendToFile(line);
      }
    }
  }

  static Future<void> writeLog(
    String message, {
    String source = "Unknown", // Menandakan file/proses asal
    int level = 2,
  }) async {
    // 1. Filter Konfigurasi (ENV)
    final int configLevel = int.tryParse(dotenv.env['LOG_LEVEL'] ?? '2') ?? 2;
    final String muteList = dotenv.env['LOG_MUTE'] ?? '';

    if (level > configLevel) return;
    if (muteList.split(',').contains(source)) return;

    try {
      // 2. Format Waktu untuk Konsol
      String timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      String label = _getLabel(level);
      String color = _getColor(level);

      // 3. Output ke VS Code Debug Console (Non-blocking)
      dev.log(message, name: source, time: DateTime.now(), level: level * 100);

      // 4. Output ke Terminal (Agar Bapak bisa lihat di PC saat flutter run)
      // Format: [14:30:05] [INFO] [log_view.dart] -> Database Terhubung
      print('$color[$timestamp][$label][$source] -> $message\x1B[0m');

      // 5. Tulis ke file log harian
      await _writeToFile(timestamp, label, source, message, level);
    } catch (e) {
      dev.log("Logging failed: $e", name: "SYSTEM", level: 1000);
    }
  }

  static String _getLabel(int level) {
    switch (level) {
      case 1:
        return "ERROR";
      case 2:
        return "INFO";
      case 3:
        return "VERBOSE";
      default:
        return "LOG";
    }
  }

  static String _getColor(int level) {
    switch (level) {
      case 1:
        return '\x1B[31m'; // Merah
      case 2:
        return '\x1B[32m'; // Hijau
      case 3:
        return '\x1B[34m'; // Biru
      default:
        return '\x1B[0m';
    }
  }

  static bool _logPathPrinted = false;

  static Future<void> _writeToFile(
    String timestamp,
    String label,
    String source,
    String message,
    int level,
  ) async {
    final logLine = '[$timestamp][$label][$source] -> $message\n';

    if (!_pluginReady) {
      // Plugin belum siap (sebelum runApp), simpan ke buffer dulu
      _earlyBuffer.add(logLine);
      return;
    }

    _appendToFile(logLine);
  }

  static Future<void> _appendToFile(String logLine) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final logFile = File('${logsDir.path}/$dateStr.log');
      await logFile.writeAsString(logLine, mode: FileMode.append);

      // Cetak path log file sekali saja agar bisa diverifikasi
      if (!_logPathPrinted) {
        _logPathPrinted = true;
        print('\x1B[33m[LOG FILE] -> ${logFile.path}\x1B[0m');
      }
    } catch (e) {
      // Tampilkan error jika penulisan file gagal (membantu debugging)
      print('\x1B[31m[LOG FILE ERROR] -> $e\x1B[0m');
    }
  }
}
