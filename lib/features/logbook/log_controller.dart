import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/log_model.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  // List cadangan untuk hasil pencarian
  ValueNotifier<List<LogModel>> filteredLogs = ValueNotifier([]);
  late String _username;

  LogController([String username = ""]) {
    _username = username;
    loadFromDisk();
    // Inisialisasi filteredLogs dengan data awal
    logsNotifier.addListener(() {
      filteredLogs.value = List<LogModel>.from(logsNotifier.value);
    });
  }

  String get _storageKey => 'user_logs_data_$_username';

  void setUsername(String username) {
    _username = username;
    loadFromDisk();
    // filteredLogs akan diupdate otomatis oleh listener
  }

  // Fitur search/filter log berdasarkan judul
  void searchLog(String query) {
    if (query.isEmpty) {
      filteredLogs.value = List<LogModel>.from(logsNotifier.value);
    } else {
      filteredLogs.value = logsNotifier.value
          .where((log) => log.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  void addLog(String title, String desc, String category) {
    final newLog = LogModel(
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      category: category,
    );
    logsNotifier.value = [...logsNotifier.value, newLog];
    saveToDisk();
  }

  void updateLog(int index, String title, String desc, String category) {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    currentLogs[index] = LogModel(
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      category: category,
    );
    logsNotifier.value = currentLogs;
    saveToDisk();
  }

  void removeLog(int index) {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    currentLogs.removeAt(index);
    logsNotifier.value = currentLogs;
    saveToDisk();
  }

  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      logsNotifier.value.map((e) => e.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      logsNotifier.value = decoded.map((e) => LogModel.fromMap(e)).toList();
    } else {
      logsNotifier.value = [];
    }
  }
}
