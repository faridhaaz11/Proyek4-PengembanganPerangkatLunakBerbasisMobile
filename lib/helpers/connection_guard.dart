import 'package:connectivity_plus/connectivity_plus.dart';

/// Exception khusus yang dilempar saat perangkat tidak terhubung ke internet.
class OfflineException implements Exception {
  final String message;
  const OfflineException([this.message = 'Tidak ada koneksi internet.']);

  @override
  String toString() => message;
}

class ConnectionGuard {
  /// Kembalikan true jika perangkat terhubung ke internet (WiFi / Mobile Data).
  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet,
    );
  }

  /// Lempar [OfflineException] jika perangkat offline.
  static Future<void> ensureOnline() async {
    if (!await isOnline()) {
      throw const OfflineException(
        'Offline Mode: Tidak ada koneksi internet.\n'
        'Sambungkan ke WiFi atau aktifkan data seluler lalu coba lagi.',
      );
    }
  }

  /// Stream yang mengirim status koneksi setiap kali berubah.
  static Stream<bool> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged.map(
        (results) => results.any(
          (r) =>
              r == ConnectivityResult.mobile ||
              r == ConnectivityResult.wifi ||
              r == ConnectivityResult.ethernet,
        ),
      );
}
