// i_mongo_service.dart
// Interface / Contract — Dependency Inversion Principle (SOLID)
//
// LogController bergantung pada abstraksi ini, bukan pada MongoDB konkret.
// Ini memungkinkan kita mengganti implementasi asli dengan MockMongoService
// saat pengujian otomatis tanpa memerlukan koneksi internet.

import 'package:logbook_app_001/features/logbook/models/log_model.dart';

/// Kontrak layanan database yang wajib dipenuhi oleh semua implementasi.
/// Setiap metode merepresentasikan satu operasi CRUD pada koleksi log.
abstract class IMongoService {
  /// Membuka koneksi ke database.
  Future<void> connect();

  /// Menutup koneksi ke database.
  Future<void> close();

  /// Mengambil semua log milik [username] tertentu.
  Future<List<LogModel>> getLogs({required String username});

  /// Mengambil semua log milik tim [teamId] — untuk Collaborative Sync.
  Future<List<LogModel>> getLogsByTeam(String teamId);

  /// Menyisipkan satu dokumen log baru.
  Future<void> insertLog(LogModel log);

  /// Memperbarui dokumen log yang sudah ada berdasarkan ID.
  Future<void> updateLog(LogModel log);

  /// Menghapus dokumen log berdasarkan [id] (hex string ObjectId).
  Future<void> deleteLog(String id);

  /// Sisipkan atau perbarui log — aman dari duplikasi saat sinkronisasi ulang.
  Future<void> upsertLog(LogModel log);
}
