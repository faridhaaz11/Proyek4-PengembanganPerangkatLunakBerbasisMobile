import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/helpers/connection_guard.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/services/i_mongo_service.dart';

class MongoService implements IMongoService {
  static final MongoService _instance = MongoService._internal();

  Db? _db;
  DbCollection? _collection;

  final String _source = "mongo_service.dart";

  factory MongoService() => _instance;
  MongoService._internal();

  Map<String, dynamic> _buildCloudPayload(LogModel log) {
    final payload = log.toMap();
    payload['syncedAt'] ??= DateTime.now().toIso8601String();
    return payload;
  }

  Future<DbCollection> _getSafeCollection() async {
    if (_db == null || !_db!.isConnected || _collection == null) {
      await LogHelper.writeLog(
        "INFO: Koleksi belum siap, mencoba rekoneksi...",
        source: _source,
        level: 3,
      );
      await connect();
    }
    return _collection!;
  }

  @override
  Future<void> connect() async {
    try {
      // Cek koneksi internet sebelum mencoba menghubungi Atlas
      await ConnectionGuard.ensureOnline();

      final dbUri = dotenv.env['MONGODB_URI'];
      if (dbUri == null) throw Exception("MONGODB_URI tidak ditemukan di .env");

      _db = await Db.create(dbUri);

      await _db!.open().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception(
            "Koneksi Timeout. Cek IP Whitelist (0.0.0.0/0) atau Sinyal HP.",
          );
        },
      );

      _collection = _db!.collection('logs');

      await LogHelper.writeLog(
        "DATABASE: Terhubung & Koleksi Siap",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DATABASE: Gagal Koneksi - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  @override
  Future<List<LogModel>> getLogs({required String username}) async {
    try {
      final collection = await _getSafeCollection();
      await LogHelper.writeLog(
        "INFO: Fetching data for user '$username' from Cloud...",
        source: _source,
        level: 3,
      );
      final List<Map<String, dynamic>> data = await collection
          .find(where.eq('username', username))
          .toList();
      return data.map((json) => LogModel.fromMap(json)).toList();
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Fetch Failed - $e",
        source: _source,
        level: 1,
      );
      return [];
    }
  }

  // ── READ by Team (Collaborative Sync — Langkah 4) ────────────────────────
  @override
  Future<List<LogModel>> getLogsByTeam(String teamId) async {
    try {
      final collection = await _getSafeCollection();
      await LogHelper.writeLog(
        "INFO: Fetching data for Team: $teamId",
        source: _source,
        level: 3,
      );
      final List<Map<String, dynamic>> data = await collection
          .find(where.eq('teamId', teamId))
          .toList();
      return data.map((json) => LogModel.fromMap(json)).toList();
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Fetch Failed (Team) - $e",
        source: _source,
        level: 1,
      );
      return [];
    }
  }

  // ── UPSERT (Insert or Replace — mencegah duplikasi) ──────────────────────
  /// Melakukan Insert jika belum ada, atau Replace jika sudah ada.
  /// Digunakan oleh background sync agar tidak menimbulkan dokumen ganda.
  @override
  Future<void> upsertLog(LogModel log) async {
    try {
      if (log.id == null) {
        await insertLog(log);
        return;
      }
      final collection = await _getSafeCollection();
      final payload = _buildCloudPayload(log);
      await collection.replaceOne(
        where.id(ObjectId.fromHexString(log.id!)),
        payload,
        upsert: true, // Insert jika tidak ditemukan, Replace jika ada
      );
      await LogHelper.writeLog(
        "DATABASE: Upsert '${log.title}' Berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DATABASE: Upsert Gagal - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  @override
  Future<void> insertLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      final payload = _buildCloudPayload(log);
      await collection.insertOne(payload);
      await LogHelper.writeLog(
        "SUCCESS: Data '${log.title}' Saved to Cloud",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Insert Failed - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      if (log.id == null) {
        throw Exception("ID Log tidak ditemukan untuk update");
      }
      final payload = _buildCloudPayload(log);
      await collection.replaceOne(
        where.id(ObjectId.fromHexString(log.id!)),
        payload,
      );
      await LogHelper.writeLog(
        "DATABASE: Update '${log.title}' Berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DATABASE: Update Gagal - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteLog(String id) async {
    try {
      final collection = await _getSafeCollection();
      await collection.remove(where.id(ObjectId.fromHexString(id)));
      await LogHelper.writeLog(
        "DATABASE: Hapus ID $id Berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DATABASE: Hapus Gagal - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      await LogHelper.writeLog(
        "DATABASE: Koneksi ditutup",
        source: _source,
        level: 2,
      );
    }
  }
}
