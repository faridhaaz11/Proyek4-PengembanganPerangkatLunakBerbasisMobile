import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:logbook_app_001/helpers/connection_guard.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/services/access_control_service.dart';
import 'package:logbook_app_001/services/i_mongo_service.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'models/log_model.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier =
      ValueNotifier<List<LogModel>>([]);

  /// ID catatan yang belum berhasil tersinkron ke cloud (ditambah saat offline).
  /// Dipakai UI untuk menampilkan ikon cloud yang sesuai per kartu.
  final ValueNotifier<Set<String>> pendingIdsNotifier =
      ValueNotifier<Set<String>>({});

  /// Peran pengguna aktif — validasi RBAC lapis-dua.
  final String userRole;

  /// ID pengguna aktif — pengecekan kepemilikan data.
  final String userId;

  /// ID kelompok — filter Collaborative Sync (Langkah 4).
  final String teamId;

  /// Referensi ke Hive Box yang sudah dibuka di main.dart.
  final Box<LogModel> _myBox;

  /// Implementasi database — bisa diganti MockMongoService saat testing.
  final IMongoService _mongo;

  /// Subscription listener koneksi untuk background sync.
  StreamSubscription<bool>? _connectivitySub;

  LogController({
    this.userRole = 'user',
    this.userId = '',
    this.teamId = 'no_team',
    IMongoService? mongoService,
    Stream<bool>? connectivityStream,
    Box<LogModel>? hiveBox,
  }) : _mongo = mongoService ?? MongoService(),
       _myBox = hiveBox ?? Hive.box<LogModel>('offline_logs') {
    _initBackgroundSyncListener(connectivityStream);
  }

  // Getter untuk mempermudah akses list data saat ini
  List<LogModel> get logs => logsNotifier.value;

  /// Hentikan listener konektivitas saat controller tidak lagi digunakan.
  void dispose() {
    _connectivitySub?.cancel();
  }

  //  TASK 5: DATA PRIVACY FILTER
  /// Mengembalikan daftar log yang boleh dilihat oleh [viewerId].
  ///
  /// Aturan Visibilitas:
  ///   - Log PRIVATE (isPublic: false) → hanya pemilik (authorId == viewerId)
  ///   - Log PUBLIC  (isPublic: true)  → semua anggota tim boleh melihat
  ///
  /// Metode ini memisahkan logika privasi dari UI sehingga dapat diuji
  /// secara independen tanpa perlu menjalankan widget.
  List<LogModel> getVisibleLogs(String viewerId) {
    return logsNotifier.value.where((log) {
      return log.authorId == viewerId || log.isPublic == true;
    }).toList();
  }

  // BACKGROUND SYNC LISTENER
  /// Memantau perubahan koneksi. Jika internet pulih, seluruh data lokal
  /// di-upsert ke Atlas agar data yang tertunda ikut tersinkronkan.
  void _initBackgroundSyncListener([Stream<bool>? stream]) {
    _connectivitySub = (stream ?? ConnectionGuard.onConnectivityChanged).listen(
      (isOnline) async {
        if (!isOnline) return;
        await LogHelper.writeLog(
          "SYNC: Koneksi pulih — memulai background sync ke Atlas...",
          source: "log_controller.dart",
          level: 2,
        );
        await _syncPendingToCloud();
      },
    );
  }

  /// Upsert semua data milik tim ini di Hive ke Atlas.
  /// Hanya sync item dengan teamId yang cocok agar tidak mencampur data antar user.
  Future<void> _syncPendingToCloud() async {
    final localLogs = _myBox.values
        .where((log) => log.teamId == teamId)
        .toList();
    int synced = 0;
    for (final log in localLogs) {
      try {
        // Tandai waktu sync saat berhasil di-upload ke MongoDB
        final syncedLog = LogModel(
          id: log.id,
          username: log.username,
          title: log.title,
          date: log.date, // Tetap preserve waktu creation
          description: log.description,
          category: log.category,
          authorId: log.authorId,
          teamId: log.teamId,
          isPublic: log.isPublic,
          syncedAt: DateTime.now(), // Waktu sync sekarang
        );
        await _mongo.upsertLog(syncedLog);
        // Update di Hive juga dengan syncedAt yang baru
        final hiveIndex = _myBox.values.toList().indexWhere(
          (l) => l.id == log.id,
        );
        if (hiveIndex >= 0) {
          await _myBox.putAt(hiveIndex, syncedLog);
        }
        synced++;
        // Sync berhasil : hapus dari daftar pending agar ikon cloud berubah hijau
        pendingIdsNotifier.value = Set<String>.from(pendingIdsNotifier.value)
          ..remove(log.id);
      } catch (_) {
        // Abaikan error per-item; dicoba lagi saat koneksi berikutnya
      }
    }
    if (synced > 0) {
      await LogHelper.writeLog(
        "SYNC: $synced item berhasil disinkronkan ke Atlas",
        source: "log_controller.dart",
        level: 2,
      );
    }
  }

  // LOAD DATA (Offline-First Strategy)
  Future<void> loadLogs(String filterTeamId) async {
    // Hive (Instan), filter hanya milik tim ini
    logsNotifier.value = _myBox.values
        .where((log) => log.teamId == filterTeamId)
        .toList();

    // PENJAGA OFFLINE
    if (!await ConnectionGuard.isOnline()) {
      await LogHelper.writeLog(
        "OFFLINE: Tidak ada koneksi — menggunakan cache Hive, skip Cloud sync",
        source: "log_controller.dart",
        level: 2,
      );
      return; // Tampilkan data Hive saja, jangan sentuh cloud
    }

    // Sync dari Cloud
    try {
      final cloudData = await _mongo.getLogsByTeam(filterTeamId);

      //  PENJAGA KEDUA: koneksi bisa putus SELAMA request berlangsung
      // getLogsByTeam() mengembalikan [] saat error, sehingga tanpa penjaga
      // ini Hive akan dihapus dengan data kosong palsu lalu catatan hilang.
      if (!await ConnectionGuard.isOnline()) {
        await LogHelper.writeLog(
          "OFFLINE: Koneksi putus saat fetch — mempertahankan cache Hive",
          source: "log_controller.dart",
          level: 2,
        );
        return;
      }

      // MERGE: pertahankan item offline yang belum ada di cloud
      // Item ditambahkan saat offline belum ada di MongoDB (cloudData),
      // namun masih tersimpan di Hive. Identifikasi lewat ID-nya.
      final cloudIds = cloudData.map((l) => l.id).toSet();
      final pendingItems = _myBox.values
          .where(
            (log) => log.teamId == filterTeamId && !cloudIds.contains(log.id),
          )
          .toList();

      // Hapus hanya item tim ini dari Hive, lalu isi kembali
      final keysToDelete = _myBox.keys.where((k) {
        final log = _myBox.get(k);
        return log != null && log.teamId == filterTeamId;
      }).toList();
      for (final key in keysToDelete) {
        await _myBox.delete(key);
      }

      // Tulis kembali: data cloud + item pending yang belum tersinkron
      await _myBox.addAll(cloudData);
      if (pendingItems.isNotEmpty) {
        await _myBox.addAll(pendingItems);
        // Langsung sync item pending ke cloud sekarang karena kita sudah online
        final Set<String> stillPending = {};
        for (final log in pendingItems) {
          try {
            await _mongo.upsertLog(log);
            await LogHelper.writeLog(
              "SYNC: Item pending '${log.title}' berhasil dikirim ke Atlas",
              source: "log_controller.dart",
              level: 2,
            );
          } catch (_) {
            // Gagal sync item ini — tandai masih pending
            if (log.id != null) stillPending.add(log.id!);
          }
        }
        pendingIdsNotifier.value = stillPending;
      } else {
        // Tidak ada item pending — pastikan set pending bersih
        pendingIdsNotifier.value = {};
      }

      logsNotifier.value = [...cloudData, ...pendingItems];

      await LogHelper.writeLog(
        "SYNC: Tim '$filterTeamId' — ${cloudData.length} dari cloud, "
        "${pendingItems.length} item offline pending",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      // Tetap gunakan data cache lokal jika Cloud tidak bisa diakses
      await LogHelper.writeLog(
        "OFFLINE: Menggunakan data cache lokal — $e",
        source: "log_controller.dart",
        level: 2,
      );
    }
  }

  /// Kompatibilitas mundur: load + sync berdasarkan username.
  Future<void> loadFromDisk({required String username}) async {
    // Cache Hive (Instan), filter hanya milik user ini
    logsNotifier.value = _myBox.values
        .where((log) => log.username == username)
        .toList();
    // Skip cloud jika offline
    if (!await ConnectionGuard.isOnline()) return;
    // Sync dari Cloud
    try {
      final cloudData = await _mongo.getLogs(username: username);
      final keysToDelete = _myBox.keys.where((k) {
        final log = _myBox.get(k);
        return log != null && log.username == username;
      }).toList();
      for (final key in keysToDelete) {
        await _myBox.delete(key);
      }
      await _myBox.addAll(cloudData);
      logsNotifier.value = cloudData;
    } catch (e) {
      await LogHelper.writeLog(
        "OFFLINE: loadFromDisk — menggunakan cache lokal",
        source: "log_controller.dart",
        level: 2,
      );
    }
  }

  // CREATE
  Future<void> addLog(
    String title,
    String desc,
    String category,
    String username, {
    bool isPublic = false,
  }) async {
    final newLog = LogModel(
      id: ObjectId().oid,
      username: username,
      title: title,
      description: desc,
      date: DateTime.now(),
      category: category,
      authorId: userId.isEmpty ? username : userId, // RBAC: tandai pemilik data
      teamId: teamId,
      isPublic: isPublic,
    );

    // ACTION 1: Simpan ke Hive : Instan, selalu berhasil
    await _myBox.add(newLog);
    logsNotifier.value = [...logsNotifier.value, newLog];

    // ACTION 2: Kirim ke Atlas di background
    try {
      final syncedLog = LogModel(
        id: newLog.id,
        username: newLog.username,
        title: newLog.title,
        date: newLog.date, // Preserve creation time
        description: newLog.description,
        category: newLog.category,
        authorId: newLog.authorId,
        teamId: newLog.teamId,
        isPublic: newLog.isPublic,
        syncedAt: DateTime.now(), // Waktu sync sekarang
      );
      // Simpan ke cloud dengan syncedAt agar dokumen Mongo langsung berisi 2 waktu
      await _mongo.insertLog(syncedLog);
      // Update di Hive juga dengan syncedAt
      final hiveIndex = _myBox.values.toList().indexWhere(
        (l) => l.id == newLog.id,
      );
      if (hiveIndex >= 0) {
        await _myBox.putAt(hiveIndex, syncedLog);
      }
      logsNotifier.value = logsNotifier.value
          .map((log) => log.id == newLog.id ? syncedLog : log)
          .toList();
      await LogHelper.writeLog(
        "SUCCESS: Data '${newLog.title}' tersinkron ke Cloud",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "WARNING: Data tersimpan lokal, akan sinkron saat online — $e",
        source: "log_controller.dart",
        level: 2,
      );
      // Data tetap di Hive; background sync akan mengirimnya saat online
      // Tandai sebagai pending agar ikon cloud berubah menjadi upload/orange
      if (newLog.id != null) {
        pendingIdsNotifier.value = Set<String>.from(pendingIdsNotifier.value)
          ..add(newLog.id!);
      }
    }
  }

  //  UPDATE
  Future<void> updateLog(
    int index,
    String newTitle,
    String newDesc,
    String newCategory, {
    bool? isPublic,
  }) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final oldLog = currentLogs[index];

    // Data Sovereignty : hanya pemilik yang bisa update
    if (!AccessControlService.canPerform(
      userRole,
      AccessControlService.actionUpdate,
      isOwner: oldLog.authorId == userId,
    )) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Unauthorized update attempt by '$userId' (role: $userRole) on log '${oldLog.title}'",
        source: "log_controller.dart",
        level: 1,
      );
      return;
    }

    final updatedLog = LogModel(
      id: oldLog.id,
      username: oldLog.username,
      title: newTitle,
      description: newDesc,
      date: oldLog.date, // Preserve waktu creation (createdAt)
      category: newCategory,
      authorId: oldLog.authorId,
      teamId: oldLog.teamId,
      isPublic:
          isPublic ??
          oldLog.isPublic, // Pertahankan nilai lama jika tidak diubah
      syncedAt: oldLog.syncedAt, // Preserve sebelumnya, akan update saat sync
    );

    // ACTION 1: Update Hive — Instan
    final hiveIndex = _myBox.values.toList().indexWhere(
      (l) => l.id == oldLog.id,
    );
    if (hiveIndex >= 0) await _myBox.putAt(hiveIndex, updatedLog);
    currentLogs[index] = updatedLog;
    logsNotifier.value = currentLogs;

    // ACTION 2: Update Atlas di background
    try {
      await _mongo.updateLog(updatedLog);
      // Jika berhasil, update syncedAt di Hive juga
      final syncedLog = LogModel(
        id: updatedLog.id,
        username: updatedLog.username,
        title: updatedLog.title,
        date: updatedLog.date, // Preserve creation time
        description: updatedLog.description,
        category: updatedLog.category,
        authorId: updatedLog.authorId,
        teamId: updatedLog.teamId,
        isPublic: updatedLog.isPublic,
        syncedAt: DateTime.now(), // Update waktu sync
      );
      if (hiveIndex >= 0) await _myBox.putAt(hiveIndex, syncedLog);
      currentLogs[index] = syncedLog;
      logsNotifier.value = currentLogs;
      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Update '${oldLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "WARNING: Update tersimpan lokal, akan sinkron saat online — $e",
        source: "log_controller.dart",
        level: 2,
      );
    }
  }

  Future<void> updateLogById(
    String logId,
    String newTitle,
    String newDesc,
    String newCategory, {
    bool? isPublic,
  }) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final index = currentLogs.indexWhere((log) => log.id == logId);
    if (index < 0) {
      throw StateError(
        'Catatan tidak ditemukan. Silakan refresh dan coba lagi.',
      );
    }

    await updateLog(index, newTitle, newDesc, newCategory, isPublic: isPublic);
  }

  //  DELETE
  Future<void> removeLog(int index) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final targetLog = currentLogs[index];

    //  RBAC Lapis Dua
    if (!AccessControlService.canPerform(
      userRole,
      AccessControlService.actionDelete,
      isOwner: targetLog.authorId == userId,
    )) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Unauthorized delete attempt by '$userId' (role: $userRole) on log '${targetLog.title}'",
        source: "log_controller.dart",
        level: 1,
      );
      return;
    }

    // ACTION 1: Hapus dari Hive : Instan
    final hiveIndex = _myBox.values.toList().indexWhere(
      (l) => l.id == targetLog.id,
    );
    if (hiveIndex >= 0) await _myBox.deleteAt(hiveIndex);
    currentLogs.removeAt(index);
    logsNotifier.value = currentLogs;

    // ACTION 2: Hapus dari Atlas di background
    try {
      if (targetLog.id == null) {
        throw Exception(
          "ID Log tidak ditemukan, tidak bisa menghapus di Cloud.",
        );
      }
      await _mongo.deleteLog(targetLog.id!);
      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Hapus '${targetLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "WARNING: Hapus tersimpan lokal, akan sinkron saat online — $e",
        source: "log_controller.dart",
        level: 2,
      );
    }
  }

  Future<void> removeLogById(String logId) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final index = currentLogs.indexWhere((log) => log.id == logId);
    if (index < 0) {
      throw StateError(
        'Catatan tidak ditemukan. Silakan refresh dan coba lagi.',
      );
    }

    await removeLog(index);
  }
}
