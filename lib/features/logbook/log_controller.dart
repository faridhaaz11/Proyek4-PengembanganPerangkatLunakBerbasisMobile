import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'models/log_model.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier =
      ValueNotifier<List<LogModel>>([]);

  // Getter untuk mempermudah akses list data saat ini
  List<LogModel> get logs => logsNotifier.value;

  // ── CREATE ─────────────────────────────────────────────────────────────────
  Future<void> addLog(
    String title,
    String desc,
    String category,
    String username,
  ) async {
    final newLog = LogModel(
      id: ObjectId(),
      username: username,
      title: title,
      description: desc,
      date: DateTime.now(),
      category: category,
    );
    try {
      await MongoService().insertLog(newLog);
      logsNotifier.value = [...logsNotifier.value, newLog];

      await LogHelper.writeLog(
        "SUCCESS: Tambah data '${newLog.title}'",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Add - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────
  Future<void> updateLog(
    int index,
    String newTitle,
    String newDesc,
    String newCategory,
  ) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final oldLog = currentLogs[index];

    final updatedLog = LogModel(
      id: oldLog.id, // ID harus tetap sama agar MongoDB mengenali dokumen ini
      username: oldLog.username, // Pertahankan username pemilik
      title: newTitle,
      description: newDesc,
      date: DateTime.now(),
      category: newCategory,
    );
    try {
      await MongoService().updateLog(updatedLog);
      currentLogs[index] = updatedLog;
      logsNotifier.value = currentLogs;

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Update '${oldLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Update - $e",
        source: "log_controller.dart",
        level: 1,
      );
      // Data di UI tidak berubah jika proses di Cloud gagal
    }
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  Future<void> removeLog(int index) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final targetLog = currentLogs[index];
    try {
      if (targetLog.id == null) {
        throw Exception(
          "ID Log tidak ditemukan, tidak bisa menghapus di Cloud.",
        );
      }
      await MongoService().deleteLog(targetLog.id!);
      currentLogs.removeAt(index);
      logsNotifier.value = currentLogs;

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Hapus '${targetLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Hapus - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  // ── READ (Cloud) ───────────────────────────────────────────────────────────
  Future<void> loadFromDisk({required String username}) async {
    final cloudData = await MongoService().getLogs(username: username);
    logsNotifier.value = cloudData;
  }
}
