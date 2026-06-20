// access_control_service.dart
// Gatekeeper & Security Policy — Centralized Role-Based Access Control (RBAC)

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AccessControlService {
  // Mengambil roles yang tersedia dari .env (APP_ROLES), fallback ke 'Anggota'
  static List<String> get availableRoles =>
      dotenv.env['APP_ROLES']?.split(',') ?? ['Anggota'];

  // Konstanta aksi yang didukung sistem
  static const String actionCreate = 'create';
  static const String actionRead = 'read';
  static const String actionUpdate = 'update';
  static const String actionDelete = 'delete';

  // Matrix perizinan: setiap role memiliki daftar aksi yang diizinkan
  static final Map<String, List<String>> _rolePermissions = {
    'admin': [actionCreate, actionRead, actionUpdate, actionDelete],
    'user': [actionCreate, actionRead],
  };

  /// Memeriksa apakah [role] diperbolehkan menjalankan [action].
  ///
  /// [isOwner] — true jika pengguna ini adalah pemilik data.
  /// Task 5 — Data Sovereignty: Hak Edit & Delete hanya dimiliki pemilik data.
  /// Role 'Ketua' TIDAK lagi memberikan hak edit/hapus atas data orang lain.
  static bool canPerform(String role, String action, {bool isOwner = false}) {
    // Data Sovereignty: Edit & Delete → hanya pemilik yang boleh
    if (action == actionUpdate || action == actionDelete) {
      return isOwner;
    }

    // Untuk aksi lain (create, read), gunakan matrix perizinan role
    final permissions = _rolePermissions[role] ?? [];
    return permissions.contains(action);
  }

  /// Mengembalikan label badge peran untuk ditampilkan di UI.
  static String roleBadge(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'user':
        return 'User';
      default:
        return 'User';
    }
  }
}
